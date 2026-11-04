// SPDX-License-Identifier: MIT
pragma solidity 0.8.25;

/// @title VenusMarketRescuePatch — self-funded rescue: settle the borrow from the collateral,
///        then move only the net equity.
///
/// @notice A temporary vToken implementation, installed and removed inside ONE Venus VIP
///         transaction. It needs no outside capital: the stuck positions are over-collateralised,
///         and every affected strategy supplies and borrows the SAME underlying asset, so the
///         collateral retires the debt directly. No router, no oracle, no price assumption.
///
/// WHAT IT DOES, PER MARKET
///   1. reads the strategy's live borrow;
///   2. burns exactly enough of the strategy's OWN vTokens to cover it;
///   3. zeroes the strategy's borrow and decrements totalBorrows by the same amount;
///   4. decrements totalSupply by the burned amount; and
///   5. splits the remaining vTokens: 20% to the Venus treasury, 80% to the RAKE claim contract.
///
/// WHY NO OTHER SUPPLIER LOSES ANYTHING
///   exchangeRate = (cash + totalBorrows - totalReserves) * 1e18 / totalSupply
///   Cancelling borrow `d` and burning `d * 1e18 / exchangeRate` of supply gives
///       (N - d) * 1e18 / (TS - d*1e18/ER) == N * 1e18 / TS == ER
///   so the exchange rate is unchanged. `cash` is never touched, so the market's liquidity is
///   unchanged too. The burn is rounded UP, which can only move the rate in the market's
///   favour — the contract asserts it never decreases.
///
/// SEQUENCING
///   Interest must be current, because the exchange rate and the live borrow are both read from
///   stored state. The VIP calls `vToken.accrueInterest()` immediately BEFORE the implementation
///   swap; `settleAndRescue()` reverts unless `accrualBlockNumber == block.number`.
///
/// Runs via delegatecall in the vToken delegator's storage context, so it reads and writes the
/// PROXY's storage. It changes totalSupply and totalBorrows (it retires debt); `cash`,
/// `totalReserves`, `borrowIndex` and the exchange rate are not changed.
///
/// All reads (exchange rate, borrow balance) delegatecall the market's original implementation,
/// so Venus's own arithmetic is authoritative on every market — including vUSDT and vUSDC,
/// where getCash() != underlying.balanceOf(vToken).
contract VenusMarketRescuePatch {
    /// Storage slots on the shared Venus VBep20Delegate, checked against the public getters
    /// (slot value == getter return, exact) on all seven markets:
    ///   slot 10 borrowIndex   slot 11 totalBorrows   slot 13 totalSupply
    ///   slot 14 accountTokens slot 16 accountBorrows slot  9 accrualBlockNumber
    /// Only WRITES rely on these; all reads go through the original implementation. Re-check
    /// them per market at the VIP's filing block.
    uint256 internal constant BORROW_INDEX_SLOT = 10;
    uint256 internal constant TOTAL_BORROWS_SLOT = 11;
    uint256 internal constant TOTAL_SUPPLY_SLOT = 13;
    uint256 internal constant ACCOUNT_TOKENS_SLOT = 14;
    uint256 internal constant ACCOUNT_BORROWS_SLOT = 16;
    uint256 internal constant ACCRUAL_BLOCK_SLOT = 9;

    /// Immutables live in CODE, not storage, so they cannot collide with the proxy's layout.
    address public immutable STRATEGY;
    /// Venus treasury (`Comptroller.treasuryAddress()`), paid 20% of the net vTokens.
    address public constant TREASURY = 0xF322942f644A996A617BD29c16bd7d231d9F35E9;
    uint256 public constant VENUS_BPS = 2_000;
    /// The RAKE claim contract, paid the other 80%. Fixed at deploy.
    address public immutable CLAIM;

    /// The market's ORIGINAL implementation. The patch delegatecalls it for every READ
    /// (exchange rate, borrow balance) so those figures come from Venus's own code rather than
    /// from a reimplementation. This matters: on vUSDT and vUSDC, getCash() does NOT equal
    /// underlying.balanceOf(vToken), so a hand-rolled exchangeRateStored() is wrong for those
    /// two markets. Delegatecalling the real implementation is correct for all seven by
    /// construction, and shrinks the audit surface to the WRITES alone.
    address public immutable ORIGINAL_IMPL;

    event Transfer(address indexed from, address indexed to, uint256 amount);
    event DebtSettledFromCollateral(address indexed strategy, uint256 debtRetired, uint256 vTokensBurned);

    constructor(address strategy_, address claim_, address originalImpl_) {
        require(strategy_ != address(0) && claim_ != address(0) && originalImpl_ != address(0), "zero addr");
        require(strategy_ != claim_ && strategy_ != TREASURY && claim_ != TREASURY, "address clash");
        require(claim_.code.length > 0, "claim not a contract");
        require(originalImpl_.code.length > 0, "impl not a contract");
        STRATEGY = strategy_;
        CLAIM = claim_;
        ORIGINAL_IMPL = originalImpl_;
    }

    // The delegator calls these on the incoming/outgoing implementation during a swap.
    function _becomeImplementation(bytes memory) external {}
    function _resignImplementation() external {}

    /// @notice Live borrow balance of the scoped strategy, per Venus's OWN implementation.
    function scopedBorrowBalance() public returns (uint256) {
        return _readUint(abi.encodeWithSignature("borrowBalanceStored(address)", STRATEGY));
    }

    /// @notice Stored exchange rate, per Venus's OWN implementation.
    /// @dev Delegatecalled into this proxy's storage, so it sees the live (and, after the
    ///      writes below, the updated) state — exactly what Venus itself would report.
    function scopedExchangeRate() public returns (uint256) {
        return _readUint(abi.encodeWithSignature("exchangeRateStored()"));
    }

    /// Delegatecall the original implementation and decode a single uint. Reverts loudly
    /// rather than silently returning zero, which would mis-size the burn.
    function _readUint(bytes memory callData) internal returns (uint256 out) {
        (bool ok, bytes memory ret) = ORIGINAL_IMPL.delegatecall(callData);
        require(ok && ret.length >= 32, "impl read failed");
        out = abi.decode(ret, (uint256));
    }

    /// @notice Retire the strategy's borrow against its own collateral, then move the net.
    /// @return debtRetired   underlying units of borrow cancelled
    /// @return burned        vTokens burned to cover it
    /// @return moved         net vTokens moved out (20% to TREASURY, 80% to CLAIM)
    function settleAndRescue() external returns (uint256 debtRetired, uint256 burned, uint256 moved) {
        // Only the market's own admin (read live, so whichever timelock Venus uses). msg.sender
        // is preserved through the delegator's delegatecall.
        require(msg.sender == address(uint160(_readUint(abi.encodeWithSignature("admin()")))), "only admin");

        // Interest must already be accrued this block, or the borrow and the exchange rate are
        // both stale and the settlement would under-retire the debt.
        uint256 accrualBlock;
        assembly {
            accrualBlock := sload(ACCRUAL_BLOCK_SLOT)
        }
        require(accrualBlock == block.number, "interest not accrued");

        bytes32 fromSlot = keccak256(abi.encode(STRATEGY, ACCOUNT_TOKENS_SLOT));

        uint256 stratTokens;
        uint256 totalSupply_;
        uint256 totalBorrows_;
        assembly {
            stratTokens := sload(fromSlot)
            totalSupply_ := sload(TOTAL_SUPPLY_SLOT)
            totalBorrows_ := sload(TOTAL_BORROWS_SLOT)
        }
        // ONE-SHOT: the first run zeroes this, so a second finds nothing.
        require(stratTokens > 0, "nothing to move");

        uint256 erBefore = scopedExchangeRate();
        debtRetired = scopedBorrowBalance();

        if (debtRetired > 0) {
            // Round UP so the market is never short. Any dust accrues to the remaining
            // suppliers as a marginally higher exchange rate, never a lower one.
            burned = (debtRetired * 1e18 + erBefore - 1) / erBefore;
            // The position must be able to cover its own debt from its own collateral.
            require(burned <= stratTokens, "collateral below debt");
            require(debtRetired <= totalBorrows_, "debt exceeds market borrows");
            require(burned < totalSupply_, "burn exceeds supply");

            bytes32 borrowBase = keccak256(abi.encode(STRATEGY, ACCOUNT_BORROWS_SLOT));
            uint256 bIndex;
            assembly {
                bIndex := sload(BORROW_INDEX_SLOT)
            }

            uint256 newTotalBorrows = totalBorrows_ - debtRetired;
            uint256 newTotalSupply = totalSupply_ - burned;
            uint256 remaining = stratTokens - burned;

            assembly {
                // Strategy's borrow is fully retired. interestIndex is set to the current
                // borrowIndex so the snapshot stays well-formed for any later read.
                sstore(borrowBase, 0)
                sstore(add(borrowBase, 1), bIndex)
                sstore(TOTAL_BORROWS_SLOT, newTotalBorrows)
                sstore(TOTAL_SUPPLY_SLOT, newTotalSupply)
                sstore(fromSlot, remaining)
            }

            stratTokens = remaining;
            emit Transfer(STRATEGY, address(0), burned);
            emit DebtSettledFromCollateral(STRATEGY, debtRetired, burned);
        }

        // The exchange rate must not have fallen. Equality is the expected outcome; the
        // rounding-up of `burned` can only raise it by dust.
        require(scopedExchangeRate() >= erBefore, "exchange rate fell");

        moved = stratTokens;
        require(moved > 0, "nothing left after settlement");

        uint256 toVenus = moved * VENUS_BPS / 10_000;
        bytes32 venusSlot = keccak256(abi.encode(TREASURY, ACCOUNT_TOKENS_SLOT));
        bytes32 claimSlot = keccak256(abi.encode(CLAIM, ACCOUNT_TOKENS_SLOT));
        uint256 venusBal;
        uint256 claimBal;
        assembly {
            venusBal := sload(venusSlot)
            claimBal := sload(claimSlot)
        }
        venusBal += toVenus; // checked outside assembly
        claimBal += moved - toVenus;

        assembly {
            sstore(fromSlot, 0)
            sstore(venusSlot, venusBal)
            sstore(claimSlot, claimBal)
        }

        emit Transfer(STRATEGY, TREASURY, toVenus);
        emit Transfer(STRATEGY, CLAIM, moved - toVenus);
    }

}
