// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

import "forge-std/Script.sol";
import "./libraries/VenusRescueProposalCommands.sol";

/// Prints the proposal Venus submits, as the four arrays GovernorBravo.propose() takes:
/// targets, values (all 0), signatures, calldatas (ABI-encoded params, without the selector).
/// Reads the deployed claim contract and rescue delegates from addresses.json, so run
/// DeployRescueContracts first. Read-only: sends nothing.
///
///   forge script script/VenusRescueProposal.s.sol --fork-url $BSC_RPC_URL
///   INCLUDE_XVS_GRANT=true forge script script/VenusRescueProposal.s.sol --fork-url $BSC_RPC_URL
contract VenusRescueProposal is Script {
    function run() external {
        string memory json = vm.readFile("../addresses.json");
        address claim = _deployed(json, ".deployed.claimContract");
        string[7] memory symbols = RakeFrozenPositions.symbols();
        address[7] memory rescueDelegates;
        for (uint256 i; i < RakeFrozenPositions.COUNT; ++i) {
            rescueDelegates[i] = _deployed(json, string.concat(".deployed.rescueDelegates.", symbols[i]));
        }
        VenusRescueProposalCommands.Command[] memory c =
            VenusRescueProposalCommands.build(claim, rescueDelegates, vm.envOr("INCLUDE_XVS_GRANT", false));

        address[] memory targets = new address[](c.length);
        uint256[] memory values = new uint256[](c.length);
        string[] memory signatures = new string[](c.length);
        bytes[] memory calldatas = new bytes[](c.length);
        for (uint256 i; i < c.length; ++i) {
            (targets[i], signatures[i], calldatas[i]) = (c[i].target, c[i].signature, c[i].params);
            console.log(string.concat(vm.toString(i), " ", vm.toString(c[i].target), " ", c[i].signature));
        }
        vm.serializeAddress("proposal", "targets", targets);
        vm.serializeUint("proposal", "values", values);
        vm.serializeString("proposal", "signatures", signatures);
        console.log(vm.serializeBytes("proposal", "calldatas", calldatas));
    }

    function _deployed(string memory json, string memory key) internal view returns (address a) {
        try vm.parseJsonAddress(json, key) returns (address parsed) {
            a = parsed;
        } catch {}
        require(a.code.length > 0, string.concat(key, " in addresses.json is not deployed: run DeployRescueContracts first"));
    }
}
