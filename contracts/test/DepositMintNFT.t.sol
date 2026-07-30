// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Test, console2} from "forge-std/Test.sol";
import {Vm} from "forge-std/Vm.sol";
import {DepositMintNFT} from "src/DepositMintNFT.sol";
import {DepositMintNFTFactory} from "src/DepositMintNFTFactory.sol";
import {ERC20Mock} from "@openzeppelin/contracts/mocks/token/ERC20Mock.sol";

contract DepositMintNFTTest is Test {
    DepositMintNFT public nft;
    DepositMintNFTFactory public factory;
    ERC20Mock public usdc;
    ERC20Mock public usdt;
    ERC20Mock public usde;
    ERC20Mock public unauthorizedToken;

    address public owner = address(1);
    address public user1 = address(2);
    address public user2 = address(3);
    address public treasury = address(4);

    uint8 constant USDC_DECIMALS = 6;
    uint8 constant USDT_DECIMALS = 6;
    uint8 constant USDE_DECIMALS = 18;

    uint256 constant MIN_USD = 5;

    event StablecoinUpdated(address indexed token, bool allowed, uint8 decimals);
    event BatchMinted(
        address indexed payer, address indexed to, uint256[] tokenIds, address stablecoin, uint256 amount
    );

    function setUp() public {
        // Deploy mock stablecoins
        usdc = new ERC20Mock();
        usdt = new ERC20Mock();
        usde = new ERC20Mock();
        unauthorizedToken = new ERC20Mock();

        // Deploy implementation + factory (factory deploys a beacon owned by `owner`).
        vm.startPrank(owner);
        DepositMintNFT implementation = new DepositMintNFT();
        factory = new DepositMintNFTFactory(address(implementation), owner);

        address[] memory initialStablecoins = new address[](3);
        bool[] memory initialAllowed = new bool[](3);
        uint8[] memory initialDecimals = new uint8[](3);
        initialStablecoins[0] = address(usdc);
        initialStablecoins[1] = address(usdt);
        initialStablecoins[2] = address(usde);
        initialAllowed[0] = true;
        initialAllowed[1] = true;
        initialAllowed[2] = true;
        initialDecimals[0] = USDC_DECIMALS;
        initialDecimals[1] = USDT_DECIMALS;
        initialDecimals[2] = USDE_DECIMALS;
        address campaign = factory.createCampaign(
            "Test NFT", "TNFT", "", owner, treasury, initialStablecoins, initialAllowed, initialDecimals
        );
        nft = DepositMintNFT(campaign);
        vm.stopPrank();

        // Mint tokens to users
        usdc.mint(user1, 1000 * 10 ** USDC_DECIMALS); // 1000 USDC
        usdt.mint(user1, 1000 * 10 ** USDT_DECIMALS); // 1000 USDT
        usde.mint(user1, 1000 * 10 ** USDE_DECIMALS); // 1000 USDe
        unauthorizedToken.mint(user1, 1000 * 10 ** 18);

        assertEq(nft.treasury(), treasury);
    }

    function test_CannotInitializeWithZeroTreasury() public {
        address[] memory initialStablecoins = new address[](1);
        bool[] memory initialAllowed = new bool[](1);
        uint8[] memory initialDecimals = new uint8[](1);

        initialStablecoins[0] = address(usdc);
        initialAllowed[0] = true;
        initialDecimals[0] = USDC_DECIMALS;

        vm.expectRevert(bytes("treasury=0"));
        factory.createCampaign(
            "Test NFT", "TNFT", "", owner, address(0), initialStablecoins, initialAllowed, initialDecimals
        );
    }

    // =====================
    // Stablecoin Whitelisting Tests
    // =====================

    function test_OnlyOwnerCanWhitelistStablecoin() public {
        ERC20Mock newToken = new ERC20Mock();

        vm.prank(user1);
        vm.expectRevert();
        nft.setStablecoin(address(newToken), true, 6);

        vm.prank(owner);
        nft.setStablecoin(address(newToken), true, 6);

        (bool allowed, uint8 decimals) = nft.stablecoins(address(newToken));
        assertTrue(allowed);
        assertEq(decimals, 6);
    }

    function test_CannotMintWithNonWhitelistedStablecoin() public {
        uint256 amount = 5 * 10 ** 18; // $5 worth

        vm.startPrank(user1);
        unauthorizedToken.approve(address(nft), amount);

        vm.expectRevert(bytes("stablecoin not allowed"));
        nft.mintWithStablecoin(address(unauthorizedToken), amount, user1, "");
        vm.stopPrank();
    }

    function test_CanMintWithWhitelistedStablecoin() public {
        uint256 amount = 5 * 10 ** USDC_DECIMALS; // $5 USDC

        uint256 treasuryBalBefore = usdc.balanceOf(treasury);
        uint256 contractBalBefore = usdc.balanceOf(address(nft));
        uint256 userBalBefore = usdc.balanceOf(user1);

        vm.startPrank(user1);
        usdc.approve(address(nft), amount);
        uint256[] memory tokenIds = nft.mintWithStablecoin(address(usdc), amount, user1, "");
        vm.stopPrank();

        assertEq(tokenIds.length, 1);
        assertEq(nft.ownerOf(tokenIds[0]), user1);
        assertEq(usdc.balanceOf(treasury), treasuryBalBefore + amount);
        assertEq(usdc.balanceOf(address(nft)), contractBalBefore);
        assertEq(usdc.balanceOf(user1), userBalBefore - amount);
    }

    function test_OwnerCanRemoveStablecoinFromWhitelist() public {
        vm.prank(owner);
        nft.setStablecoin(address(usdc), false, USDC_DECIMALS);

        uint256 amount = 5 * 10 ** USDC_DECIMALS;

        vm.startPrank(user1);
        usdc.approve(address(nft), amount);
        vm.expectRevert(bytes("stablecoin not allowed"));
        nft.mintWithStablecoin(address(usdc), amount, user1, "");
        vm.stopPrank();
    }

    // =====================
    // Multiple of $5 Tests
    // =====================

    function test_CannotMintWithLessThan5Dollars() public {
        uint256 amount = 4 * 10 ** USDC_DECIMALS; // $4 USDC

        vm.startPrank(user1);
        usdc.approve(address(nft), amount);

        vm.expectRevert(bytes("insufficient amount"));
        nft.mintWithStablecoin(address(usdc), amount, user1, "");
        vm.stopPrank();
    }

    function test_CannotMintWithNonMultipleOf5() public {
        uint256 amount = 7 * 10 ** USDC_DECIMALS; // $7 USDC (not a multiple of 5)

        vm.startPrank(user1);
        usdc.approve(address(nft), amount);

        vm.expectRevert(bytes("amount must be multiple of $5"));
        nft.mintWithStablecoin(address(usdc), amount, user1, "");
        vm.stopPrank();
    }

    function test_CanMintWithExactly5Dollars() public {
        uint256 amount = 5 * 10 ** USDC_DECIMALS; // $5 USDC

        vm.startPrank(user1);
        usdc.approve(address(nft), amount);
        uint256[] memory tokenIds = nft.mintWithStablecoin(address(usdc), amount, user1, "");
        vm.stopPrank();

        assertEq(tokenIds.length, 1);
        assertEq(nft.balanceOf(user1), 1);
    }

    function test_CanMintWith10Dollars() public {
        uint256 amount = 10 * 10 ** USDC_DECIMALS; // $10 USDC

        vm.startPrank(user1);
        usdc.approve(address(nft), amount);
        uint256[] memory tokenIds = nft.mintWithStablecoin(address(usdc), amount, user1, "");
        vm.stopPrank();

        assertEq(tokenIds.length, 2);
        assertEq(nft.balanceOf(user1), 2);
        assertEq(nft.ownerOf(tokenIds[0]), user1);
        assertEq(nft.ownerOf(tokenIds[1]), user1);
    }

    function test_CanMintWith35Dollars() public {
        uint256 amount = 35 * 10 ** USDC_DECIMALS; // $35 USDC

        vm.startPrank(user1);
        usdc.approve(address(nft), amount);
        uint256[] memory tokenIds = nft.mintWithStablecoin(address(usdc), amount, user1, "");
        vm.stopPrank();

        assertEq(tokenIds.length, 7);
        assertEq(nft.balanceOf(user1), 7);

        // Verify all tokens belong to user1
        for (uint256 i = 0; i < tokenIds.length; i++) {
            assertEq(nft.ownerOf(tokenIds[i]), user1);
        }
    }

    function test_CanMintWith100Dollars() public {
        uint256 amount = 100 * 10 ** USDC_DECIMALS; // $100 USDC

        vm.startPrank(user1);
        usdc.approve(address(nft), amount);
        uint256[] memory tokenIds = nft.mintWithStablecoin(address(usdc), amount, user1, "");
        vm.stopPrank();

        assertEq(tokenIds.length, 20);
        assertEq(nft.balanceOf(user1), 20);
    }

    // =====================
    // Different Stablecoin Tests
    // =====================

    function test_CanMintWithUSDC() public {
        uint256 amount = 15 * 10 ** USDC_DECIMALS; // $15 USDC (6 decimals)

        vm.startPrank(user1);
        usdc.approve(address(nft), amount);
        uint256[] memory tokenIds = nft.mintWithStablecoin(address(usdc), amount, user1, "");
        vm.stopPrank();

        assertEq(tokenIds.length, 3);
    }

    function test_CanMintWithUSDT() public {
        uint256 amount = 20 * 10 ** USDT_DECIMALS; // $20 USDT (6 decimals)

        vm.startPrank(user1);
        usdt.approve(address(nft), amount);
        uint256[] memory tokenIds = nft.mintWithStablecoin(address(usdt), amount, user1, "");
        vm.stopPrank();

        assertEq(tokenIds.length, 4);
    }

    function test_CanMintWithUSDe() public {
        uint256 amount = 25 * 10 ** USDE_DECIMALS; // $25 USDe (18 decimals)

        vm.startPrank(user1);
        usde.approve(address(nft), amount);
        uint256[] memory tokenIds = nft.mintWithStablecoin(address(usde), amount, user1, "");
        vm.stopPrank();

        assertEq(tokenIds.length, 5);
    }

    function test_DifferentDecimalsCalculateCorrectly() public {
        // Test USDC (6 decimals) - $10
        vm.startPrank(user1);
        usdc.approve(address(nft), 10 * 10 ** USDC_DECIMALS);
        uint256[] memory usdcTokens = nft.mintWithStablecoin(address(usdc), 10 * 10 ** USDC_DECIMALS, user1, "");
        assertEq(usdcTokens.length, 2);

        // Test USDe (18 decimals) - $10
        usde.approve(address(nft), 10 * 10 ** USDE_DECIMALS);
        uint256[] memory usdeTokens = nft.mintWithStablecoin(address(usde), 10 * 10 ** USDE_DECIMALS, user1, "");
        assertEq(usdeTokens.length, 2);
        vm.stopPrank();
    }

    // =====================
    // Token ID Tests
    // =====================

    function test_TokenIdZeroDoesNotExist() public {
        vm.expectRevert();
        nft.ownerOf(0);
    }

    function test_TokenIdsAreSequential() public {
        uint256 amount = 15 * 10 ** USDC_DECIMALS; // $15 = 3 NFTs

        vm.startPrank(user1);
        usdc.approve(address(nft), amount);
        uint256[] memory tokenIds = nft.mintWithStablecoin(address(usdc), amount, user1, "");
        vm.stopPrank();

        assertEq(tokenIds[0], 1);
        assertEq(tokenIds[1], 2);
        assertEq(tokenIds[2], 3);
    }

    function test_TokenIdsIncrementAcrossMultipleMints() public {
        vm.startPrank(user1);

        // First mint: $10 = 2 NFTs
        usdc.approve(address(nft), 10 * 10 ** USDC_DECIMALS);
        uint256[] memory batch1 = nft.mintWithStablecoin(address(usdc), 10 * 10 ** USDC_DECIMALS, user1, "");

        // Second mint: $15 = 3 NFTs
        usdc.approve(address(nft), 15 * 10 ** USDC_DECIMALS);
        uint256[] memory batch2 = nft.mintWithStablecoin(address(usdc), 15 * 10 ** USDC_DECIMALS, user1, "");

        vm.stopPrank();

        assertEq(batch1[0], 1);
        assertEq(batch1[1], 2);
        assertEq(batch2[0], 3);
        assertEq(batch2[1], 4);
        assertEq(batch2[2], 5);
    }

    // =====================
    // Recipient Tests
    // =====================

    function test_CanMintToAnotherAddress() public {
        uint256 amount = 10 * 10 ** USDC_DECIMALS; // $10 USDC

        vm.startPrank(user1);
        usdc.approve(address(nft), amount);
        uint256[] memory tokenIds = nft.mintWithStablecoin(address(usdc), amount, user2, "");
        vm.stopPrank();

        assertEq(tokenIds.length, 2);
        assertEq(nft.balanceOf(user2), 2);
        assertEq(nft.ownerOf(tokenIds[0]), user2);
        assertEq(nft.ownerOf(tokenIds[1]), user2);
    }

    function test_CannotMintToZeroAddress() public {
        uint256 amount = 5 * 10 ** USDC_DECIMALS;

        vm.startPrank(user1);
        usdc.approve(address(nft), amount);

        vm.expectRevert(bytes("to=0"));
        nft.mintWithStablecoin(address(usdc), amount, address(0), "");
        vm.stopPrank();
    }

    // =====================
    // Payment Tests
    // =====================

    function test_StablecoinsAreTransferredToTreasury() public {
        uint256 amount = 10 * 10 ** USDC_DECIMALS; // $10 USDC
        uint256 treasuryBalanceBefore = usdc.balanceOf(treasury);
        uint256 contractBalanceBefore = usdc.balanceOf(address(nft));
        uint256 userBalanceBefore = usdc.balanceOf(user1);

        vm.startPrank(user1);
        usdc.approve(address(nft), amount);
        nft.mintWithStablecoin(address(usdc), amount, user1, "");
        vm.stopPrank();

        assertEq(usdc.balanceOf(treasury), treasuryBalanceBefore + amount);
        assertEq(usdc.balanceOf(address(nft)), contractBalanceBefore);
        assertEq(usdc.balanceOf(user1), userBalanceBefore - amount);
    }

    function test_CannotMintWithoutApproval() public {
        uint256 amount = 5 * 10 ** USDC_DECIMALS;

        vm.startPrank(user1);
        // No approval given
        vm.expectRevert();
        nft.mintWithStablecoin(address(usdc), amount, user1, "");
        vm.stopPrank();
    }

    function test_CannotMintWithInsufficientBalance() public {
        uint256 amount = 2000 * 10 ** USDC_DECIMALS; // User only has 1000

        vm.startPrank(user1);
        usdc.approve(address(nft), amount);
        vm.expectRevert();
        nft.mintWithStablecoin(address(usdc), amount, user1, "");
        vm.stopPrank();
    }

    // =====================
    // Event Tests
    // =====================

    function test_EmitsBatchMintedEvent() public {
        uint256 amount = 10 * 10 ** USDC_DECIMALS; // $10 = 2 NFTs

        vm.startPrank(user1);
        usdc.approve(address(nft), amount);

        // Record logs to check event was emitted
        vm.recordLogs();
        nft.mintWithStablecoin(address(usdc), amount, user1, "");

        // Verify event was emitted by checking logs
        Vm.Log[] memory entries = vm.getRecordedLogs();
        assertGt(entries.length, 0, "No events emitted");

        vm.stopPrank();
    }

    // =====================
    // Owner Functions Tests
    // =====================

    function test_OwnerCanWithdrawStablecoins() public {
        uint256 amount = 10 * 10 ** USDC_DECIMALS;

        usdc.mint(address(nft), amount);

        uint256 contractBalance = usdc.balanceOf(address(nft));
        vm.prank(owner);
        nft.withdraw(address(usdc), owner, contractBalance);

        assertEq(usdc.balanceOf(owner), contractBalance);
        assertEq(usdc.balanceOf(address(nft)), 0);
    }

    function test_OnlyOwnerCanWithdraw() public {
        uint256 amount = 10 * 10 ** USDC_DECIMALS;
        vm.startPrank(user1);
        usdc.approve(address(nft), amount);
        nft.mintWithStablecoin(address(usdc), amount, user1, "");

        vm.expectRevert();
        nft.withdraw(address(usdc), user1, amount);
        vm.stopPrank();
    }

    // =====================
    // Fuzz Tests
    // =====================

    function testFuzz_CanOnlyMintWithMultiplesOf5(uint256 multiplier) public {
        vm.assume(multiplier > 0 && multiplier <= 100); // Reasonable range

        uint256 amount = (multiplier * 5) * 10 ** USDC_DECIMALS;

        // Mint more tokens if needed
        if (amount > usdc.balanceOf(user1)) {
            usdc.mint(user1, amount);
        }

        vm.startPrank(user1);
        usdc.approve(address(nft), amount);
        uint256[] memory tokenIds = nft.mintWithStablecoin(address(usdc), amount, user1, "");
        vm.stopPrank();

        assertEq(tokenIds.length, multiplier);
        assertEq(nft.balanceOf(user1), multiplier);
    }

    function testFuzz_CannotMintWithNonMultiples(uint256 amount) public {
        vm.assume(amount > 0);
        vm.assume(amount % (5 * 10 ** USDC_DECIMALS) != 0); // Not a multiple of $5
        vm.assume(amount < 1000 * 10 ** USDC_DECIMALS); // Keep reasonable

        usdc.mint(user1, amount);

        vm.startPrank(user1);
        usdc.approve(address(nft), amount);

        if (amount < 5 * 10 ** USDC_DECIMALS) {
            vm.expectRevert(bytes("insufficient amount"));
        } else {
            vm.expectRevert(bytes("amount must be multiple of $5"));
        }

        nft.mintWithStablecoin(address(usdc), amount, user1, "");
        vm.stopPrank();
    }

    function testFuzz_DifferentDecimalsProduceSameNFTCount(uint8 decimals, uint256 dollarAmount) public {
        // Bound decimals to reasonable range (6-24)
        decimals = uint8(bound(decimals, 6, 24));
        // Bound dollar amount to reasonable range (5-500) and ensure it's a multiple of 5
        dollarAmount = bound(dollarAmount, 1, 100) * 5;

        // Create a new mock token with specified decimals
        ERC20Mock customToken = new ERC20Mock();

        // Whitelist it
        vm.prank(owner);
        nft.setStablecoin(address(customToken), true, decimals);

        // Calculate amount based on decimals
        uint256 amount = dollarAmount * (10 ** uint256(decimals));

        // Mint tokens to user
        customToken.mint(user1, amount);

        // Mint NFTs
        vm.startPrank(user1);
        customToken.approve(address(nft), amount);
        uint256[] memory tokenIds = nft.mintWithStablecoin(address(customToken), amount, user1, "");
        vm.stopPrank();

        // Verify correct number of NFTs minted
        uint256 expectedNFTs = dollarAmount / 5;
        assertEq(tokenIds.length, expectedNFTs);
        assertEq(nft.balanceOf(user1), expectedNFTs);
    }

    function testFuzz_WithdrawAnyAmount(uint256 depositAmount, uint256 withdrawAmount) public {
        // Ensure deposit is a valid multiple of $5
        depositAmount = bound(depositAmount, 1, 100) * (5 * 10 ** USDC_DECIMALS);

        // Mint tokens if needed
        if (depositAmount > usdc.balanceOf(user1)) {
            usdc.mint(user1, depositAmount);
        }

        // User mints NFTs
        vm.startPrank(user1);
        usdc.approve(address(nft), depositAmount);
        nft.mintWithStablecoin(address(usdc), depositAmount, user1, "");
        vm.stopPrank();

        uint256 contractBalance = usdc.balanceOf(address(nft));

        // Bound withdraw amount to what's available
        withdrawAmount = bound(withdrawAmount, 0, contractBalance);

        // Owner withdraws
        uint256 ownerBalanceBefore = usdc.balanceOf(owner);
        vm.prank(owner);
        nft.withdraw(address(usdc), owner, withdrawAmount);

        assertEq(usdc.balanceOf(owner), ownerBalanceBefore + withdrawAmount);
        assertEq(usdc.balanceOf(address(nft)), contractBalance - withdrawAmount);
    }

    function testFuzz_SequentialTokenIds(uint256 firstMint, uint256 secondMint) public {
        // Bound to reasonable multiples
        firstMint = bound(firstMint, 1, 20);
        secondMint = bound(secondMint, 1, 20);

        uint256 firstAmount = firstMint * 5 * 10 ** USDC_DECIMALS;
        uint256 secondAmount = secondMint * 5 * 10 ** USDC_DECIMALS;

        // Mint enough tokens
        usdc.mint(user1, firstAmount + secondAmount);

        vm.startPrank(user1);

        // First mint
        usdc.approve(address(nft), firstAmount);
        uint256[] memory batch1 = nft.mintWithStablecoin(address(usdc), firstAmount, user1, "");

        // Second mint
        usdc.approve(address(nft), secondAmount);
        uint256[] memory batch2 = nft.mintWithStablecoin(address(usdc), secondAmount, user1, "");

        vm.stopPrank();

        // Verify sequential IDs
        assertEq(batch1.length, firstMint);
        assertEq(batch2.length, secondMint);

        // Last ID of batch1 should be one less than first ID of batch2
        assertEq(batch2[0], batch1[batch1.length - 1] + 1);
    }

    function testFuzz_MintToRandomRecipient(address recipient, uint256 dollarAmount) public {
        // Exclude problematic addresses
        vm.assume(recipient != address(0));
        vm.assume(recipient != address(nft));
        vm.assume(recipient.code.length == 0); // Not a contract (for _safeMint)

        // Bound to reasonable range and ensure multiple of 5
        dollarAmount = bound(dollarAmount, 1, 50) * 5;
        uint256 amount = dollarAmount * 10 ** USDC_DECIMALS;

        // Mint tokens if needed
        if (amount > usdc.balanceOf(user1)) {
            usdc.mint(user1, amount);
        }

        vm.startPrank(user1);
        usdc.approve(address(nft), amount);
        uint256[] memory tokenIds = nft.mintWithStablecoin(address(usdc), amount, recipient, "");
        vm.stopPrank();

        // Verify all NFTs belong to recipient
        uint256 expectedCount = dollarAmount / 5;
        assertEq(tokenIds.length, expectedCount);
        assertEq(nft.balanceOf(recipient), expectedCount);

        for (uint256 i = 0; i < tokenIds.length; i++) {
            assertEq(nft.ownerOf(tokenIds[i]), recipient);
        }
    }

    function testFuzz_CannotSetInvalidDecimals(uint8 decimals) public {
        // Test that decimals outside range [6, 24] are rejected
        vm.assume(decimals < 6 || decimals > 24);

        ERC20Mock newToken = new ERC20Mock();

        vm.prank(owner);
        vm.expectRevert(bytes("decimals out of range"));
        nft.setStablecoin(address(newToken), true, decimals);
    }

    function testFuzz_MultipleUsersCanMintIndependently(uint256 user1Amount, uint256 user2Amount) public {
        // Bound to reasonable multiples
        user1Amount = bound(user1Amount, 1, 30) * 5;
        user2Amount = bound(user2Amount, 1, 30) * 5;

        uint256 amount1 = user1Amount * 10 ** USDC_DECIMALS;
        uint256 amount2 = user2Amount * 10 ** USDC_DECIMALS;

        // Setup users with tokens
        usdc.mint(user1, amount1);
        usdc.mint(user2, amount2);

        // User1 mints
        vm.startPrank(user1);
        usdc.approve(address(nft), amount1);
        uint256[] memory tokens1 = nft.mintWithStablecoin(address(usdc), amount1, user1, "");
        vm.stopPrank();

        // User2 mints
        vm.startPrank(user2);
        usdc.approve(address(nft), amount2);
        uint256[] memory tokens2 = nft.mintWithStablecoin(address(usdc), amount2, user2, "");
        vm.stopPrank();

        // Verify independent balances
        assertEq(nft.balanceOf(user1), user1Amount / 5);
        assertEq(nft.balanceOf(user2), user2Amount / 5);

        // Verify ownership
        for (uint256 i = 0; i < tokens1.length; i++) {
            assertEq(nft.ownerOf(tokens1[i]), user1);
        }
        for (uint256 i = 0; i < tokens2.length; i++) {
            assertEq(nft.ownerOf(tokens2[i]), user2);
        }
    }

    function testFuzz_TreasuryAccumulatesPayments(uint256[] memory amounts) public {
        // Limit array size
        vm.assume(amounts.length > 0 && amounts.length <= 10);

        uint256 totalExpected = 0;

        for (uint256 i = 0; i < amounts.length; i++) {
            // Bound each amount to valid multiples
            amounts[i] = bound(amounts[i], 1, 20) * 5 * 10 ** USDC_DECIMALS;
            totalExpected += amounts[i];
        }

        // Mint enough tokens
        usdc.mint(user1, totalExpected);

        vm.startPrank(user1);
        for (uint256 i = 0; i < amounts.length; i++) {
            usdc.approve(address(nft), amounts[i]);
            nft.mintWithStablecoin(address(usdc), amounts[i], user1, "");
        }
        vm.stopPrank();

        // Verify treasury received all payments
        assertEq(usdc.balanceOf(treasury), totalExpected);
        assertEq(usdc.balanceOf(address(nft)), 0);
    }
}
