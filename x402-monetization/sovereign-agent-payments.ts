/**
 * @title SovereignAgentPayments — Agent-to-Agent Transactions
 * @notice Manages payment flows between autonomous agents in the swarm
 */

export interface AgentPaymentChannel {
  channelId: string;
  fromAgent: string;
  toAgent: string;
  depositedAmount: bigint;
  spentAmount: bigint;
  openedAt: Date;
  closedAt?: Date;
}

export interface MicropaymentVoucher {
  channelId: string;
  amount: bigint;
  nonce: number;
  signature: string;
  memo: string;  // Task description
}

export class AgentPaymentManager {
  private channels: Map<string, AgentPaymentChannel> = new Map();
  private vouchers: MicropaymentVoucher[] = [];
  
  /**
   * Open a payment channel between two agents
   */
  openChannel(
    fromAgent: string,
    toAgent: string,
    depositAmount: bigint
  ): AgentPaymentChannel {
    const channelId = `ch_${fromAgent}_${toAgent}_${Date.now()}`;
    const channel: AgentPaymentChannel = {
      channelId,
      fromAgent,
      toAgent,
      depositedAmount: depositAmount,
      spentAmount: 0n,
      openedAt: new Date(),
    };
    
    this.channels.set(channelId, channel);
    return channel;
  }
  
  /**
   * Issue a micropayment voucher within a channel
   */
  issueVoucher(
    channelId: string,
    amount: bigint,
    memo: string
  ): MicropaymentVoucher {
    const channel = this.channels.get(channelId);
    if (!channel) throw new Error(`Channel not found: ${channelId}`);
    
    const remaining = channel.depositedAmount - channel.spentAmount;
    if (amount > remaining) throw new Error('Insufficient channel balance');
    
    const voucher: MicropaymentVoucher = {
      channelId,
      amount,
      nonce: this.vouchers.filter(v => v.channelId === channelId).length,
      signature: `sig_${channelId}_${amount}`,  // Simplified
      memo,
    };
    
    this.vouchers.push(voucher);
    channel.spentAmount += amount;
    
    return voucher;
  }
  
  getChannel(channelId: string): AgentPaymentChannel | undefined {
    return this.channels.get(channelId);
  }
  
  getChannelBalance(channelId: string): bigint {
    const ch = this.channels.get(channelId);
    if (!ch) return 0n;
    return ch.depositedAmount - ch.spentAmount;
  }
}

export default AgentPaymentManager;
