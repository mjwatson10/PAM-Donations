// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {Test} from "forge-std/Test.sol";
import {Diamond} from "../src/diamond/Diamond.sol";
import {DiamondCutFacet} from "../src/diamond/facets/DiamondCutFacet.sol";
import {DiamondLoupeFacet} from "../src/diamond/facets/DiamondLoupeFacet.sol";
import {OwnershipFacet} from "../src/diamond/facets/OwnershipFacet.sol";
import {ERC721AFacet} from "../src/diamond/facets/ERC721AFacet.sol";
import {IDiamondCut} from "../src/diamond/interfaces/IDiamondCut.sol";
import {ERC721A} from "erc721a/contracts/ERC721A.sol";

contract DiamondERC721AFuzzTest is Test {
    Diamond internal diamond;
    ERC721AFacet internal erc721a;
    address internal owner = address(0xABCD);

    function setUp() public {
        vm.prank(owner);
        DiamondCutFacet diamondCutFacet = new DiamondCutFacet();
        diamond = new Diamond(owner, address(diamondCutFacet));

        DiamondLoupeFacet loupeFacet = new DiamondLoupeFacet();
        OwnershipFacet ownershipFacet = new OwnershipFacet();
        ERC721AFacet erc721AFacetImpl = new ERC721AFacet();

        IDiamondCut.FacetCut[] memory cut = new IDiamondCut.FacetCut[](3);

        bytes4[] memory loupeSelectors = new bytes4[](4);
        loupeSelectors[0] = DiamondLoupeFacet.facets.selector;
        loupeSelectors[1] = DiamondLoupeFacet.facetFunctionSelectors.selector;
        loupeSelectors[2] = DiamondLoupeFacet.facetAddresses.selector;
        loupeSelectors[3] = DiamondLoupeFacet.facetAddress.selector;
        cut[0] = IDiamondCut.FacetCut({
            facetAddress: address(loupeFacet),
            action: IDiamondCut.FacetCutAction.Add,
            functionSelectors: loupeSelectors
        });

        bytes4[] memory ownershipSelectors = new bytes4[](2);
        ownershipSelectors[0] = OwnershipFacet.owner.selector;
        ownershipSelectors[1] = OwnershipFacet.transferOwnership.selector;
        cut[1] = IDiamondCut.FacetCut({
            facetAddress: address(ownershipFacet),
            action: IDiamondCut.FacetCutAction.Add,
            functionSelectors: ownershipSelectors
        });

        bytes4[] memory erc721aSelectors = new bytes4[](3);
        erc721aSelectors[0] = ERC721AFacet.erc721aInit.selector;
        erc721aSelectors[1] = ERC721AFacet.mint.selector;
        erc721aSelectors[2] = ERC721A.totalSupply.selector;
        cut[2] = IDiamondCut.FacetCut({
            facetAddress: address(erc721AFacetImpl),
            action: IDiamondCut.FacetCutAction.Add,
            functionSelectors: erc721aSelectors
        });

        vm.prank(owner);
        IDiamondCut(address(diamond)).diamondCut(cut, address(0), "");

        erc721a = ERC721AFacet(address(diamond));

        vm.prank(owner);
        erc721a.erc721aInit("Diamond ERC721A", "DIA", "https://api.example.com/metadata/");
    }

    function testFuzz_MintTotalSupply(address to, uint64 quantity) public {
        vm.assume(to != address(0));
        vm.assume(quantity > 0 && quantity < 1000);

        uint256 beforeSupply = erc721a.totalSupply();

        vm.prank(owner);
        erc721a.mint(to, quantity);

        assertEq(erc721a.totalSupply(), beforeSupply + quantity);
    }
}
