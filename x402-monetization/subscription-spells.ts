/**
 * @title SubscriptionSpells — Time-Based Access Control
 * @notice Manages subscription-based access with esoteric tier naming
 */

export type SubscriptionTier = 'NEOPHYTE' | 'INITIATE' | 'ADEPT' | 'MAGISTER';

export interface Subscription {
  subscriber: string;
  tier: SubscriptionTier;
  startDate: Date;
  endDate: Date;
  autoRenew: boolean;
  pricePerMonthEth: number;
}

export const SUBSCRIPTION_TIERS: Record<SubscriptionTier, {
  name: string;
  pricePerMonthEth: number;
  features: string[];
}> = {
  NEOPHYTE: {
    name: 'Neophyte Scroll',
    pricePerMonthEth: 0.01,
    features: ['Public knowledge access', 'Basic lunar oracle queries'],
  },
  INITIATE: {
    name: 'Initiate Grimoire',
    pricePerMonthEth: 0.05,
    features: ['Initiated content', '10 oracle queries/day', 'Basic swarm access'],
  },
  ADEPT: {
    name: 'Adept Codex',
    pricePerMonthEth: 0.1,
    features: ['Adept content', '100 oracle queries/day', 'Full swarm coordination', 'Sigil generation'],
  },
  MAGISTER: {
    name: 'Magister Tome',
    pricePerMonthEth: 0.5,
    features: ['All content', 'Unlimited queries', 'Agent deployment', 'Custom rituals', 'API access'],
  },
};

export function createSubscription(
  subscriber: string,
  tier: SubscriptionTier,
  durationMonths: number,
  autoRenew = false
): Subscription {
  const start = new Date();
  const end = new Date(start);
  end.setMonth(end.getMonth() + durationMonths);
  
  return {
    subscriber,
    tier,
    startDate: start,
    endDate: end,
    autoRenew,
    pricePerMonthEth: SUBSCRIPTION_TIERS[tier].pricePerMonthEth,
  };
}

export function isSubscriptionActive(subscription: Subscription): boolean {
  return subscription.endDate > new Date();
}

export function getTierFeatures(tier: SubscriptionTier): string[] {
  return SUBSCRIPTION_TIERS[tier].features;
}

export default { createSubscription, isSubscriptionActive, getTierFeatures, SUBSCRIPTION_TIERS };
