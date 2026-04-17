import { IVersionStrategy } from "./index";

const USER_AGENT = "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36";

export class RegexStrategy implements IVersionStrategy {
  constructor(
    private readonly pattern: string,
    private readonly versionGroup: number,
  ) {}

  async extract(url: string): Promise<string | null> {
    try {
      const response = await fetch(url, { headers: { "User-Agent": USER_AGENT } });
      const html = await response.text();
      const match = new RegExp(this.pattern, "i").exec(html);
      return match?.[this.versionGroup]?.trim() ?? null;
    } catch {
      return null;
    }
  }
}
