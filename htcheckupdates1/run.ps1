# Input bindings are passed in via param block.
param($Timer)

# Get the current universal time in the default string format
$currentUTCtime = (Get-Date).ToUniversalTime()

# The 'IsPastDue' porperty is 'true' when the current function invocation is later than scheduled.
if ($Timer.IsPastDue) {
    Write-Host "PowerShell timer is running late!"
}

# Write an information log with the current time.
Write-Host "v2.0 PowerShell timer trigger function ran! TIME: $currentUTCtime"

#region Core Architecture Classes

# Base interface for version extraction strategies
class IVersionStrategy {
    [string] ExtractVersion([string]$url) {
        throw "ExtractVersion method must be implemented by derived class"
    }
    
    [hashtable] GetMetadata() {
        return @{
            "Strategy" = $this.GetType().Name
            "LastExecuted" = (Get-Date).ToUniversalTime()
        }
    }
}

# Product monitor class
class ProductMonitor {
    [string]$Id
    [string]$Name
    [string]$Url
    [IVersionStrategy]$Strategy
    [string]$KeyVaultKey
    [hashtable]$Config
    
    ProductMonitor([hashtable]$productConfig) {
        $this.Id = $productConfig.id
        $this.Name = $productConfig.name
        $this.Url = $productConfig.url
        $this.KeyVaultKey = $productConfig.keyVaultKey
        $this.Config = $productConfig
        $this.Strategy = New-VersionStrategy $productConfig
    }
    
    [string] GetLatestVersion() {
        try {
            $version = $this.Strategy.ExtractVersion($this.Url)
            Write-Host "[$($this.Id)] Extracted version: $version"
            return $version
        }
        catch {
            Write-Host "[$($this.Id)] Error extracting version: $($_.Exception.Message)"
            return $null
        }
    }
    
    [hashtable] GetMetadata() {
        return @{
            "ProductId" = $this.Id
            "ProductName" = $this.Name
            "Url" = $this.Url
            "Strategy" = $this.Strategy.GetMetadata()
        }
    }
}

#endregion

#region Version Extraction Strategies

# Regex-based version extraction strategy
class RegexStrategy : IVersionStrategy {
    [string]$Pattern
    [int]$VersionGroup
    [hashtable]$Headers
    
    RegexStrategy([string]$pattern, [int]$versionGroup = 1) {
        $this.Pattern = $pattern
        $this.VersionGroup = $versionGroup
        $this.Headers = @{
            "User-Agent" = "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36"
        }
    }
    
    [string] ExtractVersion([string]$url) {
        try {
            $webClient = New-Object System.Net.WebClient
            foreach ($header in $this.Headers.Keys) {
                $webClient.Headers.Add($header, $this.Headers[$header])
            }
            
            $htmlContent = $webClient.DownloadString($url)
            $matches = [regex]::Matches($htmlContent, $this.Pattern, [System.Text.RegularExpressions.RegexOptions]::IgnoreCase)
            
            if ($matches.Count -gt 0 -and $matches[0].Groups.Count -gt $this.VersionGroup) {
                return $matches[0].Groups[$this.VersionGroup].Value.Trim()
            }
            
            return $null
        }
        catch {
            Write-Host "RegexStrategy error: $($_.Exception.Message)"
            return $null
        }
        finally {
            if ($webClient) { $webClient.Dispose() }
        }
    }
}

# JSON API-based version extraction strategy
class JsonApiStrategy : IVersionStrategy {
    [string]$JsonPath
    [hashtable]$Headers
    
    JsonApiStrategy([string]$jsonPath) {
        $this.JsonPath = $jsonPath
        $this.Headers = @{
            "Accept" = "application/json"
            "User-Agent" = "UpdateMonitor/2.0"
        }
    }
    
    [string] ExtractVersion([string]$url) {
        try {
            $response = Invoke-RestMethod -Uri $url -Method Get -Headers $this.Headers
            
            # Navigate JSON path (e.g., "tag_name" or "data.version")
            $current = $response
            foreach ($part in $this.JsonPath -split '\.') {
                $current = $current.$part
                if ($null -eq $current) { return $null }
            }
            
            # Clean version string (remove 'v' prefix if present)
            $version = $current.ToString()
            if ($version -match '^v?(.+)$') {
                return $matches[1]
            }
            
            return $version
        }
        catch {
            Write-Host "JsonApiStrategy error: $($_.Exception.Message)"
            return $null
        }
    }
}

# HTML parsing strategy using basic text extraction
class HtmlParseStrategy : IVersionStrategy {
    [string]$StartMarker
    [string]$EndMarker
    [string]$VersionPattern
    
