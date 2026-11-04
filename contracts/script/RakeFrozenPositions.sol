// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

/// Every on-chain address the rescue touches, in one place (mirrors addresses.json).
/// The seven frozen RAKE positions are RakeFarm pids 9–15, in this order everywhere:
/// BUSD, BTCB, ETH, LINK, USDT, USDC, DOT.
library RakeFrozenPositions {
    uint256 internal constant COUNT = 7;

    address internal constant VENUS_NORMAL_TIMELOCK = 0x939bD8d64c0A9583A7Dcea9933f7b21697ab6396;
    address internal constant VENUS_COMPTROLLER = 0xfD36E2c2a6789Db23113685031d7F16329158384;
    address internal constant VENUS_TREASURY = 0xF322942f644A996A617BD29c16bd7d231d9F35E9;
    address internal constant XVS = 0xcF6BB5389c92Bdda8a3747Ddb454cB7a64626C63;
    /// The implementation all seven markets run today; the rescue restores it.
    address internal constant VBEP20_DELEGATE_IMPLEMENTATION = 0xCDfea50f7CECCB24Fe804657DB8E6c93b689941e;
    address internal constant RAKE_FARM = 0x7f7Bf15B9c68D23339C31652C8e860492991760d;

    /// XVS the seven strategies earned while frozen; the proposal may grant it to the claim contract.
    uint256 internal constant OPTIONAL_XVS_GRANT = 8_021_990798477276016835;

    function symbols() internal pure returns (string[7] memory) {
        return ["BUSD", "BTCB", "ETH", "LINK", "USDT", "USDC", "DOT"];
    }

    /// Venus markets: vBUSD, vBTC, vETH, vLINK, vUSDT, vUSDC, vDOT.
    function vTokens() internal pure returns (address[7] memory) {
        return [
            0x95c78222B3D6e262426483D42CfA53685A67Ab9D,
            0x882C173bC7Ff3b7786CA16dfeD3DFFfb9Ee7847B,
            0xf508fCD89b8bd15579dc79A6827cB4686A3592c8,
            0x650b940a1033B8A1b1873f78730FcFC73ec11f1f,
            0xfD5840Cd36d94D7229439859C0112a4185BC0255,
            0xecA88125a5ADbe82614ffC12D0DB554E2e2867C8,
            0x1610bc33319e9398de5f57B33a5b184c806aD217
        ];
    }

    /// RAKE strategy contracts: the frozen Venus account of each market.
    function strategies() internal pure returns (address[7] memory) {
        return [
            0xDF3df3EE9Fb6D5c9B4fdcF80A92D25d2285A859C,
            0xB3bCA2C1c2C4DF2C903BE3F341C96732Ac8b3c12,
            0x9E3e8878B53c5762Ec6F461701f02ee6d1D9d19C,
            0x0b09Efc9458c00354414D2A560aA6EDa19490169,
            0xc6f470dA6C284D16647CEE2230522a85b0818f6D,
            0x7485704d8B6cEBd1411F5AAfEB063e6f2816069A,
            0x568254EAAC1476faf9A908e577faa3Ab96029801
        ];
    }

    function vTokenList() internal pure returns (address[] memory list) {
        address[7] memory m = vTokens();
        list = new address[](COUNT);
        for (uint256 i; i < COUNT; ++i) list[i] = m[i];
    }
}
