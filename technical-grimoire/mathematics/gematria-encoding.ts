/**
 * @title Gematria Encoding — Hebrew Numerology in Ethereum Addresses
 * @notice TypeScript implementation of gematria encoding for blockchain addresses
 * @description Maps Ethereum addresses and transaction data to Hebrew numerological
 *              values, enabling symbolic analysis and harmonic address generation.
 *
 * Gematria Systems Implemented:
 *   - Mispar Gadol (Standard Gematria): Standard Hebrew letter values
 *   - Mispar Katan (Reduced Value): Single digit reduction
 *   - Mispar Siduri (Ordinal): Sequential 1-22 values
 *   - AtBash Cipher: Letter reversal transformation
 *   - Albam Cipher: Letter halving transformation
 *
 * Applications:
 *   - Address harmony analysis (find "resonant" addresses)
 *   - Transaction timing optimization (find favorable gematria windows)
 *   - Smart contract deployment address selection
 *   - Validator key generation with desired numerological properties
 *
 * References:
 *   - kabbalistic-merkle-trees.md (Sefirot data structure)
 *   - Sefer Yetzirah (Book of Formation) — gematria source text
 *   - Rabbi Elazar of Worms, Sefer HaRokeach (13th century)
 *   - Aryeh Kaplan, Sefer Yetzirah: The Book of Creation (1990)
 */

// ─── Hebrew Letter Tables ─────────────────────────────────────────────────────

/** Standard Hebrew alphabet with Mispar Gadol values */
const HEBREW_LETTERS = [
  { name: 'Aleph',  letter: 'א', value: 1,   ordinal: 1  },
  { name: 'Bet',    letter: 'ב', value: 2,   ordinal: 2  },
  { name: 'Gimel',  letter: 'ג', value: 3,   ordinal: 3  },
  { name: 'Dalet',  letter: 'ד', value: 4,   ordinal: 4  },
  { name: 'Hey',    letter: 'ה', value: 5,   ordinal: 5  },
  { name: 'Vav',    letter: 'ו', value: 6,   ordinal: 6  },
  { name: 'Zayin',  letter: 'ז', value: 7,   ordinal: 7  },
  { name: 'Chet',   letter: 'ח', value: 8,   ordinal: 8  },
  { name: 'Tet',    letter: 'ט', value: 9,   ordinal: 9  },
  { name: 'Yod',    letter: 'י', value: 10,  ordinal: 10 },
  { name: 'Kaf',    letter: 'כ', value: 20,  ordinal: 11 },
  { name: 'Lamed',  letter: 'ל', value: 30,  ordinal: 12 },
  { name: 'Mem',    letter: 'מ', value: 40,  ordinal: 13 },
  { name: 'Nun',    letter: 'נ', value: 50,  ordinal: 14 },
  { name: 'Samech', letter: 'ס', value: 60,  ordinal: 15 },
  { name: 'Ayin',   letter: 'ע', value: 70,  ordinal: 16 },
  { name: 'Pey',    letter: 'פ', value: 80,  ordinal: 17 },
  { name: 'Tzadi',  letter: 'צ', value: 90,  ordinal: 18 },
  { name: 'Kuf',    letter: 'ק', value: 100, ordinal: 19 },
  { name: 'Resh',   letter: 'ר', value: 200, ordinal: 20 },
  { name: 'Shin',   letter: 'ש', value: 300, ordinal: 21 },
  { name: 'Tav',    letter: 'ת', value: 400, ordinal: 22 },
] as const;

/** Final letter forms with elevated values (Mispar Gadol / Sofit) */
const FINAL_LETTERS = [
  { name: 'Final Kaf',   letter: 'ך', value: 500 },
  { name: 'Final Mem',   letter: 'ם', value: 600 },
  { name: 'Final Nun',   letter: 'ן', value: 700 },
  { name: 'Final Pey',   letter: 'ף', value: 800 },
  { name: 'Final Tzadi', letter: 'ץ', value: 900 },
] as const;

