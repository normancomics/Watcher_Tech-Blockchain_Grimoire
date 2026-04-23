/**
 * @title IdentityRegistration — Agent NFT Minting
 * @notice Off-chain helper for registering agent identities via ERC-8004
 */

export interface AgentIdentity {
  name: string;
  version: string;
  description: string;
  url: string;
  capabilities: string[];
  skills: AgentSkill[];
  authentication?: AgentAuthentication;
}

export interface AgentSkill {
  id: string;
  name: string;
  description: string;
  inputModes: string[];
  outputModes: string[];
  tags: string[];
}

export interface AgentAuthentication {
  schemes: string[];
  credentials?: string;
}

export interface RegistrationResult {
  agentId: string;
  agentCardCID: string;
  txHash?: string;
  enochianName: string;
  registeredAt: Date;
}

/**
 * Build an ERC-8004 compliant agent card JSON
 */
export function buildAgentCard(identity: AgentIdentity): Record<string, unknown> {
  return {
    schema_version: '1.0',
    name: identity.name,
    version: identity.version,
    description: identity.description,
    url: identity.url,
    capabilities: {
      streaming: true,
      pushNotifications: false,
      stateTransitionHistory: true,
    },
    skills: identity.skills,
    authentication: identity.authentication ?? { schemes: ['bearer'] },
    // Watcher Tech extensions
    extensions: {
      watchers: {
        grimoireRegistry: true,
        lunarRiskCheck: true,
        swarmCoordination: true,
      },
    },
  };
}

/**
 * Derive the Enochian name for an agent address
 * @param agentAddress Ethereum address of the agent
 * @returns A deterministic, human-readable Enochian-inspired identifier
 */
export function deriveEnochianName(agentAddress: string): string {
  const ENOCHIAN_LETTERS = ['ZA', 'BI', 'CO', 'DU', 'EL', 'FA', 'GI', 'HO', 'IA', 'JU'];
  const addr = agentAddress.toLowerCase().replace('0x', '');
  
  const segments = [
    addr.slice(0, 4),
    addr.slice(4, 8),
    addr.slice(8, 12),
  ];
  
  return segments.map(seg => {
    const idx = parseInt(seg, 16) % ENOCHIAN_LETTERS.length;
    return ENOCHIAN_LETTERS[idx];
  }).join('-');
}

export async function registerAgentIdentity(
  identity: AgentIdentity,
  agentAddress: string
): Promise<RegistrationResult> {
  const agentCard = buildAgentCard(identity);
  const enochianName = deriveEnochianName(agentAddress);
  
  // In production: upload to IPFS, then call AgentAttunement.sol
  const agentCardCID = `bafybei${agentAddress.slice(2, 20)}...`;  // Placeholder CID
  
  return {
    agentId: `agent_${agentAddress.slice(2, 10)}`,
    agentCardCID,
    enochianName,
    registeredAt: new Date(),
  };
}

export default { buildAgentCard, deriveEnochianName, registerAgentIdentity };
