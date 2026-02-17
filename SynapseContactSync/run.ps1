# SynapseContactSync - Azure Function for Synapse Accounting T1 Contact Management
# Syncs contacts from SharePoint Excel file to Exchange Online Distribution List
# Runs daily at 6:00 AM UTC
#v2.1
param($Timer)

$currentUTCtime = (Get-Date).ToUniversalTime()

if ($Timer.IsPastDue) {
    Write-Host "PowerShell timer is running late!"
}

Import-Module Az.Accounts -Force
Import-Module Az.KeyVault -Force
Import-Module PnP.PowerShell -Force
Import-Module ImportExcel -Force
Import-Module ExchangeOnlineManagement -Force

Write-Host "SynapseContactSync v2.0 - Timer trigger function ran! TIME: $currentUTCtime"

#region Helper Functions

function Send-ErrorNotification {
    param (
        [string]$ErrorMessage,
        [System.Security.SecureString]$SecurePassword
    )

    $smtpServer = "mail.smtp2go.com"
    $smtpPort = 2525
    $smtpUser = "patching@huntertech.ca"
    $from = "synapsecontactsync@huntertech.ca"
    $to = "matt@huntertech.ca"

    $credential = New-Object System.Management.Automation.PSCredential($smtpUser, $SecurePassword)

    try {
        Send-MailMessage -From $from -To $to -Subject "Synapse Contact Sync Error" -Body $ErrorMessage -SmtpServer $smtpServer -Port $smtpPort -Credential $credential -UseSsl
        Write-Host "Error notification sent successfully"
    }
    catch {
        Write-Warning "Failed to send error notification: $_"
    }
}

function New-MailContactWithRetry {
    param(
        [Parameter(Mandatory=$true)]
        [string]$Email,

        [Parameter(Mandatory=$true)]
        [string]$DisplayName,

        [Parameter(Mandatory=$true)]
        [string]$BaseAlias,

        [string]$FirstName = "",
        [string]$LastName = "",

        [Parameter(Mandatory=$true)]
        [string]$CustomAttributeValue
    )

    $maxAttempts = 10
    $attemptCount = 0
    $created = $false
    $finalAlias = $BaseAlias

    while (-not $created -and $attemptCount -lt $maxAttempts) {
        try {
            New-MailContact -Name $finalAlias `
                -ExternalEmailAddress $Email `
                -Alias $finalAlias `
                -DisplayName $DisplayName `
                -FirstName $FirstName `
                -LastName $LastName `
                -ErrorAction Stop | Out-Null

            Write-Host "  Created contact with alias: $finalAlias"
            $created = $true

            # Return email for batch CustomAttribute1 update later
            return @{ Email = $Email; CustomAttributeValue = $CustomAttributeValue }

        }
        catch {
            if ($_.Exception.Message -like "*proxy address*is already being used*" -or
                $_.Exception.Message -like "*alias*already exists*" -or
                $_.Exception.Message -like "*already present*" -or
                $_.Exception.Message -like "*is already used*") {
                $attemptCount++
                $finalAlias = "${BaseAlias}${attemptCount}"
                Write-Host "  Alias conflict, retrying with: $finalAlias"
            }
            else {
                throw $_
            }
        }
    }

    if (-not $created) {
        throw "Could not create contact after $maxAttempts attempts due to alias conflicts"
    }

    return $finalAlias
}

#endregion

#region Main Sync Function

