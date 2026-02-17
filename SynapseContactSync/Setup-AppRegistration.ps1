# Setup-AppRegistration.ps1
# Creates Azure AD App Registration for Synapse Contact Sync
#
# MULTI-TENANT SETUP:
# - App Registration is created in the SYNAPSE tenant (synapsetax.ca)
# - Certificate and secrets are stored in HUNTERTECH Key Vault
#
# Run this script interactively with:
# - Global Admin or Application Admin rights in the Synapse tenant

#Requires -Modules Az.Accounts, Az.Resources, Az.KeyVault, Microsoft.Graph.Applications, Microsoft.Graph.Identity.DirectoryManagement

param(
    [Parameter(Mandatory=$false)]
    [string]$AppName = "SynapseContactSync",

    [Parameter(Mandatory=$false)]
    [int]$CertificateValidityYears = 2,

    [Parameter(Mandatory=$false)]
    [string]$KeyVaultName = "huntertechvault",

    [Parameter(Mandatory=$false)]
    [string]$SynapseTenantId = "",  # Will prompt if not provided

    [Parameter(Mandatory=$false)]
    [string]$HunterTechSubscriptionId = "",  # Will prompt if not provided

    [Parameter(Mandatory=$false)]
    [switch]$SkipCertificateCreation
)

$ErrorActionPreference = "Stop"

Write-Host "========================================" -ForegroundColor Cyan
Write-Host "  Synapse Contact Sync - App Setup" -ForegroundColor Cyan
Write-Host "  (Multi-Tenant Configuration)" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""
Write-Host "This script will:" -ForegroundColor White
Write-Host "  1. Create App Registration in SYNAPSE tenant (synapsetax.ca)" -ForegroundColor Gray
Write-Host "  2. Store certificate/secrets in HUNTERTECH Key Vault" -ForegroundColor Gray
Write-Host ""

#region Get Tenant Information

# Get Synapse tenant ID if not provided
if ([string]::IsNullOrWhiteSpace($SynapseTenantId)) {
    Write-Host "Enter the Synapse tenant ID (synapsetax.ca):" -ForegroundColor Yellow
    Write-Host "  (You can find this in Azure Portal > Microsoft Entra ID > Overview)" -ForegroundColor Gray
    $SynapseTenantId = Read-Host "Synapse Tenant ID"
}

if ([string]::IsNullOrWhiteSpace($SynapseTenantId)) {
    Write-Error "Synapse Tenant ID is required"
    exit 1
}

#endregion

#region Connect to Synapse Tenant for App Registration

Write-Host ""
Write-Host "Step 1: Connecting to Synapse tenant for App Registration..." -ForegroundColor Yellow
Write-Host "  You will be prompted to sign in with a Synapse admin account" -ForegroundColor Gray

# Connect to Microsoft Graph in Synapse tenant
$graphScopes = @(
    "Application.ReadWrite.All",
    "AppRoleAssignment.ReadWrite.All",
    "Directory.ReadWrite.All",
    "RoleManagement.ReadWrite.Directory"
)

try {
    # Disconnect any existing Graph connection
    Disconnect-MgGraph -ErrorAction SilentlyContinue

    # Connect to Synapse tenant
    Connect-MgGraph -Scopes $graphScopes -TenantId $SynapseTenantId
    $mgContext = Get-MgContext

    if ($mgContext.TenantId -ne $SynapseTenantId) {
        Write-Error "Connected to wrong tenant. Expected: $SynapseTenantId, Got: $($mgContext.TenantId)"
        exit 1
    }

    Write-Host "  Connected to Microsoft Graph" -ForegroundColor Green
    Write-Host "  Tenant: $($mgContext.TenantId)" -ForegroundColor Green
    Write-Host "  Account: $($mgContext.Account)" -ForegroundColor Green
}
catch {
    Write-Error "Failed to connect to Microsoft Graph in Synapse tenant: $_"
    throw
}

$synapseTenantIdConfirmed = $mgContext.TenantId

#endregion

#region Create Self-Signed Certificate

Write-Host ""
Write-Host "Step 2: Creating certificate..." -ForegroundColor Yellow

