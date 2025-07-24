# Product Detection Helper for Claude Code
# This helper function analyzes URLs and suggests optimal strategies for version extraction

function Analyze-ProductUrl {
    param(
        [string]$ProductName,
        [string]$Url,
        [string]$SampleContent = ""
    )
    
    Write-Host "Analyzing $ProductName at $Url..."
    
    $suggestions = @()
    $config = @{
        "id" = ($ProductName -replace '[^a-zA-Z0-9]', '-').ToLower()
        "name" = $ProductName
        "url" = $Url
        "keyVaultKey" = ($ProductName -replace '[^a-zA-Z0-9]', '') + "Version"
        "enabled" = $true
    }
    
    # Check if it's a GitHub repository
    if ($Url -match 'github\.com/([^/]+)/([^/]+)') {
        $owner = $matches[1]
        $repo = $matches[2]
        $apiUrl = "https://api.github.com/repos/$owner/$repo/releases/latest"
        
        $suggestions += @{
            "strategy" = "json-api"
            "confidence" = "high"
            "reason" = "GitHub repository detected - use releases API"
            "config" = $config + @{
                "strategy" = "json-api"
                "url" = $apiUrl
                "jsonPath" = "tag_name"
            }
        }
    }
    
    # Try to fetch content if not provided
    if (-not $SampleContent -and $Url) {
        try {
            $webClient = New-Object System.Net.WebClient
            $webClient.Headers.Add("User-Agent", "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36")
            $SampleContent = $webClient.DownloadString($Url)
        }
        catch {
            Write-Host "Could not fetch content from URL: $($_.Exception.Message)"
        }
        finally {
            if ($webClient) { $webClient.Dispose() }
        }
    }
    
    if ($SampleContent) {
        # Check for common version patterns
        $versionPatterns = @(
            @{
                pattern = 'Version\s+(\d+\.\d+(?:\.\d+)?)'
                description = "Version X.Y.Z pattern"
            },
            @{
                pattern = 'v(\d+\.\d+(?:\.\d+)?)'
                description = "vX.Y.Z pattern"
            },
            @{
                pattern = '(\d+\.\d+(?:\.\d+)?)\s+(?:Release|Update)'
                description = "X.Y.Z Release/Update pattern"
            },
            @{
                pattern = 'Current[^:]*:\s*(\d+\.\d+(?:\.\d+)?)'
                description = "Current version pattern"
            },
            @{
                pattern = 'Latest[^:]*:\s*(\d+\.\d+(?:\.\d+)?)'
                description = "Latest version pattern"
            }
        )
        
        foreach ($vp in $versionPatterns) {
            if ($SampleContent -match $vp.pattern) {
                $extractedVersion = $matches[1]
                $suggestions += @{
                    "strategy" = "regex"
                    "confidence" = "medium"
                    "reason" = "Found version using $($vp.description): $extractedVersion"
                    "config" = $config + @{
                        "strategy" = "regex"
                        "pattern" = $vp.pattern
                        "versionGroup" = 1
                    }
                }
            }
        }
        
        # Check for JSON content
        try {
            $json = $SampleContent | ConvertFrom-Json
            if ($json.version -or $json.tag_name -or $json.name) {
                $jsonPath = if ($json.version) { "version" } 
                           elseif ($json.tag_name) { "tag_name" }
                           else { "name" }
                
                $suggestions += @{
                    "strategy" = "json-api"
                    "confidence" = "high"
                    "reason" = "JSON response detected with version field: $jsonPath"
                    "config" = $config + @{
                        "strategy" = "json-api"
                        "jsonPath" = $jsonPath
                    }
                }
            }
        }
        catch {
            # Not JSON, continue with other strategies
        }
        
        # Check for common release note structures
        if ($SampleContent -match '<h[1-6][^>]*>.*?(\d+\.\d+(?:\.\d+)?).*?</h[1-6]>') {
            $suggestions += @{
                "strategy" = "regex"
                "confidence" = "medium"
                "reason" = "Version found in heading tags"
                "config" = $config + @{
                    "strategy" = "regex"
                    "pattern" = '<h[1-6][^>]*>.*?(\d+\.\d+(?:\.\d+)?).*?</h[1-6]>'
                    "versionGroup" = 1
                }
            }
        }
    }
    
    # Default suggestion if no patterns found
    if ($suggestions.Count -eq 0) {
        $suggestions += @{
            "strategy" = "custom"
            "confidence" = "low"
            "reason" = "No automatic pattern detected - custom strategy recommended"
            "config" = $config + @{
                "strategy" = "custom"
                "script" = "param(`$url); # TODO: Implement custom version extraction logic"
            }
        }
    }
    
    # Sort by confidence and return
    $sortedSuggestions = $suggestions | Sort-Object -Property @{Expression={
        switch ($_.confidence) {
            "high" { 3 }
            "medium" { 2 }
            "low" { 1 }
            default { 0 }
        }
    }} -Descending
    
    return @{
        "ProductName" = $ProductName
        "Url" = $Url
        "Suggestions" = $sortedSuggestions
        "RecommendedConfig" = $sortedSuggestions[0].config
    }
}

