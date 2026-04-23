/**
 * @title KnowledgePricing — Dynamic Pricing Engine
 * @notice Computes dynamic prices for esoteric knowledge based on demand and rarity
 */

export type EsotericDomain = 
  | 'PrimordialTraditions'
  | 'NephilimRephaim'
  | 'CanaaniteSevenSages'
  | 'MysterySchools'
  | 'ThirteenBloodlines'
  | 'TechnicalGrimoire';

export interface PricingConfig {
  basePriceEth: number;
  domainMultipliers: Record<EsotericDomain, number>;
  rarityMultiplier: number;
  demandMultiplier: number;
  lunarPhaseMultiplier: number;  // 1.0 = normal, 1.5 = full moon premium
}

export const DEFAULT_PRICING_CONFIG: PricingConfig = {
  basePriceEth: 0.001,
  domainMultipliers: {
    PrimordialTraditions: 2.0,
    NephilimRephaim: 1.8,
    CanaaniteSevenSages: 1.5,
    MysterySchools: 1.3,
    ThirteenBloodlines: 1.6,
    TechnicalGrimoire: 1.0,
  },
  rarityMultiplier: 1.0,
  demandMultiplier: 1.0,
  lunarPhaseMultiplier: 1.0,
};

export function computeKnowledgePrice(
  domain: EsotericDomain,
  verified: boolean,
  viewCount: number,
  config: PricingConfig = DEFAULT_PRICING_CONFIG
): { priceEth: number; breakdown: Record<string, number> } {
  const domainMultiplier = config.domainMultipliers[domain];
  const verificationBonus = verified ? 1.5 : 1.0;
  
  // Demand curve: price increases with views (scarcity of attention)
  const demandFactor = 1 + Math.log10(Math.max(1, viewCount)) * 0.1;
  
  const priceEth = config.basePriceEth
    * domainMultiplier
    * verificationBonus
    * demandFactor
    * config.lunarPhaseMultiplier;
  
  return {
    priceEth: Math.round(priceEth * 1e6) / 1e6,
    breakdown: {
      basePriceEth: config.basePriceEth,
      domainMultiplier,
      verificationBonus,
      demandFactor,
      lunarMultiplier: config.lunarPhaseMultiplier,
    },
  };
}

export default { computeKnowledgePrice, DEFAULT_PRICING_CONFIG };