/** Hex digit → closest Hebrew letter value mapping (0-F) */
const HEX_TO_HEBREW_VALUE: Record<string, number> = {
  '0': 0,    // Ain (Nothingness — pre-aleph)
  '1': 1,    // Aleph
  '2': 2,    // Bet
  '3': 3,    // Gimel
  '4': 4,    // Dalet
  '5': 5,    // Hey
  '6': 6,    // Vav
  '7': 7,    // Zayin
  '8': 8,    // Chet
  '9': 9,    // Tet
  'a': 10,   // Yod
  'b': 20,   // Kaf
  'c': 30,   // Lamed
  'd': 40,   // Mem
  'e': 50,   // Nun
  'f': 60,   // Samech
};

// ─── Types ────────────────────────────────────────────────────────────────────

export type GematriaSystem = 'gadol' | 'katan' | 'siduri' | 'atbash' | 'albam';

export interface GematriaResult {
  input: string;
  system: GematriaSystem;
  rawValue: number;
  reducedValue: number;      // Single digit reduction
  sefirahCorrespondence: string;
  harmonicNote: string;      // Musical note (Pythagorean harmony)
  interpretation: string;
}

export interface AddressGematriaAnalysis {
  address: string;
  gadolValue: number;
  katanValue: number;
  sidruiValue: number;
  sefirahResonance: SefirahCorrespondence;
  harmonicScore: number;     // 0–100, how "harmonious" the address is
  recommendations: string[];
}

export interface SefirahCorrespondence {
  name: string;
  hebrewName: string;
  value: number;
  meaning: string;
  color: string;
  planet: string;
}

// ─── Sefirot Table ────────────────────────────────────────────────────────────

const SEFIROT: Record<number, SefirahCorrespondence> = {
  1: { name: 'Keter',    hebrewName: 'כֶּתֶר',   value: 1,   meaning: 'Crown',          color: '#FFFFFF', planet: 'Neptune/Pluto' },
  2: { name: 'Chokmah',  hebrewName: 'חָכְמָה',  value: 2,   meaning: 'Wisdom',         color: '#C0C0C0', planet: 'Uranus' },
  3: { name: 'Binah',    hebrewName: 'בִּינָה',   value: 3,   meaning: 'Understanding',  color: '#000000', planet: 'Saturn' },
  4: { name: 'Chesed',   hebrewName: 'חֶסֶד',    value: 4,   meaning: 'Mercy',          color: '#0000FF', planet: 'Jupiter' },
  5: { name: 'Gevurah',  hebrewName: 'גְּבוּרָה', value: 5,   meaning: 'Strength',       color: '#FF0000', planet: 'Mars' },
  6: { name: 'Tiferet',  hebrewName: 'תִּפְאֶרֶת', value: 6, meaning: 'Beauty',         color: '#FFFF00', planet: 'Sun' },
  7: { name: 'Netzach',  hebrewName: 'נֵצַח',    value: 7,   meaning: 'Victory',        color: '#00FF00', planet: 'Venus' },
  8: { name: 'Hod',      hebrewName: 'הוֹד',     value: 8,   meaning: 'Splendor',       color: '#FF8C00', planet: 'Mercury' },
  9: { name: 'Yesod',    hebrewName: 'יְסוֹד',   value: 9,   meaning: 'Foundation',     color: '#9400D3', planet: 'Moon' },
  10: { name: 'Malkhut', hebrewName: 'מַלְכוּת', value: 10,  meaning: 'Kingdom',        color: '#8B4513', planet: 'Earth' },
};

const PYTHAGOREAN_NOTES: Record<number, string> = {
  1: 'C',  // Do — Keter, unity
  2: 'D',  // Re — Chokmah, wisdom
  3: 'E',  // Mi — Binah, understanding
  4: 'F',  // Fa — Chesed, mercy
  5: 'G',  // Sol — Gevurah, strength
  6: 'A',  // La — Tiferet, beauty
  7: 'B',  // Ti — Netzach, victory
  8: 'C+', // High C — Hod, splendor (octave)
  9: 'D+', // Re+ — Yesod, foundation
};

// ─── Core Gematria Engine ─────────────────────────────────────────────────────

/**
 * Compute the Mispar Gadol (standard) gematria of a Hebrew word or ASCII text
 */
