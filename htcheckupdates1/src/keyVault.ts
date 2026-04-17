import { DefaultAzureCredential } from "@azure/identity";
import { SecretClient } from "@azure/keyvault-secrets";

let secretClient: SecretClient | null = null;

const SECRET_TO_ENV_MAP: Record<string, string> = {
  "smtp2go-secret": "SMTP2GO_API_KEY",
};

function getSecretClient(): SecretClient | null {
  if (!secretClient) {
    const keyVaultName = process.env.KEY_VAULT_NAME;
    if (!keyVaultName) return null;
    secretClient = new SecretClient(
      `https://${keyVaultName}.vault.azure.net`,
      new DefaultAzureCredential(),
    );
  }
  return secretClient;
}

export async function getSecret(secretName: string): Promise<string> {
  const envVarName = SECRET_TO_ENV_MAP[secretName] ?? secretName;
  const envValue = process.env[envVarName];
  if (envValue) return envValue;

  const client = getSecretClient();
  if (!client) {
    throw new Error(
      `Secret '${secretName}' not found in environment (tried ${envVarName}) and KEY_VAULT_NAME is not set`,
    );
  }

  const secret = await client.getSecret(secretName);
  if (!secret.value) throw new Error(`Secret '${secretName}' not found or has no value`);
  return secret.value;
}
