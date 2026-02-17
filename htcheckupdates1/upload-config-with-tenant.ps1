# Script to upload product configuration to Azure Key Vault with tenant selection
# Run this script locally or in Azure Cloud Shell

# List of valid tenants for the Key Vault
$validTenants = @(
    "f64d5148-50ff-47bd-a32a-c59e647de325",
    "f8cdef31-a31e-4b4a-93e4-5f571e91255a", 
    "e2d54eb5-3869-4f70-8578-dee5fc7331f4"
)

Write-Host "Valid tenants for huntertechvault Key Vault:" -ForegroundColor Cyan
foreach ($tenant in $validTenants) {
    Write-Host "  - $tenant" -ForegroundColor Gray
}
Write-Host ""

# Check current context
try {
    $context = Get-AzContext
    if ($context) {
        Write-Host "Currently connected to:" -ForegroundColor Yellow
        Write-Host "  Account: $($context.Account.Id)" -ForegroundColor Gray
        Write-Host "  Tenant: $($context.Tenant.Id)" -ForegroundColor Gray
        
        if ($validTenants -contains $context.Tenant.Id) {
            Write-Host "✓ Already connected to a valid tenant!" -ForegroundColor Green
        } else {
            Write-Host "✗ Current tenant is not valid for this Key Vault" -ForegroundColor Red
            Write-Host ""
            Write-Host "Please select a tenant to connect to:" -ForegroundColor Yellow
            for ($i = 0; $i -lt $validTenants.Count; $i++) {
                Write-Host "  $($i+1). $($validTenants[$i])" -ForegroundColor Gray
            }
            $selection = Read-Host "Enter selection (1-$($validTenants.Count))"
            $selectedTenant = $validTenants[[int]$selection - 1]
            
            Write-Host "Connecting to tenant: $selectedTenant" -ForegroundColor Yellow
            Connect-AzAccount -Tenant $selectedTenant -UseDeviceAuthentication
        }
    } else {
        throw "No context"
    }
} catch {
    Write-Host "Not connected to Azure." -ForegroundColor Yellow
    Write-Host "Please select a tenant to connect to:" -ForegroundColor Yellow
    for ($i = 0; $i -lt $validTenants.Count; $i++) {
        Write-Host "  $($i+1). $($validTenants[$i])" -ForegroundColor Gray
    }
    $selection = Read-Host "Enter selection (1-$($validTenants.Count))"
    $selectedTenant = $validTenants[[int]$selection - 1]
    
    Write-Host "Connecting to tenant: $selectedTenant" -ForegroundColor Yellow
    Connect-AzAccount -Tenant $selectedTenant -UseDeviceAuthentication
}

# Set your Key Vault name
$vaultName = "huntertechvault"

# Read the configuration from the JSON file
$configJson = Get-Content -Path ".\products-config.json" -Raw

# Parse to verify it's valid JSON
try {
    $config = $configJson | ConvertFrom-Json
    Write-Host ""
    Write-Host "Configuration loaded successfully!" -ForegroundColor Green
    Write-Host "Total products: $($config.products.Count)" -ForegroundColor Gray
} catch {
    Write-Host "Error parsing JSON configuration: $_" -ForegroundColor Red
    exit 1
}

# Upload to Key Vault as a secret
try {
    Write-Host ""
    Write-Host "Uploading configuration to Key Vault..." -ForegroundColor Yellow
    $secretValue = ConvertTo-SecureString $configJson -AsPlainText -Force
    $result = Set-AzKeyVaultSecret -VaultName $vaultName -Name "config-products" -SecretValue $secretValue
    
    Write-Host "✓ Product configuration uploaded to Key Vault successfully!" -ForegroundColor Green
    Write-Host ""
    Write-Host "Secret Details:" -ForegroundColor Cyan
    Write-Host "  Name: config-products" -ForegroundColor Gray
    Write-Host "  Version: $($result.Version)" -ForegroundColor Gray
    Write-Host "  Updated: $($result.Updated)" -ForegroundColor Gray
    
    # List all configured products
    Write-Host ""
    Write-Host "Configured products:" -ForegroundColor Cyan
    foreach ($product in $config.products) {
        $status = if ($product.enabled) { "✓" } else { "✗" }
        Write-Host "  $status $($product.name) (ID: $($product.id))" -ForegroundColor Gray
    }
} catch {
    Write-Host "✗ Failed to upload configuration to Key Vault" -ForegroundColor Red
    Write-Host "Error: $_" -ForegroundColor Red
    exit 1
}