function Test-ProductConfiguration {
    param([hashtable]$productConfig)
    
    Write-Host "Testing configuration for $($productConfig.name)..."
    
    try {
        $monitor = [ProductMonitor]::new($productConfig)
        $version = $monitor.GetLatestVersion()
        
        if ($version) {
            Write-Host "✓ Successfully extracted version: $version" -ForegroundColor Green
            return @{
                "Success" = $true
                "Version" = $version
                "Error" = $null
            }
        }
        else {
            Write-Host "✗ Version extraction returned null" -ForegroundColor Red
            return @{
                "Success" = $false
                "Version" = $null
                "Error" = "Version extraction returned null"
            }
        }
    }
    catch {
        Write-Host "✗ Error testing configuration: $($_.Exception.Message)" -ForegroundColor Red
        return @{
            "Success" = $false
            "Version" = $null
            "Error" = $_.Exception.Message
        }
    }
}

# Example usage function
function Add-ProductToConfiguration {
    param(
        [string]$ProductName,
        [string]$Url,
        [string]$VaultName = "huntertechvault",
        [switch]$TestFirst
    )
    
    # Analyze the product URL
    $analysis = Analyze-ProductUrl -ProductName $ProductName -Url $Url
    
    Write-Host "Analysis Results for $ProductName:" -ForegroundColor Cyan
    Write-Host "Recommended Strategy: $($analysis.RecommendedConfig.strategy)" -ForegroundColor Yellow
    
    foreach ($suggestion in $analysis.Suggestions) {
        Write-Host "- $($suggestion.strategy) ($($suggestion.confidence) confidence): $($suggestion.reason)"
    }
    
    $recommendedConfig = $analysis.RecommendedConfig
    
    # Test configuration if requested
    if ($TestFirst) {
        $testResult = Test-ProductConfiguration $recommendedConfig
        if (-not $testResult.Success) {
            Write-Host "Configuration test failed: $($testResult.Error)" -ForegroundColor Red
            return $null
        }
    }
    
    # Load existing configuration and add new product
    try {
        $existingProducts = Get-ProductConfiguration $VaultName
        $existingProducts += $recommendedConfig
        
        if (Set-ProductConfiguration $VaultName $existingProducts) {
            Write-Host "✓ Successfully added $ProductName to product configuration" -ForegroundColor Green
            return $recommendedConfig
        }
        else {
            Write-Host "✗ Failed to save updated configuration" -ForegroundColor Red
            return $null
        }
    }
    catch {
        Write-Host "✗ Error updating configuration: $($_.Exception.Message)" -ForegroundColor Red
        return $null
    }
}