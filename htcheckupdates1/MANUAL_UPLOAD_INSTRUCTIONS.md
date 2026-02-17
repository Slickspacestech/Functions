# Manual Configuration Upload Instructions

## The configuration has been updated with fixes for:
1. **Bluebeam Revu**: Now correctly detects version 21.7 (was detecting 20.3.3)
2. **TaxCycle**: Already working correctly, detecting version 14.2.57646.0

## To upload the updated configuration to Azure Key Vault:

### Option 1: Use Azure Portal (Easiest)
1. Go to https://portal.azure.com
2. Navigate to Key Vaults → huntertechvault
3. Go to Secrets → config-products
4. Click "+ Generate/Import" or "New Version"
5. Copy the entire contents of `products-config.json` file
6. Paste it as the secret value
7. Click "Create"

### Option 2: Use PowerShell (After Authentication)
```powershell
# First, connect to the correct tenant
# One of these tenants should work:
Connect-AzAccount -Tenant "f64d5148-50ff-47bd-a32a-c59e647de325"
# OR
Connect-AzAccount -Tenant "f8cdef31-a31e-4b4a-93e4-5f571e91255a"  
# OR
Connect-AzAccount -Tenant "e2d54eb5-3869-4f70-8578-dee5fc7331f4"

# Then upload the configuration
$configJson = Get-Content -Path ".\products-config.json" -Raw
$secretValue = ConvertTo-SecureString $configJson -AsPlainText -Force
Set-AzKeyVaultSecret -VaultName "huntertechvault" -Name "config-products" -SecretValue $secretValue
```

### Option 3: Use Azure CLI
```bash
# Login to Azure
az login --tenant "e2d54eb5-3869-4f70-8578-dee5fc7331f4"

# Upload the secret
az keyvault secret set --vault-name "huntertechvault" \
  --name "config-products" \
  --file "products-config.json"
```

## What was changed:
- **Bluebeam Revu pattern**: Changed from `<p[^>]*>(?:(?!</p>).)*?Revu\\s+(\\d{2}\\.\\d\\.\\d)[^<]*` to `Revu\\s+(\\d{1,2}\\.\\d{1,2}(?:\\.\\d+)?)`
- This allows detection of versions with 1 or 2 digit major/minor versions (like 21.7)

## Verification:
After uploading, the next time your Azure Function runs, it should:
1. Detect Bluebeam Revu version as 21.7 (not 20.3.3)
2. Continue detecting TaxCycle correctly as 14.2.57646.0
3. Send update notifications if the stored versions in Key Vault are older