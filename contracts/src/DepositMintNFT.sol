// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {ERC721A} from "ERC721A/contracts/ERC721A.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

/// @title DepositMintNFT
/// @notice ERC-721A NFT that mints only after a user deposits >= $5 of an allowed stablecoin.
///         Stablecoins are assumed to track $1 per unit; the threshold is enforced using token decimals.
/// @dev Uses ERC721A for gas-efficient batch minting and OpenZeppelin Ownable for admin management.
contract DepositMintNFT is ERC721A, Ownable {
    using SafeERC20 for IERC20;

    // =====================
    // Stablecoin management
    // =====================
    struct StablecoinInfo {
        bool allowed;
        uint8 decimals;
    }

    mapping(address => StablecoinInfo) public stablecoins; // token => info

    // Minimum USD amount in whole dollars required, fixed at 5 USD
    uint256 public constant MIN_USD = 5;

    // =====================
    // Token state
    // =====================

    // Base URI (optional). If empty, tokenURI will be empty.
    string private _baseTokenURI;

    // =====================
    // Events
    // =====================
    event StablecoinUpdated(address indexed token, bool allowed, uint8 decimals);
    event Withdrawn(address indexed token, address indexed to, uint256 amount);
    event Minted(
        address indexed payer, address indexed to, uint256 indexed tokenId, address stablecoin, uint256 amount
    );
    event BatchMinted(
        address indexed payer, address indexed to, uint256[] tokenIds, address stablecoin, uint256 amount
    );

    // =====================
    // Constructor
    // =====================
    constructor(string memory name_, string memory symbol_, string memory baseTokenURI_, address initialOwner)
        ERC721A(name_, symbol_)
        Ownable(initialOwner)
    {
        _baseTokenURI = baseTokenURI_;
    }

    /// @dev Override start token ID so that token IDs begin at 1 instead of 0.
    function _startTokenId() internal view virtual override returns (uint256) {
        return 1;
    }

    // =====================
    // Admin/manager functions
    // =====================

    /// @notice Set or update an allowed stablecoin and its decimals.
    /// @param token Stablecoin address (e.g., USDC/USDT/USDe)
    /// @param allowed Whether the token is allowed for mint payments
    /// @param decimals_ The token's decimals (e.g., 6 for USDC/USDT, 18 for USDe)
    function setStablecoin(address token, bool allowed, uint8 decimals_) external onlyOwner {
        require(token != address(0), "token=0");
        // sanity check: common decimals are in [6, 18]
        require(decimals_ >= 6 && decimals_ <= 24, "decimals out of range");
        stablecoins[token] = StablecoinInfo({allowed: allowed, decimals: decimals_});
        emit StablecoinUpdated(token, allowed, decimals_);
    }

    /// @notice Withdraw collected ERC20 stablecoins.
    /// @param token ERC20 token to withdraw
    /// @param to Recipient address
    /// @param amount Amount to withdraw
    function withdraw(address token, address to, uint256 amount) external onlyOwner {
        require(to != address(0), "to=0");
        IERC20(token).safeTransfer(to, amount);
        emit Withdrawn(token, to, amount);
    }

    // =====================
    // Minting
    // =====================

    /// @notice Mint NFTs by paying with an allowed stablecoin.
    /// @dev Caller must first approve this contract to spend `amount` of the `stablecoin`.
    ///      The number of NFTs minted = amount / $5 (must be exact multiple of $5).
    /// @param stablecoin Address of the allowed stablecoin
    /// @param amount Amount of stablecoin to transferFrom caller (must be a multiple of $5, minimum $5)
    /// @param to Recipient of the NFTs
    /// @param tokenUri Optional per-token URI; if provided, applied to all minted tokens
    /// @return tokenIds Array of minted token IDs
    function mintWithStablecoin(address stablecoin, uint256 amount, address to, string memory tokenUri)
        external
        returns (uint256[] memory tokenIds)
    {
        StablecoinInfo memory info = stablecoins[stablecoin];
        require(info.allowed, "stablecoin not allowed");
        require(to != address(0), "to=0");

        // Calculate price per NFT: $5 * 10^decimals
        uint256 pricePerNFT = MIN_USD * (10 ** uint256(info.decimals));

        // Ensure amount is a multiple of $5
        require(amount >= pricePerNFT, "insufficient amount");
        require(amount % pricePerNFT == 0, "amount must be multiple of $5");

        // Calculate number of NFTs to mint
        uint256 numToMint = amount / pricePerNFT;

        // Pull funds once
        IERC20(stablecoin).safeTransferFrom(msg.sender, address(this), amount);

        // Mint NFTs in a single ERC721A batch and construct tokenIds in memory.
        uint256 startTokenId = _nextTokenId();
        _mint(to, numToMint);

        tokenIds = new uint256[](numToMint);
        for (uint256 i = 0; i < numToMint; i++) {
            tokenIds[i] = startTokenId + i;
        }

        // tokenUri parameter is kept for API compatibility but no longer used;
        // metadata should be derived from baseURI + tokenId.

        emit BatchMinted(msg.sender, to, tokenIds, stablecoin, amount);
    }

    // =====================
    // Views
    // =====================

    function _baseURI() internal view override returns (string memory) {
        return _baseTokenURI;
    }

    /// @notice Update the base token URI (optional)
    function setBaseTokenURI(string memory newBase) external onlyOwner {
        _baseTokenURI = newBase;
    }
}
