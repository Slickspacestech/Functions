import { IVersionStrategy } from "./index";

const USER_AGENT = "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36";

export class HtmlParseStrategy implements IVersionStrategy {
  constructor(
    private readonly startMarker: string,
    private readonly endMarker: string,
    private readonly versionPattern: string,
  ) {}

  async extract(url: string): Promise<string | null> {
    try {
      const response = await fetch(url, { headers: { "User-Agent": USER_AGENT } });
      const html = await response.text();

      const startIdx = html.indexOf(this.startMarker);
      if (startIdx === -1) return null;

      const endIdx = html.indexOf(this.endMarker, startIdx);
      const section = endIdx === -1
        ? html.slice(startIdx)
        : html.slice(startIdx, endIdx + this.endMarker.length);

      const match = new RegExp(this.versionPattern, "i").exec(section);
      return match?.[1]?.trim() ?? null;
    } catch {
      return null;
    }
  }
}
