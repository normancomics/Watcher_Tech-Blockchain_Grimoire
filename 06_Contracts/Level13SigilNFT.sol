// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

/**
 * @title Level13SigilNFT
 * @author normancomics.eth — 2026 A.D.
 * @notice Level 13 Recursive Sigil-Encoded NFT Framework — deployed on Base chain.
 *
 * MU 𒉙⍤ 𐤌𐤏 — Sovereign authentication through sigil-encoded tokens.
 *
 * Token Architecture:
 *   Each NFT encodes cryptographic rights within two primary sigils:
 *     𒉙⍤  — Enochian sigil: divine encoding, recursive transformation
 *     𐤌𐤏  — Proto-Canaanite: primordial water (𐤌) + divine eye (𐤏)
 *
 *   Level 13 is the deepest sovereign tier. Tokens are hierarchically nested:
 *     Level 1–4   → Outer Watcher glyphs (public perimeter)
 *     Level 5–8   → Inner Watcher glyphs (initiated realm)
 *     Level 9–12  → Adept sigils (sovereign layer)
 *     Level 13    → MU Sovereign Core sigil (𒉙⍤ 𐤌𐤏 sealed)
 *
 * Encoding:
 *   tokenURI returns metadata with the Layered Encoding pipeline output:
 *     Latin → Enochian → Proto-Canaanite → Binary → Hex
 *   embedded as on-chain attributes for each sigil level.
 *
 * Recursive Encoding:
 *   Each Level N token's sigilHash is derived from the Level (N-1) token's
 *   sigilHash, creating an unbreakable cryptographic chain from Level 1 to 13.
 *
 * Access Control:
 *   MuWatcherGate queries holdsGateLevel(holder, level) to enforce access.
 *
 * Revenue:
 *   Mint fees flow directly to sovereign treasury.
 *   5% royalty (ERC-2981) on secondary sales.
 */

// ─── Interfaces ───────────────────────────────────────────────────────────────

interface IERC721Receiver {
    function onERC721Received(
        address operator,
        address from,
        uint256 tokenId,
        bytes calldata data
    ) external returns (bytes4);
}

interface IERC2981 {
    function royaltyInfo(
        uint256 tokenId,
        uint256 salePrice
    ) external view returns (address receiver, uint256 royaltyAmount);
}

// ─── Level13SigilNFT Contract ─────────────────────────────────────────────────

