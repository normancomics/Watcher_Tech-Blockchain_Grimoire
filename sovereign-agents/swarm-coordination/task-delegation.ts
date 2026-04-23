/**
 * @title TaskDelegation — Work Distribution Engine
 * @notice Distributes tasks across the agent swarm based on capabilities and load
 */

export interface AgentCapabilityMap {
  agentId: string;
  agentName: string;
  capabilities: string[];
  currentLoad: number;   // 0–1 (0 = idle, 1 = fully loaded)
  reputation: number;    // 0–1000
  available: boolean;
}

export interface DelegationDecision {
  taskId: string;
  assignedAgents: string[];
  coordinatorAgent: string;
  estimatedCompletionMs: number;
  delegationRationale: string;
}

export class TaskDelegation {
  private agents: Map<string, AgentCapabilityMap> = new Map();
  
  registerAgent(agent: AgentCapabilityMap): void {
    this.agents.set(agent.agentId, agent);
  }
  
  /**
   * Find the best agent(s) for a given task based on capabilities and availability
   */
  async delegateTask(
    taskId: string,
    requiredCapabilities: string[],
    minAgents = 1
  ): Promise<DelegationDecision> {
    const eligible = Array.from(this.agents.values())
      .filter(agent => 
        agent.available &&
        agent.currentLoad < 0.9 &&
        requiredCapabilities.every(cap => agent.capabilities.includes(cap))
      )
      .sort((a, b) => {
        // Score: high reputation, low load
        const scoreA = a.reputation / (a.currentLoad + 0.1);
        const scoreB = b.reputation / (b.currentLoad + 0.1);
        return scoreB - scoreA;
      });
    
    if (eligible.length < minAgents) {
      throw new Error(`Insufficient capable agents: needed ${minAgents}, found ${eligible.length}`);
    }
    
    const selected = eligible.slice(0, Math.max(minAgents, 3));
    const coordinator = selected[0];
    
    return {
      taskId,
      assignedAgents: selected.map(a => a.agentId),
      coordinatorAgent: coordinator.agentId,
      estimatedCompletionMs: 30_000,
      delegationRationale: `Selected ${selected.length} agents by reputation × load score`,
    };
  }
}

export default TaskDelegation;
