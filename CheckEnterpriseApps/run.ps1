using namespace System.Net
using namespace System.Security.Cryptography.X509Certificates

param($Timer)

# Import required modules
Import-Module Az.Accounts -Force
Import-Module Az.KeyVault -Force
Import-Module Az.Storage -Force
Import-Module Microsoft.Graph.Applications -Force

# Write version info
Write-Host "CheckM365Apps v1.0"

# Common Functions Module (shared across functions)
function Connect-HtAzureServices {
    param(
        [Parameter(Mandatory=$false)]
        [string]$VaultName = "huntertechvault"
    )
    try {
        Connect-AzAccount -Identity
        Write-Information "Successfully connected to Azure using managed identity"
        return $true
    }
    catch {
        Write-Error "Failed to connect to Azure: $_"
        return $false
    }
}

function Get-HtKeyVaultSecret {
    param(
        [Parameter(Mandatory=$true)]
        [string]$SecretName,
        
        [Parameter(Mandatory=$false)]
        [string]$VaultName = "huntertechvault"
    )
    try {
        return Get-AzKeyVaultSecret -VaultName $VaultName -Name $SecretName -AsPlainText
    }
    catch {
        Write-Error "Failed to get secret '$SecretName' from vault '$VaultName': $_"
        throw
    }
}

function Send-HtEmail {
    param(
        [Parameter(Mandatory=$true)]
        [string]$Subject,
        
        [Parameter(Mandatory=$true)]
        [string]$Body,
        
        [Parameter(Mandatory=$false)]
        [string]$To = "help@huntertech.ca",
        
        [Parameter(Mandatory=$false)]
        [string]$From = "azurefunction@huntertech.ca",
        
        [Parameter(Mandatory=$false)]
        [string]$VaultName = "huntertechvault"
    )
    try {
        # Get SMTP credentials from Key Vault
        $smtpUsername = Get-HtKeyVaultSecret -SecretName "smtp2go-username"
        $smtpPassword = ConvertTo-SecureString(Get-HtKeyVaultSecret -SecretName "smtp2go-secure") -AsPlainText -Force
        $smtpCredential = New-Object System.Management.Automation.PSCredential($smtpUsername, $smtpPassword)

        # Send email using SMTP2GO
        Send-MailMessage `
            -From $From `
            -To $To `
            -Subject $Subject `
            -Body $Body `
            -SmtpServer "mail.smtp2go.com" `
            -Port 2525 `
            -UseSSL `
            -Credential $smtpCredential
            
        Write-Information "Email sent successfully: $Subject"
        return $true
    }
    catch {
        Write-Error "Failed to send email: $_"
        return $false
    }
}

function Get-HtStorageTable {
    param(
        [Parameter(Mandatory=$true)]
        [string]$TableName,
        
        [Parameter(Mandatory=$false)]
        [string]$ResourceGroup = "htupdatechecker",
        
        [Parameter(Mandatory=$false)]
        [string]$StorageAccount = "htupdatechecker",
        
        [Parameter(Mandatory=$false)]
        [switch]$CreateIfNotExists
    )
    try {
        $storageAccount = Get-AzStorageAccount -ResourceGroupName $ResourceGroup -Name $StorageAccount
        $ctx = $storageAccount.Context
        
        $table = Get-AzStorageTable -Name $TableName -Context $ctx -ErrorAction SilentlyContinue
        
        if (-not $table -and $CreateIfNotExists) {
            $table = New-AzStorageTable -Name $TableName -Context $ctx
        }
        
        return $table
    }
    catch {
        Write-Error "Failed to get/create storage table '$TableName': $_"
        throw
    }
}

function Get-TenantsFromTable {
    try {
        $table = Get-HtStorageTable -TableName "tenants"
        $query = Get-AzTableRow -Table $table.CloudTable
        
        # Transform the data into our required format
        $tenants = $query | ForEach-Object {
            @{
                Name = $_.TenantName
                AppId = $_.AppId
                CertThumbprint = $_.CertThumbprint
            }
        }
        
        return $tenants
    }
    catch {
        Write-Error "Failed to get tenants from Azure Table: $_"
        return @()
    }
}

function Get-AppInventory {
    param(
        [Parameter(Mandatory=$true)]
        [string]$TenantId,
        [string]$AppId,
        [string]$CertThumbprint
    )

    try {
        # Connect to Microsoft Graph
        Connect-MgGraph -TenantId $TenantId -AppId $AppId -CertificateThumbprint $CertThumbprint

        # Get Enterprise Applications and App Registrations
        $enterpriseApps = Get-MgServicePrincipal -All | Select-Object DisplayName, Id, AppId
        $appRegistrations = Get-MgApplication -All | Select-Object DisplayName, Id, AppId

        return @{
            EnterpriseApps = $enterpriseApps
            AppRegistrations = $appRegistrations
        }
    }
    catch {
        Write-Error "Failed to get app inventory for tenant $TenantId`: $_"
        return $null
    }
    finally {
        Disconnect-MgGraph
    }
}

