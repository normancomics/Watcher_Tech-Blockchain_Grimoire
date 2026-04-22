/**
 * Grimoire Oracle — Exploit Archetype Definitions
 *
 * Structured knowledge base mapping the 7 exploit archetypes,
 * 13 Family threat profiles, 8 Watcher domains, and 7 defensive paradigms
 * from the Watcher Tech Blockchain Grimoire.
 */

// ─── 7 Exploit Archetypes ───────────────────────────────────────────

export interface ExploitArchetype {
  id: string;
  name: string;
  grimoireName: string;
  family: string;
  description: string;
  opcodeSignature: string[];
  solidityPatterns: string[];
  indicators: string[];
  severity: "critical" | "high" | "medium" | "low";
  defenseParadigm: string;
  defenseDescription: string;
}

export const EXPLOIT_ARCHETYPES: ExploitArchetype[] = [
  {
    id: "reentrancy",
    name: "Reentrancy Attack",
    grimoireName: "Recursive Invocation Rite",
    family: "Bundy",
    description:
      "External calls that re-enter the calling contract before state updates complete, allowing repeated extraction of funds through recursive callback loops.",
    opcodeSignature: ["CALL", "DELEGATECALL", "SSTORE"],
    solidityPatterns: [
      ".call{value:",
      "msg.sender.call",
      "(bool success,) = ",
      "payable(msg.sender).transfer",
    ],
    indicators: [
      "State update after external call",
      "Missing ReentrancyGuard",
      "Fallback/receive function with external calls",
      "Cross-function reentrancy via shared state",
    ],
    severity: "critical",
    defenseParadigm: "Checks-Effects-Interactions + ReentrancyGuard",
    defenseDescription:
      "Apply the Checks-Effects-Interactions pattern: validate conditions, update state, then make external calls. Use OpenZeppelin ReentrancyGuard as a safety net.",
  },
  {
    id: "mev_extraction",
    name: "MEV / Transaction Reordering",
    grimoireName: "Gatekeeper's Reordering",
    family: "Rothschild",
    description:
      "Maximal Extractable Value attacks where validators or searchers reorder, insert, or censor transactions to extract profit from pending transaction pools.",
    opcodeSignature: ["PUSH", "JUMPDEST", "GASPRICE", "COINBASE"],
    solidityPatterns: [
      "block.timestamp",
      "block.number",
      "tx.gasprice",
      "block.coinbase",
    ],
    indicators: [
      "Price-sensitive operations without slippage protection",
      "On-chain price oracles without TWAP",
      "Deadline-less swap operations",
      "Unprotected liquidation triggers",
    ],
    severity: "high",
    defenseParadigm: "Commit-Reveal + Private Mempool + PBS",
    defenseDescription:
      "Use commit-reveal schemes to hide transaction intent. Integrate private mempools (Flashbots Protect). Implement time-weighted average prices and slippage guards.",
  },
  {
    id: "flash_loan",
    name: "Flash Loan Attack",
    grimoireName: "Instant Conjuration",
    family: "DuPont",
    description:
      "Atomic uncollateralized loans used to manipulate prices, drain liquidity, or exploit governance in a single transaction block.",
    opcodeSignature: ["SLOAD", "CREATE2", "DELEGATECALL", "CALLVALUE"],
    solidityPatterns: [
      "flashLoan",
      "executeOperation",
      "onFlashLoan",
      "IERC3156FlashBorrower",
    ],
    indicators: [
      "Price calculations from spot reserves",
      "Single-block governance votes",
      "Collateral ratio checks without time delay",
      "Oracle reads without manipulation resistance",
    ],
    severity: "critical",
    defenseParadigm: "TVL Limits + Invariant Checks + Time Delays",
    defenseDescription:
      "Cap per-transaction volume relative to TVL. Use manipulation-resistant oracles (Chainlink, TWAP). Enforce time delays on governance and collateral changes.",
  },
  {
    id: "vampire_liquidity",
    name: "Vampire / Liquidity Extraction",
    grimoireName: "Luring Sacrificial Flow",
    family: "Rockefeller",
    description:
      "Systematic draining of liquidity from one protocol to another through incentive manipulation, reward siphoning, or parasitic migration attacks.",
    opcodeSignature: ["BALANCE", "SELFBALANCE", "CALL", "SSTORE"],
    solidityPatterns: [
      "transferFrom",
      "approve",
      "allowance",
      "balanceOf",
    ],
    indicators: [
      "Unlimited approval patterns",
      "Missing withdrawal delay",
      "Reward calculation from manipulable state",
      "No vesting or lock-up on rewards",
    ],
    severity: "high",
    defenseParadigm: "Time-Locked Vesting + TWAP Incentives",
    defenseDescription:
      "Implement vesting schedules for rewards. Use time-weighted metrics for incentive calculations. Enforce withdrawal delays and gradual release curves.",
  },
  {
    id: "bridge_exploit",
    name: "Cross-Chain Bridge Exploit",
    grimoireName: "Portal Invocation / Tunnel Corruption",
    family: "Astor",
    description:
      "Attacks on cross-chain communication that exploit message verification gaps, validator collusion, or state synchronization failures between chains.",
    opcodeSignature: ["CALLCODE", "STATICCALL", "EXTCODESIZE", "RETURNDATASIZE"],
    solidityPatterns: [
      "bridge",
      "relayer",
      "messageHash",
      "crossChainCall",
    ],
    indicators: [
      "Insufficient validator threshold",
      "Missing message replay protection",
      "No fraud proof mechanism",
      "Unverified cross-chain state roots",
    ],
    severity: "critical",
    defenseParadigm: "MPC Bridges + Fraud Proofs + Optimistic Verification",
    defenseDescription:
      "Use MPC-based validator sets with high thresholds. Implement optimistic verification with challenge periods. Add replay protection and message sequencing.",
  },
  {
    id: "zk_misuse",
    name: "Zero-Knowledge Proof Misuse",
    grimoireName: "Cloaked Initiation / Veiled Commitments",
    family: "Collins",
    description:
      "Exploits in zero-knowledge proof systems including malicious trusted setups, proof forgery, or privacy leaks through side channels.",
    opcodeSignature: ["SHA3", "STATICCALL", "RETURNDATACOPY"],
    solidityPatterns: [
      "verifyProof",
      "zkSnark",
      "commitment",
      "nullifier",
    ],
    indicators: [
      "Trusted setup without ceremony",
      "Missing nullifier checks",
      "Proof reuse vulnerability",
      "Incomplete circuit constraints",
    ],
    severity: "high",
    defenseParadigm: "Auditable Circuits + Multi-Party Ceremony + Formal Verification",
    defenseDescription:
      "Conduct multi-party computation ceremonies for trusted setup. Formally verify circuit constraints. Implement nullifier tracking and proof uniqueness checks.",
  },
  {
    id: "supply_chain",
    name: "Supply Chain / Backdoor Attack",
    grimoireName: "Artificer's Trojan",
    family: "Van Duyn",
    description:
      "Malicious code injection through compromised dependencies, poisoned compiler outputs, proxy upgrade backdoors, or hidden selfdestruct mechanisms.",
    opcodeSignature: ["CREATE", "CREATE2", "SELFDESTRUCT", "DELEGATECALL"],
    solidityPatterns: [
      "selfdestruct",
      "delegatecall",
      "upgradeTo",
      "implementation()",
    ],
    indicators: [
      "Unverified proxy implementations",
      "Hidden admin functions",
      "Unaudited dependency imports",
      "Upgradeable contracts without timelock",
    ],
    severity: "critical",
    defenseParadigm: "Reproducible Builds + Provenance + Timelocked Upgrades",
    defenseDescription:
      "Use reproducible builds with deterministic compilation. Verify dependency provenance. Implement timelocked upgrade mechanisms with community veto periods.",
  },
];

