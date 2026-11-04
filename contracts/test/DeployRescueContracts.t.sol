// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

import "forge-std/Test.sol";
import "../script/libraries/RescueContractsDeployment.sol";

/// Checks script/DeployRescueContracts.s.sol on a BSC fork: what it deploys is wired to the right
/// strategies, markets and implementation, and the claim contract snapshots every depositor
/// before any rescue runs.
contract DeployRescueContractsTest is Test {
    RakeStuckFundsClaim claim;
    address[7] rescueDelegates;

    function setUp() public {
        uint256 b = vm.envOr("FORK_BLOCK", uint256(0));
        if (b == 0) vm.createSelectFork(vm.envString("BSC_RPC_URL"));
        else vm.createSelectFork(vm.envString("BSC_RPC_URL"), b);
        (claim, rescueDelegates) = RescueContractsDeployment.deploy();
    }

    function test_deploy_eachRescueDelegateIsBoundToItsStrategyTheClaimContractAndTheCurrentImplementation()
        public
        view
    {
        address[7] memory markets = RakeFrozenPositions.vTokens();
        address[7] memory strategies = RakeFrozenPositions.strategies();
        for (uint256 i; i < RakeFrozenPositions.COUNT; ++i) {
            RescueDelegateV3 d = RescueDelegateV3(rescueDelegates[i]);
            assertEq(d.STRATEGY(), strategies[i], "strategy");
            assertEq(d.CLAIM(), address(claim), "claim contract");
            assertEq(d.ORIGINAL_IMPL(), IVTokenImplementation(markets[i]).implementation(), "original implementation");
            assertEq(d.TREASURY(), RakeFrozenPositions.VENUS_TREASURY, "treasury");
        }
    }

    function test_deploy_claimContractIsOwnedByTheDeployerAndListsTheSevenUnderlyingsInMarketOrder() public view {
        assertEq(claim.owner(), address(this), "owner");
        assertEq(claim.FEE_RECIPIENT(), address(this), "fee recipient");
        assertEq(claim.BENEFICIARY(), address(this), "beneficiary");
        assertEq(claim.openedAt(), 0, "must not be open");
        address[7] memory markets = RakeFrozenPositions.vTokens();
        for (uint256 i; i < RakeFrozenPositions.COUNT; ++i) {
            assertEq(claim.tokens(i), IVTokenClaim(markets[i]).underlying(), "token order");
        }
    }

    function test_deploy_claimContractSnapshotsAll103DepositorsCoveringEveryPoolsShares() public view {
        address[] memory wallets = claim.builtInWallets();
        assertEq(wallets.length, 103, "wallet count");
        for (uint256 i; i < RakeFrozenPositions.COUNT; ++i) {
            address t = claim.tokens(i);
            uint256 recorded;
            for (uint256 j; j < wallets.length; ++j) {
                assertTrue(claim.recorded(wallets[j]), "wallet not recorded");
                recorded += claim.snapshot(wallets[j], t);
            }
            assertLe(claim.totalShares(t) - recorded, 10, "a pool has unrecorded shares");
        }
    }
}
