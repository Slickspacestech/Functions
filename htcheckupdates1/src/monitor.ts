import { InvocationContext } from "@azure/functions";
import { getProductConfigs, getVersion, setVersion } from "./cosmos";
import { createStrategy } from "./strategies";
import { sendEmail } from "./email";
import { MonitorResult } from "./types";

const RECIPIENT = "matt@huntertech.ca";
const SENDER = "patching@huntertech.ca";

export async function runMonitoring(context: InvocationContext): Promise<MonitorResult[]> {
  const products = await getProductConfigs();
  context.log(`Loaded ${products.length} products (${products.filter(p => p.enabled).length} enabled)`);

  const results: MonitorResult[] = [];

  for (const product of products) {
    if (!product.enabled) continue;

    const result: MonitorResult = {
      productId: product.id,
      productName: product.name,
      currentVersion: null,
      latestVersion: null,
      updateAvailable: false,
      success: false,
    };

    try {
      const strategy = createStrategy(product);
      const [latestVersion, currentVersion] = await Promise.all([
        strategy.extract(product.url),
        getVersion(product.id),
      ]);

      result.currentVersion = currentVersion;
      result.latestVersion = latestVersion;

      if (!latestVersion) {
        context.warn(`[${product.id}] Version extraction failed`);
        await sendEmail({
          to: RECIPIENT,
          sender: SENDER,
          subject: `Update check failed: ${product.name}`,
          body: `Could not extract version from ${product.url}`,
        }).catch((err) => context.error(`[${product.id}] Failed to send failure email: ${err}`));
      } else if (!currentVersion) {
        context.log(`[${product.id}] Initial version: ${latestVersion}`);
        await setVersion(product.id, latestVersion, null);
        result.success = true;
      } else if (latestVersion !== currentVersion) {
        context.log(`[${product.id}] Update: ${currentVersion} → ${latestVersion}`);
        await setVersion(product.id, latestVersion, currentVersion);
        await sendEmail({
          to: RECIPIENT,
          sender: SENDER,
          subject: `Update available: ${product.name} ${latestVersion}`,
          body: `${product.name} has a new release.\n\nNew:      ${latestVersion}\nPrevious: ${currentVersion}\n\n${product.url}`,
        });
        result.updateAvailable = true;
        result.success = true;
      } else {
        context.log(`[${product.id}] Up to date: ${currentVersion}`);
        result.success = true;
      }
    } catch (err) {
      const msg = err instanceof Error ? err.message : String(err);
      context.error(`[${product.id}] Unhandled error: ${msg}`);
      result.error = msg;
    }

    results.push(result);
  }

  return results;
}
