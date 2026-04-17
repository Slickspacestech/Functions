/**
 * AutodeskStrategy
 *
 * Handles Autodesk help pages that list product updates in a <ul><li><a> structure.
 * Equivalent to the PowerShell: $html.html.body.div.ul.li.a[0].'#text'.replace(' Update','')
 *
 * Extracts the text of the first <a> inside the first <ul>, then strips the " Update" suffix.
 */
import { IVersionStrategy } from "./index";

const USER_AGENT = "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36";

export class AutodeskStrategy implements IVersionStrategy {
  async extract(url: string): Promise<string | null> {
    try {
      const response = await fetch(url, { headers: { "User-Agent": USER_AGENT } });
      const html = await response.text();

      // Find the first <ul>…</ul> block
      const ulMatch = /<ul[^>]*>([\s\S]*?)<\/ul>/i.exec(html);
      if (!ulMatch) return null;

      // Find the first <li><a …>text</a> within it
      const aMatch = /<li[^>]*>[\s\S]*?<a[^>]*>([^<]+)<\/a>/i.exec(ulMatch[1]);
      if (!aMatch) return null;

      return aMatch[1].replace(/\s+Update\s*$/i, "").trim();
    } catch {
      return null;
    }
  }
}
