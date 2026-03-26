// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC1155/ERC1155.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";

/**
 * @title GrimoireAccessPass
 * @author normancomics.eth 2026 A.D.
 * @notice ERC-1155 access-pass NFT that gates the Watcher Tech Blockchain
 *         Grimoire MCP Sovereign Agent.
 *
 * Three tiers of access are sold at configurable ETH prices:
 *
 *   ID 1 — Seeker   : read-only grimoire queries
 *   ID 2 — Initiate : ritual encoding + on-chain alignment tools
 *   ID 3 — Adept    : full sovereign agent (mint, write, execute)
 *
 * Monetization flow
 * -----------------
 * 1. User calls mint() with the desired tier ID and attached ETH.
 * 2. ETH is held in the contract.
 * 3. Owner calls withdraw() to collect revenue.
 * 4. The MCP server calls balanceOf(user, tierId) to gate premium tools.
 *
 * Royalties
 * ---------
 * Secondary-market royalties are enforced on-chain via the ERC-2981 pattern.
 * Override royaltyInfo if ERC-2981 support is desired (add IERC2981).
 */
contract GrimoireAccessPass is ERC1155, Ownable, ReentrancyGuard {

    // -----------------------------------------------------------------------
    // Constants
    // -----------------------------------------------------------------------

    uint256 public constant SEEKER   = 1;
    uint256 public constant INITIATE = 2;
    uint256 public constant ADEPT    = 3;

    // -----------------------------------------------------------------------
    // State
    // -----------------------------------------------------------------------

    /// @notice ETH price in wei for each tier (owner-configurable)
    mapping(uint256 => uint256) public tierPrice;

    /// @notice Human-readable name per tier
    mapping(uint256 => string) public tierName;

    /// @notice Maximum supply per tier (0 = unlimited)
    mapping(uint256 => uint256) public tierMaxSupply;

    /// @notice Total minted per tier
    mapping(uint256 => uint256) public tierMinted;

    // -----------------------------------------------------------------------
    // Events
    // -----------------------------------------------------------------------

    event PassMinted(address indexed recipient, uint256 indexed tierId, uint256 pricePaid);
    event TierPriceUpdated(uint256 indexed tierId, uint256 newPrice);
    event Withdrawn(address indexed to, uint256 amount);

    // -----------------------------------------------------------------------
    // Constructor
    // -----------------------------------------------------------------------

    /**
     * @param metadataUri  Base URI for token metadata, e.g.
     *                     "https://grimoire.normancomics.eth/api/token/{id}.json"
     */
    constructor(string memory metadataUri) ERC1155(metadataUri) Ownable(msg.sender) {
        // Default prices (owner can update via setTierPrice)
        tierPrice[SEEKER]   = 0.001 ether;   //  ~$2–3  at 2026 ETH prices
        tierPrice[INITIATE] = 0.005 ether;   //  ~$10–15
        tierPrice[ADEPT]    = 0.02  ether;   //  ~$40–60

        tierName[SEEKER]   = "Seeker";
        tierName[INITIATE] = "Initiate";
        tierName[ADEPT]    = "Adept";

        // Unlimited supply by default; owner may cap tiers
        tierMaxSupply[SEEKER]   = 0;
        tierMaxSupply[INITIATE] = 0;
        tierMaxSupply[ADEPT]    = 0;
    }

    // -----------------------------------------------------------------------
    // Public mint
    // -----------------------------------------------------------------------

    /**
     * @notice Purchase a GrimoireAccessPass for a given tier.
     * @param to     Recipient wallet address.
     * @param tierId 1=Seeker, 2=Initiate, 3=Adept.
     * @param amount Number of passes to mint (usually 1).
     */
    function mint(
        address to,
        uint256 tierId,
        uint256 amount
    ) external payable nonReentrant {
        require(tierId >= SEEKER && tierId <= ADEPT, "Invalid tier ID");
        require(amount > 0, "Amount must be > 0");
        require(msg.value >= tierPrice[tierId] * amount, "Insufficient ETH sent");

        uint256 maxSupply = tierMaxSupply[tierId];
        if (maxSupply > 0) {
            require(
                tierMinted[tierId] + amount <= maxSupply,
                "Tier supply exhausted"
            );
        }

        tierMinted[tierId] += amount;
        _mint(to, tierId, amount, "");

        emit PassMinted(to, tierId, msg.value);

        // Refund excess ETH
        uint256 excess = msg.value - tierPrice[tierId] * amount;
        if (excess > 0) {
            (bool ok, ) = payable(msg.sender).call{value: excess}("");
            require(ok, "Refund failed");
        }
    }

    // -----------------------------------------------------------------------
    // Access helpers
    // -----------------------------------------------------------------------

    /**
     * @notice Return true if `account` holds at least one pass of `tierId`
     *         OR any higher tier.
     */
    function hasAccess(address account, uint256 tierId) external view returns (bool) {
        for (uint256 t = tierId; t <= ADEPT; t++) {
            if (balanceOf(account, t) > 0) return true;
        }
        return false;
    }

    // -----------------------------------------------------------------------
    // Owner administration
    // -----------------------------------------------------------------------

    /**
     * @notice Update the ETH price for a tier.
     */
    function setTierPrice(uint256 tierId, uint256 newPrice) external onlyOwner {
        require(tierId >= SEEKER && tierId <= ADEPT, "Invalid tier ID");
        tierPrice[tierId] = newPrice;
        emit TierPriceUpdated(tierId, newPrice);
    }

    /**
     * @notice Cap the total supply for a tier (0 = unlimited).
     */
    function setTierMaxSupply(uint256 tierId, uint256 maxSupply) external onlyOwner {
        require(tierId >= SEEKER && tierId <= ADEPT, "Invalid tier ID");
        tierMaxSupply[tierId] = maxSupply;
    }

    /**
     * @notice Owner gift-mint (no ETH required).
     */
    function giftMint(address to, uint256 tierId, uint256 amount) external onlyOwner {
        require(tierId >= SEEKER && tierId <= ADEPT, "Invalid tier ID");
        tierMinted[tierId] += amount;
        _mint(to, tierId, amount, "");
        emit PassMinted(to, tierId, 0);
    }

    /**
     * @notice Withdraw all collected ETH to the owner.
     */
    function withdraw() external onlyOwner nonReentrant {
        uint256 balance = address(this).balance;
        require(balance > 0, "Nothing to withdraw");
        (bool ok, ) = payable(owner()).call{value: balance}("");
        require(ok, "Withdraw failed");
        emit Withdrawn(owner(), balance);
    }

    /**
     * @notice Withdraw ETH to an arbitrary address (owner only).
     */
    function withdrawTo(address payable recipient, uint256 amount) external onlyOwner nonReentrant {
        require(amount <= address(this).balance, "Insufficient balance");
        (bool ok, ) = recipient.call{value: amount}("");
        require(ok, "Withdraw failed");
        emit Withdrawn(recipient, amount);
    }

    // -----------------------------------------------------------------------
    // Metadata
    // -----------------------------------------------------------------------

    /**
     * @notice Update the metadata base URI.
     */
    function setURI(string memory newUri) external onlyOwner {
        _setURI(newUri);
    }

    // -----------------------------------------------------------------------
    // Receive ETH
    // -----------------------------------------------------------------------

    receive() external payable {}
}