// ─── 13 Family Threat Profiles ──────────────────────────────────────

export interface FamilyProfile {
  id: string;
  name: string;
  patron: string;
  domain: string;
  exploitArchetype: string;
  description: string;
  threatVectors: string[];
  defenseMeasures: string[];
}

export const FAMILY_PROFILES: FamilyProfile[] = [
  {
    id: "rothschild",
    name: "Rothschild",
    patron: "Shamash",
    domain: "Banking / Settlement Layer",
    exploitArchetype: "mev_extraction",
    description:
      "Controls transaction ordering and settlement infrastructure. Extracts value through information asymmetry at the consensus layer.",
    threatVectors: [
      "Transaction reordering for frontrunning",
      "Sandwich attacks on DEX trades",
      "Block builder collusion",
      "Settlement delay exploitation",
    ],
    defenseMeasures: [
      "Private transaction submission (Flashbots)",
      "Commit-reveal trade mechanisms",
      "MEV-aware slippage settings",
      "Batch auction protocols",
    ],
  },
  {
    id: "rockefeller",
    name: "Rockefeller",
    patron: "Mot",
    domain: "Energy / Industrial Infrastructure",
    exploitArchetype: "vampire_liquidity",
    description:
      "Controls energy and resource flows. Extracts value by redirecting liquidity streams through monopolistic infrastructure control.",
    threatVectors: [
      "Liquidity migration attacks",
      "Reward token inflation manipulation",
      "LP token arbitrage exploitation",
      "Protocol dependency lock-in",
    ],
    defenseMeasures: [
      "Gradual vesting and lock-ups",
      "Anti-vampire attack mechanisms",
      "Diversified liquidity sources",
      "Protocol-owned liquidity",
    ],
  },
  {
    id: "astor",
    name: "Astor",
    patron: "Enki",
    domain: "Real Estate / Bridge Infrastructure",
    exploitArchetype: "bridge_exploit",
    description:
      "Controls cross-domain infrastructure and portals. Exploits communication gaps between isolated systems.",
    threatVectors: [
      "Bridge validator collusion",
      "Cross-chain message forgery",
      "State root manipulation",
      "Replay attacks across chains",
    ],
    defenseMeasures: [
      "High-threshold MPC validation",
      "Optimistic bridges with challenge periods",
      "Canonical message sequencing",
      "Cross-chain fraud proofs",
    ],
  },
  {
    id: "bundy",
    name: "Bundy",
    patron: "Baal-Hadad",
    domain: "Military / Recursive Operations",
    exploitArchetype: "reentrancy",
    description:
      "Specializes in recursive infiltration patterns that exploit callback mechanisms for repeated extraction.",
    threatVectors: [
      "Classic single-function reentrancy",
      "Cross-function reentrancy",
      "Read-only reentrancy via view functions",
      "Cross-contract reentrancy",
    ],
    defenseMeasures: [
      "Checks-Effects-Interactions pattern",
      "ReentrancyGuard modifier",
      "Pull-over-push payment patterns",
      "Reentrancy lock state variables",
    ],
  },
  {
    id: "collins",
    name: "Collins",
    patron: "Ishtar",
    domain: "Intelligence / Hidden Data",
    exploitArchetype: "zk_misuse",
    description:
      "Operates in concealed information domains. Exploits gaps between what is proven and what is actually true.",
    threatVectors: [
      "Corrupted trusted setups",
      "Proof replay without nullifier checks",
      "Side-channel leaks in zk circuits",
      "Incomplete constraint systems",
    ],
    defenseMeasures: [
      "Multi-party ceremony for setup",
      "Strict nullifier tracking",
      "Formal verification of circuits",
      "Independent audit of constraints",
    ],
  },
  {
    id: "dupont",
    name: "DuPont",
    patron: "Kothar-wa-Khasis",
    domain: "Manufacturing / Instant Fabrication",
    exploitArchetype: "flash_loan",
    description:
      "Masters of instantaneous creation and destruction. Exploits atomic execution to create temporary economic distortions.",
    threatVectors: [
      "Flash loan price manipulation",
      "Single-block governance takeover",
      "Collateral ratio manipulation",
      "Oracle price distortion",
    ],
    defenseMeasures: [
      "TWAP oracles over multiple blocks",
      "Time-delayed governance execution",
      "Flash loan-resistant price feeds",
      "Per-block TVL caps",
    ],
  },
  {
    id: "freeman",
    name: "Freeman",
    patron: "Dagon",
    domain: "Offshore Trade / Stealth Arbitrage",
    exploitArchetype: "bridge_exploit",
    description:
      "Operates in the gaps between jurisdictions and chains. Exploits arbitrage opportunities across disconnected systems.",
    threatVectors: [
      "Cross-chain price discrepancy exploitation",
      "Regulatory arbitrage between chains",
      "Bridge latency exploitation",
      "Multi-chain state inconsistency",
    ],
    defenseMeasures: [
      "Cross-chain price synchronization",
      "Atomic cross-chain swaps",
      "Unified liquidity pools",
      "Bridge finality verification",
    ],
  },
  {
    id: "kennedy",
    name: "Kennedy",
    patron: "Hermes",
    domain: "Media / Oracle Manipulation",
    exploitArchetype: "mev_extraction",
    description:
      "Controls information flow and oracular data. Exploits information asymmetry to front-run market movements.",
    threatVectors: [
      "Oracle data manipulation",
      "Information front-running",
      "Stale price exploitation",
      "Single oracle point of failure",
    ],
    defenseMeasures: [
      "Decentralized oracle networks",
      "Multi-source price aggregation",
      "Heartbeat and deviation thresholds",
      "Oracle update frequency monitoring",
    ],
  },
  {
    id: "li",
    name: "Li",
    patron: "El",
    domain: "Substrate Control / Systemic Influence",
    exploitArchetype: "supply_chain",
    description:
      "Controls foundational infrastructure. Extracts value by manipulating the substrate upon which others build.",
    threatVectors: [
      "Compiler-level backdoors",
      "Infrastructure dependency exploits",
      "Hardware-level attacks on validators",
      "Network-level censorship",
    ],
    defenseMeasures: [
      "Reproducible and auditable builds",
      "Multi-client diversity",
      "Decentralized infrastructure",
      "Hardware attestation verification",
    ],
  },
  {
    id: "onassis",
    name: "Onassis",
    patron: "Poseidon",
    domain: "Maritime / Liquid Asset Routing",
    exploitArchetype: "vampire_liquidity",
    description:
      "Controls fluid asset transportation and routing. Exploits liquidity flow patterns for extraction.",
    threatVectors: [
      "Liquidity pool manipulation",
      "Routing path exploitation",
      "Slippage amplification",
      "Pool imbalance attacks",
    ],
    defenseMeasures: [
      "Multi-path routing with comparison",
      "Dynamic slippage protection",
      "Concentrated liquidity ranges",
      "Pool balance monitoring",
    ],
  },
  {
    id: "reynolds",
    name: "Reynolds",
    patron: "Resheph",
    domain: "Pharma / Behavioral Capture",
    exploitArchetype: "vampire_liquidity",
    description:
      "Engineers addictive incentive mechanisms that capture and lock users into extractive economic cycles.",
    threatVectors: [
      "Unsustainable yield farming incentives",
      "Ponzi-structured reward systems",
      "Token emission inflation traps",
      "Lock-up period exploitation",
    ],
    defenseMeasures: [
      "Sustainable tokenomics modeling",
      "Emissions schedule transparency",
      "Gradual unlock mechanisms",
      "Real yield verification",
    ],
  },
  {
    id: "russell",
    name: "Russell",
    patron: "Secret Order",
    domain: "Governance / Institutional Capture",
    exploitArchetype: "flash_loan",
    description:
      "Captures governance mechanisms to redirect protocol resources. Uses institutional frameworks for systemic control.",
    threatVectors: [
      "Flash loan governance attacks",
      "Proposal spam and fatigue",
      "Delegate vote manipulation",
      "Timelock bypass attempts",
    ],
    defenseMeasures: [
      "Vote-escrowed token governance",
      "Time-delayed execution",
      "Quorum requirements",
      "Snapshot-based voting power",
    ],
  },
  {
    id: "van_duyn",
    name: "Van Duyn",
    patron: "Asherah",
    domain: "Architecture / Protocol Standards",
    exploitArchetype: "supply_chain",
    description:
      "Controls the architectural standards and protocol specifications that define how systems interoperate.",
    threatVectors: [
      "Malicious standard proposals",
      "Proxy upgrade backdoors",
      "Implementation divergence attacks",
      "Dependency chain poisoning",
    ],
    defenseMeasures: [
      "Community standard review",
      "Timelocked upgrade mechanisms",
      "Multi-sig admin controls",
      "Implementation verification tools",
    ],
  },
];

