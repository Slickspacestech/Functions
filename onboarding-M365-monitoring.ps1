# Script to create Enterprise App for Huntertech with required permissions
# Requires Global Admin rights in Office 365

# Import required modules
Install-Module -Name Microsoft.Graph.Applications -Force
Install-Module -Name Microsoft.Graph.Authentication -Force
Install-Module -Name Microsoft.Graph.Identity.DirectoryManagement -Force
Install-Module -Name Az.Resources -Force
Install-Module -Name AzTable -Force

Import-Module Microsoft.Graph.Applications
Import-Module Microsoft.Graph.Authentication
Import-Module Microsoft.Graph.Identity.DirectoryManagement
Import-Module Az.Accounts
Import-Module Az.Storage
Import-Module Az.KeyVault
Import-Module Az.Resources
Import-Module AzTable

# Connect to Microsoft Graph with admin consent scope
Connect-MgGraph -Scopes "Application.ReadWrite.All", "Directory.ReadWrite.All"

# Get tenant details
$orgInfo = Get-MgOrganization
$tenantName = $orgInfo.DisplayName
$sanitizedTenantName = $tenantName -replace '[^a-zA-Z0-9]', ''

# Create the Enterprise Application
$appName = "Huntertech"
$app = New-MgApplication -DisplayName $appName

# Create corresponding service principal
$sp = New-MgServicePrincipal -AppId $app.AppId

# Required permissions for the app
$requiredResourceAccess = @(
    # Microsoft Graph permissions
    @{
        ResourceAppId = "00000003-0000-0000-c000-000000000000" # Microsoft Graph
        ResourceAccess = @(
            # Application.Read.All
            @{
                Id = "9a5d68dd-52b0-4cc2-bd40-abcf44ac3a30"
                Type = "Role"
            }
            # Directory.Read.All
            @{
                Id = "7ab1d382-f21e-4acd-a863-ba3e13f7da61"
                Type = "Role"
            }
            # Exchange.ManageAsApp
            @{
                Id = "dc50a0fb-09a3-484d-be87-e023b12c6440"
                Type = "Role"
            }
        )
    }
)

# Update application with required permissions
Update-MgApplication -ApplicationId $app.Id -RequiredResourceAccess $requiredResourceAccess

