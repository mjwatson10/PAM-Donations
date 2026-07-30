// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Script, console2} from "forge-std/Script.sol";
import {DepositMintNFT} from "src/DepositMintNFT.sol";
import {DepositMintNFTFactory} from "src/DepositMintNFTFactory.sol";
import {MockUSDC} from "src/MockUSDC.sol";

contract DeployLocalAnvil is Script {
    function run() external {
        vm.startBroadcast();
        address owner = msg.sender;
        address treasury = owner;

        MockUSDC usdc = new MockUSDC();

        DepositMintNFT implementation = new DepositMintNFT();
        DepositMintNFTFactory factory = new DepositMintNFTFactory(address(implementation), owner);

        address[] memory initialStablecoins = new address[](1);
        bool[] memory initialAllowed = new bool[](1);
        uint8[] memory initialDecimals = new uint8[](1);

        initialStablecoins[0] = address(usdc);
        initialAllowed[0] = true;
        initialDecimals[0] = 6;

        address campaign = factory.createCampaign(
            "Planet-A-mor Local Campaign",
            "PAM",
            "",
            owner,
            treasury,
            initialStablecoins,
            initialAllowed,
            initialDecimals
        );

        usdc.mint(owner, 1_000_000 * 10 ** 6);

        vm.stopBroadcast();

        console2.log("USDC:", address(usdc));
        console2.log("CAMPAIGN:", campaign);
        console2.log("OWNER:", owner);
    }
}
