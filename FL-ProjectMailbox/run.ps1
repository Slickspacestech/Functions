# Input bindings are passed in via param block.
using namespace System.Net
using namespace System.Security.Cryptography.X509Certificates
param($Timer)

# Get the current universal time in the default string format
$currentUTCtime = (Get-Date).ToUniversalTime()

# The 'IsPastDue' porperty is 'true' when the current function invocation is later than scheduled.
if ($Timer.IsPastDue) {
    Write-Host "PowerShell timer is running late!"
}

import-module ExchangeOnlineManagement
import-module Az.Accounts -Force
import-module Az.KeyVault -Force
import-module PnP.PowerShell -Force
import-module ImportExcel -Force

# Write an information log with the current time.
Write-Host "v1.3 PowerShell timer trigger function ran! TIME: $currentUTCtime"
$exchange = get-module ExchangeOnlineManagement
$accounts = get-module Az.Accounts
$keyvault = get-module Az.KeyVault
$pnp = get-module PnP.PowerShell
$importexcel = get-module ImportExcel



write-host "exchange: $($exchange.Version)"
write-host "accounts: $($accounts.Version)"
write-host "keyvault: $($keyvault.Version)"
write-host "pnp: $($pnp.Version)"
write-host "importexcel: $($importexcel.Version)"







# Define the function to send an email
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



function safe_create_distribution_list {
    param(
        [Parameter(Mandatory=$true)]
        [string]$DisplayName,

        [Parameter(Mandatory=$true)]
        [string]$ProjectCode,
        
        [Parameter(Mandatory=$true)]
        [string]$OwnerEmail,
        
        [Parameter(Mandatory=$true)]
        [string]$MemberEmail
    )

    try {
        # Check if the distribution list exists
        $existingGroup = Get-DistributionGroup -Identity $DisplayName -ErrorAction SilentlyContinue
        
        if ($existingGroup) {
            Write-Host "Distribution list '$DisplayName' already exists."
            
            # Check if owner needs to be added
            $currentOwners = Get-DistributionGroup -Identity $DisplayName | Select-Object -ExpandProperty ManagedBy
            if ( $OwnerEmail.Substring(0,$OwnerEmail.IndexOf("@")) -eq $currentOwners) {
                write-information "owner $OwnerEmail doesn't equal $currentOwners, skipping"
                Add-DistributionGroupMember -Identity $DisplayName -Member $OwnerEmail -BypassSecurityGroupManagerCheck
                Set-DistributionGroup -Identity $DisplayName -ManagedBy $OwnerEmail -RequireSenderAuthenticationEnabled $false
                Write-Host "Added owner: $OwnerEmail"
            }
            
            # Check if member needs to be added
            $currentMembers = Get-DistributionGroupMember -Identity $DisplayName | Select-Object -ExpandProperty PrimarySmtpAddress
            foreach ($member in $currentMembers){
                if ($member -eq $MemberEmail){
                    write-information "member $MemberEmail already exists, skipping"
                }else{
                    Add-DistributionGroupMember -Identity $DisplayName -Member $MemberEmail
                    Write-Host "Added member: $MemberEmail"
                }
            }
            
            return $existingGroup
        }

        # Create the distribution list
        $newGroup = New-DistributionGroup -Name $DisplayName -DisplayName $DisplayName -ManagedBy $OwnerEmail -PrimarySmtpAddress "$ProjectCode@firstlightenergy.ca"
        Write-Host "Created new distribution list '$DisplayName'"

        # Add member
        Add-DistributionGroupMember -Identity $DisplayName -Member $MemberEmail
        Write-Host "Added member: $MemberEmail"

        return $newGroup
    }
    catch {
        Write-Error "Error creating distribution list: $_"
        return $null
    }
}



