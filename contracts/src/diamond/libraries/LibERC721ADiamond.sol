// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

library LibERC721ADiamond {
    bytes32 internal constant ERC721A_STORAGE_POSITION = keccak256("diamond.standard.erc721a.storage");

    struct ERC721AStorage {
        string name;
        string symbol;
        string baseURI;
    }

    function erc721AStorage() internal pure returns (ERC721AStorage storage es) {
        bytes32 position = ERC721A_STORAGE_POSITION;
        assembly {
            es.slot := position
        }
    }
}
