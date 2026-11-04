// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

import "forge-std/Script.sol";
import "./RakeFrozenPositions.sol";
import "../src/RescueDelegateV3.sol";

/// The proposal's command list, shared by the script below and by VenusRescueProposal.t.sol,
/// so the commands the tests execute are byte-for-byte the commands Venus is asked to submit.
library VenusRescueProposalCommands {
    /// One Venus Timelock action: it calls `target` with selector(signature) ++ params.
    struct Command {
        address target;
        string signature;
        bytes params;
    }

    /// Number of XVS-settle commands at the start of the list (step 1 below).
    uint256 internal constant XVS_SETTLE_COMMANDS = 2;

    /// 1. Settle the XVS index of the claim contract and the Venus treasury on the seven
    ///    markets, so the vTokens they receive earn no back-dated XVS. Uses the 2-argument
    ///    claimVenus: the 1-argument one walks every market ever listed and reverts on a delisted one.
    /// 2. For each market: accrue interest, swap in its RescueDelegateV3, call settleAndRescue()
    ///    (retires the strategy's debt from its own collateral, moves the net vTokens 20% to the
    ///    Venus treasury and 80% to the claim contract), then restore the original implementation.
    /// 3. Optional: grant the strategies' earned XVS to the claim contract.
    function build(address claim, address[7] memory rescueDelegates, bool includeXvsGrant)
        internal
        view
        returns (Command[] memory c)
    {
        address comptroller = RakeFrozenPositions.VENUS_COMPTROLLER;
        address[7] memory markets = RakeFrozenPositions.vTokens();
        address[] memory marketList = RakeFrozenPositions.vTokenList();

        c = new Command[](XVS_SETTLE_COMMANDS + 4 * RakeFrozenPositions.COUNT + (includeXvsGrant ? 1 : 0));
        uint256 n;
        c[n++] = Command(comptroller, "claimVenus(address,address[])", abi.encode(claim, marketList));
        c[n++] = Command(
            comptroller, "claimVenus(address,address[])", abi.encode(RakeFrozenPositions.VENUS_TREASURY, marketList)
        );
        for (uint256 i; i < RakeFrozenPositions.COUNT; ++i) {
            RescueDelegateV3 d = RescueDelegateV3(rescueDelegates[i]);
            c[n++] = Command(markets[i], "accrueInterest()", "");
            c[n++] = Command(markets[i], "_setImplementation(address,bool,bytes)", abi.encode(address(d), false, ""));
            c[n++] = Command(markets[i], "settleAndRescue()", "");
            c[n++] = Command(
                markets[i], "_setImplementation(address,bool,bytes)", abi.encode(d.ORIGINAL_IMPL(), false, "")
            );
        }
        if (includeXvsGrant) {
            c[n++] = Command(
                comptroller, "_grantXVS(address,uint256)", abi.encode(claim, RakeFrozenPositions.OPTIONAL_XVS_GRANT)
            );
        }
    }

    /// The exact bytes the Timelock sends for a command.
    function callData(Command memory c) internal pure returns (bytes memory) {
        return abi.encodePacked(bytes4(keccak256(bytes(c.signature))), c.params);
    }
}

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