# Generate self-signed certificate
$certName = "Huntertech-$sanitizedTenantName"
$cert = New-SelfSignedCertificate -Subject "CN=$certName" `
    -CertStoreLocation "Cert:\CurrentUser\My" `
    -KeyExportPolicy Exportable `
    -KeySpec Signature `
    -KeyLength 2048 `
    -KeyAlgorithm RSA `
    -HashAlgorithm SHA256 `
    -NotAfter (Get-Date).AddYears(2)

# Export certificate as PFX
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
            key = [System.Convert]::FromBase64String($certBase64)  # Convert to byte array as per example
            startDateTime = $cert.NotBefore
            endDateTime = $cert.NotAfter
        }
    )
}

Update-MgApplication -ApplicationId $app.Id -BodyParameter $params

function Add-TenantToAzure {
    param(
        [Parameter(Mandatory=$true)]
        [string]$TenantName,
        [Parameter(Mandatory=$true)]
        [string]$AppId,
        [Parameter(Mandatory=$true)]
        [string]$CertThumbprint,
        [Parameter(Mandatory=$true)]
        [string]$PfxPath,
        [Parameter(Mandatory=$true)]
        [SecureString]$PfxPassword
    )
    
    try {
        # Connect to Azure (if not already connected)
        $azContext = Get-AzContext
        if (-not $azContext) {
            Connect-AzAccount
        }
        
        # Get storage account context
        $storageAccount = Get-AzStorageAccount -ResourceGroupName "htupdatechecker" -Name "htupdatechecker"
        $ctx = $storageAccount.Context
        
        # Get table reference
        $tableName = "tenants"
        $table = Get-AzStorageTable -Name $tableName -Context $ctx -ErrorAction SilentlyContinue
        
        if (-not $table) {
            $table = New-AzStorageTable -Name $tableName -Context $ctx
        }

        # Check if tenant already exists by querying for TenantName
        $existingTenant = Get-AzTableRow -Table $table.CloudTable -PartitionKey "tenants" | 
            Where-Object { $_.TenantName -eq $TenantName }
        
        # Prepare table entry
        $tableEntry = @{
            TenantName = $TenantName
            AppId = $AppId
            CertThumbprint = $CertThumbprint
            DateAdded = (Get-Date).ToString("yyyy-MM-dd HH:mm:ss")
            IsActive = $true
        }
        
        # Validate required fields
        if ([string]::IsNullOrEmpty($tableEntry.TenantName) -or 
            [string]::IsNullOrEmpty($tableEntry.AppId) -or 
            [string]::IsNullOrEmpty($tableEntry.CertThumbprint)) {
            throw "Required fields (TenantName, AppId, CertThumbprint) cannot be empty"
        }

        if ($existingTenant) {
            # Update existing record
            $tableEntry.Add("PartitionKey", $existingTenant.PartitionKey)
            $tableEntry.Add("RowKey", $existingTenant.RowKey)
            $tableEntry.Add("Etag", $existingTenant.Etag)
            Update-AzTableRow -Table $table.CloudTable -Entity $tableEntry
            $rowKey = $existingTenant.RowKey
        } else {
            # Add new record
            $rowKey = [guid]::NewGuid().ToString()
            Add-AzTableRow -Table $table.CloudTable -Property $tableEntry -PartitionKey "tenants" -RowKey $rowKey
        }
        
        # Handle certificate in Key Vault
        $vaultName = "huntertechvault"
        $certName = "cert2-" + ($TenantName -replace '[^a-zA-Z0-9]', '')

        # Check if certificate exists in Key Vault
        try {
            $existingCert = Get-AzKeyVaultCertificate -VaultName $vaultName -Name $certName -ErrorAction SilentlyContinue

            if ($existingCert) {
                # Check Key Vault properties for purge protection
                $vault = Get-AzKeyVault -VaultName $vaultName
                
                if ($vault.EnablePurgeProtection) {
                    Write-Warning "Cannot remove existing certificate - Purge Protection is enabled on Key Vault"
                    Write-Warning "Using a new certificate name to avoid conflicts"
                    # Generate a new unique name by appending timestamp
                    $timestamp = Get-Date -Format "yyyyMMddHHmmss"
                    $certName = "cert2-" + ($TenantName -replace '[^a-zA-Z0-9]', '') + "-" + $timestamp
                } else {
                    # Remove the existing certificate
                    Remove-AzKeyVaultCertificate -VaultName $vaultName -Name $certName -Force
                    # Ensure it's fully purged
                    Remove-AzKeyVaultCertificate -VaultName $vaultName -Name $certName -InRemovedState -Force
                    Write-Host "Removed existing certificate from Key Vault"
                }
            }

            # Import new certificate to Key Vault
            $newCert = Import-AzKeyVaultCertificate `
                -VaultName $vaultName `
                -Name $certName `
                -FilePath $PfxPath `
                -Password $PfxPassword

            # Update the table entry with the new certificate name if it was changed
            if ($existingTenant -and $vault.EnablePurgeProtection) {
                $tableEntry.CertThumbprint = $newCert.Thumbprint
                Update-AzTableRow -Table $table.CloudTable -Entity $tableEntry
            }

            Write-Host "Successfully added/updated tenant in Azure storage and imported certificate to Key Vault"
            Write-Host "Table Entry RowKey: $rowKey"
            Write-Host "Key Vault Certificate Name: $certName"
            Write-Host "Certificate Thumbprint: $($newCert.Thumbprint)"
            Write-Host "Certificate Expiry: $($newCert.Expires)"
        }
        catch {
            throw "Failed to manage certificate in Key Vault: $_"
        }
    }
    catch {
        Write-Error "Failed to add/update tenant in Azure: $_"
        throw
    }
}

# After certificate creation, add call to new function
try {
    Add-TenantToAzure `
        -TenantName $tenantName `
        -AppId $app.AppId `
        -CertThumbprint $cert.Thumbprint `
        -PfxPath $pfxPath `
        -PfxPassword $pfxPassword
    
    Write-Host "Enterprise Application created and Azure resources updated successfully!"
    Write-Host "Application ID: $($app.AppId)"
    Write-Host "Certificate Thumbprint: $($cert.Thumbprint)"
    Write-Host "PFX file exported to: $pfxPath"
    Write-Host "Tenant Name: $tenantName"
    Write-Host ""
    Write-Host "Important: Store these credentials securely and grant admin consent in Azure Portal"
}
catch {
    Write-Error "Failed to complete setup: $_"
}

