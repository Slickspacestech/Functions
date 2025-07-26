# Script to upload product configuration to Azure Key Vault
# Run this script locally or in Azure Cloud Shell

# Check if already connected to Azure
try {
    $context = Get-AzContext
    if (-not $context) {
        Write-Host "Not connected to Azure. Initiating device code login..." -ForegroundColor Yellow
        Connect-AzAccount -UseDeviceAuthentication
    } else {
        Write-Host "Already connected to Azure as: $($context.Account.Id)" -ForegroundColor Green
        Write-Host "Tenant: $($context.Tenant.Id)" -ForegroundColor Green
    }
} catch {
    Write-Host "Not connected to Azure. Initiating device code login..." -ForegroundColor Yellow
    Connect-AzAccount -UseDeviceAuthentication
}

# Set your Key Vault name
$vaultName = "huntertechvault"

# Read the configuration from the JSON file
$configJson = Get-Content -Path ".\products-config.json" -Raw

# Upload to Key Vault as a secret
$secretValue = ConvertTo-SecureString $configJson -AsPlainText -Force
Set-AzKeyVaultSecret -VaultName $vaultName -Name "config-products" -SecretValue $secretValue

Write-Host "Product configuration uploaded to Key Vault successfully!"
Write-Host "Total products configured: $((($configJson | ConvertFrom-Json).products).Count)"

# List all configured products
$config = $configJson | ConvertFrom-Json
Write-Host "`nConfigured products:"
foreach ($product in $config.products) {
    Write-Host "- $($product.name) (ID: $($product.id))"
}