// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Script} from "forge-std/Script.sol";
import {DepositMintNFT} from "src/DepositMintNFT.sol";
import {DepositMintNFTFactory} from "src/DepositMintNFTFactory.sol";

/// @notice Foundry script to deploy DepositMintNFT and configure allowed stablecoins.
/// @dev Fill in the token addresses for the target network before running.
contract DeployDepositMintNFT is Script {
    // ====== CONFIGURE THESE PER NETWORK ======
    // Example mainnet addresses (UNSET by default to avoid mistakes). Replace with the correct ones per network.
    address constant USDC = address(0); // e.g., mainnet 0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48 (6 decimals)
    address constant USDT = address(0); // e.g., mainnet 0xdAC17F958D2ee523a2206206994597C13D831ec7 (6 decimals)
    address constant USDE = address(0); // e.g., Ethena USDe proxy on your target chain (likely 18 decimals)

    string constant NAME = "Deposit Mint NFT";
    string constant SYMBOL = "DMNFT";
    string constant BASE_URI = ""; // optional base URI

    function run() external {
        // Set your deployer private key in env var: PRIVATE_KEY
        uint256 pk = vm.envUint("PRIVATE_KEY");
        address owner = vm.addr(pk);
        address treasury = owner;

        vm.startBroadcast(pk);

        // Deploy implementation + factory (factory deploys a beacon owned by `owner`).
        DepositMintNFT implementation = new DepositMintNFT();
        DepositMintNFTFactory factory = new DepositMintNFTFactory(address(implementation), owner);

        uint256 count = 0;
        if (USDC != address(0)) count++;
        if (USDT != address(0)) count++;
        if (USDE != address(0)) count++;

        address[] memory initialStablecoins = new address[](count);
        bool[] memory initialAllowed = new bool[](count);
        uint8[] memory initialDecimals = new uint8[](count);

        uint256 i = 0;
        if (USDC != address(0)) {
            initialStablecoins[i] = USDC;
            initialAllowed[i] = true;
            initialDecimals[i] = 6;
            i++;
        }
        if (USDT != address(0)) {
            initialStablecoins[i] = USDT;
            initialAllowed[i] = true;
            initialDecimals[i] = 6;
            i++;
        }
        if (USDE != address(0)) {
            initialStablecoins[i] = USDE;
            initialAllowed[i] = true;
            initialDecimals[i] = 18;
            i++;
        }

        // Create a campaign proxy initialized with the provided stablecoins.
        address campaign = factory.createCampaign(
            NAME, SYMBOL, BASE_URI, owner, treasury, initialStablecoins, initialAllowed, initialDecimals
        );

        // Silence unused-variable warnings in case you only care about broadcast side effects.
        campaign;

        vm.stopBroadcast();
    }
}
