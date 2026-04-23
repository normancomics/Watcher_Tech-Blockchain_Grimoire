/**
 * @title AncientTextParser — NLP for Esoteric Corpora
 * @notice Processes and indexes ancient and esoteric texts for knowledge retrieval
 */

export interface ParsedText {
  originalText: string;
  language: 'hebrew' | 'greek' | 'latin' | 'sumerian' | 'english' | 'unknown';
  entities: NamedEntity[];
  concepts: Concept[];
  gematriaValues: Record<string, number>;
  blockchainParallels: string[];
}

export interface NamedEntity {
  text: string;
  type: 'DEITY' | 'PLACE' | 'PERSON' | 'TECHNOLOGY' | 'CONCEPT';
  confidence: number;
}

export interface Concept {
  name: string;
  domain: string;
  modernEquivalent: string;
}

// Esoteric entity dictionary
const ESOTERIC_ENTITIES: Record<string, NamedEntity> = {
  'enoch': { text: 'Enoch', type: 'PERSON', confidence: 0.95 },
  'nephilim': { text: 'Nephilim', type: 'PERSON', confidence: 0.9 },
  'watchers': { text: 'Watchers', type: 'CONCEPT', confidence: 0.95 },
  'grigori': { text: 'Grigori', type: 'CONCEPT', confidence: 0.9 },
  'merkabah': { text: 'Merkabah', type: 'TECHNOLOGY', confidence: 0.85 },
  'sefirot': { text: 'Sefirot', type: 'CONCEPT', confidence: 0.95 },
  'vimana': { text: 'Vimana', type: 'TECHNOLOGY', confidence: 0.85 },
};

export async function parseAncientText(text: string): Promise<ParsedText> {
  const lower = text.toLowerCase();
  
  // Entity detection
  const entities: NamedEntity[] = [];
  for (const [keyword, entity] of Object.entries(ESOTERIC_ENTITIES)) {
    if (lower.includes(keyword)) entities.push(entity);
  }
  
  // Simple blockchain parallel detection
  const blockchainParallels: string[] = [];
  if (lower.includes('watchers')) blockchainParallels.push('Validator nodes (Watcher = always-on observer)');
  if (lower.includes('covenant')) blockchainParallels.push('Smart contract (immutable agreement)');
  if (lower.includes('merkabah') || lower.includes('chariot')) blockchainParallels.push('Transaction vehicle (merkabah = chariot of ascent)');
  if (lower.includes('seal') || lower.includes('sealed')) blockchainParallels.push('Cryptographic signature (seal = authentication)');
  
  return {
    originalText: text,
    language: detectLanguage(text),
    entities,
    concepts: [],
    gematriaValues: {},
    blockchainParallels,
  };
}

function detectLanguage(text: string): ParsedText['language'] {
  if (/[\u0590-\u05FF]/.test(text)) return 'hebrew';
  if (/[\u0370-\u03FF]/.test(text)) return 'greek';
  if (/\b(et|est|sunt|in|ad)\b/.test(text)) return 'latin';
  return 'english';
}

export default { parseAncientText };
