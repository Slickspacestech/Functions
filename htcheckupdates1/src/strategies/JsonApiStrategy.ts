import { IVersionStrategy } from "./index";

export class JsonApiStrategy implements IVersionStrategy {
  constructor(private readonly jsonPath: string) {}

  async extract(url: string): Promise<string | null> {
    try {
      const response = await fetch(url, {
        headers: {
          "Accept": "application/json",
          "User-Agent": "UpdateMonitor/2.0",
        },
      });
      const data = await response.json() as Record<string, unknown>;

      // Navigate dot-path — supports array indices as numeric strings (e.g. "releases.0.version")
      let value: unknown = data;
      for (const part of this.jsonPath.split(".")) {
        if (value == null || typeof value !== "object") return null;
        value = (value as Record<string, unknown>)[part];
      }

      if (typeof value !== "string") return null;
      return value.replace(/^v/, "").trim();
    } catch {
      return null;
    }
  }
}
