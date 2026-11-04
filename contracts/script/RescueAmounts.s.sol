// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

import "forge-std/Script.sol";
import "./libraries/RakeFrozenPositions.sol";

interface IVTokenAmounts {
    function balanceOf(address) external view returns (uint256);
    function exchangeRateStored() external view returns (uint256);
    function borrowBalanceStored(address) external view returns (uint256);
}

interface IComptrollerOracle {
    function oracle() external view returns (address);
}

interface IVenusOracle {
    function getUnderlyingPrice(address vToken) external view returns (uint256);
}

/// What the proposal moves, read live from BSC. Read-only: sends nothing.
/// For each of the seven frozen positions: net value = vToken balance × exchange rate − borrow,
/// in tokens and in USD at Venus's own oracle price. Then the split of the total:
/// 20% Venus treasury, 10% founder fee, 70% depositors.
///
///   forge script script/RescueAmounts.s.sol --fork-url $BSC_RPC_URL
///   forge script script/RescueAmounts.s.sol --fork-url $BSC_RPC_URL --fork-block-number 131610085
contract RescueAmounts is Script {
    function run() external view {
        address[7] memory markets = RakeFrozenPositions.vTokens();
        address[7] memory strategies = RakeFrozenPositions.strategies();
        string[7] memory symbols = RakeFrozenPositions.symbols();
        IVenusOracle oracle = IVenusOracle(IComptrollerOracle(RakeFrozenPositions.VENUS_COMPTROLLER).oracle());

        console.log("block", block.number);
        uint256 totalUsd; // 18 decimals
        for (uint256 i; i < RakeFrozenPositions.COUNT; ++i) {
            IVTokenAmounts v = IVTokenAmounts(markets[i]);
            // All seven underlyings have 18 decimals, so the oracle price is USD per token, 1e18-scaled.
            uint256 net = v.balanceOf(strategies[i]) * v.exchangeRateStored() / 1e18 - v.borrowBalanceStored(strategies[i]);
            uint256 usd = net * oracle.getUnderlyingPrice(markets[i]) / 1e18;
            totalUsd += usd;
            console.log(string.concat(symbols[i], "  net ", _decimal(net), " tokens  =  $", _decimal(usd)));
        }
        console.log(string.concat("TOTAL                $", _decimal(totalUsd)));
        console.log(string.concat("Venus treasury 20%   $", _decimal(totalUsd * 20 / 100)));
        console.log(string.concat("Founder fee 10%      $", _decimal(totalUsd * 10 / 100)));
        console.log(string.concat("Depositors 70%       $", _decimal(totalUsd * 70 / 100)));
    }

    /// 18-decimal fixed point to "1234.56".
    function _decimal(uint256 x) internal pure returns (string memory) {
        uint256 cents = x / 1e16 % 100;
        return string.concat(vm.toString(x / 1e18), cents < 10 ? ".0" : ".", vm.toString(cents));
    }
}
