// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

import "./RakeFrozenPositions.sol";
import "../../src/RescueDelegateV3.sol";
import "../../src/RakeStuckFundsClaim.sol";

interface IVTokenImplementation {
    function implementation() external view returns (address);
}

/// The deployment, shared by script/DeployRescueContracts.s.sol and the tests, so both deploy the same way.
library RescueContractsDeployment {
    /// One claim contract (the caller becomes its owner, fee recipient and beneficiary; it
    /// snapshots all 103 depositors' farm shares in its constructor), then one RescueDelegateV3
    /// per market, each bound to its strategy, the claim contract and the market's current
    /// implementation (which the proposal restores).
    function deploy() internal returns (RakeStuckFundsClaim claim, address[7] memory rescueDelegates) {
        claim = new RakeStuckFundsClaim();
        address[7] memory markets = RakeFrozenPositions.vTokens();
        address[7] memory strategies = RakeFrozenPositions.strategies();
        for (uint256 i; i < RakeFrozenPositions.COUNT; ++i) {
            address current = IVTokenImplementation(markets[i]).implementation();
            require(current == RakeFrozenPositions.VBEP20_DELEGATE_IMPLEMENTATION, "market implementation changed");
            rescueDelegates[i] = address(new RescueDelegateV3(strategies[i], address(claim), current));
        }
    }
}
