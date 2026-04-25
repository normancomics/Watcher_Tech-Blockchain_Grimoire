// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

/**
 * @title ArcanusMathematica
 * @author normancomics.eth — 2026 A.D.
 * @notice ERC-721 Grimoire NFT with tiered free minting and WatcherGate integration.
 */

import {ERC721} from "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";

contract ArcanusMathematica is ERC721, Ownable {
    uint256 private _tokenIdCounter;   // starts at 0; first token minted gets ID 1
    uint256 public mintPrice = 0.033 ether;
    uint256 public maxSupply = 1333;

    string public constant GRIMOIRE_TITLE = "ARCANUS MATHEMATICA";
    string public constant GRIMOIRE_METADATA = "Occult and apocryphal revelations concerning non-human entities teaching mankind the arts of mathematics, geometry, mensuration, astronomy, and sacred calculations. Compiled from the Book of Enoch, Zohar, Testament of Solomon, and Solomonic Grimoires. Preserved as a permanent immutable blockchain grimoire.";

    /// Thrown when insufficient ETH is sent for a paid mint.
    error InsufficientETH();
    /// Thrown when an always-free minter accidentally sends ETH with their mint tx.
    error EthNotAllowed();
    /// Thrown when the max supply cap has been reached.
    error MaxSupplyReached();

    // -------------------------------------------------------------------------
    // Always-free minters: unlimited free mints; msg.value MUST be 0.
    // -------------------------------------------------------------------------
    mapping(address => bool) private _alwaysFreeMinters;

    // -------------------------------------------------------------------------
    // One-time-free minters: first mint is free (ETH optional); subsequent
    // mints require mintPrice like everyone else.
    // -------------------------------------------------------------------------
    mapping(address => bool) private _oneTimeFreeMinters;

    // Tracks whether a one-time-free address has already used their free mint.
    mapping(address => bool) private _hasUsedFreeMint;

    // Per-token URI overrides (optional).
    mapping(uint256 => string) private _tokenURIOverrides;

    // Base URI for all tokens (fallback when no per-token override is set).
    string private _baseTokenURI;

    // WatcherGate contract for grimoire access checks.
    address public watcherGate;

    constructor() ERC721("ArcanusMathematica", "ARCMATH") Ownable(msg.sender) {
        _baseTokenURI = "ipfs://QmArcanusMathematicaFullGrimoireHash";
        // Always-free minters (unlimited, msg.value == 0 enforced)
        _alwaysFreeMinters[0x3d95D4A6DbaE0Cd0643a82b13A13b08921D6ADf7] = true; // normancomics.eth
        _alwaysFreeMinters[0x80cFfdCA4d7E05Eb25e703A183E98C7a4094EeC0] = true; // fundsaresafu.eth
        _alwaysFreeMinters[0xe0AD8c715dbce1912A820233f7138959c84c1B9C] = true; // autisticwigger.base.eth
        _alwaysFreeMinters[0x7bEda57074AA917FF0993fb329E16C2c188baF08] = true; // BibleFi.base.eth

        // One-time-free minters (first mint free, ETH allowed but not required)
        _oneTimeFreeMinters[0x2f1F612A9Ea877A98fd156e6B6086d0a029B8caf] = true; // quincredible.eth
        _oneTimeFreeMinters[0x9F8679C8F662fdF09654FE73BD3702eDeeD1B9f3] = true; // mxjxn.eth
        _oneTimeFreeMinters[0x048D3894F7f4C8FEBd82d0B6bd22633c53C00b73] = true; // blazedbison.eth
        _oneTimeFreeMinters[0x6Fd6AfE08202D7aefDF533ee44dc0E62941C4B22] = true; // maxcapacity.eth
        _oneTimeFreeMinters[0x2B41876e754Aa455B056AAFB3c9828dc8b242491] = true; // masterlotion.dmt
    }

    // -------------------------------------------------------------------------
    // Public view helpers
    // -------------------------------------------------------------------------

    /// Returns true if `addr` is an always-free minter (unlimited free mints).
    function isAlwaysFreeMinter(address addr) public view returns (bool) {
        return _alwaysFreeMinters[addr];
    }

    /// Returns true if `addr` is a one-time-free minter.
    function isOneTimeFreeMinter(address addr) public view returns (bool) {
        return _oneTimeFreeMinters[addr];
    }

    /// Returns true if `addr` has already consumed their one-time free mint.
    function hasUsedFreeMint(address addr) public view returns (bool) {
        return _hasUsedFreeMint[addr];
    }

    /// Returns true if `addr` holds at least one ArcanusMathematica grimoire.
    function holdsGrimoire(address addr) public view returns (bool) {
        return balanceOf(addr) > 0;
    }

    /// Returns the total number of tokens minted so far.
    function totalMinted() public view returns (uint256) {
        return _tokenIdCounter;
    }

    // -------------------------------------------------------------------------
    // Minting
    // -------------------------------------------------------------------------

    function mintGrimoire(address to) public onlyOwner {
        if (_tokenIdCounter >= maxSupply) revert MaxSupplyReached();
        uint256 tokenId = ++_tokenIdCounter;    // pre-increment: IDs start at 1
        _safeMint(to, tokenId);
    }

    function publicMint() public payable {
        if (_tokenIdCounter >= maxSupply) revert MaxSupplyReached();

        if (_alwaysFreeMinters[msg.sender]) {
            // Always-free: block accidental ETH to prevent funds being locked.
            if (msg.value != 0) revert EthNotAllowed();
        } else if (_oneTimeFreeMinters[msg.sender] && !_hasUsedFreeMint[msg.sender]) {
            // First mint is free; ETH is accepted but not required.
            _hasUsedFreeMint[msg.sender] = true;
        } else {
            // Everyone else (and one-time-free minters after their free mint) must pay.
            if (msg.value < mintPrice) revert InsufficientETH();
        }

        uint256 tokenId = ++_tokenIdCounter;    // pre-increment: IDs start at 1
        _safeMint(msg.sender, tokenId);
    }

    // -------------------------------------------------------------------------
    // Admin
    // -------------------------------------------------------------------------

    function setMintPrice(uint256 _newPrice) public onlyOwner {
        mintPrice = _newPrice;
    }

    /// @notice Update the max supply cap (cannot exceed already-minted total).
    function setMaxSupply(uint256 _newMaxSupply) public onlyOwner {
        require(_newMaxSupply >= _tokenIdCounter, "ArcanusMathematica: below current supply");
        maxSupply = _newMaxSupply;
    }

    /// @notice Set the WatcherGate contract address for grimoire access checks.
    function setWatcherGate(address _watcherGate) public onlyOwner {
        watcherGate = _watcherGate;
    }

    function withdraw() public onlyOwner {
        uint256 amount = address(this).balance;
        require(amount > 0, "ArcanusMathematica: nothing to withdraw");
        (bool sent,) = owner().call{value: amount}("");
        require(sent, "ArcanusMathematica: withdrawal failed");
    }

    // -------------------------------------------------------------------------
    // Metadata
    // -------------------------------------------------------------------------

    /// @notice Set the base URI returned for all tokens without a per-token override.
    function setBaseURI(string calldata newBaseURI) public onlyOwner {
        _baseTokenURI = newBaseURI;
    }

    /// @notice Set a per-token metadata URI override (owner only).
    function setTokenURI(uint256 tokenId, string calldata uri) public onlyOwner {
        _requireOwned(tokenId);
        _tokenURIOverrides[tokenId] = uri;
    }

    function tokenURI(uint256 tokenId) public view override returns (string memory) {
        _requireOwned(tokenId);
        string memory override_ = _tokenURIOverrides[tokenId];
        if (bytes(override_).length > 0) {
            return override_;
        }
        return _baseTokenURI;
    }
}