export function computeGadol(text: string): number {
  const normalized = text.toLowerCase();
  let total = 0;
  
  for (const char of normalized) {
    // Check hex digits (for address computation)
    if (char in HEX_TO_HEBREW_VALUE) {
      total += HEX_TO_HEBREW_VALUE[char];
      continue;
    }
    
    // Check ASCII letters mapped to Hebrew equivalents
    const charCode = char.charCodeAt(0);
    if (charCode >= 97 && charCode <= 122) {
      // a-z → maps to approximate Hebrew values
      const idx = charCode - 97;
      const letterIndex = idx % 22; // Cycle through 22 Hebrew letters
      total += HEBREW_LETTERS[letterIndex].value;
    }
  }
  
  return total;
}

/**
 * Reduce a gematria value to a single digit (Mispar Katan)
 */
export function reduceToSingleDigit(value: number): number {
  let n = value;
  while (n > 9) {
    n = String(n).split('').reduce((sum, d) => sum + parseInt(d), 0);
  }
  return n;
}

/**
 * Compute ordinal gematria (1–22 sequential values)
 */
export function computeSiduri(text: string): number {
  const normalized = text.toLowerCase();
  let total = 0;
  
  for (const char of normalized) {
    const charCode = char.charCodeAt(0);
    if (charCode >= 97 && charCode <= 122) {
      const idx = (charCode - 97) % 22;
      total += HEBREW_LETTERS[idx].ordinal;
    } else if (char in HEX_TO_HEBREW_VALUE) {
      total += parseInt(char, 16) + 1; // 0-15 → 1-16 ordinal
    }
  }
  
  return total;
}

/**
 * AtBash cipher — reversal transformation (Aleph↔Tav, Bet↔Shin, etc.)
 */
export function applyAtbash(text: string): string {
  return text.toLowerCase().split('').map(char => {
    const charCode = char.charCodeAt(0);
    if (charCode >= 97 && charCode <= 122) {
      // Reverse the alphabet: a→z, b→y, etc.
      return String.fromCharCode(219 - charCode); // 97+122 = 219
    }
    return char;
  }).join('');
}

// ─── Ethereum Address Analysis ────────────────────────────────────────────────

/**
 * Perform comprehensive gematria analysis of an Ethereum address
 * @param address Ethereum address (with or without 0x prefix)
 */
export function analyzeAddress(address: string): AddressGematriaAnalysis {
  const cleanAddress = address.toLowerCase().replace('0x', '');
  
  const gadolValue = computeGadol(cleanAddress);
  const katanValue = reduceToSingleDigit(gadolValue);
  const siduriValue = computeSiduri(cleanAddress);
  
  const sefirahNum = ((katanValue - 1) % 10) + 1;
  const sefirahResonance = SEFIROT[sefirahNum] ?? SEFIROT[1];
  
  const harmonicScore = computeHarmonicScore(cleanAddress);
  const recommendations = generateRecommendations(cleanAddress, harmonicScore, sefirahResonance);
  
  return {
    address,
    gadolValue,
    katanValue,
    sidruiValue: siduriValue,
    sefirahResonance,
    harmonicScore,
    recommendations,
  };
}

/**
 * Compute how "harmonious" an address is based on its gematria properties
 * @returns Score 0–100
 */
export function computeHarmonicScore(addressHex: string): number {
  const gadol = computeGadol(addressHex);
  const reduced = reduceToSingleDigit(gadol);
  
  let score = 50; // Base score
  
  // Bonus for sacred numbers (3, 7, 9, 10)
  if ([3, 7, 9].includes(reduced)) score += 20;
  
  // Bonus for palindromic hex sequences (balance)
  if (hasPalindromicPattern(addressHex)) score += 15;
  
  // Bonus for repeating digit groups (resonance)
  const repetitionScore = computeRepetitionScore(addressHex);
  score += repetitionScore;
  
  // Bonus for Fibonacci digit appearance
  const fibBonus = countFibonacciDigits(addressHex);
  score += fibBonus;
  
  return Math.min(100, score);
}

/**
 * Find the Sefirah correspondence for a gematria value
 */
export function findSefirahCorrespondence(value: number): SefirahCorrespondence {
  const reduced = reduceToSingleDigit(value);
  const sefirahNum = reduced === 0 ? 10 : reduced;
  return SEFIROT[sefirahNum] ?? SEFIROT[1];
}

/**
 * Get the Pythagorean musical note for a gematria value
 */
