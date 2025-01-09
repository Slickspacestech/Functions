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
Import-Module Az.Accounts
Import-Module Microsoft.Graph
Import-Module ImportExcel
Import-Module PnP.PowerShell

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
    params(
        $sequence,
        $folderid,
        $displayName,
        $project_string
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

function get_transport_rule(){
    Param(
        $mailbox
    )
    $rule = Get-TransportRule -Identity $mailbox -ErrorAction SilentlyContinue
    return $rule
}
function safe_update_transport_rule(){
    Param(
        $transport_rule,
        $project_code,
        $mailbox
    )
    $rule = Get-TransportRule -Identity $mailbox -ErrorAction SilentlyContinue
    if(!($rule)){
        New-TransportRule -Name $mailbox -SubjectContainsWords $project_code -CopyTo $mailbox -StopRuleProcessing $true -Enabled $true -errorAction stop
    }else{
        $existingWords = $rule.SubjectContainsWords
        $updatedWords = $existingWords + $project_code
        set-transportrule $mailbox -SubjectContainsWords $updatedWords
    }
    $rule = Get-TransportRule -Identity $mailbox -ErrorAction SilentlyContinue

}


# Main function to be triggered by the Azure Function
function RunFunction {
    param($Timer)

    Connect-AzAccount -Identity

    # Retrieve the secure password from Azure Key Vault
    $vaultName = "huntertechvault"
    $certName = "fl-mailbox"
    $certsecret = Get-AzKeyVaultSecret -VaultName $vaultName -Name $certName -AsPlainText
    $privatebytes = [system.convert]::FromBase64String($certsecret)
    $cert = new-object System.security.cryptography.x509certificates.x509certificate2(,$privatebytes)
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
    $transport_rule = get_transport_rule $mailbox
    $size = $transport_rule.Size
    if ($size -gt 7500){
        Send-Email -subject "Rule Size $size" -securePassword $smtp2go -version " " -Body "TransportRule for $mailbox has reached $size bytes, maximum is 8192"
    }
    #check mailbox exists
    #check rule count lt 500
    #possibly create new mailbox
    foreach ($project in $projects){
        $projectCode = $project.'Project #'.trim()
        $projectName = $project.'Project Name'.trim()
        
        $name = "$projectCode-$projectName"
        $folder = safe_create_folder $name
        
        if ($folder){
            $mb_rule = safe_create_rule $folder.id $projectCode #left off here
        }
        if($mb_rule){
            safe_update_transport_rule $transport_rule $projectCode, $mailbox
        }
        
    }
    #goal is to read the csv or xlsx, connect to graph, check for/create a folder for each item in the shared mailbox
    #create the mailbox rule to move the item to the correct folder
    #update transport rule to include the new subject string to match on
    # also should check rule count, create new mailbox + new transport rule if above 500, nm total rule size is probably 500 at transport level

    
}

# Timer trigger to run the function periodically
$Timer = $null
$vaultName = "huntertechvault"
$latest = Get-AzKeyVaultSecret -VaultName $vaultName -Name "BBversion" -AsPlainText
RunFunction -Timer $Timer
write-host "why!"
write-host $latest