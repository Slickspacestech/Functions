# Input bindings are passed in via param block.

param($Timer)

# Get the current universal time in the default string format
$currentUTCtime = (Get-Date).ToUniversalTime()

# The 'IsPastDue' property is 'true' when the current function invocation is later than scheduled.
if ($Timer.IsPastDue) {
    Write-Host "PowerShell timer is running late!"
}

import-module Az.Accounts -Force
import-module Az.KeyVault -Force
import-module PnP.PowerShell -Force
import-module ImportExcel -Force
import-module Az.Storage -Force

# Write an information log with the current time.
Write-Host "v1.6 PowerShell timer trigger function ran! TIME: $currentUTCtime"

function Clear-TempFiles {
    try {
        Write-Information "Starting temp file cleanup..."
        $tempPath = $env:TEMP
        
        if (-not (Test-Path -Path $tempPath)) {
            Write-Warning "Temp directory not found at: $tempPath"
            return
        }

        # Get-ChildItem -Path $tempPath -File -Recurse -ErrorAction SilentlyContinue | 
        #     ForEach-Object {
        #         if ($_.FullName -notlike "*exchange.format.ps1xml*") {
        #             try {
        #                 Remove-Item -Path $_.FullName -Force -ErrorAction SilentlyContinue
        #                 Write-Debug "Deleted: $($_.FullName)"
        #             }
        #             catch {
        #                 Write-Debug "Could not delete: $($_.FullName)"
        #                 continue
        #             }
        #         }
        #     }
        
        # Write-Information "Temp file cleanup completed"


        # Get the size of all files in the temporary folder
        $folderSize = Get-ChildItem -Path $tempPath -Recurse | Measure-Object -Property Length -Sum

        # Convert the size from bytes to megabytes
        $sizeInMB = [math]::Round($folderSize.Sum / 1MB, 2)

        # Display the total size
        Write-Information "The total size of the temporary folder is $sizeInMB MB"

    }
    catch {
        Write-Warning "Error during temp cleanup: $_"
    }
}

function Send-Email {
    param (
        [string]$subject,
        [string]$version,
        $securePassword,
        $body
    )

    # Define the email parameters
    $smtpServer = "mail.smtp2go.com"
    $smtpPort = 2525
    $smtpUser = "patching@huntertech.ca"
    $from = "flmailbox@huntertech.ca"
    $to = "matt@huntertech.ca"

    # Create the credential object
    $credential = New-Object System.Management.Automation.PSCredential($smtpUser, $securePassword)

    # Send the email
    Send-MailMessage -From $from -To $to -Subject $subject -Body $body -SmtpServer $smtpServer -Port $smtpPort -Credential $credential -UseSsl
}

function Test-CertificateExpiry {
    param(
        [Parameter(Mandatory=$true)]
        [string]$CertificateName,
        
        [Parameter(Mandatory=$true)]
        [string]$VaultName,
        
        [Parameter(Mandatory=$true)]
        [System.Security.SecureString]$SmtpPassword,
        
        [Parameter(Mandatory=$false)]
        [int]$WarningDays = 30
    )

    try {
        # Get certificate from Key Vault
        $cert = Get-AzKeyVaultCertificate -VaultName $VaultName -Name $CertificateName
        if (-not $cert) {
            throw "Certificate '$CertificateName' not found in vault '$VaultName'"
        }

        # Calculate days until expiry
        $daysUntilExpiry = ($cert.Certificate.NotAfter - (Get-Date)).Days
        
        # Create email body with certificate details
        $emailBody = @"
Certificate Details:
-------------------
Name: $($cert.Name)
Subject: $($cert.Certificate.Subject)
Thumbprint: $($cert.Certificate.Thumbprint)
Expiry Date: $($cert.Certificate.NotAfter)
Days Remaining: $daysUntilExpiry
Key Vault: $VaultName

Please ensure the certificate is renewed before expiration.
"@

        # Check if warning needed and not already sent today
        if ($daysUntilExpiry -le $WarningDays) {
            # Connect to Azure Storage
            $storageAccount = Get-AzStorageAccount -ResourceGroupName "htupdatechecker" -Name "htupdatechecker"
            $ctx = $storageAccount.Context
            
            # Create table if it doesn't exist
            $tableName = "CertificateWarnings"
            $table = Get-AzStorageTable -Name $tableName -Context $ctx -ErrorAction SilentlyContinue
            if (-not $table) {
                $table = New-AzStorageTable -Name $tableName -Context $ctx
            }
            
            # Check last warning date
            $lastWarning = Get-AzTableRow -Table $table.CloudTable -PartitionKey "Certificates" -RowKey $cert.Certificate.Thumbprint -ErrorAction SilentlyContinue
            $today = (Get-Date).Date
            
            if (-not $lastWarning -or ([DateTime]$lastWarning.LastWarningDate).Date -lt $today) {
                # Send warning email
                Send-Email `
                    -subject "Key Vault Certificate Expiry Warning - $($cert.Name)" `
                    -version "" `
                    -securePassword $SmtpPassword `
                    -body $emailBody

                # Update or add warning record
                if ($lastWarning) {
                    $lastWarning.LastWarningDate = $today
                    $lastWarning | Update-AzTableRow -Table $table.CloudTable
                } else {
                    Add-AzTableRow `
                        -Table $table.CloudTable `
                        -PartitionKey "Certificates" `
                        -RowKey $cert.Certificate.Thumbprint `
                        -Property @{
                            "LastWarningDate" = $today
                            "CertificateName" = $cert.Name
                            "VaultName" = $VaultName
                        }
                }

                Write-Warning "Certificate will expire in $daysUntilExpiry days - Warning email sent"
            } else {
                Write-Information "Certificate expiry warning already sent today"
            }
            return $false
        }
        
        Write-Information "Certificate valid for $daysUntilExpiry days"
        return $true
    }
    catch {
        $errorMessage = "Error checking certificate expiry: $_"
        Write-Error $errorMessage
        
        # Send error notification (errors always send regardless of daily limit)
        Send-Email `
            -subject "Certificate Check Error" `
            -version "" `
            -securePassword $SmtpPassword `
            -body $errorMessage

        return $false
    }
}

