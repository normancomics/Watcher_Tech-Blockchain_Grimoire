// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

/**
 * @title KnowledgeNFT
 * @notice ERC-721 NFT for esoteric text ownership and access control
 * @dev Implements ERC-721 for tokenized ownership of Grimoire knowledge entries.
 *      Each NFT represents ownership of a specific esoteric text or knowledge domain.
 *      Holders gain access to gated content through GrimoireRegistry access checks.
 *
 * Token Tiers:
 *   0: Neophyte  — Access to Public content
 *   1: Initiate  — Access to Initiated content
 *   2: Adept     — Access to Adept content
 *   3: Magister  — Access to all content
 *
 * Royalty: 5% to original contributor on secondary sales (ERC-2981)
 */

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

contract KnowledgeNFT is IERC2981 {
    
    // ─── ERC-721 State ────────────────────────────────────────────────────────
    
    string public name = "Watcher Tech Grimoire Knowledge";
    string public symbol = "WTGK";
    
    mapping(uint256 => address) private _owners;
    mapping(address => uint256) private _balances;
    mapping(uint256 => address) private _tokenApprovals;
    mapping(address => mapping(address => bool)) private _operatorApprovals;
    
    uint256 private _totalSupply;
    
    // ─── Grimoire-Specific State ──────────────────────────────────────────────
    
    enum KnowledgeTier { Neophyte, Initiate, Adept, Magister }
    
    struct KnowledgeToken {
        uint256 tokenId;
        uint256 linkedEntryId;    // Registry entry this token grants access to
        KnowledgeTier tier;
        string metadataURI;       // IPFS URI with token metadata + esoteric content
        address originalContributor;
        uint256 mintedAt;
        uint256 price;            // Current sale price (0 = not for sale)
        bool transferable;        // Some knowledge tokens are soul-bound
    }
    
    mapping(uint256 => KnowledgeToken) public knowledgeTokens;
    mapping(address => uint256[]) public holderTokens;
    mapping(uint256 => uint256) public entryToTokenId;  // Registry entry → token
    
    uint256 public constant ROYALTY_BPS = 500;  // 5% royalty
    
    address public owner;
    address public grimoireRegistry;
    
    // ─── Events ───────────────────────────────────────────────────────────────
    
    // ERC-721 events
    event Transfer(address indexed from, address indexed to, uint256 indexed tokenId);
    event Approval(address indexed owner_, address indexed approved, uint256 indexed tokenId);
    event ApprovalForAll(address indexed owner_, address indexed operator, bool approved);
    
    // Grimoire-specific events
    event KnowledgeMinted(
        uint256 indexed tokenId,
        uint256 indexed entryId,
        address indexed recipient,
        KnowledgeTier tier
    );
    
    event KnowledgeListed(uint256 indexed tokenId, uint256 price);
    event KnowledgeSold(uint256 indexed tokenId, address seller, address buyer, uint256 price);
    
    // ─── Constructor ──────────────────────────────────────────────────────────
    
    constructor(address _registry) {
        owner = msg.sender;
        grimoireRegistry = _registry;
    }
    
    modifier onlyOwner() {
        require(msg.sender == owner, "Not the owner");
        _;
    }
    
    // ─── ERC-721 Core Functions ───────────────────────────────────────────────
    
    function balanceOf(address account) public view returns (uint256) {
        require(account != address(0), "Zero address");
        return _balances[account];
    }
    
    function ownerOf(uint256 tokenId) public view returns (address) {
        address tokenOwner = _owners[tokenId];
        require(tokenOwner != address(0), "Token does not exist");
        return tokenOwner;
    }
    
    function tokenURI(uint256 tokenId) public view returns (string memory) {
        require(_owners[tokenId] != address(0), "Token does not exist");
        return knowledgeTokens[tokenId].metadataURI;
    }
    
    function approve(address to, uint256 tokenId) public {
        address tokenOwner = ownerOf(tokenId);
        require(to != tokenOwner, "Cannot approve to self");
        require(
            msg.sender == tokenOwner || isApprovedForAll(tokenOwner, msg.sender),
            "Not authorized"
        );
        _tokenApprovals[tokenId] = to;
        emit Approval(tokenOwner, to, tokenId);
    }
    
    function getApproved(uint256 tokenId) public view returns (address) {
        require(_owners[tokenId] != address(0), "Token does not exist");
        return _tokenApprovals[tokenId];
    }
    
    function setApprovalForAll(address operator, bool approved) public {
        require(operator != msg.sender, "Cannot approve self");
        _operatorApprovals[msg.sender][operator] = approved;
        emit ApprovalForAll(msg.sender, operator, approved);
    }
    
    function isApprovedForAll(address tokenOwner, address operator) public view returns (bool) {
        return _operatorApprovals[tokenOwner][operator];
    }
    
    function transferFrom(address from, address to, uint256 tokenId) public {
        require(_isApprovedOrOwner(msg.sender, tokenId), "Not authorized");
        require(knowledgeTokens[tokenId].transferable, "Token is soul-bound");
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
        require(_isApprovedOrOwner(msg.sender, tokenId), "Not authorized");
        require(knowledgeTokens[tokenId].transferable, "Token is soul-bound");
        _transfer(from, to, tokenId);
        require(_checkOnERC721Received(from, to, tokenId, data), "Non-receiver");
    }
    
    // ─── ERC-2981 Royalty ─────────────────────────────────────────────────────
    
    function royaltyInfo(
        uint256 tokenId,
        uint256 salePrice
    ) external view override returns (address receiver, uint256 royaltyAmount) {
        receiver = knowledgeTokens[tokenId].originalContributor;
        royaltyAmount = (salePrice * ROYALTY_BPS) / 10000;
    }
    
    // ─── Grimoire Knowledge Minting ───────────────────────────────────────────
    
    /**
     * @notice Mint a Knowledge NFT for a registry entry
     * @param recipient Who receives the token
     * @param entryId Registry entry this token represents
     * @param tier Access tier this token grants
     * @param metadataURI IPFS URI of token metadata
     * @param contributor Original knowledge contributor (royalty recipient)
     * @param transferable Whether this token can be traded
     * @param price Initial listing price (0 = not for sale)
     */
    function mintKnowledge(
        address recipient,
        uint256 entryId,
        KnowledgeTier tier,
        string calldata metadataURI,
        address contributor,
        bool transferable,
        uint256 price
    ) external onlyOwner returns (uint256 tokenId) {
        require(recipient != address(0), "Cannot mint to zero address");
        
        tokenId = ++_totalSupply;
        
        _owners[tokenId] = recipient;
        _balances[recipient]++;
        holderTokens[recipient].push(tokenId);
        
        knowledgeTokens[tokenId] = KnowledgeToken({
            tokenId: tokenId,
            linkedEntryId: entryId,
            tier: tier,
            metadataURI: metadataURI,
            originalContributor: contributor,
            mintedAt: block.timestamp,
            price: price,
            transferable: transferable
        });
        
        if (entryId > 0) {
            entryToTokenId[entryId] = tokenId;
        }
        
        emit Transfer(address(0), recipient, tokenId);
        emit KnowledgeMinted(tokenId, entryId, recipient, tier);
    }
    
    // ─── Marketplace Functions ────────────────────────────────────────────────
    
    /**
     * @notice List a Knowledge NFT for sale
     */
    function listForSale(uint256 tokenId, uint256 price) external {
        require(ownerOf(tokenId) == msg.sender, "Not the owner");
        require(knowledgeTokens[tokenId].transferable, "Token not transferable");
        require(price > 0, "Price must be positive");
        
        knowledgeTokens[tokenId].price = price;
        emit KnowledgeListed(tokenId, price);
    }
    
    /**
     * @notice Purchase a listed Knowledge NFT
     */
    function purchase(uint256 tokenId) external payable {
        KnowledgeToken storage token = knowledgeTokens[tokenId];
        address seller = ownerOf(tokenId);
        
        require(token.price > 0, "Not for sale");
        require(msg.value >= token.price, "Insufficient payment");
        require(seller != msg.sender, "Cannot buy own token");
        
        // Calculate royalty
        uint256 royalty = (msg.value * ROYALTY_BPS) / 10000;
        uint256 sellerAmount = msg.value - royalty;
        
        // Transfer token
        token.price = 0;  // Delist
        _transfer(seller, msg.sender, tokenId);
        
        // Send payments
        (bool royaltySent,) = token.originalContributor.call{value: royalty}("");
        require(royaltySent, "Royalty transfer failed");
        
        (bool sellerPaid,) = seller.call{value: sellerAmount}("");
        require(sellerPaid, "Seller payment failed");
        
        emit KnowledgeSold(tokenId, seller, msg.sender, msg.value);
    }
    
    // ─── Access Control Queries ───────────────────────────────────────────────
    
    /**
     * @notice Check if an address holds any Grimoire token at or above a tier
     */
    function holdsAccessTier(
        address holder,
        KnowledgeTier requiredTier
    ) external view returns (bool) {
        uint256[] memory tokens = holderTokens[holder];
        for (uint256 i = 0; i < tokens.length; i++) {
            if (knowledgeTokens[tokens[i]].tier >= requiredTier) {
                return true;
            }
        }
        return false;
    }
    
    function totalSupply() external view returns (uint256) {
        return _totalSupply;
    }
    
    // ─── Internal Functions ───────────────────────────────────────────────────
    
    function _transfer(address from, address to, uint256 tokenId) internal {
        require(ownerOf(tokenId) == from, "Transfer from incorrect owner");
        require(to != address(0), "Transfer to zero address");
        
        delete _tokenApprovals[tokenId];
        
        _balances[from]--;
        _balances[to]++;
        _owners[tokenId] = to;
        
        holderTokens[to].push(tokenId);
        
        emit Transfer(from, to, tokenId);
    }
    
    function _isApprovedOrOwner(address spender, uint256 tokenId) internal view returns (bool) {
        address tokenOwner = ownerOf(tokenId);
        return (
            spender == tokenOwner ||
            getApproved(tokenId) == spender ||
            isApprovedForAll(tokenOwner, spender)
        );
    }
    
    function _checkOnERC721Received(
        address from,
        address to,
        uint256 tokenId,
        bytes memory data
    ) private returns (bool) {
        if (to.code.length > 0) {
            try IERC721Receiver(to).onERC721Received(
                msg.sender, from, tokenId, data
            ) returns (bytes4 retval) {
                return retval == IERC721Receiver.onERC721Received.selector;
            } catch {
                return false;
            }
        }
        return true;
    }
}
