# Script to create Enterprise App for client tenant and configure Huntertech monitoring
# Required modules
$requiredModules = @(
    @{Name = "Microsoft.Graph.Applications"; Version = "2.0.0"},
    @{Name = "Microsoft.Graph.Authentication"; Version = "2.0.0"},
    @{Name = "Az.Accounts"; Version = "2.10.0"},
    @{Name = "Az.Storage"; Version = "5.0.0"},
    @{Name = "Az.KeyVault"; Version = "4.0.0"},
    @{Name = "Az.WebSites"; Version = "3.0.0"},
    @{Name = "AzTable"; Version = "2.1.0"}
)

# Install and import required modules
foreach ($module in $requiredModules) {
    if (-not (Get-Module -ListAvailable -Name $module.Name | Where-Object { $_.Version -ge $module.Version })) {
        Write-Host "Installing $($module.Name)..."
        Install-Module -Name $module.Name -MinimumVersion $module.Version -Force
    }
    Import-Module -Name $module.Name -Force
}

# Constants
$HT_SUBSCRIPTION_ID = "098c55e5-b140-49ba-a490-a1a51e259748"
$HT_RESOURCE_GROUP = "htupdatechecker"
$HT_STORAGE_ACCOUNT = "htupdatechecker"
$HT_KEY_VAULT = "huntertechvault"
$HT_FUNCTION_APP = "htupdatechecker2"

function Update-ApplicationPermissions {
    param (
        [Parameter(Mandatory=$true)]
        [string]$ApplicationId
    )

    $requiredResourceAccess = @(
        @{
            ResourceAppId = "00000003-0000-0000-c000-000000000000" # Microsoft Graph
            ResourceAccess = @(
                @{Id = "9a5d68dd-52b0-4cc2-bd40-abcf44ac3a30"; Type = "Role"}, # Application.Read.All
                @{Id = "7ab1d382-f21e-4acd-a863-ba3e13f7da61"; Type = "Role"}, # Directory.Read.All
                @{Id = "df021288-bdef-4463-88db-98f22de89214"; Type = "Role"}, # User.Read.All
                @{Id = "5b567255-7703-4780-807c-7be8301ae99b"; Type = "Role"}, # Organization.Read.All
                @{Id = "246dd0d5-5bd0-4def-940b-0421030a5b68"; Type = "Role"}, # Reports.Read.All
                @{Id = "230c1aed-a721-4c5d-9cb4-a90514e508ef"; Type = "Role"}, # Policy.Read.All
                @{Id = "483bed4a-2ad3-4361-a73b-c83ccdbdc53c"; Type = "Role"}, # SecurityEvents.Read.All
                @{Id = "dc377aa6-52d8-4e23-b271-2a7ae04cedf3"; Type = "Role"}, # SecurityActions.Read.All
                @{Id = "40f97065-369a-49f4-947c-6a255697ae91"; Type = "Role"}, # IdentityRiskyUser.Read.All
            )
        }
    )

    Update-MgApplication -ApplicationId $ApplicationId -RequiredResourceAccess $requiredResourceAccess
}

# Step 1: Connect to client tenant
Write-Host "`n=== Step 1: Connecting to CLIENT tenant ===" -ForegroundColor Green
Write-Host "Please sign in with CLIENT tenant Global Admin credentials..."
Connect-MgGraph -Scopes "Application.ReadWrite.All", "Directory.ReadWrite.All"

# Get client tenant details
$orgInfo = Get-MgOrganization
$tenantName = $orgInfo.DisplayName
$sanitizedTenantName = $tenantName -replace '[^a-zA-Z0-9]', ''

# Create or update app registration
$appName = "Huntertech"
$app = Get-MgApplication -Filter "DisplayName eq '$appName'"
if (-not $app) {
    Write-Host "Creating new application: $appName"
    $app = New-MgApplication -DisplayName $appName
} else {
    Write-Host "Found existing application: $appName"
}

# Update permissions
Update-ApplicationPermissions -ApplicationId $app.Id

# Create and configure certificate
$certName = "Huntertech-$sanitizedTenantName"
$cert = New-SelfSignedCertificate -Subject "CN=$certName" `
    -CertStoreLocation "Cert:\CurrentUser\My" `
    -KeyExportPolicy Exportable `
    -KeySpec Signature `
    -KeyLength 2048 `
    -KeyAlgorithm RSA `
    -HashAlgorithm SHA256 `
    -NotAfter (Get-Date).AddYears(2)

# Export certificate
$pfxPassword = ConvertTo-SecureString -String "Wn'i[92~dS.at0eL9<r!" -Force -AsPlainText
$pfxPath = ".\Huntertech-$sanitizedTenantName.pfx"
Export-PfxCertificate -Cert $cert -FilePath $pfxPath -Password $pfxPassword

# Add certificate to application
$certBase64 = [System.Convert]::ToBase64String($cert.GetRawCertData())
$params = @{
    keyCredentials = @(
        @{
            displayName = $certName
            type = "AsymmetricX509Cert"
            usage = "Verify"
            key = [System.Convert]::FromBase64String($certBase64)
            startDateTime = $cert.NotBefore
            endDateTime = $cert.NotAfter
        }
    )
}
Update-MgApplication -ApplicationId $app.Id -BodyParameter $params

# Step 2: Connect to Huntertech tenant
Write-Host "`n=== Step 2: Connecting to HUNTERTECH tenant ===" -ForegroundColor Green
Write-Host "Please sign in with HUNTERTECH tenant admin credentials..."
Disconnect-AzAccount -ErrorAction SilentlyContinue
Connect-AzAccount -Subscription $HT_SUBSCRIPTION_ID

