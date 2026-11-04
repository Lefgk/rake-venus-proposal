// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

import "forge-std/Vm.sol";

/// Reads and records deployed addresses in addresses.json (repo root), under ".deployed".
library AddressesJson {
    Vm private constant vm = Vm(address(uint160(uint256(keccak256("hevm cheat code")))));
    string internal constant PATH = "../addresses.json";

    /// A deployed address, or a revert naming the script that deploys it.
    function deployed(string memory key, string memory deployScript) internal view returns (address a) {
        try vm.parseJsonAddress(vm.readFile(PATH), key) returns (address parsed) {
            a = parsed;
        } catch {}
        require(a.code.length > 0, string.concat(key, " in addresses.json is not deployed: run ", deployScript, " first"));
    }

    /// Records an address, only on a real broadcast: a dry run leaves addresses.json alone.
    function record(string memory key, address a) internal {
        if (!vm.isContext(VmSafe.ForgeContext.ScriptBroadcast)) return;
        vm.writeJson(string.concat('"', vm.toString(a), '"'), PATH, key);
    }
}
