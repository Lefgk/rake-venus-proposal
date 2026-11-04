// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

import "./RakeFrozenPositions.sol";
import "../../src/VenusMarketRescuePatch.sol";
import "../../src/RakeDepositorsClaim.sol";

interface IVTokenImplementation {
    function implementation() external view returns (address);
}

/// How the contracts are deployed, shared by the two deploy scripts and the tests, so both
/// deploy the same way.
library RescueContractsDeployment {
    /// RAKE deploys this (script/DeployRakeDepositorsClaim.s.sol). The caller becomes the claim
    /// contract's owner, fee recipient and beneficiary; its constructor snapshots all 103
    /// depositors' farm shares.
    function deployClaim() internal returns (RakeDepositorsClaim) {
        return new RakeDepositorsClaim();
    }

    /// Venus deploys these (script/DeployVenusMarketRescuePatches.s.sol). One VenusMarketRescuePatch per market,
    /// each bound to its strategy, the claim contract and the market's current implementation
    /// (which the proposal restores). The deployer gets no power over them: only the market
    /// admin can call settleAndRescue().
    function deployRescuePatches(address claim) internal returns (address[7] memory rescuePatches) {
        address[7] memory markets = RakeFrozenPositions.vTokens();
        address[7] memory strategies = RakeFrozenPositions.strategies();
        for (uint256 i; i < RakeFrozenPositions.COUNT; ++i) {
            address current = IVTokenImplementation(markets[i]).implementation();
            require(current == RakeFrozenPositions.VBEP20_DELEGATE_IMPLEMENTATION, "market implementation changed");
            rescuePatches[i] = address(new VenusMarketRescuePatch(strategies[i], claim, current));
        }
    }
}