    HtmlParseStrategy([string]$startMarker, [string]$endMarker, [string]$versionPattern) {
        $this.StartMarker = $startMarker
        $this.EndMarker = $endMarker
        $this.VersionPattern = $versionPattern
    }
    
    [string] ExtractVersion([string]$url) {
        try {
            $webClient = New-Object System.Net.WebClient
            $webClient.Headers.Add("User-Agent", "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36")
            
            $htmlContent = $webClient.DownloadString($url)
            
            # Find content between markers
            $startIndex = $htmlContent.IndexOf($this.StartMarker)
            if ($startIndex -eq -1) { return $null }
            
            $endIndex = $htmlContent.IndexOf($this.EndMarker, $startIndex)
            if ($endIndex -eq -1) { $endIndex = $htmlContent.Length }
            
            $section = $htmlContent.Substring($startIndex, $endIndex - $startIndex)
            
            # Extract version using pattern
            if ($section -match $this.VersionPattern) {
                return $matches[1]
            }
            
            return $null
        }
        catch {
            Write-Host "HtmlParseStrategy error: $($_.Exception.Message)"
            return $null
        }
        finally {
            if ($webClient) { $webClient.Dispose() }
        }
    }
}

# Custom PowerShell script strategy
class CustomScriptStrategy : IVersionStrategy {
    [scriptblock]$Script
    
    CustomScriptStrategy([scriptblock]$script) {
        $this.Script = $script
    }
    
    [string] ExtractVersion([string]$url) {
        try {
            $result = & $this.Script $url
            return $result
        }
        catch {
            Write-Host "CustomScriptStrategy error: $($_.Exception.Message)"
            return $null
        }
    }
}

#endregion

# Strategy factory function
function New-VersionStrategy {
    param([hashtable]$config)
    
    switch ($config.strategy) {
        "regex" {
            $versionGroup = if ($config.versionGroup) { $config.versionGroup } else { 1 }
            return [RegexStrategy]::new($config.pattern, $versionGroup)
        }
        "json-api" {
            return [JsonApiStrategy]::new($config.jsonPath)
        }
        "html-parse" {
            return [HtmlParseStrategy]::new($config.startMarker, $config.endMarker, $config.versionPattern)
        }
        "custom" {
            $scriptBlock = [scriptblock]::Create($config.script)
            return [CustomScriptStrategy]::new($scriptBlock)
        }
        default {
            throw "Unknown strategy: $($config.strategy)"
        }
    }
}

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

#region Configuration Management

# Get product configuration from Key Vault
function Get-ProductConfiguration {
    param([string]$vaultName)
    
    try {
        $configJson = Get-AzKeyVaultSecret -VaultName $vaultName -Name "config-products" -AsPlainText
        if ($configJson) {
            $config = $configJson | ConvertFrom-Json
            # Convert PSCustomObject array to hashtable array
            $products = @()
            foreach ($product in $config.products) {
                $hashtable = @{}
                foreach ($prop in $product.PSObject.Properties) {
                    # Handle nested objects and preserve all property types
                    if ($prop.Value -is [System.Management.Automation.PSCustomObject]) {
                        # Convert nested PSCustomObject to hashtable
                        $nestedHash = @{}
                        foreach ($nestedProp in $prop.Value.PSObject.Properties) {
                            $nestedHash[$nestedProp.Name] = $nestedProp.Value
                        }
                        $hashtable[$prop.Name] = $nestedHash
                    }
                    else {
                        $hashtable[$prop.Name] = $prop.Value
                    }
                }
                $products += $hashtable
            }
            return $products
        }
    }
    catch {
        Write-Host "Failed to load product configuration: $($_.Exception.Message)"
    }
    
    # Return default configuration if Key Vault config doesn't exist
    return Get-DefaultProductConfiguration
}

# Default product configuration (fallback)
function Get-DefaultProductConfiguration {
    return @(
        @{
            "id" = "bluebeam-revu"
            "name" = "Bluebeam Revu"
            "url" = "https://support.bluebeam.com/en-us/release-notes-all.html"
            "strategy" = "regex"
            "pattern" = '<p[^>]*>(?:(?!</p>).)*?Revu\s+(\d{2}\.\d\.\d)[^<]*'
            "versionGroup" = 1
            "keyVaultKey" = "BBversion"
            "enabled" = $true
        },
        @{
            "id" = "taxcycle"
            "name" = "TaxCycle"
            "url" = "https://www.taxcycle.com/support/download/"
            "strategy" = "regex"
            "pattern" = 'TaxCycle Version\s+(\d+\.\d+\.\d+(?:\.\d+)?)'
            "versionGroup" = 1
            "keyVaultKey" = "TaxCycleVersion"
            "enabled" = $true
        }
    )
}

