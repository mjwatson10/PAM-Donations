// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {OwnableUpgradeable} from "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import {Initializable} from "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import {ERC721Upgradeable} from "@openzeppelin/contracts-upgradeable/token/ERC721/ERC721Upgradeable.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

/// @title DepositMintNFT
/// @notice ERC-721A NFT that mints only after a user deposits >= $5 of an allowed stablecoin.
///         Stablecoins are assumed to track $1 per unit; the threshold is enforced using token decimals.
/// @dev Upgradeable ERC-721 that mints only after a user deposits >= $5 of an allowed stablecoin.
contract DepositMintNFT is Initializable, ERC721Upgradeable, OwnableUpgradeable {
    using SafeERC20 for IERC20;

    constructor() {
        _disableInitializers();
    }

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

    address public treasury;

    // Base URI (optional). If empty, tokenURI will be empty.
    string private _baseTokenURI;

    // Next token id to mint. Starts at 1.
    uint256 private _nextTokenId;

    // =====================
    // Events
    // =====================
    event StablecoinUpdated(address indexed token, bool allowed, uint8 decimals);
    event Withdrawn(address indexed token, address indexed to, uint256 amount);
    event TreasuryUpdated(address indexed treasury);
    event Minted(
        address indexed payer, address indexed to, uint256 indexed tokenId, address stablecoin, uint256 amount
    );
    event BatchMinted(
        address indexed payer, address indexed to, uint256[] tokenIds, address stablecoin, uint256 amount
    );

    // =====================
    // Initialization
    // =====================
    function initialize(
        string memory name_,
        string memory symbol_,
        string memory baseTokenURI_,
        address initialOwner,
        address treasury_,
        address[] memory initialStablecoins,
        bool[] memory initialAllowed,
        uint8[] memory initialDecimals
    ) external initializer {
        __ERC721_init(name_, symbol_);
        __Ownable_init(initialOwner);

        require(treasury_ != address(0), "treasury=0");
        treasury = treasury_;
        emit TreasuryUpdated(treasury_);

        _baseTokenURI = baseTokenURI_;
        _nextTokenId = 1;

        require(
            initialStablecoins.length == initialAllowed.length && initialStablecoins.length == initialDecimals.length,
            "initial stablecoin arrays mismatch"
        );
        for (uint256 i = 0; i < initialStablecoins.length; i++) {
            _setStablecoin(initialStablecoins[i], initialAllowed[i], initialDecimals[i]);
        }
    }

    // =====================
    // Admin/manager functions
    // =====================

    /// @notice Set or update an allowed stablecoin and its decimals.
    /// @param token Stablecoin address (e.g., USDC/USDT/USDe)
    /// @param allowed Whether the token is allowed for mint payments
    /// @param decimals_ The token's decimals (e.g., 6 for USDC/USDT, 18 for USDe)
    function setStablecoin(address token, bool allowed, uint8 decimals_) external onlyOwner {
        _setStablecoin(token, allowed, decimals_);
    }

    function _setStablecoin(address token, bool allowed, uint8 decimals_) internal {
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
        require(treasury != address(0), "treasury not set");

        // Calculate price per NFT: $5 * 10^decimals
        uint256 pricePerNFT = MIN_USD * (10 ** uint256(info.decimals));

        // Ensure amount is a multiple of $5
        require(amount >= pricePerNFT, "insufficient amount");
        require(amount % pricePerNFT == 0, "amount must be multiple of $5");

        // Calculate number of NFTs to mint
        uint256 numToMint = amount / pricePerNFT;

        // Pull funds once
        IERC20(stablecoin).safeTransferFrom(msg.sender, treasury, amount);

        // Mint NFTs and construct tokenIds in memory.
        tokenIds = new uint256[](numToMint);
        for (uint256 i = 0; i < numToMint; i++) {
            uint256 tokenId = _nextTokenId;
            _nextTokenId = tokenId + 1;
            _safeMint(to, tokenId);
            tokenIds[i] = tokenId;
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