# Get storage account context and create/update table
$storageAccount = Get-AzStorageAccount -ResourceGroupName $HT_RESOURCE_GROUP -Name $HT_STORAGE_ACCOUNT
$ctx = $storageAccount.Context
$tableName = "tenants"
$table = Get-AzStorageTable -Name $tableName -Context $ctx -ErrorAction SilentlyContinue
if (-not $table) {
    $table = New-AzStorageTable -Name $tableName -Context $ctx
}

# Update table entry
$tableEntry = @{
    PartitionKey = "tenants"
    RowKey = [guid]::NewGuid().ToString()
    TenantName = $tenantName
    AppId = $app.AppId
    CertThumbprint = $cert.Thumbprint
    DateAdded = (Get-Date).ToString("yyyy-MM-dd HH:mm:ss")
    IsActive = $true
}

$existingTenant = Get-AzTableRow -Table $table.CloudTable -PartitionKey "tenants" | 
    Where-Object { $_.TenantName -eq $tenantName }

if ($existingTenant) {
    $existingTenant.AppId = $tableEntry.AppId
    $existingTenant.CertThumbprint = $tableEntry.CertThumbprint
    $existingTenant.DateAdded = $tableEntry.DateAdded
    $existingTenant.IsActive = $tableEntry.IsActive
    Update-AzTableRow -Table $table.CloudTable -Entity $existingTenant
} else {
    Add-AzTableRow -Table $table.CloudTable -Property $tableEntry
}

# Import certificate to Key Vault
$kvCertName = "cert2-$sanitizedTenantName"
$existingCert = Get-AzKeyVaultCertificate -VaultName $HT_KEY_VAULT -Name $kvCertName -ErrorAction SilentlyContinue
if (-not $existingCert) {
    $existingCert = Get-AzKeyVaultCertificate -VaultName $HT_KEY_VAULT -Name $kvCertName -ErrorAction SilentlyContinue -InRemovedState
}

if ($existingCert) {
    $timestamp = Get-Date -Format "yyyyMMddHHmmss"
    $kvCertName = "cert2-$sanitizedTenantName-$timestamp"
}

$newCert = Import-AzKeyVaultCertificate -VaultName $HT_KEY_VAULT -Name $kvCertName -FilePath $pfxPath -Password $pfxPassword

# Import certificate to Azure Function
Write-Host "`n=== Step 3: Importing certificate to Azure Function ===" -ForegroundColor Green
$functionApp = Get-AzWebApp -ResourceGroupName $HT_RESOURCE_GROUP -Name $HT_FUNCTION_APP
$kvSecretId = $newCert.SecretId

# Add Key Vault reference to Function App
$certificates = @()
if ($functionApp.ClientCertEnabled) {
    $certificates = $functionApp.ClientCertificates
}
$certificates += @{
    KeyVaultId = $kvSecretId
    Name = $kvCertName
}

#Set-AzWebApp -ResourceGroupName $HT_RESOURCE_GROUP -Name $HT_FUNCTION_APP -ClientCertEnabled $true -ClientCertificates $certificates

# Add this verification section before the final summary
Write-Host "`n=== Verifying Certificate Thumbprints ===" -ForegroundColor Green

# Get the app registration certificate thumbprint
$appCerts = Get-MgApplication -ApplicationId $app.Id | 
    Select-Object -ExpandProperty KeyCredentials
$appThumbprint = $appCerts | 
    Where-Object { $_.DisplayName -eq $certName } | 
    Select-Object -ExpandProperty CustomKeyIdentifier | 
    ForEach-Object { [System.Convert]::ToHexString($_).ToUpper() }

# Get the Key Vault certificate thumbprint
$kvThumbprint = $newCert.Thumbprint

# Compare thumbprints
if ($appThumbprint -eq $kvThumbprint) {
    Write-Host "Certificate thumbprint verification successful!" -ForegroundColor Green
    Write-Host "App Registration Thumbprint: $appThumbprint"
    Write-Host "Key Vault Certificate Thumbprint: $kvThumbprint"
} else {
    Write-Host "WARNING: Certificate thumbprint mismatch!" -ForegroundColor Red
    Write-Host "App Registration Thumbprint: $appThumbprint"
    Write-Host "Key Vault Certificate Thumbprint: $kvThumbprint"
    Write-Host "Please verify the certificate configuration manually."
    throw "Certificate thumbprint mismatch detected"
}

# Output summary
Write-Host "`n=== Configuration Complete ===" -ForegroundColor Green
Write-Host "Client Tenant Name: $tenantName"
Write-Host "Application ID: $($app.AppId)"
Write-Host "Certificate Thumbprint: $($cert.Thumbprint)"
Write-Host "Key Vault Certificate Name: $kvCertName"
Write-Host "PFX file exported to: $pfxPath"
Write-Host "`nIMPORTANT: Please grant admin consent in the Azure Portal for the application permissions & import cert into azure functions"

