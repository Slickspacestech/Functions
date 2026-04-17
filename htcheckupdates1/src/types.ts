export type StrategyType = 'regex' | 'json-api' | 'html-parse' | 'autodesk';

export interface ProductConfig {
  id: string;
  partitionKey: string;
  type: 'software-product';
  name: string;
  url: string;
  strategy: StrategyType;
  keyVaultKey: string;
  enabled: boolean;
  // regex
  pattern?: string;
  versionGroup?: number;
  // json-api
  jsonPath?: string;
  // html-parse
  startMarker?: string;
  endMarker?: string;
  versionPattern?: string;
}

export interface VersionDoc {
  id: string;           // "version:{productId}"
  partitionKey: string; // "software-updates"
  type: 'software-version';
  productId: string;
  version: string;
  previousVersion?: string;
  detectedAt: string;
  updatedAt: string;
}

export interface MonitorResult {
  productId: string;
  productName: string;
  currentVersion: string | null;
  latestVersion: string | null;
  updateAvailable: boolean;
  success: boolean;
  error?: string;
}
