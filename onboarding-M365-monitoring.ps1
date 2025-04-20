# Script to create Enterprise App for Huntertech with required permissions
# Requires Global Admin rights in Office 365

# Import required modules
Install-Module -Name Microsoft.Graph -Force
Import-Module Microsoft.Graph
Import-Module Az.Accounts
Import-Module Az.Storage
Import-Module Az.KeyVault

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
$pfxPassword = ConvertTo-SecureString -String "YourSecurePassword123!" -Force -AsPlainText
$pfxPath = ".\Huntertech-$sanitizedTenantName.pfx"
Export-PfxCertificate -Cert $cert -FilePath $pfxPath -Password $pfxPassword

# Add certificate to application
$certBase64 = [System.Convert]::ToBase64String($cert.GetRawCertData())
$certKeyCredential = @{
    Type = "AsymmetricX509Cert"
    Usage = "Verify"
    Key = $certBase64
}
Add-MgApplicationKey -ApplicationId $app.Id -KeyCredential $certKeyCredential

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
        
        # Create unique RowKey
        $rowKey = [guid]::NewGuid().ToString()
        
        # Add tenant record to table - ensuring exact schema match with CheckMailBoxStats
        $tableEntry = @{
            PartitionKey = "tenants"
            RowKey = $rowKey
            TenantName = $TenantName    # Used by Get-TenantsFromTable as Name
            AppId = $AppId              # Used directly in Get-TenantsFromTable
            CertThumbprint = $CertThumbprint  # Used directly in Get-TenantsFromTable
            DateAdded = (Get-Date).ToString("yyyy-MM-dd HH:mm:ss")  # Additional metadata field
            IsActive = $true            # Additional field for future use
        }
        
        # Validate required fields are present and not empty
        if ([string]::IsNullOrEmpty($tableEntry.TenantName) -or 
            [string]::IsNullOrEmpty($tableEntry.AppId) -or 
            [string]::IsNullOrEmpty($tableEntry.CertThumbprint)) {
            throw "Required fields (TenantName, AppId, CertThumbprint) cannot be empty"
        }
        
        # Add to table
        Add-AzTableRow -Table $table.CloudTable -Property $tableEntry
        
        # Upload certificate to Key Vault
        $vaultName = "huntertechvault"
        $certBytes = Get-Content $pfxPath -Encoding Byte
        $certBase64 = [System.Convert]::ToBase64String($certBytes)
        
        # Create secret name based on tenant (sanitized)
        $secretName = "cert-" + ($TenantName -replace '[^a-zA-Z0-9]', '')
        
        # Create Key Vault secret with certificate data
        $secretValue = @{
            data = $certBase64
            password = $PfxPassword | ConvertFrom-SecureString -AsPlainText
        } | ConvertTo-Json
        
        $secretValueSecure = ConvertTo-SecureString -String $secretValue -AsPlainText -Force
        Set-AzKeyVaultSecret -VaultName $vaultName -Name $secretName -SecretValue $secretValueSecure
        
        Write-Host "Successfully added tenant to Azure storage and uploaded certificate to Key Vault"
        Write-Host "Table Entry RowKey: $rowKey"
        Write-Host "Key Vault Secret Name: $secretName"
        Write-Host "Verifying table entry schema matches CheckMailBoxStats requirements..."
        
        # Verify the entry was created correctly
        $verifyEntry = Get-AzTableRow -Table $table.CloudTable -PartitionKey "tenants" -RowKey $rowKey
        if ($verifyEntry.TenantName -eq $TenantName -and 
            $verifyEntry.AppId -eq $AppId -and 
            $verifyEntry.CertThumbprint -eq $CertThumbprint) {
            Write-Host "Table entry verified - schema matches CheckMailBoxStats requirements"
        } else {
            Write-Warning "Table entry verification failed - please check the data manually"
        }
    }
    catch {
        Write-Error "Failed to add tenant to Azure: $_"
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

