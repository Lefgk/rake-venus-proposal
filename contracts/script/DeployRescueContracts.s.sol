// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

import "forge-std/Script.sol";
import "./RakeFrozenPositions.sol";
import "../src/RescueDelegateV3.sol";
import "../src/RakeStuckFundsClaim.sol";

interface IVTokenImplementation {
    function implementation() external view returns (address);
}

/// The deployment, shared by the script below and by the tests, so both deploy the same way.
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

/// Deploys the claim contract and the seven rescue delegates on BSC, then records their
/// addresses in addresses.json. Must run BEFORE Venus executes the proposal.
/// The key is read from $PRIVATE_KEY; that wallet owns the claim contract and later calls open().
///
///   forge script script/DeployRescueContracts.s.sol --fork-url $BSC_RPC_URL               # dry run
///   forge script script/DeployRescueContracts.s.sol --rpc-url $BSC_RPC_URL --broadcast    # deploy
contract DeployRescueContracts is Script {
    string constant ADDRESSES_JSON = "../addresses.json";

    function run() external {
        uint256 pk = vm.envUint("PRIVATE_KEY");
        vm.startBroadcast(pk);
        (RakeStuckFundsClaim claim, address[7] memory rescueDelegates) = RescueContractsDeployment.deploy();
        vm.stopBroadcast();

        string[7] memory symbols = RakeFrozenPositions.symbols();
        console.log("claim contract", address(claim));
        for (uint256 i; i < RakeFrozenPositions.COUNT; ++i) {
            console.log(string.concat("rescue delegate ", symbols[i]), rescueDelegates[i]);
        }

        // A dry run leaves addresses.json alone; only a real broadcast records the addresses.
        if (!vm.isContext(VmSafe.ForgeContext.ScriptBroadcast)) return;
        vm.writeJson(_quoted(address(claim)), ADDRESSES_JSON, ".deployed.claimContract");
        for (uint256 i; i < RakeFrozenPositions.COUNT; ++i) {
            vm.writeJson(
                _quoted(rescueDelegates[i]), ADDRESSES_JSON, string.concat(".deployed.rescueDelegates.", symbols[i])
            );
        }
    }

    function _quoted(address a) internal pure returns (string memory) {
        return string.concat('"', vm.toString(a), '"');
    }
}
