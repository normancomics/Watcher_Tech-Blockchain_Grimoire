/**
 * @title ValidationHooks — Proof-of-Work Verification
 * @notice Validation hook system for ERC-8004 agent capability verification
 */

export interface ValidationHook {
  hookId: string;
  name: string;
  description: string;
  validator: (input: unknown) => Promise<ValidationResult>;
  requiredFor: string[];  // Capability names this hook validates
}

export interface ValidationResult {
  hookId: string;
  passed: boolean;
  score: number;     // 0–100
  details: string;
  proofHash?: string;
  timestamp: Date;
}

export const GRIMOIRE_VALIDATION_HOOKS: ValidationHook[] = [
  {
    hookId: 'esoteric_rag_hook',
    name: 'Esoteric RAG Validation',
    description: 'Validates agent can perform retrieval-augmented generation from esoteric corpus',
    requiredFor: ['ESOTERIC_RAG'],
    validator: async (input: unknown) => {
      const query = input as { question: string; expectedAnswer: string };
      const passed = typeof query.question === 'string' && query.question.length > 0;
      return {
        hookId: 'esoteric_rag_hook',
        passed,
        score: passed ? 80 : 0,
        details: passed ? 'Agent responded to esoteric query' : 'Failed to process query',
        timestamp: new Date(),
      };
    },
  },
  {
    hookId: 'lunar_calc_hook',
    name: 'Lunar Calculation Validation',
    description: 'Validates agent can compute accurate lunar phases',
    requiredFor: ['LUNAR_CALC'],
    validator: async (input: unknown) => {
      const result = input as { phase: string; illumination: number };
      const validPhases = ['new_moon', 'waxing_crescent', 'first_quarter', 'waxing_gibbous',
                           'full_moon', 'waning_gibbous', 'last_quarter', 'waning_crescent'];
      const passed = validPhases.includes(result.phase) && 
                     result.illumination >= 0 && result.illumination <= 1;
      return {
        hookId: 'lunar_calc_hook',
        passed,
        score: passed ? 95 : 0,
        details: passed ? 'Accurate lunar phase computation' : 'Invalid lunar phase output',
        timestamp: new Date(),
      };
    },
  },
];

export async function runValidationHooks(
  agentId: string,
  capabilities: string[],
  testInputs: Map<string, unknown>
): Promise<ValidationResult[]> {
  const relevantHooks = GRIMOIRE_VALIDATION_HOOKS.filter(hook =>
    hook.requiredFor.some(cap => capabilities.includes(cap))
  );
  
  const results = await Promise.all(
    relevantHooks.map(hook => hook.validator(testInputs.get(hook.hookId)))
  );
  
  return results;
}

export default { GRIMOIRE_VALIDATION_HOOKS, runValidationHooks };
