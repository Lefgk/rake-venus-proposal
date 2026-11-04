// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

import "forge-std/Script.sol";
import "./libraries/RescueContractsDeployment.sol";
import "./libraries/AddressesJson.sol";

/// Step 2, run by Venus: deploys the seven RescueDelegateV3s, each bound to the claim contract
/// read from addresses.json, and records them there (.deployed.rescueDelegates.<TOKEN>).
/// The key is read from $PRIVATE_KEY; the deployer gets no power over the delegates.
///
///   forge script script/DeployRescueDelegates.s.sol --fork-url $BSC_RPC_URL              # dry run
///   forge script script/DeployRescueDelegates.s.sol --rpc-url $BSC_RPC_URL --broadcast   # deploy
contract DeployRescueDelegates is Script {
    function run() external {
        address claim = AddressesJson.deployed(".deployed.claimContract", "DeployRakeStuckFundsClaim");

        uint256 pk = vm.envUint("PRIVATE_KEY");
        vm.startBroadcast(pk);
        address[7] memory rescueDelegates = RescueContractsDeployment.deployRescueDelegates(claim);
        vm.stopBroadcast();

        string[7] memory symbols = RakeFrozenPositions.symbols();
        for (uint256 i; i < RakeFrozenPositions.COUNT; ++i) {
            console.log(string.concat("rescue delegate ", symbols[i]), rescueDelegates[i]);
            AddressesJson.record(string.concat(".deployed.rescueDelegates.", symbols[i]), rescueDelegates[i]);
        }
    }
}
