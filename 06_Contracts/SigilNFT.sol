// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

/**
 * @title SigilNFT
 * @author normancomics.eth — 2026 A.D.
 * @notice ERC-721 sigil NFT used by WatcherGate for tiered authentication.
 *
 * Tier system:
 *   1 = Neophyte   — entry-level initiates
 *   2 = Initiate   — confirmed initiates
 *   3 = Adept      — advanced practitioners
 *   4 = Sovereign  — supreme authority
 *
 * @dev holderTier tracks the highest sigil tier held by each address.
 *      Tier is updated on mint and on transfer (via _update override).
 */

import {ERC721} from "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";

contract SigilNFT is ERC721, Ownable {

    // ─── Constants ────────────────────────────────────────────────────────────

    uint8 public constant NEOPHYTE  = 1;
    uint8 public constant INITIATE  = 2;
    uint8 public constant ADEPT     = 3;
    uint8 public constant SOVEREIGN = 4;

    // ─── State ────────────────────────────────────────────────────────────────

    uint256 private _tokenIdCounter;

    /// @notice Token tier: tokenId → tier (1-4)
    mapping(uint256 => uint8) public tokenTier;

    /// @notice Token URI: tokenId → URI
    mapping(uint256 => string) private _tokenURIs;

    /// @notice Highest sigil tier held per address (updated on mint/transfer)
    mapping(address => uint8) public holderTier;

    // ─── Events ───────────────────────────────────────────────────────────────

    event SigilMinted(address indexed to, uint256 indexed tokenId, uint8 tier);
    event HolderTierUpdated(address indexed holder, uint8 newTier);

    // ─── Constructor ──────────────────────────────────────────────────────────

    constructor() ERC721("WatcherTech Sigil", "SIGIL") Ownable(msg.sender) {}

    // ─── Minting ──────────────────────────────────────────────────────────────

    /**
     * @notice Mint a sigil NFT to `to` with the given `tier` and metadata `uri`.
     * @dev Only owner can mint. Tier must be 1-4. holderTier is updated.
     * @param to    Recipient address
     * @param tier  Sigil tier (1=Neophyte, 2=Initiate, 3=Adept, 4=Sovereign)
     * @param uri   Token metadata URI (IPFS recommended)
     */
    function mint(address to, uint8 tier, string calldata uri)
        external onlyOwner
    {
        require(tier >= NEOPHYTE && tier <= SOVEREIGN, "SigilNFT: invalid tier");
        require(to != address(0), "SigilNFT: mint to zero address");

        ++_tokenIdCounter;                              // start at tokenId 1
        uint256 tokenId = _tokenIdCounter;

        tokenTier[tokenId]  = tier;
        _tokenURIs[tokenId] = uri;

        _safeMint(to, tokenId);

        // Update holder's highest tier
        _updateHolderTier(to, tier);

        emit SigilMinted(to, tokenId, tier);
    }

    // ─── Access Checks ────────────────────────────────────────────────────────

    /**
     * @notice Returns true if `holder` owns at least one sigil with tier ≥ `minTier`.
     * @param holder  Address to query
     * @param minTier Minimum acceptable tier (1-4)
     */
    function holderHasTier(address holder, uint8 minTier)
        external view
        returns (bool)
    {
        return holderTier[holder] >= minTier;
    }

    // ─── Metadata ─────────────────────────────────────────────────────────────

    /**
     * @notice Returns the metadata URI for `tokenId`.
     */
    function tokenURI(uint256 tokenId)
        public view override
        returns (string memory)
    {
        _requireOwned(tokenId);
        return _tokenURIs[tokenId];
    }

    /**
     * @notice Update the metadata URI for an existing token (owner only).
     */
    function setTokenURI(uint256 tokenId, string calldata uri)
        external onlyOwner
    {
        _requireOwned(tokenId);
        _tokenURIs[tokenId] = uri;
    }

    // ─── Transfer Hook ────────────────────────────────────────────────────────

    /**
     * @dev On every transfer (including mint and burn), recalculate holderTier
     *      for both the sender and recipient by scanning all tokens they hold.
     *      This keeps holderTier accurate after secondary market transfers.
     */
    function _update(address to, uint256 tokenId, address auth)
        internal override
        returns (address from)
    {
        from = super._update(to, tokenId, auth);

        // Recalculate tier for previous owner (if not mint)
        if (from != address(0)) {
            _recalculateHolderTier(from);
        }

        // Update tier for new owner (if not burn)
        if (to != address(0)) {
            _updateHolderTier(to, tokenTier[tokenId]);
        }
    }

    // ─── Internal ─────────────────────────────────────────────────────────────

    /**
     * @dev Update holderTier[holder] if `tier` is higher than the current value.
     */
    function _updateHolderTier(address holder, uint8 tier) internal {
        if (tier > holderTier[holder]) {
            holderTier[holder] = tier;
            emit HolderTierUpdated(holder, tier);
        }
    }

    /**
     * @dev Recalculate the highest tier held by `holder` by scanning
     *      all minted tokens. Necessary after a transfer-out.
     *      NOTE: This is an O(totalSupply) scan — acceptable for the
     *      expected sigil NFT volumes in this project.
     */
    function _recalculateHolderTier(address holder) internal {
        uint8 highest = 0;
        uint256 total = _tokenIdCounter;
        for (uint256 id = 1; id <= total; id++) {
            // _ownerOf returns address(0) for burned/non-existent tokens
            if (_ownerOf(id) == holder) {
                uint8 t = tokenTier[id];
                if (t > highest) highest = t;
            }
        }
        if (holderTier[holder] != highest) {
            holderTier[holder] = highest;
            emit HolderTierUpdated(holder, highest);
        }
    }

    // ─── View Helpers ─────────────────────────────────────────────────────────

    /// @notice Total number of sigils ever minted (includes burned tokens).
    function totalMinted() external view returns (uint256) {
        return _tokenIdCounter;
    }
}
