using namespace System.Net
using namespace System.Security.Cryptography.X509Certificates

param($Request, $TriggerMetadata)

# Import required modules
Import-Module ExchangeOnlineManagement -RequiredVersion 3.4.0 -Force
Import-Module Az.Accounts -Force
Import-Module Az.KeyVault -Force

$exchangemodule = get-module ExchangeOnlineManagement


write-host "exchange: $($exchangemodule.Version)"


# Write version info
Write-Host "FL-ExchangeManager v1.1"

function Connect-ExchangeServices {
    param(
        [Parameter(Mandatory=$true)]
        [string]$VaultName
    )
    
    try {
        Connect-AzAccount -Identity

        # Get certificate and credentials
        $certthumb = "F87409186E7544C2D93B79931987BF2BE313E336"

        
        # Get tenant and app IDs
        $tenantid = Get-AzKeyVaultSecret -VaultName $VaultName -Name "tenantid" -AsPlainText
        $appid = Get-AzKeyVaultSecret -VaultName $VaultName -Name "appid" -AsPlainText

        # Connect to Exchange Online
        Connect-ExchangeOnline -CertificateThumbprint $certthumb -AppId $appid -Organization "firstlightca.onmicrosoft.com"
        Write-Information "Successfully connected to Exchange Online"
        
        return $true
    }
    catch {
        Write-Error "Failed to connect to Exchange: $_"
        return $false
    }
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
                Write-Information "owner $OwnerEmail doesn't equal $currentOwners, skipping"
                Add-DistributionGroupMember -Identity $DisplayName -Member $OwnerEmail -BypassSecurityGroupManagerCheck
                Set-DistributionGroup -Identity $DisplayName -ManagedBy $OwnerEmail -RequireSenderAuthenticationEnabled $false
                Write-Host "Added owner: $OwnerEmail"
            }
            
            # Check if member needs to be added
            $currentMembers = Get-DistributionGroupMember -Identity $DisplayName | Select-Object -ExpandProperty PrimarySmtpAddress
            foreach ($member in $currentMembers){
                if ($member -eq $MemberEmail){
                    Write-Information "member $MemberEmail already exists, skipping"
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
        Set-DistributionGroup -Identity $DisplayName -RequireSenderAuthenticationEnabled $false
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

# Main function processing
try {
    # Parse request body
    $requestBody = $Request.Body
    Write-Information "Received request for project: $($requestBody.projectCode)"
    
    # Validate required fields
    if (-not $requestBody.projectCode -or -not $requestBody.projectName) {
        Push-OutputBinding -Name Response -Value ([HttpResponseContext]@{
            StatusCode = [HttpStatusCode]::BadRequest
            Body = "Missing required fields: projectCode and projectName are required"
        })
        return
    }

    # Connect to services
    $connected = Connect-ExchangeServices -VaultName "huntertechvault"
    if (-not $connected) {
        throw "Failed to connect to Exchange Services"
    }

    # Process distribution list
    $projectCode = $requestBody.projectCode.Trim()
    $projectName = $requestBody.projectName.Trim()
    $name = "$projectCode-$projectName"
    
    $dlOwner = "plan8admin@firstlightenergy.ca"
    $dlMember = "projects@firstlightenergy.ca"

    Write-Information "Creating distribution list for $name"
    $distributionList = safe_create_distribution_list -DisplayName $name `
                                                    -OwnerEmail $dlOwner `
                                                    -MemberEmail $dlMember `
                                                    -ProjectCode $projectCode

    if ($distributionList) {
        Write-Information "Distribution list created successfully"
        $result = @{
            success = $true
            message = "Distribution list created/updated successfully"
            distributionList = $name
        }
    } else {
        Write-Information "Failed to create distribution list"
        $result = @{
            success = $false
            message = "Failed to create/update distribution list"
            distributionList = $null
        }
    }

    # Return success response
    Push-OutputBinding -Name Response -Value ([HttpResponseContext]@{
        StatusCode = [HttpStatusCode]::OK
        Body = $result
    })
}
catch {
    Write-Error "Error processing request: $_"
    # Return error response
    Push-OutputBinding -Name Response -Value ([HttpResponseContext]@{
        StatusCode = [HttpStatusCode]::InternalServerError
        Body = "Error processing request: $_"
    })
}