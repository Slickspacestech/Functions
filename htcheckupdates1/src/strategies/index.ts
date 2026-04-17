import { ProductConfig } from "../types";
import { RegexStrategy } from "./RegexStrategy";
import { JsonApiStrategy } from "./JsonApiStrategy";
import { HtmlParseStrategy } from "./HtmlParseStrategy";
import { AutodeskStrategy } from "./AutodeskStrategy";

export interface IVersionStrategy {
  extract(url: string): Promise<string | null>;
}

export function createStrategy(config: ProductConfig): IVersionStrategy {
  switch (config.strategy) {
    case "regex":
      if (!config.pattern) throw new Error(`[${config.id}] regex strategy requires 'pattern'`);
      return new RegexStrategy(config.pattern, config.versionGroup ?? 1);

    case "json-api":
      if (!config.jsonPath) throw new Error(`[${config.id}] json-api strategy requires 'jsonPath'`);
      return new JsonApiStrategy(config.jsonPath);

    case "html-parse":
      if (!config.startMarker || !config.endMarker || !config.versionPattern) {
        throw new Error(`[${config.id}] html-parse strategy requires 'startMarker', 'endMarker', 'versionPattern'`);
      }
      return new HtmlParseStrategy(config.startMarker, config.endMarker, config.versionPattern);

    case "autodesk":
      return new AutodeskStrategy();

    default:
      throw new Error(`[${config.id}] Unknown strategy: ${(config as ProductConfig).strategy}`);
  }
}