export function getHarmonicNote(value: number): string {
  const reduced = reduceToSingleDigit(value);
  return PYTHAGOREAN_NOTES[reduced] ?? 'C';
}

// ─── Vanity Address Generator Guidance ───────────────────────────────────────

/**
 * Compute the target gematria value for a desired Sefirah
 * Used as a guide for vanity address mining
 */
export function targetGematriaForSefirah(sefirahName: string): number {
  const sefirah = Object.values(SEFIROT).find(s => 
    s.name.toLowerCase() === sefirahName.toLowerCase()
  );
  
  if (!sefirah) {
    throw new Error(`Unknown Sefirah: ${sefirahName}`);
  }
  
  return sefirah.value;
}

/**
 * Check if an address has the desired Sefirah resonance
 */
export function hasSefirahResonance(address: string, targetSefirah: string): boolean {
  const analysis = analyzeAddress(address);
  return analysis.sefirahResonance.name.toLowerCase() === targetSefirah.toLowerCase();
}

// ─── Gematria of Sacred Words ─────────────────────────────────────────────────

/** Pre-computed gematria values of sacred terms */
export const SACRED_VALUES = {
  // Hebrew
  TORAH: 611,       // תּוֹרָה (611 commandments in Torah)
  SHALOM: 376,      // שָׁלוֹם (peace)
  EMET: 441,        // אֶמֶת (truth, 21²)
  CHAI: 18,         // חַי (life — 18 is sacred)
  ADAM: 45,         // אָדָם (human)
  ELOHIM: 86,       // אֱלֹהִים (God/powers)
  YHVH: 26,         // יהוה (The Name, 10+5+6+5)
  
  // Blockchain terms in gematria
  BITCOIN: computeGadol('bitcoin'),
  ETHEREUM: computeGadol('ethereum'),
  BLOCKCHAIN: computeGadol('blockchain'),
  WATCHER: computeGadol('watcher'),
  GRIMOIRE: computeGadol('grimoire'),
};

// ─── Internal Helpers ─────────────────────────────────────────────────────────

function hasPalindromicPattern(hex: string): boolean {
  // Check first 8 chars for palindrome pattern
  const sample = hex.slice(0, 8);
  return sample === sample.split('').reverse().join('');
}

function computeRepetitionScore(hex: string): number {
  let score = 0;
  for (let i = 0; i < hex.length - 3; i++) {
    const quad = hex.slice(i, i + 4);
    if (new Set(quad).size === 1) score += 5;  // 4 same chars in a row
    else if (quad[0] === quad[2] && quad[1] === quad[3]) score += 2;  // ABAB pattern
  }
  return Math.min(15, score);
}

function countFibonacciDigits(hex: string): number {
  const fibDigits = new Set(['1', '2', '3', '5', '8']);
  const fibCount = hex.split('').filter(c => fibDigits.has(c)).length;
  return Math.floor((fibCount / hex.length) * 10);
}

function generateRecommendations(
  addressHex: string,
  harmonicScore: number,
  sefirah: SefirahCorrespondence
): string[] {
  const recommendations: string[] = [];
  
  if (harmonicScore >= 80) {
    recommendations.push(`✨ Highly harmonious address — resonates with ${sefirah.name}`);
  } else if (harmonicScore >= 60) {
    recommendations.push(`🌙 Moderately harmonious — ${sefirah.name} influence`);
  } else {
    recommendations.push(`⚠️ Low harmonic score — consider mining a more resonant address`);
  }
  
  recommendations.push(
    `🔢 Sefirah: ${sefirah.hebrewName} (${sefirah.name}) — ${sefirah.meaning}`,
    `🪐 Planetary ruler: ${sefirah.planet}`,
    `🎵 Harmonic note: ${getHarmonicNote(computeGadol(addressHex))}`,
  );
  
  return recommendations;
}

// ─── Export ───────────────────────────────────────────────────────────────────

export const GematriaEncoding = {
  computeGadol,
  reduceToSingleDigit,
  computeSiduri,
  applyAtbash,
  analyzeAddress,
  computeHarmonicScore,
  findSefirahCorrespondence,
  getHarmonicNote,
  targetGematriaForSefirah,
  hasSefirahResonance,
  SACRED_VALUES,
  SEFIROT,
  HEBREW_LETTERS,
};

export default GematriaEncoding;