function Compare-AppInventory {
    param(
        [Parameter(Mandatory=$true)]
        $CurrentInventory,
        [Parameter(Mandatory=$true)]
        $PreviousInventory
    )

    $changes = @{
        Added = @{
            EnterpriseApps = @()
            AppRegistrations = @()
        }
        Removed = @{
            EnterpriseApps = @()
            AppRegistrations = @()
        }
    }

    # Compare Enterprise Apps
    $currentEAIds = $CurrentInventory.EnterpriseApps.AppId
    $previousEAIds = $PreviousInventory.EnterpriseApps.AppId

    $changes.Added.EnterpriseApps = $CurrentInventory.EnterpriseApps | Where-Object { $_.AppId -notin $previousEAIds }
    $changes.Removed.EnterpriseApps = $PreviousInventory.EnterpriseApps | Where-Object { $_.AppId -notin $currentEAIds }

    # Compare App Registrations
    $currentARIds = $CurrentInventory.AppRegistrations.AppId
    $previousARIds = $PreviousInventory.AppRegistrations.AppId

    $changes.Added.AppRegistrations = $CurrentInventory.AppRegistrations | Where-Object { $_.AppId -notin $previousARIds }
    $changes.Removed.AppRegistrations = $PreviousInventory.AppRegistrations | Where-Object { $_.AppId -notin $currentARIds }

    return $changes
}

# Main execution
try {
    Connect-HtAzureServices
    
    # Get tenants from Azure Table
    $tenants = Get-TenantsFromTable
    
    if ($tenants.Count -eq 0) {
        Write-Error "No tenants found in Azure Table"
        return
    }
    
    # Get storage table for app inventory
    $appInventoryTable = Get-HtStorageTable -TableName "appinventory" -CreateIfNotExists

    foreach ($tenant in $tenants) {
        # Get current inventory
        $currentInventory = Get-AppInventory -TenantId $tenant.Name -AppId $tenant.AppId -CertThumbprint $tenant.CertThumbprint
        
        if ($null -eq $currentInventory) {
            continue
        }

        # Get previous inventory from table
        $previousInventory = Get-AzTableRow `
            -Table $appInventoryTable.CloudTable `
            -PartitionKey $tenant.Name `
            -RowKey "latest"

        if ($previousInventory) {
            $previousApps = @{
                EnterpriseApps = $previousInventory.EnterpriseApps | ConvertFrom-Json
                AppRegistrations = $previousInventory.AppRegistrations | ConvertFrom-Json
            }

            # Compare inventories
            $changes = Compare-AppInventory -CurrentInventory $currentInventory -PreviousInventory $previousApps

            # If changes detected, send email
            if (($changes.Added.EnterpriseApps.Count -gt 0) -or 
                ($changes.Removed.EnterpriseApps.Count -gt 0) -or
                ($changes.Added.AppRegistrations.Count -gt 0) -or
                ($changes.Removed.AppRegistrations.Count -gt 0)) {

                $emailBody = @"
M365 Application Changes Detected for Tenant: $($tenant.Name)

Enterprise Applications Added:
$($changes.Added.EnterpriseApps | ForEach-Object { "- $($_.DisplayName) (AppId: $($_.AppId))" } | Out-String)

Enterprise Applications Removed:
$($changes.Removed.EnterpriseApps | ForEach-Object { "- $($_.DisplayName) (AppId: $($_.AppId))" } | Out-String)

App Registrations Added:
$($changes.Added.AppRegistrations | ForEach-Object { "- $($_.DisplayName) (AppId: $($_.AppId))" } | Out-String)

App Registrations Removed:
$($changes.Removed.AppRegistrations | ForEach-Object { "- $($_.DisplayName) (AppId: $($_.AppId))" } | Out-String)
"@

                Send-HtEmail `
                    -Subject "M365 Application Changes Detected - $($tenant.Name)" `
                    -Body $emailBody
            }
        }

        # Store current inventory
        $inventoryEntry = @{
            PartitionKey = $tenant.Name
            RowKey = "latest"
            EnterpriseApps = ($currentInventory.EnterpriseApps | ConvertTo-Json -Compress)
            AppRegistrations = ($currentInventory.AppRegistrations | ConvertTo-Json -Compress)
            LastUpdated = (Get-Date).ToString("yyyy-MM-dd HH:mm:ss")
        }

        if ($previousInventory) {
            $inventoryEntry | Update-AzTableRow -Table $appInventoryTable.CloudTable
        }
        else {
            Add-AzTableRow -Table $appInventoryTable.CloudTable -Property $inventoryEntry
        }
    }
}
catch {
    Write-Error "Main execution error: $_"
    Send-HtEmail -Subject "CheckEnterpriseApps Error" -Body "Error in main execution: $_"
}
