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

        Get-ChildItem -Path $tempPath -File -Recurse -ErrorAction SilentlyContinue | 
            ForEach-Object {
                try {
                    Remove-Item -Path $_.FullName -Force -ErrorAction SilentlyContinue
                    Write-Debug "Deleted: $($_.FullName)"
                }
                catch {
                    Write-Debug "Could not delete: $($_.FullName)"
                    continue
                }
            }
        
        Write-Information "Temp file cleanup completed"
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

# Main function to be triggered by the Azure Function
function RunFunction {
    param($Timer)
    
    # try {
        Connect-AzAccount -Identity

        # Retrieve secrets from Azure Key Vault
        $vaultName = "huntertechvault"
        $tenantid = Get-AzKeyVaultSecret -VaultName $vaultName -Name "tenantid" -AsPlainText
        $appid = Get-AzKeyVaultSecret -VaultName $vaultName -Name "appid" -AsPlainText
        $certsecret = Get-AzKeyVaultSecret -VaultName $vaultName -Name "fl-mailbox" -AsPlainText
        
        $smtp2go = ConvertTo-SecureString(Get-AzKeyVaultSecret -VaultName $vaultName -Name "smtp2go-secure" -AsPlainText) -AsPlainText -Force

        # Connect to SharePoint and get project list
        connect-pnponline -Url "https://firstlightca.sharepoint.com/sites/firstlightfiles" -Tenant $tenantid -ApplicationId $appid -CertificateBase64Encoded $certsecret
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
    # }
    # catch {
        # Write-Error "Error in main function: $_"
        # Send-Email -subject "Project Processing Error" `
                #   -version "" `
                #   -securePassword $smtp2go `
                #   -body "Function failed with error: $_"
    # }
    # finally {
         #Clear-TempFiles
    # }
}

# Timer trigger to run the function periodically
$Timer = $null
$vaultName = "huntertechvault"
RunFunction -Timer $Timer

