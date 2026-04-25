// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

/**
 * @title GrimoireERC8004Registry
 * @author normancomics.eth — 2026 A.D.
 * @notice ERC-721-based identity registry per ERC-8004 spec.
 * @dev Each agent is minted a unique NFT (agentId = tokenId).
 *      The NFT's tokenURI points to the ERC-8004 agent card JSON on IPFS.
 *      Agents can update their own URI; the owner can register new agents.
 */

import {ERC721} from "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";

contract GrimoireERC8004Registry is ERC721, Ownable {

    // ─── State ────────────────────────────────────────────────────────────────

    uint256 private _agentIdCounter;

    /// @notice Maps agent NFT tokenId → agent card URI (IPFS CID)
    mapping(uint256 => string) private _agentURIs;

    /// @notice Maps Ethereum address → agentId (tokenId); 0 = not registered
    mapping(address => uint256) public addressToAgentId;

    // ─── Events ───────────────────────────────────────────────────────────────

    event AgentRegistered(address indexed agentAddress, uint256 indexed agentId, string agentURI);
    event AgentURIUpdated(uint256 indexed agentId, string newURI);

    // ─── Constructor ──────────────────────────────────────────────────────────

    constructor() ERC721("GrimoireAgent", "AGENT") Ownable(msg.sender) {}

    // ─── Registration ─────────────────────────────────────────────────────────

    /**
     * @notice Register a new agent and mint its identity NFT.
     * @dev Owner-only. Each address may only be registered once.
     * @param agentAddress  Ethereum address of the agent
     * @param agentURI      IPFS URI of the ERC-8004 agent card JSON
     * @return agentId      The minted token ID representing this agent
     */
    function registerAgent(address agentAddress, string calldata agentURI)
        external onlyOwner
        returns (uint256 agentId)
    {
        require(agentAddress != address(0),          "GrimoireERC8004Registry: zero address");
        require(addressToAgentId[agentAddress] == 0, "GrimoireERC8004Registry: already registered");

        agentId = ++_agentIdCounter;

        _agentURIs[agentId]            = agentURI;
        addressToAgentId[agentAddress] = agentId;

        _safeMint(agentAddress, agentId);

        emit AgentRegistered(agentAddress, agentId, agentURI);
    }

    // ─── URI Management ───────────────────────────────────────────────────────

    /**
     * @notice Update the agent card URI for an existing agent.
     * @dev Callable only by the NFT owner (the agent itself).
     * @param agentId  The agent's tokenId
     * @param newURI   New IPFS URI for the updated agent card
     */
    function setAgentURI(uint256 agentId, string calldata newURI) external {
        require(ownerOf(agentId) == msg.sender, "GrimoireERC8004Registry: not agent owner");
        _agentURIs[agentId] = newURI;
        emit AgentURIUpdated(agentId, newURI);
    }

    /**
     * @notice Returns the agent card URI for the given `agentAddress`.
     * @param agentAddress  Ethereum address of the registered agent
     * @return              IPFS URI of the agent card (empty string if not registered)
     */
    function getAgentURI(address agentAddress) external view returns (string memory) {
        uint256 agentId = addressToAgentId[agentAddress];
        if (agentId == 0) return "";
        return _agentURIs[agentId];
    }

    /**
     * @notice ERC-721 tokenURI — returns the agent card URI.
     */
    function tokenURI(uint256 agentId) public view override returns (string memory) {
        _requireOwned(agentId);
        return _agentURIs[agentId];
    }

    // ─── View Helpers ─────────────────────────────────────────────────────────

    /// @notice Returns true if `agentAddress` is a registered agent.
    function isRegistered(address agentAddress) external view returns (bool) {
        return addressToAgentId[agentAddress] != 0;
    }

    /// @notice Total number of agents ever registered.
    function totalAgents() external view returns (uint256) {
        return _agentIdCounter;
    }
}
