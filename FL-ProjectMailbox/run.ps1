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

# Write an information log with the current time.
Write-Host "PowerShell timer trigger function ran! TIME: $currentUTCtime"
# Import the required modules 
# Import-Module Az.Accounts
# Import-Module Microsoft.Graph
# Import-Module ImportExcel
# Import-Module PnP.PowerShell

<#
Import-Module Az.Accounts
Import-Module Az.Functions
Install-Module -Name Az.KeyVault -Force -Scope CurrentUser
#>



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


function create_mailboxfolder(){
    param(
        $identity,
        $folder
    )
    $params = @{
        displayName = "$folder"
        isHidden = $false
       }
    $folder = New-MgUserMailFolder -UserId $identity -BodyParameter $params
    return $folder
}
function safe_create_folder(){
    param($name)
    $folder = get-mguserMailFolder -UserId projects@firstlightenergy.ca | Where {$_.displayName -eq "$name"}
    if (!($folder)){
        $folder = create_mailboxfolder "projects@firstlightenergy.ca" $name
    }
    return $folder
}

function create_rule(){
    param(
        $sequence,
        $folderid,
        $displayName,
        $project_string,
        $userid
    )
    $rule = @{
        displayName = $displayName
        sequence = $sequence
        isEnabled = $true
        conditions = @{
            subjectContains = @(
                $project_string
            )
        }
        actions = @{
            moveToFolder = $folderid
        }
    }
    $new_rule = New-MgUserMailFolderMessageRule -UserId $userid -BodyParameter $rule -MailFolderId $folderid
    return $new_rule
}

function safe_create_rule(){
    param(
        $folderid,
        $matchstring,
        $userid
    )
    $projectRule = $null
    $rules = Get-MgUserMailFolderMessageRule -MailFolderId inbox -UserId $userid
    if ($rules){
        $nextSequence = ($rules | Sort-Object -Property Sequence -Descending | select sequence -First 1).sequence + 1
    }else{
        $nextSequence = 1
    }
    
    $exists = $false
    foreach ($rule in $rules){
        if ($rule.Conditions.SubjectContains -eq $matchstring){
            $exists = $true
            $projectRule = $rule
            break
        }
    }
    if (-not ($exists)){
        $projectRule = create_rule $nextSequence $folderid $matchstring $matchstring $userid
    }
    return $projectRule
}

function safe_create_distribution_list {
    param(
        [Parameter(Mandatory=$true)]
        [string]$DisplayName,
        
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
            if ($currentOwners -notcontains $OwnerEmail) {
                Add-DistributionGroupMember -Identity $DisplayName -Member $OwnerEmail -BypassSecurityGroupManagerCheck
                Set-DistributionGroup -Identity $DisplayName -ManagedBy $OwnerEmail
                Write-Host "Added owner: $OwnerEmail"
            }
            
            # Check if member needs to be added
            $currentMembers = Get-DistributionGroupMember -Identity $DisplayName | Select-Object -ExpandProperty PrimarySmtpAddress
            if ($currentMembers -notcontains $MemberEmail) {
                Add-DistributionGroupMember -Identity $DisplayName -Member $MemberEmail
                Write-Host "Added member: $MemberEmail"
            }
            
            return $existingGroup
        }

        # Create the distribution list
        $newGroup = New-DistributionGroup -Name $DisplayName -DisplayName $DisplayName -ManagedBy $OwnerEmail -PrimarySmtpAddress "$DisplayName@firstlightenergy.ca"
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
    $certsecret = Get-AzKeyVaultSecret -VaultName $vaultName -Name $cert.Name -AsPlainText
    $privatebytes = [system.convert]::FromBase64String($certsecret)
    $flags = [System.Security.Cryptography.X509Certificates.X509KeyStorageFlags]::EphemeralKeySet
    $cert = [System.Security.Cryptography.X509Certificates.X509Certificate2]::new($privatebytes, "", $flags)
    $vTenantid = "tenantid"
    $vAppid = "appid"
    $tenantid = Get-AzKeyVaultSecret -VaultName $vaultName -Name $vTenantid -AsPlainText
    $appid = Get-AzKeyVaultSecret -VaultName $vaultName -Name $vAppid -AsPlainText
    $session = Connect-ExchangeOnline -Certificate $cert -AppId $appid -Organization "firstlightca.onmicrosoft.com"
    $smtp2go = ConvertTo-SecureString(Get-AzKeyVaultSecret -VaultName $vaultName -Name "smtp2go-secure" -AsPlainText) -AsPlainText -Force
    Connect-MgGraph -TenantId $tenantid -appid $appid -certificate $cert
    connect-pnponline -url "https://firstlightca.sharepoint.com/sites/firstlightfiles" -Tenant $tenantid -ApplicationId $appid -CertificateBase64Encoded $certsecret
    Get-PnPFile -Url "/sites/firstlightfiles/Shared Documents/General/Projects/Project-List.xlsx" -Path "D:\Local\" -Filename "projects.xlsx" -AsFile
    $projects = import-excel -Path D:\local\projects.xlsx
    $mailbox = Get-AzKeyVaultSecret -VaultName $vaultName -Name "flmailbox" -AsPlainText
    
    foreach ($project in $projects){
        $projectCode = $project.'Project #'.trim()
        $projectName = $project.'Project Name'.trim()
        
        $name = "$projectCode-$projectName"
        $folder = safe_create_folder $name

        # Create distribution list for the project
        $dlName = $name  # Using the full project name (ProjectCode-ProjectName)
        $dlOwner = "matt@huntertech.ca"  # Changed to be the owner
        $dlMember = "projects@firstlightenergy.ca"  # Changed to be the member
        
        $distributionList = safe_create_distribution_list -DisplayName $dlName -OwnerEmail $dlOwner -MemberEmail $dlMember
        if ($distributionList) {
            # Enable external email reception
            Set-DistributionGroup -Identity $dlName -RequireSenderAuthenticationEnabled $false
            Write-Host "Successfully created/updated distribution list for project $projectCode"
        } else {
            Write-Host "Failed to create/update distribution list for project $projectCode"
        }
    }
    #goal is to read the csv or xlsx, connect to graph, check for/create a folder in the shared mailbox for each item in the xlsx
    #create the mailbox rule to move the item to the correct folder
    #create a distribution list for the project with the owner as matt@huntertech.ca and the member as projects@firstlightenergy.ca
    #allow external email reception for the distribution list
}

# Timer trigger to run the function periodically
$Timer = $null
$vaultName = "huntertechvault"
RunFunction -Timer $Timer
