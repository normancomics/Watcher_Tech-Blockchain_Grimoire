/**
 * @title ReputationAggregator — ERC-8004 Reputation Management
 * @notice Aggregates and computes agent reputation scores
 */

export interface ReputationEvent {
  agentId: string;
  eventType: 'TASK_COMPLETE' | 'TASK_FAIL' | 'PEER_REVIEW' | 'SLASH' | 'BONUS';
  delta: number;      // Positive or negative reputation change
  reason: string;
  timestamp: Date;
  blockNumber?: number;
  txHash?: string;
}

export interface AgentReputation {
  agentId: string;
  currentScore: number;    // 0–1000
  historicalPeak: number;
  totalTasksCompleted: number;
  totalTasksFailed: number;
  successRate: number;     // 0–1
  tier: 'NOVICE' | 'ADEPT' | 'MASTER' | 'ARCHON';
}

export class ReputationAggregator {
  private scores: Map<string, number> = new Map();
  private events: ReputationEvent[] = [];
  
  recordEvent(event: ReputationEvent): number {
    const current = this.scores.get(event.agentId) ?? 100;
    const updated = Math.max(0, Math.min(1000, current + event.delta));
    this.scores.set(event.agentId, updated);
    this.events.push(event);
    return updated;
  }
  
  getReputation(agentId: string): AgentReputation {
    const score = this.scores.get(agentId) ?? 0;
    const agentEvents = this.events.filter(e => e.agentId === agentId);
    const completed = agentEvents.filter(e => e.eventType === 'TASK_COMPLETE').length;
    const failed = agentEvents.filter(e => e.eventType === 'TASK_FAIL').length;
    
    let tier: AgentReputation['tier'] = 'NOVICE';
    if (score >= 750) tier = 'ARCHON';
    else if (score >= 500) tier = 'MASTER';
    else if (score >= 250) tier = 'ADEPT';
    
    return {
      agentId,
      currentScore: score,
      historicalPeak: Math.max(...agentEvents.map(e => {
        let s = 100;
        for (const ev of agentEvents.filter(x => x.timestamp <= e.timestamp)) s += ev.delta;
        return Math.max(0, Math.min(1000, s));
      }), score),
      totalTasksCompleted: completed,
      totalTasksFailed: failed,
      successRate: completed + failed > 0 ? completed / (completed + failed) : 1,
      tier,
    };
  }
  
  getLeaderboard(): AgentReputation[] {
    return Array.from(this.scores.keys())
      .map(id => this.getReputation(id))
      .sort((a, b) => b.currentScore - a.currentScore);
  }
}

export default ReputationAggregator;
