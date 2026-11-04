// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

import "forge-std/Script.sol";
import "./libraries/RescueContractsDeployment.sol";
import "./libraries/AddressesJson.sol";

/// Step 1 (APPENDIX A2), run by RAKE: deploys the claim contract on BSC and records it in addresses.json
/// (.deployed.claimContract). The key is read from $PRIVATE_KEY; that wallet becomes the owner,
/// fee recipient and beneficiary, and later calls open().
///
///   forge script script/DeployRakeDepositorsClaim.s.sol --fork-url $BSC_RPC_URL              # dry run
///   forge script script/DeployRakeDepositorsClaim.s.sol --rpc-url $BSC_RPC_URL --broadcast   # deploy
contract DeployRakeDepositorsClaim is Script {
    function run() external {
        uint256 pk = vm.envUint("PRIVATE_KEY");
        vm.startBroadcast(pk);
        RakeDepositorsClaim claim = RescueContractsDeployment.deployClaim();
        vm.stopBroadcast();

        console.log("claim contract", address(claim));
        console.log("owner         ", claim.owner());
        AddressesJson.record(".deployed.claimContract", address(claim));
    }
}
