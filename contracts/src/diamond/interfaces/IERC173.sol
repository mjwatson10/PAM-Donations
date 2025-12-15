// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

/// @title IERC173 Ownership Standard
interface IERC173 {
    event OwnershipTransferred(address indexed previousOwner, address indexed newOwner);

    function owner() external view returns (address owner_);

    function transferOwnership(address _newOwner) external;
}