# Save product configuration to Key Vault
function Set-ProductConfiguration {
    param(
        [string]$vaultName,
        [array]$products
    )
    
    $config = @{ "products" = $products }
    $configJson = $config | ConvertTo-Json -Depth 10
    
    try {
        Set-AzKeyVaultSecret -VaultName $vaultName -Name "config-products" -SecretValue (ConvertTo-SecureString $configJson -AsPlainText -Force)
        Write-Host "Product configuration saved to Key Vault"
        return $true
    }
    catch {
        Write-Host "Failed to save product configuration: $($_.Exception.Message)"
        return $false
    }
}

# Get stored version for a product
function Get-StoredVersion {
    param(
        [string]$vaultName,
        [string]$productId,
        [string]$keyVaultKey
    )
    
    try {
        $version = Get-AzKeyVaultSecret -VaultName $vaultName -Name $keyVaultKey -AsPlainText
        return $version
    }
    catch {
        Write-Host "No stored version found for $productId"
        return $null
    }
}

# Update stored version for a product
function Set-StoredVersion {
    param(
        [string]$vaultName,
        [string]$productId,
        [string]$keyVaultKey,
        [string]$version
    )
    
    try {
        Set-AzKeyVaultSecret -VaultName $vaultName -Name $keyVaultKey -SecretValue (ConvertTo-SecureString $version -AsPlainText -Force)
        Write-Host "[$productId] Version updated to: $version"
        return $true
    }
    catch {
        Write-Host "[$productId] Failed to update version: $($_.Exception.Message)"
        return $false
    }
}

#endregion

#region Product Monitoring Engine

# Main product monitoring function
function Invoke-ProductMonitoring {
    param(
        [string]$vaultName,
        [securestring]$smtpPassword
    )
    
    Write-Host "Starting product monitoring..."
    
    $products = Get-ProductConfiguration $vaultName
    $results = @()
    
    foreach ($product in $products) {
        if (-not $product.enabled) {
            Write-Host "[$($product.id)] Skipping disabled product"
            continue
        }
        
        try {
            Write-Host "[$($product.id)] Checking for updates..."
            
            $monitor = [ProductMonitor]::new($product)
            $currentVersion = Get-StoredVersion $vaultName $product.id $product.keyVaultKey
            $latestVersion = $monitor.GetLatestVersion()
            
            $result = @{
                "ProductId" = $product.id
                "ProductName" = $product.name
                "CurrentVersion" = $currentVersion
                "LatestVersion" = $latestVersion
                "UpdateAvailable" = $false
                "Success" = $true
                "Error" = $null
            }
            
            if (-not $latestVersion) {
                $result.Success = $false
                $result.Error = "Failed to extract version"
                Send-Email -subject "[$($product.name)] Version extraction failed" -version "unknown" -previous $currentVersion -securePassword $smtpPassword
            }
            elseif (-not $currentVersion) {
                # First time setup - store current version
                Set-StoredVersion $vaultName $product.id $product.keyVaultKey $latestVersion
                Write-Host "[$($product.id)] Initial version stored: $latestVersion"
            }
            elseif ($latestVersion -gt $currentVersion) {
                $result.UpdateAvailable = $true
                Set-StoredVersion $vaultName $product.id $product.keyVaultKey $latestVersion
                Send-Email -subject "[$($product.name)] New Update Available!" -version $latestVersion -previous $currentVersion -securePassword $smtpPassword
                Write-Host "[$($product.id)] Update notification sent: $currentVersion -> $latestVersion"
            }
            else {
                Write-Host "[$($product.id)] No update available (current: $currentVersion)"
            }
            
            $results += $result
        }
        catch {
            Write-Host "[$($product.id)] Error during monitoring: $($_.Exception.Message)"
            $results += @{
                "ProductId" = $product.id
                "ProductName" = $product.name
                "Success" = $false
                "Error" = $_.Exception.Message
            }
        }
    }
    
    Write-Host "Product monitoring completed. Processed $($results.Count) products."
    return $results
}

#endregion

# Main function to be triggered by the Azure Function
function RunFunction {
    param($Timer)
    
    Connect-AzAccount -Identity

    # Retrieve the secure password from Azure Key Vault
    $vaultName = "huntertechvault"
    $secretName = "smtp2go-secure"
    $securePassword = ConvertTo-SecureString(Get-AzKeyVaultSecret -VaultName $vaultName -Name $secretName -AsPlainText) -AsPlainText -Force
    
    # Run new monitoring system
    $results = Invoke-ProductMonitoring $vaultName $securePassword
    
    # Legacy support - keep existing Bluebeam and Autodesk logic for now
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
            "year" = "2026"
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
        },
        @{
            "product" = "RVTLT"
            "year" = "2026"
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
