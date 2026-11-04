// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

interface IERC20 {
    function totalSupply() external view returns (uint256);
    function balanceOf(address) external view returns (uint256);
    function approve(address, uint256) external returns (bool);
    function transfer(address, uint256) external returns (bool);
    function decimals() external view returns (uint8);
    function symbol() external view returns (string memory);
}

// Venus vToken (Compound VBep20 fork) — the market contracts.
interface IVToken {
    function underlying() external view returns (address);
    function balanceOf(address) external view returns (uint256);
    function balanceOfUnderlying(address) external returns (uint256);
    function borrowBalanceCurrent(address) external returns (uint256);
    function borrowBalanceStored(address) external view returns (uint256);
    function exchangeRateCurrent() external returns (uint256);
    function redeem(uint256 redeemTokens) external returns (uint256);
    function repayBorrowBehalf(address borrower, uint256 amount) external returns (uint256);
    function admin() external view returns (address);
    function implementation() external view returns (address);
    // VBep20Delegator upgrade hook — defined on the delegator itself, admin-only.
    function _setImplementation(
        address implementation_,
        bool allowResign,
        bytes memory becomeImplementationData
    ) external;
}

interface IComptroller {
    function getAccountLiquidity(address) external view returns (uint256, uint256, uint256);
    function closeFactorMantissa() external view returns (uint256);
    function liquidatorContract() external view returns (address);
    function setForcedLiquidation(address vToken, bool enable) external;
    function isForcedLiquidationEnabled(address vToken) external view returns (bool);
}

// Venus official Liquidator router — all core-pool liquidations flow through here.
interface ILiquidator {
    function treasuryPercentMantissa() external view returns (uint256);
    function liquidateBorrow(
        address vToken,
        address borrower,
        uint256 repayAmount,
        address vTokenCollateral
    ) external payable;
}