$certSubject = "CN=$AppName"
$certPath = Join-Path $PSScriptRoot "$AppName.pfx"
$certCerPath = Join-Path $PSScriptRoot "$AppName.cer"

if (-not $SkipCertificateCreation) {
    # Generate a secure password for the PFX
    $certPassword = [System.Web.Security.Membership]::GeneratePassword(24, 4)
    $certSecurePassword = ConvertTo-SecureString -String $certPassword -Force -AsPlainText

    # Create self-signed certificate
    $certStartDate = Get-Date
    $certEndDate = $certStartDate.AddYears($CertificateValidityYears)

    Write-Host "  Creating self-signed certificate..." -ForegroundColor Gray
    Write-Host "    Subject: $certSubject" -ForegroundColor Gray
    Write-Host "    Valid: $($certStartDate.ToString('yyyy-MM-dd')) to $($certEndDate.ToString('yyyy-MM-dd'))" -ForegroundColor Gray

    $cert = New-SelfSignedCertificate `
        -Subject $certSubject `
        -CertStoreLocation "Cert:\CurrentUser\My" `
        -KeyExportPolicy Exportable `
        -KeySpec Signature `
        -KeyLength 2048 `
        -KeyAlgorithm RSA `
        -HashAlgorithm SHA256 `
        -NotBefore $certStartDate `
        -NotAfter $certEndDate

    $thumbprint = $cert.Thumbprint
    Write-Host "  Certificate created with thumbprint: $thumbprint" -ForegroundColor Green

    # Export to PFX (with private key)
    Export-PfxCertificate -Cert "Cert:\CurrentUser\My\$thumbprint" -FilePath $certPath -Password $certSecurePassword | Out-Null
    Write-Host "  Exported PFX to: $certPath" -ForegroundColor Green

    # Export to CER (public key only, for uploading to Azure)
    Export-Certificate -Cert "Cert:\CurrentUser\My\$thumbprint" -FilePath $certCerPath | Out-Null
    Write-Host "  Exported CER to: $certCerPath" -ForegroundColor Green

    # Get base64 of certificate for app registration
    $certBase64 = [System.Convert]::ToBase64String($cert.RawData)
}
else {
    Write-Host "  Skipping certificate creation (using existing)" -ForegroundColor Gray
    $thumbprint = Read-Host "Enter existing certificate thumbprint"
    $cert = Get-ChildItem "Cert:\CurrentUser\My\$thumbprint"
    $certBase64 = [System.Convert]::ToBase64String($cert.RawData)
}

#endregion

#region Create App Registration

Write-Host ""
Write-Host "Step 3: Creating App Registration..." -ForegroundColor Yellow

# Check if app already exists
$existingApp = Get-MgApplication -Filter "displayName eq '$AppName'" -ErrorAction SilentlyContinue
if ($existingApp) {
    Write-Host "  App Registration '$AppName' already exists. AppId: $($existingApp.AppId)" -ForegroundColor Yellow
    $response = Read-Host "  Do you want to update it? (Y/N)"
    if ($response -ne 'Y') {
        Write-Host "  Exiting..." -ForegroundColor Red
        exit 1
    }
    $app = $existingApp
}
else {
    # Define required API permissions
    $requiredResourceAccess = @(
        # Microsoft Graph - Sites.Read.All (for SharePoint via PnP)
        @{
            ResourceAppId = "00000003-0000-0000-c000-000000000000"  # Microsoft Graph
            ResourceAccess = @(
                @{
                    Id = "332a536c-c7ef-4017-ab91-336970924f0d"  # Sites.Read.All (Application)
                    Type = "Role"
                }
            )
        },
        # Office 365 Exchange Online - Exchange.ManageAsApp
        @{
            ResourceAppId = "00000002-0000-0ff1-ce00-000000000000"  # Office 365 Exchange Online
            ResourceAccess = @(
                @{
                    Id = "dc50a0fb-09a3-484d-be87-e023b12c6440"  # Exchange.ManageAsApp (Application)
                    Type = "Role"
                }
            )
        },
        # SharePoint Online - Sites.Read.All (alternative for PnP)
        @{
            ResourceAppId = "00000003-0000-0ff1-ce00-000000000000"  # SharePoint Online
            ResourceAccess = @(
                @{
                    Id = "678536fe-1083-478a-9c59-b99265e6b0d3"  # Sites.Read.All (Application)
                    Type = "Role"
                }
            )
        }
    )

    # Create the app registration
    Write-Host "  Creating new App Registration..." -ForegroundColor Gray

    $appParams = @{
        DisplayName = $AppName
        SignInAudience = "AzureADMyOrg"
        RequiredResourceAccess = $requiredResourceAccess
        KeyCredentials = @(
            @{
                DisplayName = "$AppName Certificate"
                Type = "AsymmetricX509Cert"
                Usage = "Verify"
                Key = [System.Convert]::FromBase64String($certBase64)
                StartDateTime = $cert.NotBefore
                EndDateTime = $cert.NotAfter
            }
        )
    }

    $app = New-MgApplication @appParams
    Write-Host "  App Registration created successfully" -ForegroundColor Green
}

$appId = $app.AppId
$appObjectId = $app.Id

Write-Host "  App Name: $AppName" -ForegroundColor Cyan
Write-Host "  App (Client) ID: $appId" -ForegroundColor Cyan
Write-Host "  Object ID: $appObjectId" -ForegroundColor Cyan

#endregion

#region Create Service Principal (Enterprise App)

Write-Host ""
Write-Host "Step 4: Creating Service Principal (Enterprise App)..." -ForegroundColor Yellow

$sp = Get-MgServicePrincipal -Filter "appId eq '$appId'" -ErrorAction SilentlyContinue
if (-not $sp) {
    $sp = New-MgServicePrincipal -AppId $appId -DisplayName $AppName
    Write-Host "  Service Principal created" -ForegroundColor Green
}
else {
    Write-Host "  Service Principal already exists" -ForegroundColor Yellow
}

$spObjectId = $sp.Id
Write-Host "  Service Principal Object ID: $spObjectId" -ForegroundColor Cyan

#endregion

#region Grant Admin Consent for API Permissions

Write-Host ""
Write-Host "Step 5: Granting Admin Consent for API Permissions..." -ForegroundColor Yellow

# Get resource service principals
$graphSp = Get-MgServicePrincipal -Filter "appId eq '00000003-0000-0000-c000-000000000000'"
$exchangeSp = Get-MgServicePrincipal -Filter "appId eq '00000002-0000-0ff1-ce00-000000000000'"
$sharePointSp = Get-MgServicePrincipal -Filter "appId eq '00000003-0000-0ff1-ce00-000000000000'"

# Function to grant app role
function Grant-AppRole {
    param($ServicePrincipalId, $ResourceId, $AppRoleId, $RoleName)

    try {
        $existing = Get-MgServicePrincipalAppRoleAssignment -ServicePrincipalId $ServicePrincipalId |
            Where-Object { $_.AppRoleId -eq $AppRoleId }

        if (-not $existing) {
            $params = @{
                PrincipalId = $ServicePrincipalId
                ResourceId = $ResourceId
                AppRoleId = $AppRoleId
            }
            New-MgServicePrincipalAppRoleAssignment -ServicePrincipalId $ServicePrincipalId -BodyParameter $params | Out-Null
            Write-Host "  Granted: $RoleName" -ForegroundColor Green
        }
        else {
            Write-Host "  Already granted: $RoleName" -ForegroundColor Yellow
        }
    }
    catch {
        Write-Warning "  Failed to grant $RoleName : $_"
    }
}

# Grant Microsoft Graph - Sites.Read.All
Grant-AppRole -ServicePrincipalId $spObjectId -ResourceId $graphSp.Id `
    -AppRoleId "332a536c-c7ef-4017-ab91-336970924f0d" -RoleName "Microsoft Graph - Sites.Read.All"

# Grant Exchange Online - Exchange.ManageAsApp
Grant-AppRole -ServicePrincipalId $spObjectId -ResourceId $exchangeSp.Id `
    -AppRoleId "dc50a0fb-09a3-484d-be87-e023b12c6440" -RoleName "Exchange Online - Exchange.ManageAsApp"

# Grant SharePoint - Sites.Read.All
Grant-AppRole -ServicePrincipalId $spObjectId -ResourceId $sharePointSp.Id `
    -AppRoleId "678536fe-1083-478a-9c59-b99265e6b0d3" -RoleName "SharePoint Online - Sites.Read.All"

#endregion

#region Assign Exchange Administrator Role

Write-Host ""
Write-Host "Step 6: Assigning Exchange Administrator Role..." -ForegroundColor Yellow

# Get Exchange Administrator role
$exchangeAdminRole = Get-MgDirectoryRole -Filter "displayName eq 'Exchange Administrator'" -ErrorAction SilentlyContinue

if (-not $exchangeAdminRole) {
    # Role might not be activated, get from template
    $roleTemplate = Get-MgDirectoryRoleTemplate | Where-Object { $_.DisplayName -eq "Exchange Administrator" }
    if ($roleTemplate) {
        # Activate the role
        $exchangeAdminRole = New-MgDirectoryRole -RoleTemplateId $roleTemplate.Id
    }
}

if ($exchangeAdminRole) {
    # Check if already assigned
    $existingAssignment = Get-MgDirectoryRoleMember -DirectoryRoleId $exchangeAdminRole.Id |
        Where-Object { $_.Id -eq $spObjectId }

    if (-not $existingAssignment) {
        # Assign role to service principal
        $params = @{
            "@odata.id" = "https://graph.microsoft.com/v1.0/directoryObjects/$spObjectId"
        }
        New-MgDirectoryRoleMemberByRef -DirectoryRoleId $exchangeAdminRole.Id -BodyParameter $params
        Write-Host "  Exchange Administrator role assigned to service principal" -ForegroundColor Green
    }
    else {
        Write-Host "  Exchange Administrator role already assigned" -ForegroundColor Yellow
    }
}
else {
    Write-Warning "  Could not find Exchange Administrator role. You may need to assign it manually in Azure Portal."
}

#endregion

#region Connect to HunterTech for Key Vault

Write-Host ""
Write-Host "Step 7: Connecting to HunterTech tenant for Key Vault..." -ForegroundColor Yellow
Write-Host "  You will be prompted to sign in with a HunterTech account" -ForegroundColor Gray

try {
    # Disconnect any existing Azure connection
    Disconnect-AzAccount -ErrorAction SilentlyContinue

    # Connect to Azure (HunterTech tenant where Key Vault is)
    if ([string]::IsNullOrWhiteSpace($HunterTechSubscriptionId)) {
        Write-Host "  Connecting to Azure (select HunterTech subscription)..." -ForegroundColor Gray
        Connect-AzAccount
    }
    else {
        Connect-AzAccount -Subscription $HunterTechSubscriptionId
    }

    $azContext = Get-AzContext
    Write-Host "  Connected to Azure" -ForegroundColor Green
    Write-Host "  Subscription: $($azContext.Subscription.Name)" -ForegroundColor Green
    Write-Host "  Account: $($azContext.Account.Id)" -ForegroundColor Green

    # Verify Key Vault access
    $vault = Get-AzKeyVault -VaultName $KeyVaultName -ErrorAction SilentlyContinue
    if (-not $vault) {
        Write-Error "Cannot access Key Vault '$KeyVaultName'. Ensure you have access."
        exit 1
    }
    Write-Host "  Key Vault verified: $KeyVaultName" -ForegroundColor Green
}
catch {
    Write-Error "Failed to connect to Azure for Key Vault: $_"
    throw
}

#endregion

#region Store Secrets in Key Vault

Write-Host ""
Write-Host "Step 8: Storing secrets in Key Vault..." -ForegroundColor Yellow

try {
    # Store App ID
    $secretName = "synapse-app-id"
    Set-AzKeyVaultSecret -VaultName $KeyVaultName -Name $secretName -SecretValue (ConvertTo-SecureString $appId -AsPlainText -Force) | Out-Null
    Write-Host "  Stored: $secretName" -ForegroundColor Green

    # Store Certificate Thumbprint
    $secretName = "synapse-cert-thumbprint"
    Set-AzKeyVaultSecret -VaultName $KeyVaultName -Name $secretName -SecretValue (ConvertTo-SecureString $thumbprint -AsPlainText -Force) | Out-Null
    Write-Host "  Stored: $secretName" -ForegroundColor Green

    # Store Synapse Tenant ID (separate from existing tenantid which might be HunterTech)
    $secretName = "synapse-tenant-id"
    Set-AzKeyVaultSecret -VaultName $KeyVaultName -Name $secretName -SecretValue (ConvertTo-SecureString $synapseTenantIdConfirmed -AsPlainText -Force) | Out-Null
    Write-Host "  Stored: $secretName" -ForegroundColor Green

    # Upload certificate to Key Vault
    if (-not $SkipCertificateCreation) {
        $certSecretName = "synapse-certificate"
        Import-AzKeyVaultCertificate -VaultName $KeyVaultName -Name $certSecretName -FilePath $certPath -Password $certSecurePassword | Out-Null
        Write-Host "  Stored certificate: $certSecretName" -ForegroundColor Green
    }
}
catch {
    Write-Warning "Failed to store some secrets in Key Vault: $_"
    Write-Warning "You may need to manually add these secrets."
}

#endregion

#region Summary

Write-Host ""
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "  Setup Complete!" -ForegroundColor Green
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""
Write-Host "App Registration Details (in Synapse tenant):" -ForegroundColor White
Write-Host "  App Name:              $AppName" -ForegroundColor Gray
Write-Host "  App (Client) ID:       $appId" -ForegroundColor Gray
Write-Host "  Synapse Tenant ID:     $synapseTenantIdConfirmed" -ForegroundColor Gray
Write-Host "  Certificate Thumbprint: $thumbprint" -ForegroundColor Gray
Write-Host ""
Write-Host "Key Vault Secrets Created (in HunterTech vault):" -ForegroundColor White
Write-Host "  synapse-app-id         - Application Client ID" -ForegroundColor Gray
Write-Host "  synapse-cert-thumbprint - Certificate thumbprint" -ForegroundColor Gray
Write-Host "  synapse-tenant-id      - Synapse tenant ID" -ForegroundColor Gray
Write-Host "  synapse-certificate    - Full PFX certificate" -ForegroundColor Gray
Write-Host ""
Write-Host "API Permissions Granted (in Synapse tenant):" -ForegroundColor White
Write-Host "  - Microsoft Graph: Sites.Read.All" -ForegroundColor Gray
Write-Host "  - SharePoint Online: Sites.Read.All" -ForegroundColor Gray
Write-Host "  - Exchange Online: Exchange.ManageAsApp" -ForegroundColor Gray
Write-Host ""
Write-Host "Role Assignments (in Synapse tenant):" -ForegroundColor White
Write-Host "  - Exchange Administrator" -ForegroundColor Gray
Write-Host ""

if (-not $SkipCertificateCreation) {
    Write-Host "Certificate Files (local):" -ForegroundColor White
    Write-Host "  PFX (with private key): $certPath" -ForegroundColor Gray
    Write-Host "  CER (public key only):  $certCerPath" -ForegroundColor Gray
    Write-Host "  PFX Password:           $certPassword" -ForegroundColor Yellow
    Write-Host ""
    Write-Host "IMPORTANT: Save the PFX password securely! It will not be shown again." -ForegroundColor Red
}

Write-Host ""
Write-Host "Next Steps:" -ForegroundColor White
Write-Host "  1. Upload the certificate to your Azure Function App (from Key Vault)" -ForegroundColor Gray
Write-Host "  2. Add WEBSITE_LOAD_CERTIFICATES=* to Function App settings" -ForegroundColor Gray
Write-Host "  3. Test the function locally or deploy to Azure" -ForegroundColor Gray
Write-Host ""

#endregion

# Output values for easy copy
$output = @{
    AppName = $AppName
    AppId = $appId
    SynapseTenantId = $synapseTenantIdConfirmed
    Thumbprint = $thumbprint
    ServicePrincipalId = $spObjectId
    KeyVaultName = $KeyVaultName
}

return $output
