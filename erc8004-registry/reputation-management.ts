/**
 * @title ReputationManagement — Feedback Signal System
 * @notice Manages ERC-8004 reputation signals across the agent ecosystem
 */

export interface ReputationSignal {
  signalId: string;
  agentId: string;
  signalType: 'TASK_SUCCESS' | 'TASK_FAILURE' | 'PEER_ENDORSEMENT' | 'PEER_REPORT' | 'STAKE_INCREASE';
  value: number;
  reporter: string;
  evidence?: string;
  timestamp: Date;
  onChainTxHash?: string;
}

export interface ReputationProfile {
  agentId: string;
  totalScore: number;          // 0–1000
  taskSuccessRate: number;     // 0–1
  peerEndorsements: number;
  peerReports: number;
  stakeAmount: number;         // ETH bonded
  tier: 'BRONZE' | 'SILVER' | 'GOLD' | 'PLATINUM' | 'ARCHON';
  signals: ReputationSignal[];
}

const TIER_THRESHOLDS = {
  BRONZE: 0,
  SILVER: 200,
  GOLD: 400,
  PLATINUM: 700,
  ARCHON: 900,
} as const;

const SIGNAL_WEIGHTS: Record<ReputationSignal['signalType'], number> = {
  TASK_SUCCESS: 5,
  TASK_FAILURE: -20,
  PEER_ENDORSEMENT: 10,
  PEER_REPORT: -15,
  STAKE_INCREASE: 2,
};

export class ReputationManager {
  private signals: Map<string, ReputationSignal[]> = new Map();
  
  recordSignal(signal: ReputationSignal): void {
    const agentSignals = this.signals.get(signal.agentId) ?? [];
    agentSignals.push(signal);
    this.signals.set(signal.agentId, agentSignals);
  }
  
  computeScore(agentId: string): number {
    const agentSignals = this.signals.get(agentId) ?? [];
    const base = 100;
    const delta = agentSignals.reduce(
      (sum, s) => sum + (SIGNAL_WEIGHTS[s.signalType] ?? 0) * s.value, 0
    );
    return Math.max(0, Math.min(1000, base + delta));
  }
  
  getProfile(agentId: string): ReputationProfile {
    const signals = this.signals.get(agentId) ?? [];
    const score = this.computeScore(agentId);
    const successes = signals.filter(s => s.signalType === 'TASK_SUCCESS').length;
    const failures = signals.filter(s => s.signalType === 'TASK_FAILURE').length;
    
    let tier: ReputationProfile['tier'] = 'BRONZE';
    for (const [t, threshold] of Object.entries(TIER_THRESHOLDS).reverse()) {
      if (score >= threshold) { tier = t as ReputationProfile['tier']; break; }
    }
    
    return {
      agentId,
      totalScore: score,
      taskSuccessRate: successes + failures > 0 ? successes / (successes + failures) : 1,
      peerEndorsements: signals.filter(s => s.signalType === 'PEER_ENDORSEMENT').length,
      peerReports: signals.filter(s => s.signalType === 'PEER_REPORT').length,
      stakeAmount: 0,
      tier,
      signals,
    };
  }
}

export default ReputationManager;
