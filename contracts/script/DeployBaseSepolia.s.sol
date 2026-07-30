// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Script} from "forge-std/Script.sol";
import {DepositMintNFT} from "src/DepositMintNFT.sol";
import {DepositMintNFTFactory} from "src/DepositMintNFTFactory.sol";

contract DeployBaseSepolia is Script {
    address constant USDC = 0x036CbD53842c5426634e7929541eC2318f3dCF7e;

    string constant NAME = "Deposit Mint NFT";
    string constant SYMBOL = "DMNFT";
    string constant BASE_URI = "";

    function run() external {
        uint256 pk = vm.envUint("PRIVATE_KEY");
        address owner = vm.addr(pk);

        address treasury;
        try vm.envAddress("TREASURY") returns (address t) {
            treasury = t;
        } catch {
            treasury = owner;
        }

        vm.startBroadcast(pk);

        DepositMintNFT implementation = new DepositMintNFT();
        DepositMintNFTFactory factory = new DepositMintNFTFactory(address(implementation), owner);

        address[] memory initialStablecoins = new address[](1);
        bool[] memory initialAllowed = new bool[](1);
        uint8[] memory initialDecimals = new uint8[](1);

        initialStablecoins[0] = USDC;
        initialAllowed[0] = true;
        initialDecimals[0] = 6;

        factory.createCampaign(NAME, SYMBOL, BASE_URI, owner, treasury, initialStablecoins, initialAllowed, initialDecimals);

        vm.stopBroadcast();
    }
}
