# Input bindings are passed in via param block.
param($Timer)

# Get the current universal time in the default string format
$currentUTCtime = (Get-Date).ToUniversalTime()

# The 'IsPastDue' porperty is 'true' when the current function invocation is later than scheduled.
if ($Timer.IsPastDue) {
    Write-Host "PowerShell timer is running late!"
}

# Write an information log with the current time.
Write-Host "v1.1 PowerShell timer trigger function ran! TIME: $currentUTCtime"
# Import the required modules 
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
        [string]$previous
    )

    # Define the email parameters
    $smtpServer = "mail.smtp2go.com"
    $smtpPort = 2525
    $smtpUser = "patching@huntertech.ca"
    $from = "patching@huntertech.ca"
    $to = "matt@huntertech.ca"
    $body = "$subject, latest version is $version, the previous version was: $previous "

    # Create the credential object
    $credential = New-Object System.Management.Automation.PSCredential($smtpUser, $securePassword)

    # Send the email
    Send-MailMessage -From $from -To $to -Subject $subject -Body $body -SmtpServer $smtpServer -Port $smtpPort -Credential $credential -UseSsl
}

function getBlueBeamLatest {
    param($currentVersion)
    write-host "latest in vault is $currentVersion"
    $url = "https://support.bluebeam.com/en-us/release-notes-all.html"

    $webClient = New-Object System.Net.WebClient
    $webClient.Headers.Add("User-Agent", "Mozilla/5.0")
        
        # Download the HTML content
    $htmlContent = $webClient.DownloadString($url)
    # Load the HTML content from the URL
    $pattern = '<p[^>]*>(?:(?!</p>).)*?Revu\s+(\d{2}\.\d\.\d)[^<]*'
        
    # Find all matches
    $found= [regex]::Matches($htmlContent, $pattern, [System.Text.RegularExpressions.RegexOptions]::IgnoreCase)
    
   
    if ($found) {
        $firstLiItem = ([string]$found[0].Value).Replace("<p>Revu ", "")
        return $firstLiItem
    }else{
        return $null
    }
}


function getAutodeskLatest {
    param(
        $product,
        $year
    )
    #https://help.autodesk.com/cloudhelp/2025/ENU/AutoCAD-LT-ReleaseNotes/files/AUTOCADLT_2025_UPDATES.html
    #https://help.autodesk.com/cloudhelp/2025/ENU/RevitLTReleaseNotes/files/RevitLTReleaseNotes_2025updates_html.html
    #https://help.autodesk.com/cloudhelp/2025/ENU/AutoCAD-ReleaseNotes/files/AUTOCAD_2025_UPDATES.html
    #https://help.autodesk.com/cloudhelp/2025/ENU/RevitReleaseNotes/files/RevitReleaseNotes_2025updates_html.html

    switch($product){
        "RVT" {$url = "https://help.autodesk.com/cloudhelp/YEAR/ENU/RevitReleaseNotes/files/RevitReleaseNotes_YEARupdates_html.html".Replace("YEAR",$year)}
        "RVTLT" {$url = "https://help.autodesk.com/cloudhelp/YEAR/ENU/RevitLTReleaseNotes/files/RevitLTReleaseNotes_YEARupdates_html.html".Replace("YEAR",$year)}
        "ACD" {$url = "https://help.autodesk.com/cloudhelp/YEAR/ENU/AutoCAD-ReleaseNotes/files/AUTOCAD_YEAR_UPDATES.html".Replace("prod",$product).Replace("YEAR",$year)}
        "ACDLT" {$url = "https://help.autodesk.com/cloudhelp/YEAR/ENU/AutoCAD-LT-ReleaseNotes/files/AUTOCADLT_YEAR_UPDATES.html".Replace("YEAR",$year)}
    }
    $html = Invoke-RestMethod -Uri $url -Method Get -UseBasicParsing
    try {
        $updates = $html.html.body.div.ul.li.a
    }catch {
        write-host "unable to parse html xml object"
    }
    
    $latest = $updates[0].'#text'.replace(" Update","")
    return $latest
    #$found = $html -match '<p>Revu.+?(?=<)'

}

# Main function to be triggered by the Azure Function
function RunFunction {
    param($Timer)
    # import-module Az.Accounts
    Connect-AzAccount -Identity

    # Retrieve the secure password from Azure Key Vault
    $vaultName = "huntertechvault"
    $secretName = "smtp2go-secure"
    $securePassword = ConvertTo-SecureString(Get-AzKeyVaultSecret -VaultName $vaultName -Name $secretName -AsPlainText) -AsPlainText -Force
    # Load the secure password from Azure Key Vault or a secure location
    #$securePassword = Get-Content -Path "C:\home\site\wwwroot\secure\smtp2go-secure.txt" | ConvertTo-SecureString

    $latest = Get-AzKeyVaultSecret -VaultName $vaultName -Name "BBversion" -AsPlainText
    
    $bluebeam_latest = getBlueBeamLatest $latest

    if (!($bluebeam_latest)){  
        Send-Email -subject "Bluebeam failed to parse website" -version "0.0" -previous $latest -securePassword $securePassword
    }else{
        if ($bluebeam_latest -gt $latest){
            set-azkeyvaultSecret -VaultName $vaultName -Name "BBversion"  -secretValue (ConvertTo-SecureString $bluebeam_latest -AsPlainText -Force)
            Send-Email -subject "Bluebeam New Update!" -version $bluebeam_latest -previous $latest -securePassword $securePassword
        }
        
    }

    $autodesk_products = @(
        @{
            "product" = "ACDLT"
            "year" = "2024"
        }, 
        @{
            "product" = "ACDLT"
            "year" = "2025"
        },
        @{
            "product" = "ACD"
            "year" = "2024"
        },
        @{
            "product" = "ACD"
            "year" = "2025"
        },
        @{
            "product" = "RVT"
            "year" = "2024"
        },
        @{
            "product" = "RVT"
            "year" = "2025"
        },
        @{
            "product" = "RVT"
            "year" = "2023"
        },
        @{
            "product" = "RVTLT"
            "year" = "2023"
        },
        @{
            "product" = "RVTLT"
            "year" = "2024"
        },
        @{
            "product" = "RVTLT"
            "year" = "2025"
        }
    )
        foreach ($item in $autodesk_products) {
            $currentVersion = Get-AzKeyVaultSecret -VaultName $vaultName -Name "$($item.product)$($item.year)" -AsPlainText
            
            $latest_update = $null
            $latest_update = getAutodeskLatest $item.product $item.year

            if (!($currentVersion)){
                Set-AzKeyVaultSecret -VaultName $vaultName -Name "$($item.product)$($item.year)" -SecretValue (ConvertTo-SecureString $latest_update -AsPlainText -Force)
            } else{
                if ($currentVersion -lt $latest_update){
                    Set-AzKeyVaultSecret -VaultName $vaultName -Name "$($item.product)$($item.year)" -SecretValue (ConvertTo-SecureString $latest_update -AsPlainText -Force)
                    Send-Email -subject "$($item.product) $($item.year) New Update!" -version $latest_update -previous $currentVersion -securePassword $securePassword
                }
            }
            
        }
        
}

# Timer trigger to run the function periodically
$Timer = $null
RunFunction -Timer $Timer