# Main function to be triggered by the Azure Function
function RunFunction {
    param($Timer)
    # import-module Az.Accounts
    Connect-AzAccount -Identity

    # Retrieve the secure password from Azure Key Vault
    $vaultName = "huntertechvault"
    $certName = "fl-mailbox"
    $cert = Get-AzKeyVaultCertificate -VaultName $vaultName -Name $certName
    $certsecret = Get-AzKeyVaultSecret -VaultName $vaultName -Name $certName -AsPlainText
    $privatebytes = [system.convert]::FromBase64String($certsecret)
    if ($privatebytes -eq $null -or $privatebytes.Length -eq 0) {
        throw "The certificate data is empty or null."
    }
    $flags = [System.Security.Cryptography.X509Certificates.X509KeyStorageFlags]::EphemeralKeySet
    $cert = [System.Security.Cryptography.X509Certificates.X509Certificate2]::new($privatebytes, "", $flags)
    $vTenantid = "tenantid"
    $vAppid = "appid"
    $tenantid = Get-AzKeyVaultSecret -VaultName $vaultName -Name $vTenantid -AsPlainText
    $appid = Get-AzKeyVaultSecret -VaultName $vaultName -Name $vAppid -AsPlainText
    Connect-ExchangeOnline -Certificate $cert -AppId $appid -Organization "firstlightca.onmicrosoft.com"
    $projectsmb = Get-Mailbox -Identity "projects@firstlightenergy.ca"
    Write-Information "connected to exchange, projectsmb is $($projectsmb.Name)"
    $smtp2go = ConvertTo-SecureString(Get-AzKeyVaultSecret -VaultName $vaultName -Name "smtp2go-secure" -AsPlainText) -AsPlainText -Force
    connect-pnponline -Url "https://firstlightca.sharepoint.com/sites/firstlightfiles" -Tenant $tenantid -ApplicationId $appid -CertificateBase64Encoded $certsecret
    $web = Get-PnPWeb
    Write-Information "connected to sharepoint, url is $($web.Url)"
    Get-PnPFile -Url "/sites/firstlightfiles/Shared Documents/General/Projects/Project-List.xlsx" -Path "D:\Local\" -Filename "projects.xlsx" -AsFile -force
    $projects = import-excel -Path D:\local\projects.xlsx
    $mailbox = Get-AzKeyVaultSecret -VaultName $vaultName -Name "flmailbox" -AsPlainText
    
    foreach ($project in $projects){
        $projectCode = $project.'Project #'.trim()
        $projectName = $project.'Project Name'.trim()
        
        $name = "$projectCode-$projectName"
        # $folder = safe_create_folder $name

        # Create distribution list for the project
        $dlName = $name  # Using the full project name (ProjectCode-ProjectName)
        $dlOwner = "plan8admin@firstlightenergy.ca"  # Changed to be the owner
        $dlMember = "projects@firstlightenergy.ca"  # Changed to be the member

        if (!$project.Created){
            write-information "creating distribution list for $dlName"
            $distributionList = safe_create_distribution_list -DisplayName $dlName -OwnerEmail $dlOwner -MemberEmail $dlMember -ProjectCode $projectCode
            if ($distributionList) {
                write-information "distribution list created for $dlName"
                # Enable external email reception
                $requireSenderAuthenticationEnabled = get-distributiongroup $dlName | select-object -expandproperty requireSenderAuthenticationEnabled
                if ($requireSenderAuthenticationEnabled -eq $true){
                    Set-DistributionGroup -Identity $dlName -RequireSenderAuthenticationEnabled $false
                }
                Write-Information "Successfully created/updated distribution list for project $projectCode"
            } else {
                Write-Information "Failed to create/update distribution list for project $projectCode"
            }
            # Update Excel with distribution list status
            $excel = Open-ExcelPackage -Path "D:\local\projects.xlsx"
            $worksheet = $excel.Workbook.Worksheets[1]  # Assuming first worksheet
            $row = if ($projects.count -le 1) { 2 } else { $projects.IndexOf($project) + 2 }
            $worksheet.Cells["C$row"].Value = ($distributionList -ne $null)
            $excel.Save()
            Close-ExcelPackage $excel
        }else{
            write-information "project $projectCode already exists, skipping"
        }
    
    }
    # # Upload the updated Excel file back to SharePoint
    write-information "uploading projects.xlsx to sharepoint"
   
    Add-PnPFile -Path "D:\local\projects.xlsx" -Folder "Shared Documents/General/Projects" -NewFileName "Project-List.xlsx"
    #goal is to read the csv or xlsx, connect to graph, check for/create a folder in the shared mailbox for each item in the xlsx
    #create the mailbox rule to move the item to the correct folder
    #create a distribution list for the project with the owner as matt@huntertech.ca and the member as projects@firstlightenergy.ca
    #allow external email reception for the distribution list
}

# Timer trigger to run the function periodically
$Timer = $null
$vaultName = "huntertechvault"
RunFunction -Timer $Timer
