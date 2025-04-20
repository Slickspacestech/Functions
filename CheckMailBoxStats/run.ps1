using namespace System.Net
using namespace System.Security.Cryptography.X509Certificates

param($Timer)

# Import required modules
Import-Module ExchangeOnlineManagement -RequiredVersion 3.4.0 -Force
Import-Module Az.Accounts -Force
Import-Module Az.KeyVault -Force
Import-Module Az.Storage -Force

# Import common functions (mechanism depends on your deployment method)
# . "./Common/HtFunctions.ps1"

# Write version info
Write-Host "CheckMailBoxStats v1.0"

# Define size threshold in bytes (45GB)
$sizeThreshold = 45GB

# Common Functions Module (to be shared across functions)

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

function Connect-HtExchangeOnline {
    param(
        [Parameter(Mandatory=$true)]
        [string]$TenantName,
        
        [Parameter(Mandatory=$true)]
        [string]$AppId,
        
        [Parameter(Mandatory=$true)]
        [string]$CertThumbprint
    )
    try {
        Connect-ExchangeOnline -CertificateThumbprint $CertThumbprint -AppId $AppId -Organization $TenantName
        Write-Information "Successfully connected to Exchange Online for tenant: $TenantName"
        return $true
    }
    catch {
        Write-Error "Failed to connect to Exchange for tenant $TenantName: $_"
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
        # Get the storage account context
        $storageAccount = Get-AzStorageAccount -ResourceGroupName "htupdatechecker" -Name "htupdatechecker"
        $ctx = $storageAccount.Context
        
        # Get table data
        $tableName = "tenants"
        $table = Get-AzStorageTable -Name $tableName -Context $ctx
        
        # Query all entries from the table
        $query = Get-AzTableRow -Table $table.CloudTable
        
        # Transform the data into our required format
        $tenants = $query | ForEach-Object {
            @{
                Name = $_.TenantName
                AppId = $_.AppId
                CertThumbprint = $_.CertThumbprint  # Added certificate thumbprint from table
            }
        }
        
        return $tenants
    }
    catch {
        Write-Error "Failed to get tenants from Azure Table: $_"
        return @()
    }
}

function Check-MailboxSizes {
    param(
        [Parameter(Mandatory=$true)]
        [string]$UserPrincipalName,
        [int64]$SizeThreshold = 45GB
    )
    
    try {
        $stats = Get-MailboxStatistics $UserPrincipalName
        $mailbox = Get-Mailbox $UserPrincipalName
        $archiveStats = $null
        
        if ($mailbox.ArchiveStatus -eq "Active") {
            $archiveStats = Get-MailboxStatistics $UserPrincipalName -Archive
        }
        
        if (($stats.TotalItemSize.Value.ToBytes() -gt $SizeThreshold) -or 
            ($archiveStats -and $archiveStats.TotalItemSize.Value.ToBytes() -gt $SizeThreshold)) {
            
            $emailBody = @"
Mailbox Size Alert:

User: $($mailbox.DisplayName)
Email: $UserPrincipalName
Primary Mailbox Size: $([math]::Round($stats.TotalItemSize.Value.ToBytes()/1GB, 2)) GB
Archive Size: $([math]::Round(($archiveStats?.TotalItemSize.Value.ToBytes() ?? 0)/1GB, 2)) GB
"@

            Send-HtEmail `
                -Subject "Large Mailbox Alert - $UserPrincipalName" `
                -Body $emailBody
        }
    }
    catch {
        Write-Error "Error checking mailbox size for $UserPrincipalName`: $_"
    }
}

# Main execution
try {
    Connect-HtAzureServices
    
    $tenants = Get-TenantsFromTable
    
    foreach ($tenant in $tenants) {
        if ([string]::IsNullOrEmpty($tenant.CertThumbprint)) {
            Write-Error "Certificate thumbprint not found for tenant: $($tenant.Name)"
            continue
        }
        
        if (Connect-HtExchangeOnline -TenantName $tenant.Name -CertThumbprint $tenant.CertThumbprint -AppId $tenant.AppId) {
            $mailboxes = Get-Mailbox -ResultSize Unlimited
            foreach ($mailbox in $mailboxes) {
                Check-MailboxSizes -UserPrincipalName $mailbox.UserPrincipalName
            }
            Disconnect-ExchangeOnline -Confirm:$false
        }
    }
}
catch {
    Write-Error "Main execution error: $_"
    Send-HtEmail -Subject "CheckMailBoxStats Error" -Body "Error in main execution: $_"
}
finally {
    Disconnect-ExchangeOnline -Confirm:$false
}
