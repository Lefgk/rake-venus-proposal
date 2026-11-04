// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

import "./RakeFrozenPositions.sol";
import "../../src/RescueDelegateV3.sol";
import "../../src/RakeStuckFundsClaim.sol";

interface IVTokenImplementation {
    function implementation() external view returns (address);
}

/// How the contracts are deployed, shared by the two deploy scripts and the tests, so both
/// deploy the same way.
library RescueContractsDeployment {
    /// RAKE deploys this (script/DeployRakeStuckFundsClaim.s.sol). The caller becomes the claim
    /// contract's owner, fee recipient and beneficiary; its constructor snapshots all 103
    /// depositors' farm shares.
    function deployClaim() internal returns (RakeStuckFundsClaim) {
        return new RakeStuckFundsClaim();
    }

    /// Venus deploys these (script/DeployRescueDelegates.s.sol). One RescueDelegateV3 per market,
    /// each bound to its strategy, the claim contract and the market's current implementation
    /// (which the proposal restores). The deployer gets no power over them: only the market
    /// admin can call settleAndRescue().
    function deployRescueDelegates(address claim) internal returns (address[7] memory rescueDelegates) {
        address[7] memory markets = RakeFrozenPositions.vTokens();
        address[7] memory strategies = RakeFrozenPositions.strategies();
        for (uint256 i; i < RakeFrozenPositions.COUNT; ++i) {
            address current = IVTokenImplementation(markets[i]).implementation();
            require(current == RakeFrozenPositions.VBEP20_DELEGATE_IMPLEMENTATION, "market implementation changed");
            rescueDelegates[i] = address(new RescueDelegateV3(strategies[i], claim, current));
        }
    }
}
