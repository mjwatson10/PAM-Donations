// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {IERC165} from "../interfaces/IERC165.sol";
import {LibERC721ADiamond} from "../libraries/LibERC721ADiamond.sol";
import {LibDiamond} from "../libraries/LibDiamond.sol";
import {ERC721A} from "erc721a/contracts/ERC721A.sol";

contract ERC721AFacet is ERC721A, IERC165 {
    using LibERC721ADiamond for LibERC721ADiamond.ERC721AStorage;

    constructor() ERC721A("", "") {}

    function erc721aInit(string calldata _name, string calldata _symbol, string calldata _baseURI) external {
        LibDiamond.enforceIsContractOwner();
        LibERC721ADiamond.ERC721AStorage storage es = LibERC721ADiamond.erc721AStorage();
        es.name = _name;
        es.symbol = _symbol;
        es.baseURI = _baseURI;
    }

    function name() public view override returns (string memory) {
        return LibERC721ADiamond.erc721AStorage().name;
    }

    function symbol() public view override returns (string memory) {
        return LibERC721ADiamond.erc721AStorage().symbol;
    }

    function _baseURI() internal view override returns (string memory) {
        return LibERC721ADiamond.erc721AStorage().baseURI;
    }

    function mint(address _to, uint256 _quantity) external {
        LibDiamond.enforceIsContractOwner();
        _mint(_to, _quantity);
    }

    function supportsInterface(bytes4 interfaceId) public view override(ERC721A, IERC165) returns (bool) {
        LibDiamond.DiamondStorage storage ds = LibDiamond.diamondStorage();
        return ERC721A.supportsInterface(interfaceId) || ds.supportedInterfaces[interfaceId];
    }
}
