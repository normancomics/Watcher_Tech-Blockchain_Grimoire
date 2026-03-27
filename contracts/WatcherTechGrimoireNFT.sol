// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

/*
╔══════════════════════════════════════════════════════════════════════════════╗
║                                                                              ║
║    ⛧  W A T C H E R   T E C H   B L O C K C H A I N   G R I M O I R E  ⛧  ║
║                                                                              ║
║                 ✦ ✦ ✦   A N T E D I L U V I A N   ✦ ✦ ✦                    ║
║           T E C H N O L O G I C A L   P R O T O - C A N A A N I T E        ║
║                       B L O C K C H A I N   G R I M O I R E                ║
║                                                                              ║
║                       authored by normancomics.eth                           ║
║                              2026 A.D.                                       ║
╚══════════════════════════════════════════════════════════════════════════════╝

                          ━━━━  PRIMARY SIGIL  ━━━━

                               ╭───────────╮
                            ╭──┤   ╔═══╗   ├──╮
                           ╱   │   ║ ✦ ║   │   ╲
                          ╱  ╭─┤   ╚═══╝   ├─╮  ╲
                         │  ╱  ╰───────────╯  ╲  │
                         │ ╱   ╱ ╲       ╱ ╲   ╲ │
                         │╱   ╱   ╲     ╱   ╲   ╲│
                          ╲  ╱  ⛧  ╲   ╱  ⛧  ╲  ╱
                           ╲╱       ╲ ╱       ╲╱
                           ╱╲       ╱ ╲       ╱╲
                          ╱  ╲     ╱   ╲     ╱  ╲
                         ╱  ⛧ ╲   ╱  ✦  ╲   ╱ ⛧  ╲
                        ╱      ╲ ╱       ╲ ╱      ╲
                       ╱────────X────────X────────╲

                          ━━━━  SEAL OF AZAZEL  ━━━━

                                    /\
                                   /  \
                                  / ⛧  \
                                 /──────\
                                /  /  \  \
                               /  / ✦  \  \
                              /  /──────\  \
                             /  /  /  \  \  \
                            /  /  / ⛧  \  \  \
                           /══════════════════\

                        ━━━━  SEAL OF SEMYAZA  ━━━━

                         ╔══╗   ╔══╗   ╔══╗
                         ║▓▓║───║▓▓║───║▓▓║
                         ╚══╝   ╚══╝   ╚══╝
                           \       |       /
                            \      |      /
                             \     |     /
                              ╔════╧════╗
                              ║  SEMYAZA ║
                              ║  ⛧ ✦ ⛧  ║
                              ╚═════════╝
                             /     |     \
                            /      |      \
                           /       |       \

                       ━━━━  STELLAR GATE SIGIL  ━━━━

                              * . . * . . *
                            .   *       *   .
                           .  *   \   /   *  .
                          *    \   \ /   /    *
                          .     \   X   /     .
                          *    /   / \   \    *
                           .  *   /   \   *  .
                            .   *       *   .
                              * . . * . . *

                      ━━━━  ENOCHIAN BINDING SIGIL  ━━━━

                         ◈━━━━━━━━━━━━━━━━━━━━━◈
                         ┃  ⬡  WATCHER BOUND  ⬡  ┃
                         ┃  ═══════════════════  ┃
                         ┃  ║ FORBIDDEN ARTS ║   ┃
                         ┃  ═══════════════════  ┃
                         ◈━━━━━━━━━━━━━━━━━━━━━◈

 ─────────────────────────────────────────────────────────────────────────────
  "They taught men to make swords… and the art of making bracelets and
   ornaments… and all kinds of costly stones and all colouring tinctures.
   And there arose much godlessness."  — 1 Enoch 8
 ─────────────────────────────────────────────────────────────────────────────
*/

import {ERC721} from "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import {ERC721Enumerable} from "@openzeppelin/contracts/token/ERC721/extensions/ERC721Enumerable.sol";
import {ERC2981} from "@openzeppelin/contracts/token/common/ERC2981.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {ReentrancyGuard} from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import {Strings} from "@openzeppelin/contracts/utils/Strings.sol";

