/**
 * GrimoireConfig — configuration type definitions
 */

export type EpistemicStatus = "documented" | "contested" | "speculative" | "fiction";

export interface OpenMythosConfig {
  /** 'mock' for offline mode, 'online' to use the real OpenMythos API */
  mode: "mock" | "online";
  model: string;
  apiKey: string;
  baseUrl: string;
  timeout: number;
}

export interface CorpusConfig {
  rootDir: string;
  schemasDir: string;
  entriesDir: string;
  entitiesDir: string;
  factionsDir: string;
  ritualsDir: string;
  timelinesDir: string;
}

export interface GenerationConfig {
  seed: number;
  deterministicMode: boolean;
  defaultEpistemicStatus: EpistemicStatus;
  requireCitationsFor: EpistemicStatus[];
  autoLabel: boolean;
}

export interface SafetyConfig {
  enableContentFilter: boolean;
  rejectExploitInstructions: boolean;
  requireDefensiveFocusOnSecurity: boolean;
  allowedEpistemicStatuses: EpistemicStatus[];
}

export interface ExportConfig {
  outputDir: string;
  formats: Array<"json" | "yaml" | "markdown">;
  includeSchemas: boolean;
}

export interface GrimoireConfig {
  openmythos: OpenMythosConfig;
  corpus: CorpusConfig;
  generation: GenerationConfig;
  safety: SafetyConfig;
  export: ExportConfig;
}

export interface CommandContext {
  config: GrimoireConfig;
  flags: string[];
  verbose: boolean;
}