contract Level13SigilNFT is IERC2981 {

    // ─── ERC-721 State ────────────────────────────────────────────────────────

    string public name   = unicode"MU 𒉙⍤ 𐤌𐤏 Sovereign Sigil";
    string public symbol = "MU13";

    mapping(uint256 => address) private _owners;
    mapping(address => uint256) private _balances;
    mapping(uint256 => address) private _tokenApprovals;
    mapping(address => mapping(address => bool)) private _operatorApprovals;

    uint256 private _totalSupply;

    // ─── Sigil-Specific State ─────────────────────────────────────────────────

    uint8  public constant MAX_LEVEL = 13;
    uint256 public constant ROYALTY_BPS = 500;  // 5%

    // Canonical MU sigil strings (stored as constants for on-chain metadata)
    string public constant SIGIL_ENOCHIAN       = unicode"𒉙⍤";
    string public constant SIGIL_PROTO_CANAANITE = unicode"𐤌𐤏";

    // Mint prices by level tier (on Base, in wei)
    uint256 public constant PRICE_LEVELS_1_4    = 0.001 ether;
    uint256 public constant PRICE_LEVELS_5_8    = 0.005 ether;
    uint256 public constant PRICE_LEVELS_9_12   = 0.025 ether;
    uint256 public constant PRICE_LEVEL_13      = 0.13  ether;

    struct SigilToken {
        uint8   level;              // Gate level (1–13)
        bytes32 sigilHash;          // Recursive sigil hash for this level
        bytes32 parentSigilHash;    // Previous level's sigilHash (0x0 for level 1)
        string  encodedSequence;    // Layered Encoding output (Latin→Hex pipeline)
        string  metadataURI;        // IPFS URI for full metadata
        uint256 mintedAt;
        bool    soulBound;          // Level 13 tokens are soul-bound by default
    }

    mapping(uint256 => SigilToken) public sigilTokens;

    // Holder → level → tokenId (one active token per level per holder)
    mapping(address => mapping(uint8 => uint256)) public holderLevelToken;

    // Level → active supply cap (sovereign can set per-level scarcity)
    mapping(uint8 => uint256) public levelSupplyCap;
    mapping(uint8 => uint256) public levelMinted;

    address public sovereign;
    address public treasury;

    uint256 public totalRevenue;

    // ─── Events ───────────────────────────────────────────────────────────────

    event Transfer(address indexed from, address indexed to, uint256 indexed tokenId);
    event Approval(address indexed owner_, address indexed approved, uint256 indexed tokenId);
    event ApprovalForAll(address indexed owner_, address indexed operator, bool approved);

    event SigilMinted(
        uint256 indexed tokenId,
        address indexed recipient,
        uint8   indexed level,
        bytes32         sigilHash,
        bytes32         parentSigilHash
    );

    event SigilLevelCapSet(uint8 level, uint256 cap);
    event SovereignTransferred(address indexed newSovereign);

    // ─── Constructor ──────────────────────────────────────────────────────────

    constructor(address _treasury) {
        sovereign = msg.sender;
        treasury  = _treasury;

        // Default supply caps per level (sovereign can override)
        for (uint8 i = 1; i <= MAX_LEVEL; i++) {
            if (i <= 4)       levelSupplyCap[i] = 1000;
            else if (i <= 8)  levelSupplyCap[i] = 400;
            else if (i <= 12) levelSupplyCap[i] = 130;
            else              levelSupplyCap[i] = 13;  // Only 13 Level-13 tokens ever
        }
    }

    modifier onlySovereign() {
        require(msg.sender == sovereign, "MU13: not sovereign");
        _;
    }

    // ─── Minting ──────────────────────────────────────────────────────────────

    /**
     * @notice Mint a Level N Sigil NFT.
     * @dev The caller must pay the level-appropriate mint fee (x402 on Base).
     *      For level > 1, the caller must hold a token at level (N-1), enabling
     *      the recursive sigil chain: each level's hash derives from the parent.
     *
     * @param level           Gate level to mint (1–13)
     * @param encodedSequence Layered Encoding output string for this sigil
     * @param metadataURI     IPFS URI for token metadata
     * @param soulBound       If true, token cannot be transferred (recommended for level 13)
     */
    function mintSigil(
        uint8  level,
        string calldata encodedSequence,
        string calldata metadataURI,
        bool   soulBound
    ) external payable returns (uint256 tokenId) {
        require(level >= 1 && level <= MAX_LEVEL, "MU13: invalid level");
        require(
            levelMinted[level] < levelSupplyCap[level],
            "MU13: level supply cap reached"
        );
        require(
            msg.value >= _mintPrice(level),
            "MU13: insufficient mint payment"
        );

        // Recursive prerequisite: must hold previous level to unlock next
        bytes32 parentHash = bytes32(0);
        if (level > 1) {
            uint256 parentTokenId = holderLevelToken[msg.sender][level - 1];
            require(
                parentTokenId != 0 && _owners[parentTokenId] == msg.sender,
                "MU13: must hold level N-1 sigil to mint level N"
            );
            parentHash = sigilTokens[parentTokenId].sigilHash;
        }

        // Compute recursive sigil hash: keccak256(parent || level || caller || encoded)
        bytes32 sigilHash = keccak256(
            abi.encodePacked(
                parentHash,
                level,
                msg.sender,
                encodedSequence,
                block.timestamp
            )
        );

        tokenId = ++_totalSupply;

        _owners[tokenId]   = msg.sender;
        _balances[msg.sender]++;

        sigilTokens[tokenId] = SigilToken({
            level:            level,
            sigilHash:        sigilHash,
            parentSigilHash:  parentHash,
            encodedSequence:  encodedSequence,
            metadataURI:      metadataURI,
            mintedAt:         block.timestamp,
            soulBound:        soulBound || (level == MAX_LEVEL)
        });

        holderLevelToken[msg.sender][level] = tokenId;
        levelMinted[level]++;
        totalRevenue += msg.value;

        // Forward mint fee to treasury
        (bool sent,) = treasury.call{value: msg.value}("");
        require(sent, "MU13: treasury transfer failed");

        emit Transfer(address(0), msg.sender, tokenId);
        emit SigilMinted(tokenId, msg.sender, level, sigilHash, parentHash);
    }

    /**
     * @notice Sovereign-only free mint (for sovereign's own tokens or grants).
     */
    function sovereignMint(
        address recipient,
        uint8   level,
        string calldata encodedSequence,
        string calldata metadataURI,
        bool   soulBound
    ) external onlySovereign returns (uint256 tokenId) {
        require(level >= 1 && level <= MAX_LEVEL, "MU13: invalid level");
        require(
            levelMinted[level] < levelSupplyCap[level],
            "MU13: level supply cap reached"
        );

        bytes32 parentHash = bytes32(0);
        if (level > 1) {
            uint256 parentTokenId = holderLevelToken[recipient][level - 1];
            if (parentTokenId != 0 && _owners[parentTokenId] == recipient) {
                parentHash = sigilTokens[parentTokenId].sigilHash;
            }
        }

        bytes32 sigilHash = keccak256(
            abi.encodePacked(
                parentHash,
                level,
                recipient,
                encodedSequence,
                block.timestamp
            )
        );

        tokenId = ++_totalSupply;

        _owners[tokenId]  = recipient;
        _balances[recipient]++;

        sigilTokens[tokenId] = SigilToken({
            level:            level,
            sigilHash:        sigilHash,
            parentSigilHash:  parentHash,
            encodedSequence:  encodedSequence,
            metadataURI:      metadataURI,
            mintedAt:         block.timestamp,
            soulBound:        soulBound || (level == MAX_LEVEL)
        });

        holderLevelToken[recipient][level] = tokenId;
        levelMinted[level]++;

        emit Transfer(address(0), recipient, tokenId);
        emit SigilMinted(tokenId, recipient, level, sigilHash, parentHash);
    }

    // ─── Access Control Query (for MuWatcherGate) ─────────────────────────────

    /**
     * @notice Returns true if the holder holds an active Level-N (or higher) sigil.
     * @dev Called by MuWatcherGate to enforce hierarchical sovereign access.
     */
    function holdsGateLevel(address holder, uint8 level) external view returns (bool) {
        require(level >= 1 && level <= MAX_LEVEL, "MU13: invalid level");
        // Check if holder has a token at this level or any higher level
        for (uint8 l = level; l <= MAX_LEVEL; l++) {
            uint256 tid = holderLevelToken[holder][l];
            if (tid != 0 && _owners[tid] == holder) {
                return true;
            }
        }
        return false;
    }

    /**
     * @notice Returns the recursive sigil hash chain for a holder at a given level.
     * @dev Useful for off-chain verification of the full sigil ancestry.
     */
    function getSigilChain(
        address holder,
        uint8 level
    ) external view returns (bytes32[] memory chain) {
        require(level >= 1 && level <= MAX_LEVEL, "MU13: invalid level");
        chain = new bytes32[](level);
        for (uint8 l = 1; l <= level; l++) {
            uint256 tid = holderLevelToken[holder][l];
            if (tid != 0) {
                chain[l - 1] = sigilTokens[tid].sigilHash;
            }
        }
    }

    // ─── ERC-721 Core ─────────────────────────────────────────────────────────

    function balanceOf(address account) public view returns (uint256) {
        require(account != address(0), "MU13: zero address");
        return _balances[account];
    }

    function ownerOf(uint256 tokenId) public view returns (address) {
        address owner_ = _owners[tokenId];
        require(owner_ != address(0), "MU13: token does not exist");
        return owner_;
    }

    function tokenURI(uint256 tokenId) public view returns (string memory) {
        require(_owners[tokenId] != address(0), "MU13: token does not exist");
        return sigilTokens[tokenId].metadataURI;
    }

    function approve(address to, uint256 tokenId) public {
        address owner_ = ownerOf(tokenId);
        require(to != owner_, "MU13: cannot approve self");
        require(
            msg.sender == owner_ || isApprovedForAll(owner_, msg.sender),
            "MU13: not authorized"
        );
        _tokenApprovals[tokenId] = to;
        emit Approval(owner_, to, tokenId);
    }

    function getApproved(uint256 tokenId) public view returns (address) {
        require(_owners[tokenId] != address(0), "MU13: token does not exist");
        return _tokenApprovals[tokenId];
    }

    function setApprovalForAll(address operator, bool approved) public {
        require(operator != msg.sender, "MU13: cannot approve self");
        _operatorApprovals[msg.sender][operator] = approved;
        emit ApprovalForAll(msg.sender, operator, approved);
    }

    function isApprovedForAll(address owner_, address operator) public view returns (bool) {
        return _operatorApprovals[owner_][operator];
    }

    function transferFrom(address from, address to, uint256 tokenId) public {
        require(_isApprovedOrOwner(msg.sender, tokenId), "MU13: not authorized");
        require(!sigilTokens[tokenId].soulBound, "MU13: sigil is soul-bound");
        _transfer(from, to, tokenId);
    }

    function safeTransferFrom(address from, address to, uint256 tokenId) public {
        safeTransferFrom(from, to, tokenId, "");
    }

    function safeTransferFrom(
        address from,
        address to,
        uint256 tokenId,
        bytes memory data
    ) public {
        require(_isApprovedOrOwner(msg.sender, tokenId), "MU13: not authorized");
        require(!sigilTokens[tokenId].soulBound, "MU13: sigil is soul-bound");
        _transfer(from, to, tokenId);
        require(_checkOnERC721Received(from, to, tokenId, data), "MU13: non-receiver");
    }

    // ─── ERC-2981 Royalty ─────────────────────────────────────────────────────

    function royaltyInfo(
        uint256 tokenId,
        uint256 salePrice
    ) external view override returns (address receiver, uint256 royaltyAmount) {
        require(_owners[tokenId] != address(0), "MU13: token does not exist");
        receiver      = treasury;
        royaltyAmount = (salePrice * ROYALTY_BPS) / 10000;
    }

    // ─── Sovereign Admin ──────────────────────────────────────────────────────

    function setLevelCap(uint8 level, uint256 cap) external onlySovereign {
        require(level >= 1 && level <= MAX_LEVEL, "MU13: invalid level");
        require(cap >= levelMinted[level], "MU13: cap below already minted");
        levelSupplyCap[level] = cap;
        emit SigilLevelCapSet(level, cap);
    }

    function updateTreasury(address newTreasury) external onlySovereign {
        require(newTreasury != address(0), "MU13: zero treasury");
        treasury = newTreasury;
    }

    function transferSovereignty(address newSovereign) external onlySovereign {
        require(newSovereign != address(0), "MU13: zero sovereign");
        sovereign = newSovereign;
        emit SovereignTransferred(newSovereign);
    }

    function totalSupply() external view returns (uint256) { return _totalSupply; }

    // ─── Internal Functions ───────────────────────────────────────────────────

    function _mintPrice(uint8 level) internal pure returns (uint256) {
        if (level <= 4)  return PRICE_LEVELS_1_4;
        if (level <= 8)  return PRICE_LEVELS_5_8;
        if (level <= 12) return PRICE_LEVELS_9_12;
        return PRICE_LEVEL_13;
    }

    function _transfer(address from, address to, uint256 tokenId) internal {
        require(ownerOf(tokenId) == from, "MU13: transfer from incorrect owner");
        require(to != address(0), "MU13: transfer to zero address");

        delete _tokenApprovals[tokenId];

        _balances[from]--;
        _balances[to]++;
        _owners[tokenId] = to;

        // Update holderLevelToken mapping on transfer
        uint8 level = sigilTokens[tokenId].level;
        if (holderLevelToken[from][level] == tokenId) {
            delete holderLevelToken[from][level];
        }
        holderLevelToken[to][level] = tokenId;

        emit Transfer(from, to, tokenId);
    }

    function _isApprovedOrOwner(address spender, uint256 tokenId) internal view returns (bool) {
        address owner_ = ownerOf(tokenId);
        return (
            spender == owner_ ||
            getApproved(tokenId) == spender ||
            isApprovedForAll(owner_, spender)
        );
    }

    function _checkOnERC721Received(
        address from,
        address to,
        uint256 tokenId,
        bytes memory data
    ) private returns (bool) {
        if (to.code.length > 0) {
            try IERC721Receiver(to).onERC721Received(msg.sender, from, tokenId, data)
                returns (bytes4 retval) {
                return retval == IERC721Receiver.onERC721Received.selector;
            } catch {
                return false;
            }
        }
        return true;
    }
}
