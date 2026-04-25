// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

/**
 * @title ArcanusMathematicaTest
 * @author normancomics.eth — 2026 A.D.
 * @notice Foundry test suite for ArcanusMathematica.sol
 *
 * Run: forge test --match-path test/ArcanusMathematica.t.sol -vvvv
 */

import {Test, console} from "forge-std/Test.sol";
import {ArcanusMathematica} from "../06_Contracts/ArcanusMathematica.sol";

contract ArcanusMathematicaTest is Test {

    ArcanusMathematica nft;

    // Addresses from the deployed constructor allow-lists
    address constant ALWAYS_FREE_1   = 0x3d95D4A6DbaE0Cd0643a82b13A13b08921D6ADf7; // normancomics.eth
    address constant ONE_TIME_FREE_1 = 0x2f1F612A9Ea877A98fd156e6B6086d0a029B8caf; // quincredible.eth

    address owner = address(this);
    address alice = address(0xA11CE);
    address bob   = address(0xB0B);

    function setUp() public {
        nft = new ArcanusMathematica();
        vm.deal(alice, 10 ether);
        vm.deal(bob,   10 ether);
        vm.deal(ALWAYS_FREE_1, 10 ether);
        vm.deal(ONE_TIME_FREE_1, 10 ether);
    }

    // ─── testPublicMintPaid ───────────────────────────────────────────────────

    function testPublicMintPaid() public {
        uint256 price = nft.mintPrice();
        uint256 tokensBefore = nft.totalMinted();

        vm.prank(alice);
        nft.publicMint{value: price}();

        assertEq(nft.totalMinted(), tokensBefore + 1);
        assertEq(nft.ownerOf(1), alice);            // first minted token has ID 1
    }

    // ─── testAlwaysFreeMinter ─────────────────────────────────────────────────

    function testAlwaysFreeMinter() public {
        vm.prank(ALWAYS_FREE_1);
        nft.publicMint{value: 0}();                 // must be free
        assertEq(nft.ownerOf(1), ALWAYS_FREE_1);

        // Can mint a second time for free as well
        vm.prank(ALWAYS_FREE_1);
        nft.publicMint{value: 0}();
        assertEq(nft.ownerOf(2), ALWAYS_FREE_1);
    }

    // ─── testAlwaysFreeMinterETHReverts ───────────────────────────────────────

    function testAlwaysFreeMinterETHReverts() public {
        vm.prank(ALWAYS_FREE_1);
        vm.expectRevert(ArcanusMathematica.EthNotAllowed.selector);
        nft.publicMint{value: 0.001 ether}();
    }

    // ─── testOneTimeFreeMinter ────────────────────────────────────────────────

    function testOneTimeFreeMinter() public {
        assertFalse(nft.hasUsedFreeMint(ONE_TIME_FREE_1));

        vm.prank(ONE_TIME_FREE_1);
        nft.publicMint{value: 0}();                 // first mint: free

        assertTrue(nft.hasUsedFreeMint(ONE_TIME_FREE_1));
        assertEq(nft.ownerOf(1), ONE_TIME_FREE_1);
    }

    // ─── testOneTimeFreeMinterSecondMintPaid ──────────────────────────────────

    function testOneTimeFreeMinterSecondMintPaid() public {
        // Use the free mint
        vm.prank(ONE_TIME_FREE_1);
        nft.publicMint{value: 0}();

        // Second mint must pay
        uint256 price = nft.mintPrice();
        vm.prank(ONE_TIME_FREE_1);
        nft.publicMint{value: price}();

        assertEq(nft.ownerOf(2), ONE_TIME_FREE_1);

        // Third mint without payment should revert
        vm.prank(ONE_TIME_FREE_1);
        vm.expectRevert(ArcanusMathematica.InsufficientETH.selector);
        nft.publicMint{value: 0}();
    }

    // ─── testMaxSupplyCap ─────────────────────────────────────────────────────

    function testMaxSupplyCap() public {
        // Set a very small max supply for the test
        nft.setMaxSupply(2);

        uint256 price = nft.mintPrice();

        vm.prank(alice);
        nft.publicMint{value: price}();

        vm.prank(bob);
        nft.publicMint{value: price}();

        // Third mint must revert
        vm.prank(alice);
        vm.expectRevert(ArcanusMathematica.MaxSupplyReached.selector);
        nft.publicMint{value: price}();
    }

    function testSetMaxSupplyBelowCurrentReverts() public {
        uint256 price = nft.mintPrice();
        vm.prank(alice);
        nft.publicMint{value: price}();

        vm.expectRevert("ArcanusMathematica: below current supply");
        nft.setMaxSupply(0);
    }

    // ─── testTokenURIUpdatable ────────────────────────────────────────────────

    function testTokenURIUpdatable() public {
        uint256 price = nft.mintPrice();
        vm.prank(alice);
        nft.publicMint{value: price}();

        // Check default (base URI)
        string memory defaultURI = nft.tokenURI(1);
        assertGt(bytes(defaultURI).length, 0);

        // Update base URI
        nft.setBaseURI("ipfs://QmNewBaseHash");
        assertEq(nft.tokenURI(1), "ipfs://QmNewBaseHash");

        // Set per-token override
        nft.setTokenURI(1, "ipfs://QmTokenSpecificHash");
        assertEq(nft.tokenURI(1), "ipfs://QmTokenSpecificHash");
    }

    // ─── testWithdraw ─────────────────────────────────────────────────────────

    function testWithdraw() public {
        uint256 price = nft.mintPrice();
        vm.prank(alice);
        nft.publicMint{value: price}();

        uint256 balanceBefore = owner.balance;
        nft.withdraw();
        uint256 balanceAfter = owner.balance;

        assertEq(balanceAfter - balanceBefore, price);
    }

    function testNonOwnerWithdrawReverts() public {
        uint256 price = nft.mintPrice();
        vm.prank(alice);
        nft.publicMint{value: price}();

        vm.prank(bob);
        vm.expectRevert();                          // OZ Ownable revert
        nft.withdraw();
    }

    // ─── testHoldsGrimoire ────────────────────────────────────────────────────

    function testHoldsGrimoire() public {
        assertFalse(nft.holdsGrimoire(alice));

        uint256 price = nft.mintPrice();
        vm.prank(alice);
        nft.publicMint{value: price}();

        assertTrue(nft.holdsGrimoire(alice));
    }

    // ─── testMintGrimoireOwnerOnly ────────────────────────────────────────────

    function testMintGrimoireOwnerOnly() public {
        nft.mintGrimoire(bob);
        assertEq(nft.ownerOf(1), bob);
    }

    function testMintGrimoireNonOwnerReverts() public {
        vm.prank(alice);
        vm.expectRevert();                          // OZ Ownable revert
        nft.mintGrimoire(alice);
    }

    // ─── testTokenIdsStartAt1 ────────────────────────────────────────────────

    function testTokenIdsStartAt1() public {
        assertEq(nft.totalMinted(), 0);

        uint256 price = nft.mintPrice();
        vm.prank(alice);
        nft.publicMint{value: price}();

        assertEq(nft.totalMinted(), 1);
        assertEq(nft.ownerOf(1), alice);
    }

    // ─── receive ETH ─────────────────────────────────────────────────────────

    receive() external payable {}
}