// ─── 8 Watcher Domains ─────────────────────────────────────────────

export interface WatcherDomain {
  id: string;
  name: string;
  domain: string;
  description: string;
  expertise: string[];
  modernAnalogue: string;
}

export const WATCHER_DOMAINS: WatcherDomain[] = [
  {
    id: "azazel",
    name: "Azazel",
    domain: "Weaponry & Cybersecurity",
    description:
      "Guardian of offensive and defensive security arts. Specializes in exploit detection, penetration testing, and adversarial analysis of smart contracts.",
    expertise: [
      "Smart contract vulnerability detection",
      "Exploit chain analysis",
      "Adversarial simulation",
      "Security audit methodology",
    ],
    modernAnalogue: "Security Auditor / Red Team Lead",
  },
  {
    id: "semyaza",
    name: "Semyaza",
    domain: "Divination & Smart Contracts",
    description:
      "Master of predictive analysis and contract interpretation. Reads the patterns in code to foresee outcomes and identify hidden logic.",
    expertise: [
      "Contract behavior prediction",
      "State machine analysis",
      "Symbolic execution",
      "Formal verification guidance",
    ],
    modernAnalogue: "Smart Contract Analyst / Formal Verifier",
  },
  {
    id: "armaros",
    name: "Armaros",
    domain: "Cryptographic Ritual Orchestration",
    description:
      "Architect of binding agreements and cryptographic protocols. Designs secure multi-step processes and ceremony-based verification.",
    expertise: [
      "Multi-sig scheme design",
      "Cryptographic protocol analysis",
      "Key management review",
      "Ceremony coordination",
    ],
    modernAnalogue: "Cryptographer / Protocol Designer",
  },
  {
    id: "baraqel",
    name: "Baraqel",
    domain: "Timing & MEV Strategy",
    description:
      "Master of temporal dynamics and transaction ordering. Analyzes timing attacks, MEV opportunities, and block-level strategies.",
    expertise: [
      "MEV analysis and defense",
      "Transaction ordering strategy",
      "Block timing exploitation",
      "Flashbots/PBS integration",
    ],
    modernAnalogue: "MEV Researcher / Searcher Analyst",
  },
  {
    id: "kokabiel",
    name: "Kokabiel",
    domain: "Opcode Analysis & Gas Optimization",
    description:
      "Stellar mechanic who maps the low-level operations of the EVM. Optimizes bytecode and analyzes gas consumption patterns.",
    expertise: [
      "EVM opcode analysis",
      "Gas optimization",
      "Bytecode decompilation",
      "Assembly-level auditing",
    ],
    modernAnalogue: "EVM Engineer / Gas Optimizer",
  },
  {
    id: "tamiel",
    name: "Tamiel",
    domain: "On-Chain Analytics & Data Divination",
    description:
      "Earth sciences sage who surveys on-chain data landscapes. Identifies patterns, anomalies, and hidden relationships in blockchain data.",
    expertise: [
      "On-chain data analysis",
      "Transaction pattern recognition",
      "Whale movement tracking",
      "Protocol health metrics",
    ],
    modernAnalogue: "On-Chain Analyst / Data Scientist",
  },
  {
    id: "ramiel",
    name: "Ramiel",
    domain: "Recovery & Fund Tracing",
    description:
      "Master of resurrection and recovery. Traces stolen or lost funds and designs recovery strategies for compromised protocols.",
    expertise: [
      "Fund tracing and recovery",
      "Incident response planning",
      "Post-exploit forensics",
      "Protocol recovery design",
    ],
    modernAnalogue: "Incident Responder / Forensic Analyst",
  },
  {
    id: "daniel",
    name: "Daniel",
    domain: "Advanced Research & Zero-Day Discovery",
    description:
      "Explorer of forbidden and unknown arts. Researches novel attack vectors, zero-day vulnerabilities, and cutting-edge security techniques.",
    expertise: [
      "Zero-day vulnerability research",
      "Novel attack vector discovery",
      "Advanced persistent threat analysis",
      "Experimental security techniques",
    ],
    modernAnalogue: "Security Researcher / Zero-Day Hunter",
  },
];

