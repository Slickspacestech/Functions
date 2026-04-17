import { CosmosClient, Container, Database, SqlQuerySpec } from "@azure/cosmos";
import { DefaultAzureCredential } from "@azure/identity";
import { ProductConfig, VersionDoc } from "./types";

const DATABASE_NAME = "helpdesk";
const SW_PARTITION = "software-updates";

const CONTAINERS = {
  CACHE: "cache",
} as const;

let cosmosClient: CosmosClient | null = null;
let database: Database | null = null;
const containers: Map<string, Container> = new Map();

function getCosmosClient(): CosmosClient {
  if (!cosmosClient) {
    const connectionString = process.env.COSMOS_CONNECTION_STRING;
    const endpoint = process.env.COSMOS_ENDPOINT;

    if (connectionString) {
      cosmosClient = new CosmosClient(connectionString);
    } else if (endpoint) {
      cosmosClient = new CosmosClient({ endpoint, aadCredentials: new DefaultAzureCredential() });
    } else {
      throw new Error("Either COSMOS_CONNECTION_STRING or COSMOS_ENDPOINT must be set");
    }
  }
  return cosmosClient;
}

function getDatabase(): Database {
  if (!database) {
    database = getCosmosClient().database(DATABASE_NAME);
  }
  return database;
}

function getContainer(containerName: string): Container {
  let container = containers.get(containerName);
  if (!container) {
    container = getDatabase().container(containerName);
    containers.set(containerName, container);
  }
  return container;
}

async function getCacheDocument<T>(id: string, partitionKey: string): Promise<T | null> {
  try {
    const { resource } = await getContainer(CONTAINERS.CACHE).item(id, partitionKey).read();
    return (resource as T) ?? null;
  } catch (error: unknown) {
    if (error && typeof error === "object" && "code" in error && error.code === 404) return null;
    throw error;
  }
}

async function queryCacheDocuments<T>(
  query: string,
  parameters: { name: string; value: string | number | boolean | null }[] = [],
  partitionKey?: string,
): Promise<T[]> {
  const querySpec: SqlQuerySpec = { query, parameters };
  const options = partitionKey ? { partitionKey } : {};
  const { resources } = await getContainer(CONTAINERS.CACHE).items.query<T>(querySpec, options).fetchAll();
  return resources;
}

async function upsertCacheDocument<T extends { id: string; partitionKey: string }>(document: T): Promise<T> {
  const { resource } = await getContainer(CONTAINERS.CACHE).items.upsert(document);
  return resource as unknown as T;
}

// =============================================================================
// Software-updates helpers
// =============================================================================

export async function getProductConfigs(): Promise<ProductConfig[]> {
  return queryCacheDocuments<ProductConfig>(
    'SELECT * FROM c WHERE c.type = "software-product" ORDER BY c.name',
    [],
    SW_PARTITION,
  );
}

export async function getVersion(productId: string): Promise<string | null> {
  const doc = await getCacheDocument<VersionDoc>(`version:${productId}`, SW_PARTITION);
  return doc?.version ?? null;
}

export async function setVersion(
  productId: string,
  version: string,
  previous: string | null,
): Promise<void> {
  const now = new Date().toISOString();
  const doc: VersionDoc = {
    id: `version:${productId}`,
    partitionKey: SW_PARTITION,
    type: "software-version",
    productId,
    version,
    detectedAt: now,
    updatedAt: now,
  };
  if (previous) doc.previousVersion = previous;
  await upsertCacheDocument(doc);
}
