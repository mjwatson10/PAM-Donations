// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Script} from "forge-std/Script.sol";
import {DepositMintNFT} from "src/DepositMintNFT.sol";

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

        vm.startBroadcast(pk);

        DepositMintNFT nft = new DepositMintNFT(NAME, SYMBOL, BASE_URI, owner);

        // Configure allowed stablecoins if provided
        if (USDC != address(0)) {
            nft.setStablecoin(USDC, true, 6);
        }
        if (USDT != address(0)) {
            nft.setStablecoin(USDT, true, 6);
        }
        if (USDE != address(0)) {
            nft.setStablecoin(USDE, true, 18);
        }

        vm.stopBroadcast();
    }
}
