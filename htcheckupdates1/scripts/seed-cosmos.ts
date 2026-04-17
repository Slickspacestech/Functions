/**
 * seed-cosmos.ts
 *
 * Seeds product configs from products-config.json into Cosmos DB.
 * Run once after initial deployment or to reset configs:
 *   npm run seed
 *
 * Requires COSMOS_CONNECTION_STRING (or COSMOS_ENDPOINT) in environment.
 * Copy local.settings.json.example to local.settings.json and fill in values.
 */

import * as dotenv from "dotenv";
dotenv.config({ path: "local.settings.json" });

// local.settings.json uses "Values" wrapper — flatten to process.env
try {
  const settings = require("../local.settings.json") as { Values?: Record<string, string> };
  if (settings.Values) {
    for (const [k, v] of Object.entries(settings.Values)) {
      process.env[k] = v;
    }
  }
} catch {
  // File not present — rely on actual environment vars
}

import { CosmosClient } from "@azure/cosmos";
import * as fs from "fs";
import * as path from "path";

const DATABASE_NAME = "helpdesk";
const CONTAINER_NAME = "cache";
const PARTITION_KEY = "software-updates";

async function seed(): Promise<void> {
  const connectionString = process.env.COSMOS_CONNECTION_STRING;
  if (!connectionString) {
    console.error("COSMOS_CONNECTION_STRING is required for seeding");
    process.exit(1);
  }

  const client = new CosmosClient(connectionString);
  const container = client.database(DATABASE_NAME).container(CONTAINER_NAME);

  const configPath = path.join(__dirname, "..", "products-config.json");
  const config = JSON.parse(fs.readFileSync(configPath, "utf8")) as {
    products: Array<Record<string, unknown>>;
  };

  console.log(`Seeding ${config.products.length} products...`);

  for (const product of config.products) {
    // id stays as the bare product id (e.g. "bluebeam-revu")
    // version docs use id "version:{productId}" in the same partition — no collision
    const doc = {
      ...product,
      partitionKey: PARTITION_KEY,
      type: "software-product",
    };
    await container.items.upsert(doc);
    console.log(`  ✓ ${product.name}`);
  }

  console.log("Done.");
}

seed().catch((err) => {
  console.error("Seed failed:", err);
  process.exit(1);
});
