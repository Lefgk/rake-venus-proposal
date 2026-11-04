// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

import "forge-std/Test.sol";
import "../script/libraries/RescueContractsDeployment.sol";

/// Checks script/DeployRescueDelegates.s.sol on a BSC fork: each of the seven delegates is bound
/// to its own strategy, the RAKE claim contract, the Venus treasury and the market's current
/// implementation, whoever deploys it.
contract DeployRescueDelegatesTest is Test {
    RakeStuckFundsClaim claim;
    address[7] rescueDelegates;

    function setUp() public {
        uint256 b = vm.envOr("FORK_BLOCK", uint256(0));
        if (b == 0) vm.createSelectFork(vm.envString("BSC_RPC_URL"));
        else vm.createSelectFork(vm.envString("BSC_RPC_URL"), b);
        claim = RescueContractsDeployment.deployClaim();
        vm.startPrank(makeAddr("venusDeployer")); // not the claim contract's owner
        rescueDelegates = RescueContractsDeployment.deployRescueDelegates(address(claim));
        vm.stopPrank();
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

    function test_deploy_revertsIfAMarketNoLongerRunsTheExpectedImplementation() public {
        address vBusd = RakeFrozenPositions.vTokens()[0];
        vm.mockCall(vBusd, abi.encodeWithSignature("implementation()"), abi.encode(address(0xBEEF)));
        vm.expectRevert("market implementation changed");
        this.deployDelegatesExternally(address(claim));
    }

    function deployDelegatesExternally(address c) external returns (address[7] memory) {
        return RescueContractsDeployment.deployRescueDelegates(c);
    }
}