# Main function to be triggered by the Azure Function
function RunFunction {
    param($Timer)
    
    try {
        Connect-AzAccount -Identity

        # Retrieve secrets from Azure Key Vault
        $vaultName = "huntertechvault"
        $tenantid = Get-AzKeyVaultSecret -VaultName $vaultName -Name "tenantid" -AsPlainText
        $appid = Get-AzKeyVaultSecret -VaultName $vaultName -Name "appid" -AsPlainText
        $thumbprint = "F87409186E7544C2D93B79931987BF2BE313E336"
        $smtp2go = ConvertTo-SecureString(Get-AzKeyVaultSecret -VaultName $vaultName -Name "smtp2go-secure" -AsPlainText) -AsPlainText -Force

        # Check certificate expiry
        $certValid = Test-CertificateExpiry `
            -CertificateName "fl-mailbox" `
            -VaultName $vaultName `
            -SmtpPassword $smtp2go
        if (-not $certValid) {
            Write-Warning "Certificate expiry check failed or certificate needs renewal"
        }

        # Connect to SharePoint and get project list
        connect-pnponline -Url "https://firstlightca.sharepoint.com/sites/firstlightfiles" -Tenant $tenantid -ApplicationId $appid -Thumbprint $thumbprint
        $web = Get-PnPWeb
        Write-host "Connected to SharePoint, url is $($web.Url)"
        
        Get-PnPFile -Url "/sites/firstlightfiles/Shared Documents/General/Projects/Project-List.xlsx" -Path "D:\Local\" -Filename "projects.xlsx" -AsFile -force -ErrorAction Stop
        if (-not (Test-Path -Path "D:\Local\projects.xlsx")) {
            Write-Error "Failed to download Project-List.xlsx from SharePoint"
            Send-Email -subject "Project List Download Error" `
                       -version "" `
                       -securePassword $smtp2go `
                       -body "Failed to download Project-List.xlsx from SharePoint"
        }
        $projects = import-excel -Path D:\local\projects.xlsx
        
        foreach ($project in $projects){
            $projectCode = $project.'Project #'.trim()
            $projectName = $project.'Project Name'.trim()
            
            if (!$project.Created){
                Write-Information "Processing project: $projectCode"
                
                # Call Exchange Manager Function
                $body = @{
                    projectCode = $projectCode
                    projectName = $projectName
                }
                
                try {
                    $result = Invoke-RestMethod `
                        -Uri "https://htupdatechecker2.azurewebsites.net/api/FL-ExchangeManager" `
                        -Method Post `
                        -Body ($body | ConvertTo-Json) `
                        -ContentType "application/json" `
                        -Headers @{
                            "x-functions-key" = Get-AzKeyVaultSecret -VaultName $vaultName -Name "exchange-function-key" -AsPlainText
                        }

                    Write-Information "Exchange Manager result: $($result | ConvertTo-Json)"
                    
                    # Update Excel with distribution list status
                    $excel = Open-ExcelPackage -Path "D:\local\projects.xlsx"
                    $worksheet = $excel.Workbook.Worksheets[1]
                    $row = if ($projects.count -le 1) { 2 } else { $projects.IndexOf($project) + 2 }
                    $worksheet.Cells["C$row"].Value = $result.success
                    $excel.Save()
                    Close-ExcelPackage $excel
                }
                catch {
                    Write-Error "Failed to process project $projectCode with Exchange Manager: $_"
                    Send-Email -subject "Project Processing Error" `
                             -version "" `
                             -securePassword $smtp2go `
                             -body "Failed to process project $projectCode. Error: $_"
                }
            } else {
                Write-Information "Project $projectCode already exists, skipping"
            }
        }
        
        # Upload the updated Excel file back to SharePoint
        Write-Information "Uploading projects.xlsx to SharePoint"
        Add-PnPFile -Path "D:\local\projects.xlsx" -Folder "Shared Documents/General/Projects" -NewFileName "Project-List.xlsx"
        remove-item -path "D:\local\projects.xlsx" -force
        disconnect-pnponline
        disconnect-azaccount
    }
    catch {
        Write-Error "Error in main function: $_"
        Send-Email -subject "Project Processing Error" `
                  -version "" `
                  -securePassword $smtp2go `
                  -body "Function failed with error: $_"
    }
    finally {
        Clear-TempFiles
    }
}

# Timer trigger to run the function periodically
$Timer = $null
$vaultName = "huntertechvault"
RunFunction -Timer $Timer