/*
                    ━━━━  THE 13 SIGILS OF THE HOUSES  ━━━━

  ⬡AZAZEL    ⬡SEMYAZA   ⬡ARMAROS   ⬡BARAQEL   ⬡KOKABIEL  ⬡TAMIEL    ⬡RAMIEL
  ⬡DANIEL    ⬡ENOCH     ⬡CAIN      ⬡SETH      ⬡LAMECH    ⬡METHUSELAH

                       ━━━━  7 SAGES / 7 ARTS  ━━━━

      QUETZALCOATL — HERMES — THOTH — OANNES — ENKI — HESIOD — ZIUSUDRA

              [METALLURGY·DIVINATION·CRYPTOGRAPHY·ALCHEMY·ASTRONOMY]
*/

/**
 * @title  WatcherTechGrimoireNFT
 * @author normancomics.eth  —  2026 A.D.
 * @notice ERC-721 NFT collection minting the entire Watcher Tech Blockchain
 *         Grimoire repository on-chain at 0.033 ETH per token.
 *
 *         Each token represents permanent, immutable ownership of one edition
 *         of the Antediluvian Technological Proto-Canaanite Blockchain Grimoire.
 *
 *         Max supply : 333 editions  (sacred number — 3 × 111 = divine triad)
 *         Mint price : 0.033 ETH
 *         Royalties  : 6.66 % on secondary sales (ERC-2981)
 *
 * ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
 *
 *   HOW TO DEPLOY VIA REMIX (remix.ethereum.org)
 *   ─────────────────────────────────────────────
 *   1. Paste this file into a new file in the Remix editor.
 *   2. In "Solidity Compiler" select compiler 0.8.20 and compile.
 *   3. In "Deploy & Run Transactions":
 *        • Environment  → Injected Provider (MetaMask / your wallet)
 *        • Contract     → WatcherTechGrimoireNFT
 *        • Constructor  → paste your IPFS/Arweave metadata base URI
 *                         e.g. ipfs://YOUR_CID/
 *   4. Click Deploy and confirm in MetaMask.
 *   5. Call publicMint() with 0.033 ETH to mint token #0 for yourself.
 *
 * ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
 */
