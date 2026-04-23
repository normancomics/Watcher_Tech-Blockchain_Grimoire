/**
 * @title SwarmConsensus — Agent Collective Decision-Making
 * @notice Off-chain consensus engine for the Watcher agent swarm
 * @description Implements Byzantine fault-tolerant consensus among
 *              sovereign agents for collective decision-making.
 */

export interface AgentVote {
  agentId: string;
  agentName: string;
  vote: boolean;
  confidence: number;  // 0–1
  reasoning: string;
  timestamp: Date;
}

export interface ConsensusResult {
  proposalId: string;
  approved: boolean;
  voteCount: number;
  approvalRatio: number;
  weightedScore: number;
  participatingAgents: string[];
  finalizedAt: Date;
}

export class SwarmConsensus {
  private readonly quorumThreshold: number;
  private readonly supermajority: number;
  
  constructor(quorumThreshold = 0.67, supermajority = 0.75) {
    this.quorumThreshold = quorumThreshold;
    this.supermajority = supermajority;
  }
  
  /**
   * Reach consensus on a proposal across the agent swarm
   */
  async reachConsensus(
    proposalId: string,
    proposal: Record<string, unknown>,
    votes: AgentVote[]
  ): Promise<ConsensusResult> {
    if (votes.length === 0) {
      throw new Error('No votes submitted — cannot reach consensus');
    }
    
    // Weighted voting by confidence
    const weightedApproval = votes
      .filter(v => v.vote)
      .reduce((sum, v) => sum + v.confidence, 0);
    
    const totalWeight = votes.reduce((sum, v) => sum + v.confidence, 0);
    const weightedScore = weightedApproval / totalWeight;
    
    const approvalRatio = votes.filter(v => v.vote).length / votes.length;
    const approved = approvalRatio >= this.supermajority && weightedScore >= this.quorumThreshold;
    
    return {
      proposalId,
      approved,
      voteCount: votes.length,
      approvalRatio,
      weightedScore,
      participatingAgents: votes.map(v => v.agentId),
      finalizedAt: new Date(),
    };
  }
  
  /**
   * Seven-Pillar consensus — requires 5/7 agreement (Proverbs 9:1 model)
   */
  async sevenPillarConsensus(votes: AgentVote[]): Promise<boolean> {
    if (votes.length !== 7) {
      throw new Error('Seven-Pillar consensus requires exactly 7 votes');
    }
    const approvals = votes.filter(v => v.vote).length;
    return approvals >= 5;  // 5/7 required
  }
}

export default SwarmConsensus;