function Sync-ContactsFromExcel {
    param(
        [Parameter(Mandatory=$true)]
        [string]$ExcelPath,

        [Parameter(Mandatory=$true)]
        [string]$CustomAttributeValue,

        [Parameter(Mandatory=$true)]
        [string]$DistributionGroup
    )

    try {
        Write-Host "Starting contact sync from Excel file: $ExcelPath"

        if (-not (Test-Path -Path $ExcelPath)) {
            throw "Excel file not found at path: $ExcelPath"
        }

        $contacts = Import-Excel -Path $ExcelPath
        Write-Host "Found $($contacts.Count) contacts in Excel file"

        $processedContacts = @()
        $errors = @()
        $created = 0
        $updated = 0
        $skipped = 0

        # Get current DG members for efficient checking
        $dgMembers = Get-DistributionGroupMember -Identity $DistributionGroup -ResultSize Unlimited -ErrorAction SilentlyContinue
        $dgMemberEmails = @{}
        if ($dgMembers) {
            foreach ($member in $dgMembers) {
                $dgMemberEmails[$member.PrimarySmtpAddress.ToLower()] = $true
            }
        }

        # Get ALL existing mail contacts with our custom attribute upfront (single query)
        Write-Host "Fetching existing mail contacts..."
        $existingMailContacts = Get-MailContact -ResultSize Unlimited | Where-Object { $_.CustomAttribute1 -eq $CustomAttributeValue }
        $existingContactsMap = @{}
        foreach ($mc in $existingMailContacts) {
            $extEmail = ($mc.ExternalEmailAddress -replace '^SMTP:', '').ToLower()
            $existingContactsMap[$extEmail] = $mc
        }
        Write-Host "Found $($existingContactsMap.Count) existing managed contacts"

        # Track emails in Excel for removal check later
        $excelEmails = @{}

        # Collect newly created contacts for batch CustomAttribute1 update
        $newlyCreatedContacts = @()

        foreach ($contact in $contacts) {
            try {
                # Handle both column name formats
                $email = if ($contact.'Email Address') { $contact.'Email Address'.ToString().Trim() }
                         elseif ($contact.Email) { $contact.Email.ToString().Trim() }
                         else { "" }

                $name = if ($contact.Name) { $contact.Name.ToString().Trim() }
                        elseif ($contact.DisplayName) { $contact.DisplayName.ToString().Trim() }
                        else { "" }

                # Skip if no email
                if ([string]::IsNullOrWhiteSpace($email)) {
                    Write-Warning "Skipping contact with empty email"
                    $skipped++
                    continue
                }

                # Track this email
                $excelEmails[$email.ToLower()] = $true

                # Parse names
                $nameParts = if ($name) { $name -split '\s+' } else { @() }
                $firstName = if ($nameParts.Count -ge 1) { $nameParts[0] } else { "" }
                $lastName = if ($nameParts.Count -ge 2) { ($nameParts[1..($nameParts.Count-1)]) -join ' ' } else { "" }
                $displayName = if ([string]::IsNullOrWhiteSpace($name)) { $email.Split('@')[0] } else { $name }

                Write-Host "Processing: $email ($displayName)"

                # Check if contact exists using pre-fetched hashtable (no Exchange round-trip)
                $existingContact = $existingContactsMap[$email.ToLower()]

                if ($existingContact) {
                    # Only update if something actually changed
                    $needsUpdate = ($existingContact.DisplayName -ne $displayName) -or
                                   ($existingContact.CustomAttribute1 -ne $CustomAttributeValue)

                    if ($needsUpdate) {
                        Write-Host "  Updating existing contact"
                        Set-MailContact -Identity $email `
                            -DisplayName $displayName `
                            -CustomAttribute1 $CustomAttributeValue `
                            -ErrorAction Stop
                        $updated++
                    }
                    else {
                        Write-Host "  No changes needed"
                        $skipped++
                    }
                }
                else {
                    Write-Host "  Creating new contact"

                    # Generate base alias from email prefix
                    $baseAlias = $email.Split('@')[0] -replace '[^a-zA-Z0-9]', ''

                    # Create contact (CustomAttribute1 will be set in batch later)
                    $newContact = New-MailContactWithRetry `
                        -Email $email `
                        -DisplayName $displayName `
                        -BaseAlias $baseAlias `
                        -FirstName $firstName `
                        -LastName $lastName `
                        -CustomAttributeValue $CustomAttributeValue

                    if ($newContact) {
                        $newlyCreatedContacts += $newContact
                    }
                    $created++
                }

                # Add to distribution group if not already a member
                if (-not $dgMemberEmails.ContainsKey($email.ToLower())) {
                    Write-Host "  Adding to distribution group: $DistributionGroup"
                    Add-DistributionGroupMember -Identity $DistributionGroup -Member $email -ErrorAction Stop
                    $dgMemberEmails[$email.ToLower()] = $true
                }
                else {
                    Write-Host "  Already in distribution group"
                }

                $processedContacts += @{
                    Email = $email
                    DisplayName = $displayName
                    Status = "Success"
                }

            }
            catch {
                $errorMessage = "Error processing contact $email : $_"
                Write-Error $errorMessage
                $errors += $errorMessage

                $processedContacts += @{
                    Email = $email
                    DisplayName = $displayName
                    Status = "Failed: $_"
                }
            }
        }

        # Batch update CustomAttribute1 for newly created contacts
        if ($newlyCreatedContacts.Count -gt 0) {
            Write-Host "`nSetting CustomAttribute1 on $($newlyCreatedContacts.Count) newly created contacts..."
            Start-Sleep -Seconds 3  # Give Exchange time to replicate

            foreach ($newContact in $newlyCreatedContacts) {
                try {
                    Set-MailContact -Identity $newContact.Email `
                        -CustomAttribute1 $newContact.CustomAttributeValue `
                        -ErrorAction Stop
                    Write-Host "  Set attribute on: $($newContact.Email)"
                }
                catch {
                    Write-Warning "  Failed to set attribute on $($newContact.Email): $_"
                    $errors += "Failed to set CustomAttribute1 on $($newContact.Email): $_"
                }
            }
        }

        # Remove contacts no longer in Excel (bidirectional sync)
        # Using $existingMailContacts already fetched at the start
        Write-Host "`nChecking for contacts to remove..."
        $removed = 0

        foreach ($existingContact in $existingMailContacts) {
            $externalEmail = $existingContact.ExternalEmailAddress -replace '^SMTP:', ''

            if (-not $excelEmails.ContainsKey($externalEmail.ToLower())) {
                Write-Host "  Removing contact no longer in Excel: $externalEmail"
                try {
                    # Remove from DG first
                    Remove-DistributionGroupMember -Identity $DistributionGroup `
                        -Member $externalEmail `
                        -Confirm:$false `
                        -ErrorAction SilentlyContinue

                    # Then remove the contact
                    Remove-MailContact -Identity $externalEmail `
                        -Confirm:$false `
                        -ErrorAction Stop

                    $removed++
                }
                catch {
                    Write-Warning "Error removing contact $externalEmail : $_"
                    $errors += "Error removing contact $externalEmail : $_"
                }
            }
        }

        Write-Host "`n==================== SYNC SUMMARY ===================="
        Write-Host "Total contacts in Excel: $($contacts.Count)"
        Write-Host "Created: $created"
        Write-Host "Updated: $updated"
        Write-Host "Removed: $removed"
        Write-Host "Skipped: $skipped"
        Write-Host "Errors: $($errors.Count)"
        Write-Host "======================================================"

        return @{
            ProcessedContacts = $processedContacts
            Errors = $errors
            TotalProcessed = $contacts.Count
            Created = $created
            Updated = $updated
            Removed = $removed
            Skipped = $skipped
            SuccessCount = ($processedContacts | Where-Object { $_.Status -eq "Success" }).Count
            FailureCount = ($processedContacts | Where-Object { $_.Status -like "Failed:*" }).Count
        }

    }
    catch {
        throw "Contact sync failed: $_"
    }
}

#endregion

#region Main Function

function RunFunction {
    param($Timer)

    $smtpPassword = $null

    try {
        # Connect to Azure with Managed Identity
        Connect-AzAccount -Identity
        Write-Host "Connected to Azure"

        # Retrieve secrets from Azure Key Vault (HunterTech vault)
        # Certificate is stored in Key Vault and loaded via WEBSITE_LOAD_CERTIFICATES app setting
        $vaultName = "huntertechvault"
        $smtpPassword = ConvertTo-SecureString(Get-AzKeyVaultSecret -VaultName $vaultName -Name "smtp2go-secure" -AsPlainText) -AsPlainText -Force

        # Synapse-specific secrets (app is registered in Synapse tenant)
        $synapseTenantId = Get-AzKeyVaultSecret -VaultName $vaultName -Name "synapse-tenant-id" -AsPlainText
        $synapseAppId = Get-AzKeyVaultSecret -VaultName $vaultName -Name "synapse-app-id" -AsPlainText
        $synapseCertThumbprint = Get-AzKeyVaultSecret -VaultName $vaultName -Name "synapse-cert-thumbprint" -AsPlainText

        # SharePoint Configuration
        $sharePointSiteUrl = "https://synapsetax.sharepoint.com/sites/Administration"
        $excelFilePath = "/sites/Administration/Shared Documents/Administration/Tax Processes/T1 Processes/2026 T1 Season/T1 Client Email Listing TO BE UPDATED 2026.xlsx"
        $excelFileName = "T1ClientEmailListing.xlsx"

        # Exchange Configuration
        $exchangeOrganization = "synapsetax.ca"
        $distributionGroup = "T1Contacts@synapsetax.ca"
        $customAttributeValue = "T1SynapseContact"

        # Connect to SharePoint (Synapse tenant)
        Write-Host "Connecting to SharePoint: $sharePointSiteUrl"
        Connect-PnPOnline -Url $sharePointSiteUrl `
            -Tenant $synapseTenantId `
            -ClientId $synapseAppId `
            -Thumbprint $synapseCertThumbprint

        $web = Get-PnPWeb
        Write-Host "Connected to SharePoint site: $($web.Url)"

        # Prepare local path
        $localPath = "D:\Local\"
        if (-not (Test-Path -Path $localPath)) {
            New-Item -ItemType Directory -Path $localPath -Force | Out-Null
        }
        $localExcelPath = Join-Path $localPath $excelFileName

        # Download Excel file from SharePoint
        Write-Host "Downloading Excel file from SharePoint..."
        Get-PnPFile -Url $excelFilePath `
            -Path $localPath `
            -Filename $excelFileName `
            -AsFile `
            -Force `
            -ErrorAction Stop

        if (-not (Test-Path -Path $localExcelPath)) {
            throw "Failed to download Excel file from SharePoint"
        }
        Write-Host "Excel file downloaded successfully"

        # Connect to Exchange Online
        Write-Host "Connecting to Exchange Online..."
        Connect-ExchangeOnline -CertificateThumbprint $synapseCertThumbprint `
            -AppId $synapseAppId `
            -Organization $exchangeOrganization `
            -ShowBanner:$false

        Write-Host "Connected to Exchange Online"

        # Run the sync
        $syncResult = Sync-ContactsFromExcel `
            -ExcelPath $localExcelPath `
            -CustomAttributeValue $customAttributeValue `
            -DistributionGroup $distributionGroup

        Write-Host "Sync completed. Total: $($syncResult.TotalProcessed), Created: $($syncResult.Created), Updated: $($syncResult.Updated), Removed: $($syncResult.Removed), Failed: $($syncResult.FailureCount)"

        # Send error notification if there were failures
        if ($syncResult.Errors.Count -gt 0) {
            $errorReport = @"
Synapse Contact Sync completed with errors.

Summary:
- Total Processed: $($syncResult.TotalProcessed)
- Created: $($syncResult.Created)
- Updated: $($syncResult.Updated)
- Removed: $($syncResult.Removed)
- Failed: $($syncResult.FailureCount)

Errors:
$($syncResult.Errors -join "`n")

Function executed at: $currentUTCtime UTC
"@

            Send-ErrorNotification -ErrorMessage $errorReport -SecurePassword $smtpPassword
        }

        # Cleanup and disconnect
        Disconnect-PnPOnline -ErrorAction SilentlyContinue
        Disconnect-ExchangeOnline -Confirm:$false -ErrorAction SilentlyContinue
        Disconnect-AzAccount -ErrorAction SilentlyContinue

        Write-Host "SynapseContactSync completed successfully"

    }
    catch {
        $errorMessage = "SynapseContactSync function error: $_"
        Write-Error $errorMessage

        if ($smtpPassword) {
            Send-ErrorNotification -ErrorMessage $errorMessage -SecurePassword $smtpPassword
        }

        throw
    }
    finally {
        # Clean up temp files
        if (Test-Path -Path "D:\Local\*.xlsx") {
            Remove-Item -Path "D:\Local\*.xlsx" -Force -ErrorAction SilentlyContinue
        }
    }
}

#endregion

# Execute the function
RunFunction -Timer $Timer