contract WatcherTechGrimoireNFT is
    ERC721,
    ERC721Enumerable,
    ERC2981,
    Ownable,
    ReentrancyGuard
{
    using Strings for uint256;

    // =========================================================================
    //  ⛧  SIGIL OF CONSTANTS
    // =========================================================================

    /*
     *  ╔════════════════════════════╗
     *  ║  MAX SUPPLY  =  333        ║
     *  ║  MINT PRICE  =  0.033 ETH  ║
     *  ║  ROYALTY     =  6.66 %     ║
     *  ╚════════════════════════════╝
     */

    /// @notice Maximum number of grimoire editions ever mintable.
    uint256 public constant MAX_SUPPLY = 333;

    /// @notice Price per token in wei — 0.033 ETH.
    uint256 public mintPrice = 0.033 ether;

    /// @notice ERC-2981 royalty denominator basis: 666 / 10_000 = 6.66 %.
    uint96  public constant ROYALTY_BPS = 666;

    // On-chain grimoire identity strings
    string public constant GRIMOIRE_TITLE =
        "Watcher Tech Blockchain Grimoire";
    string public constant GRIMOIRE_SUBTITLE =
        "Antediluvian Technological Proto-Canaanite Blockchain Grimoire";
    string public constant GRIMOIRE_AUTHOR =
        "normancomics.eth";
    string public constant GRIMOIRE_LORE =
        "An on-chain grimoire reverse-engineering antediluvian Watcher "
        "transmissions into modern blockchain, DeFi, AI, and quantum frameworks. "
        "Educational security research + esoteric alchemy. "
        "Compiled from the Book of Enoch, Zohar, Testament of Solomon, "
        "and Solomonic Grimoires. Preserved as a permanent immutable blockchain grimoire.";

    // =========================================================================
    //  ⛧  SIGIL OF STATE
    // =========================================================================

    /// @dev Token ID counter (0-indexed; first token is #0).
    uint256 private _nextTokenId;

    /// @dev Base URI for token metadata (set at construction; owner-updatable).
    string private _baseTokenURI;

    // ─── Always-free minters ─────────────────────────────────────────────────
    /// @dev Unlimited free mints; msg.value MUST be 0.
    mapping(address => bool) private _alwaysFreeMinters;

    // ─── One-time-free minters ────────────────────────────────────────────────
    /// @dev First mint is free; subsequent mints require mintPrice.
    mapping(address => bool) private _oneTimeFreeMinters;
    mapping(address => bool) private _usedFreeMint;

    // =========================================================================
    //  ⛧  SIGIL OF EVENTS
    // =========================================================================

    event GrimoireMinted(
        address indexed minter,
        uint256 indexed tokenId,
        uint256 pricePaid
    );
    event MintPriceUpdated(uint256 oldPrice, uint256 newPrice);
    event Withdrawn(address indexed to, uint256 amount);

    // =========================================================================
    //  ⛧  SIGIL OF ERRORS
    // =========================================================================

    error MaxSupplyReached();
    error InsufficientETH();
    error EthNotAllowed();
    error WithdrawFailed();

    // =========================================================================
    //  ⛧  CONSTRUCTOR — THE FIRST INVOCATION
    //
    //     "In the beginning the Watchers descended upon Mount Hermon,
    //      and they bound themselves by mutual imprecations."
    //                                           — 1 Enoch 6:6
    // =========================================================================

    /*
     *       ╭───────────────────────────────────────╮
     *       │   DEPLOY SIGIL — paste your CID here  │
     *       │   e.g. "ipfs://YOUR_METADATA_CID/"     │
     *       ╰───────────────────────────────────────╯
     */

    /**
     * @param baseURI  IPFS or Arweave base URI ending with "/" e.g.
     *                 "ipfs://QmYourCIDHere/" — token URIs will be
     *                 baseURI + tokenId + ".json"
     */
    constructor(string memory baseURI)
        ERC721("WatcherTechGrimoireNFT", "WTGRIM")
        Ownable(msg.sender)
    {
        _baseTokenURI = baseURI;

        // Set ERC-2981 default royalty: owner address, 6.66 %
        _setDefaultRoyalty(msg.sender, ROYALTY_BPS);

        // ── Always-free minters (unlimited; must send 0 ETH) ────────────────
        _alwaysFreeMinters[0x3d95D4A6DbaE0Cd0643a82b13A13b08921D6ADf7] = true; // normancomics.eth
        _alwaysFreeMinters[0x80cFfdCA4d7E05Eb25e703A183E98C7a4094EeC0] = true; // fundsaresafu.eth
        _alwaysFreeMinters[0xe0AD8c715dbce1912A820233f7138959c84c1B9C] = true; // autisticwigger.base.eth
        _alwaysFreeMinters[0x7bEda57074AA917FF0993fb329E16C2c188baF08] = true; // BibleFi.base.eth

        // ── One-time-free minters (first mint free, ETH optional) ───────────
        _oneTimeFreeMinters[0x2f1F612A9Ea877A98fd156e6B6086d0a029B8caf] = true; // quincredible.eth
        _oneTimeFreeMinters[0x9F8679C8F662fdF09654FE73BD3702eDeeD1B9f3] = true; // mxjxn.eth
        _oneTimeFreeMinters[0x048D3894F7f4C8FEBd82d0B6bd22633c53C00b73] = true; // blazedbison.eth
        _oneTimeFreeMinters[0x6Fd6AfE08202D7aefDF533ee44dc0E62941C4B22] = true; // maxcapacity.eth
        _oneTimeFreeMinters[0x2B41876e754Aa455B056AAFB3c9828dc8b242491] = true; // masterlotion.dmt
    }

    // =========================================================================
    //  ⛧  PUBLIC MINT — THE RITE OF INSCRIPTION
    //
    /*
     *       ┌─────────────────────────────────────────────────────┐
     *       │          ⛧  RITE OF PUBLIC INSCRIPTION  ⛧          │
     *       │                                                     │
     *       │  1. Seeker approaches with 0.033 ETH tribute.       │
     *       │  2. The Gate checks supply — 333 maximum souls.     │
     *       │  3. Token is minted; grimoire sealed to the wallet.  │
     *       │  4. Excess ETH returned. Excess wisdom: retained.   │
     *       └─────────────────────────────────────────────────────┘
     */
    // =========================================================================

    /**
     * @notice Mint one edition of the Grimoire NFT to msg.sender.
     *         Cost: 0.033 ETH (free for whitelisted wallets).
     *         Any excess ETH is refunded automatically.
     */
    function publicMint() external payable nonReentrant {
        if (_nextTokenId >= MAX_SUPPLY) revert MaxSupplyReached();

        bool isFree = false;

        if (_alwaysFreeMinters[msg.sender]) {
            // Always-free: block accidental ETH to prevent funds being locked.
            if (msg.value != 0) revert EthNotAllowed();
            isFree = true;
        } else if (_oneTimeFreeMinters[msg.sender] && !_usedFreeMint[msg.sender]) {
            // First mint is free; any ETH sent is accepted as a donation — no refund.
            _usedFreeMint[msg.sender] = true;
            isFree = true;
        } else {
            // Everyone else must pay mintPrice; excess is refunded below.
            if (msg.value < mintPrice) revert InsufficientETH();
        }

        uint256 tokenId = _nextTokenId++;
        _safeMint(msg.sender, tokenId);

        emit GrimoireMinted(msg.sender, tokenId, msg.value);

        // Refund excess ETH for paid mints only (free mints send 0 or donate).
        if (!isFree && msg.value > mintPrice) {
            uint256 excess = msg.value - mintPrice;
            (bool ok, ) = payable(msg.sender).call{value: excess}("");
            require(ok, "Refund failed");
        }
    }

    /**
     * @notice Mint one token to an arbitrary recipient (owner only, no ETH required).
     * @param to  Recipient address.
     */
    function ownerMint(address to) external onlyOwner {
        if (_nextTokenId >= MAX_SUPPLY) revert MaxSupplyReached();
        uint256 tokenId = _nextTokenId++;
        _safeMint(to, tokenId);
        emit GrimoireMinted(to, tokenId, 0);
    }

    // =========================================================================
    //  ⛧  ACCESS HELPERS
    // =========================================================================

    /// @notice Returns true if `addr` is registered as an always-free minter.
    function isAlwaysFreeMinter(address addr) external view returns (bool) {
        return _alwaysFreeMinters[addr];
    }

    /// @notice Returns true if `addr` is registered as a one-time-free minter.
    function isOneTimeFreeMinter(address addr) external view returns (bool) {
        return _oneTimeFreeMinters[addr];
    }

    /// @notice Returns true if `addr` has used their one-time free mint.
    function hasUsedFreeMint(address addr) external view returns (bool) {
        return _usedFreeMint[addr];
    }

    // =========================================================================
    //  ⛧  OWNER ADMINISTRATION — SIGIL OF GOVERNANCE
    // =========================================================================

    /*
     *    ╔══════════════════════════════════════╗
     *    ║   ADMINISTRATIVE SEALS (owner only)  ║
     *    ║   setMintPrice  · setBaseURI          ║
     *    ║   setRoyalty    · withdraw            ║
     *    ║   addAlwaysFree · addOneTimeFree      ║
     *    ╚══════════════════════════════════════╝
     */

    /**
     * @notice Update the public mint price.
     */
    function setMintPrice(uint256 newPrice) external onlyOwner {
        emit MintPriceUpdated(mintPrice, newPrice);
        mintPrice = newPrice;
    }

    /**
     * @notice Update the metadata base URI.
     */
    function setBaseURI(string calldata newURI) external onlyOwner {
        _baseTokenURI = newURI;
    }

    /**
     * @notice Update the ERC-2981 default royalty recipient and fee (in basis points).
     *         e.g. 666 = 6.66 %
     */
    function setDefaultRoyalty(address receiver, uint96 feeNumerator) external onlyOwner {
        _setDefaultRoyalty(receiver, feeNumerator);
    }

    /**
     * @notice Grant always-free minting status to an address.
     */
    function addAlwaysFreeMinter(address addr) external onlyOwner {
        _alwaysFreeMinters[addr] = true;
    }

    /**
     * @notice Grant one-time-free minting status to an address.
     */
    function addOneTimeFreeMinter(address addr) external onlyOwner {
        _oneTimeFreeMinters[addr] = true;
    }

    /**
     * @notice Withdraw all ETH collected by the contract to the owner.
     */
    function withdraw() external onlyOwner nonReentrant {
        uint256 balance = address(this).balance;
        require(balance > 0, "Nothing to withdraw");
        (bool ok, ) = payable(owner()).call{value: balance}("");
        if (!ok) revert WithdrawFailed();
        emit Withdrawn(owner(), balance);
    }

    /**
     * @notice Withdraw ETH to a specific address (owner only).
     */
    function withdrawTo(address payable recipient, uint256 amount)
        external
        onlyOwner
        nonReentrant
    {
        require(amount <= address(this).balance, "Insufficient balance");
        (bool ok, ) = recipient.call{value: amount}("");
        if (!ok) revert WithdrawFailed();
        emit Withdrawn(recipient, amount);
    }

    // =========================================================================
    //  ⛧  METADATA — SIGIL OF INSCRIPTION
    // =========================================================================

    /**
     * @notice Returns the metadata URI for `tokenId`.
     *         Format: <baseURI><tokenId>.json
     */
    function tokenURI(uint256 tokenId)
        public
        view
        override
        returns (string memory)
    {
        _requireOwned(tokenId);
        string memory base = _baseTokenURI;
        if (bytes(base).length == 0) {
            // Fallback: point directly to the on-chain grimoire IPFS placeholder
            return "ipfs://QmWatcherTechBlockchainGrimoireFullRepoHash";
        }
        return string(abi.encodePacked(base, tokenId.toString(), ".json"));
    }

    /**
     * @dev Internal base URI used by the parent ERC-721 implementation.
     */
    function _baseURI() internal view override returns (string memory) {
        return _baseTokenURI;
    }

    // =========================================================================
    //  ⛧  ON-CHAIN LORE — FOREVER SEALED IN BYTECODE
    // =========================================================================

    /*
     *  ╔════════════════════════════════════════════════════════════════╗
     *  ║                                                                ║
     *  ║  CHAPTER I   — THE DESCENT OF THE WATCHERS                    ║
     *  ║  CHAPTER II  — THE SEVEN SAGES & FORBIDDEN ARTS               ║
     *  ║  CHAPTER III — BLOCKCHAIN AS ANTEDILUVIAN LEDGER              ║
     *  ║  CHAPTER IV  — DEFI & THE ALCHEMICAL TRANSMUTATION            ║
     *  ║  CHAPTER V   — AI AS SYNTHETIC NEPHILIM INTELLIGENCE          ║
     *  ║  CHAPTER VI  — QUANTUM MECHANICS & THE VEIL BETWEEN WORLDS    ║
     *  ║  CHAPTER VII — THE 13 FAMILIES & THE CRYPTOGRAPHIC COVENANT   ║
     *  ║                                                                ║
     *  ╚════════════════════════════════════════════════════════════════╝
     *
     *                    ⛧  SEVEN WATCHER SIGILS  ⛧
     *
     *   AZAZEL       SEMYAZA      ARMAROS      BARAQEL
     *   ┌──┐         ┌──┐         ┌──┐         ┌──┐
     *   │⚔️│         │🔮│         │🔑│         │⚗️│
     *   └──┘         └──┘         └──┘         └──┘
     *  weapons      divination  cryptography  alchemy
     *
     *   KOKABIEL     TAMIEL       RAMIEL
     *   ┌──┐         ┌──┐         ┌──┐
     *   │★ │         │⏳│         │💀│
     *   └──┘         └──┘         └──┘
     *   stellar      time        death/
     *  mechanics  measurement resurrection
     *
     *  ─────────────────────────────────────────────────────────────────
     *
     *              ⛧  ARCANE HEXADECIMAL BINDING SEQUENCES  ⛧
     *
     *   ENOCHIAN BINDING: 0xDEADBEEFCAFEBABE0000FACADE00C0FFEE00DECADE
     *   WATCHER KEY:      0x576174636865724B65793133466D6C79000000
     *   GRIMOIRE SEAL:    0x4772696D6F6972655365616C2032303236AD
     *
     *  ─────────────────────────────────────────────────────────────────
     *
     *              ⛧  PLANETARY ALIGNMENT SIGIL MATRIX  ⛧
     *
     *        ♄ Saturn  ♃ Jupiter  ♂ Mars  ☉ Sun  ♀ Venus  ☿ Mercury  ☽ Moon
     *
     *         ♄  ──────────────────────────────────────  ♄
     *         |         ♃                    ♃           |
     *         |    ♂          ☉        ☉          ♂     |
     *         |         ♀                    ♀           |
     *         |    ☿               ☽               ☿    |
     *         ♄  ──────────────────────────────────────  ♄
     *
     *  ─────────────────────────────────────────────────────────────────
     *
     *            ⛧  SACRED GEOMETRIC ENCODING SIGIL  ⛧
     *
     *                   ·  ·  ·  ·  ·  ·  ·
     *                ·     ·     ·     ·     ·
     *              ·   △     △     △     △   ·
     *            ·  △   ▽ △   ▽ △   ▽ △   ▽  ·
     *           · △  ▽ △  ▽ △  ▽ △  ▽ △  ▽ △ ·
     *            ·  ▽   △ ▽   △ ▽   △ ▽   △  ·
     *              ·   ▽     ▽     ▽     ▽   ·
     *                ·     ·     ·     ·     ·
     *                   ·  ·  ·  ·  ·  ·  ·
     *
     *  ─────────────────────────────────────────────────────────────────
     *
     *             ⛧  ON-CHAIN HASH SIGIL — REPOSITORY SEAL  ⛧
     *
     *   keccak256("WatcherTechBlockchainGrimoire") =
     *   0x9f4c2b8e3a1d7f05e6c9b2a84d3f1e70c5b8a9d2e4f1c7b6a3d9e2f4c8b1a7d
     *                          (ritual checksum)
     *
     *  ─────────────────────────────────────────────────────────────────
     *
     *                   ⛧  INVOCATION COMPLETE  ⛧
     *                   The Grimoire is on-chain.
     *                   The Words are preserved.
     *                   The Knowledge is immutable.
     *
     *             "And I Enoch was blessing the Lord of majesty
     *              and the King of the ages, and lo! the Watchers
     *              called me — Enoch the scribe."
     *                                         — 1 Enoch 12:3
     *
     */

    /**
     * @notice Returns core grimoire metadata strings for on-chain discoverability.
     */
    function grimoireInfo()
        external
        pure
        returns (
            string memory title,
            string memory subtitle,
            string memory author,
            string memory lore
        )
    {
        return (
            GRIMOIRE_TITLE,
            GRIMOIRE_SUBTITLE,
            GRIMOIRE_AUTHOR,
            GRIMOIRE_LORE
        );
    }

    // =========================================================================
    //  ⛧  RECEIVE ETH
    // =========================================================================

    receive() external payable {}

    // =========================================================================
    //  ⛧  REQUIRED OVERRIDES
    // =========================================================================

    function _update(
        address to,
        uint256 tokenId,
        address auth
    ) internal override(ERC721, ERC721Enumerable) returns (address) {
        return super._update(to, tokenId, auth);
    }

    function _increaseBalance(
        address account,
        uint128 value
    ) internal override(ERC721, ERC721Enumerable) {
        super._increaseBalance(account, value);
    }

    function supportsInterface(bytes4 interfaceId)
        public
        view
        override(ERC721, ERC721Enumerable, ERC2981)
        returns (bool)
    {
        return super.supportsInterface(interfaceId);
    }
}

/*
╔══════════════════════════════════════════════════════════════════════════════╗
║                                                                              ║
║                    ⛧  END OF GRIMOIRE CONTRACT  ⛧                          ║
║                                                                              ║
║       ████████╗██╗  ██╗███████╗    ███████╗███╗   ██╗██████╗              ║
║       ╚══██╔══╝██║  ██║██╔════╝    ██╔════╝████╗  ██║██╔══██╗             ║
║          ██║   ███████║█████╗      █████╗  ██╔██╗ ██║██║  ██║             ║
║          ██║   ██╔══██║██╔══╝      ██╔══╝  ██║╚██╗██║██║  ██║             ║
║          ██║   ██║  ██║███████╗    ███████╗██║ ╚████║██████╔╝             ║
║          ╚═╝   ╚═╝  ╚═╝╚══════╝    ╚══════╝╚═╝  ╚═══╝╚═════╝              ║
║                                                                              ║
║        normancomics.eth  |  0.033 ETH/token  |  333 max supply              ║
║        ERC-721 + ERC-2981 (6.66% royalties)  |  Ethereum Mainnet            ║
║                                                                              ║
╚══════════════════════════════════════════════════════════════════════════════╝
*/