// ─── 7 Defensive Paradigms ──────────────────────────────────────────

export interface DefenseParadigm {
  id: string;
  name: string;
  grimoireName: string;
  targetExploit: string;
  description: string;
  implementation: string[];
  tools: string[];
}

export const DEFENSE_PARADIGMS: DefenseParadigm[] = [
  {
    id: "checks_effects_interactions",
    name: "Checks-Effects-Interactions + ReentrancyGuard",
    grimoireName: "Ward of Binding Order",
    targetExploit: "reentrancy",
    description:
      "Enforces strict ordering: validate inputs, update state, then perform external calls. Combined with a mutex lock to prevent recursive entry.",
    implementation: [
      "Move all state changes before external calls",
      "Add OpenZeppelin ReentrancyGuard to vulnerable functions",
      "Use pull-over-push for ETH transfers",
      "Consider read-only reentrancy in view functions",
    ],
    tools: [
      "OpenZeppelin ReentrancyGuard",
      "Slither reentrancy detectors",
      "Foundry invariant tests",
    ],
  },
  {
    id: "commit_reveal_mev",
    name: "Commit-Reveal + Private Mempool",
    grimoireName: "Veil of Hidden Intent",
    targetExploit: "mev_extraction",
    description:
      "Hides transaction intent until execution time, preventing frontrunning and sandwich attacks through information concealment.",
    implementation: [
      "Implement two-phase commit-reveal for sensitive operations",
      "Use Flashbots Protect for private transaction submission",
      "Add deadline parameters to all swap operations",
      "Implement minimum output amount (slippage) checks",
    ],
    tools: [
      "Flashbots Protect RPC",
      "MEV Blocker",
      "CoW Protocol batch auctions",
    ],
  },
  {
    id: "flash_loan_defense",
    name: "TVL Limits + Invariant Verification",
    grimoireName: "Seal of Measured Conjuration",
    targetExploit: "flash_loan",
    description:
      "Limits single-transaction impact and verifies protocol invariants are maintained before and after operations.",
    implementation: [
      "Cap per-transaction operations to percentage of TVL",
      "Use Chainlink or TWAP oracles instead of spot prices",
      "Add time delays to governance and parameter changes",
      "Verify invariants (k=x*y) in critical operations",
    ],
    tools: [
      "Chainlink Price Feeds",
      "Uniswap V3 TWAP",
      "Custom invariant checkers",
    ],
  },
  {
    id: "vesting_liquidity",
    name: "Time-Locked Vesting + TWAP Incentives",
    grimoireName: "Temporal Binding Seal",
    targetExploit: "vampire_liquidity",
    description:
      "Prevents rapid liquidity extraction through time-based restrictions and time-weighted incentive calculations.",
    implementation: [
      "Implement linear or cliff vesting for rewards",
      "Add withdrawal delay periods",
      "Calculate incentives using time-weighted metrics",
      "Build protocol-owned liquidity reserves",
    ],
    tools: [
      "OpenZeppelin VestingWallet",
      "Sablier streaming contracts",
      "Custom vesting schedules",
    ],
  },
  {
    id: "bridge_security",
    name: "MPC Bridges + Fraud Proofs",
    grimoireName: "Ward of Portal Integrity",
    targetExploit: "bridge_exploit",
    description:
      "Secures cross-chain communication through multi-party validation, optimistic verification, and fraud proof mechanisms.",
    implementation: [
      "Require high validator threshold (2/3+) for message signing",
      "Implement optimistic verification with 7-day challenge period",
      "Add canonical message sequencing to prevent replay",
      "Use light client verification where possible",
    ],
    tools: [
      "LayerZero messaging",
      "Axelar cross-chain",
      "Optimistic rollup bridges",
    ],
  },
  {
    id: "zk_integrity",
    name: "Auditable Circuits + Formal Verification",
    grimoireName: "Seal of True Concealment",
    targetExploit: "zk_misuse",
    description:
      "Ensures zero-knowledge proof systems are correctly constructed and verified through mathematical proofs and multi-party ceremonies.",
    implementation: [
      "Conduct multi-party computation ceremony for trusted setup",
      "Formally verify circuit constraints match specification",
      "Implement strict nullifier tracking to prevent double-spend",
      "Audit proof verification contracts independently",
    ],
    tools: [
      "Circom/SnarkJS",
      "Noir language",
      "Formal verification tools (Certora, Halmos)",
    ],
  },
  {
    id: "supply_chain_integrity",
    name: "Reproducible Builds + Timelocked Upgrades",
    grimoireName: "Seal of Provenance",
    targetExploit: "supply_chain",
    description:
      "Ensures code integrity from source to deployment through verifiable builds, dependency auditing, and upgrade safety mechanisms.",
    implementation: [
      "Use deterministic compilation with verified compiler versions",
      "Implement timelocked proxy upgrades with community review",
      "Pin and audit all dependency versions",
      "Verify deployed bytecode matches source compilation",
    ],
    tools: [
      "Sourcify verification",
      "OpenZeppelin Defender",
      "Foundry deterministic builds",
    ],
  },
];
