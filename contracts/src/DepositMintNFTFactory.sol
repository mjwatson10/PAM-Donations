// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {DepositMintNFT} from "./DepositMintNFT.sol";
import {BeaconProxy} from "@openzeppelin/contracts/proxy/beacon/BeaconProxy.sol";
import {UpgradeableBeacon} from "@openzeppelin/contracts/proxy/beacon/UpgradeableBeacon.sol";

contract DepositMintNFTFactory {
    UpgradeableBeacon public immutable beacon;

    event CampaignCreated(address indexed proxy, address indexed owner, string name, string symbol);

    constructor(address implementation, address beaconOwner) {
        beacon = new UpgradeableBeacon(implementation, beaconOwner);
    }

    function createCampaign(
        string memory name_,
        string memory symbol_,
        string memory baseTokenURI_,
        address initialOwner,
        address treasury_,
        address[] memory initialStablecoins,
        bool[] memory initialAllowed,
        uint8[] memory initialDecimals
    ) external returns (address proxy) {
        bytes memory data = abi.encodeCall(
            DepositMintNFT.initialize,
            (
                name_,
                symbol_,
                baseTokenURI_,
                initialOwner,
                treasury_,
                initialStablecoins,
                initialAllowed,
                initialDecimals
            )
        );
        proxy = address(new BeaconProxy(address(beacon), data));
        emit CampaignCreated(proxy, initialOwner, name_, symbol_);
    }
}
