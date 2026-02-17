# Test script to verify product configurations work correctly
# This script tests the extraction strategies for each product

# Load the configuration
$config = Get-Content -Path ".\products-config.json" -Raw | ConvertFrom-Json

# Test function for custom strategy
function Test-CustomStrategy {
    param(
        [string]$url,
        [string]$scriptText
    )
    
    try {
        $scriptBlock = [scriptblock]::Create($scriptText)
        $result = & $scriptBlock $url
        return $result
    }
    catch {
        return "ERROR: $($_.Exception.Message)"
    }
}

# Test function for regex strategy
function Test-RegexStrategy {
    param(
        [string]$url,
        [string]$pattern,
        [int]$versionGroup = 1
    )
    
    try {
        $webClient = New-Object System.Net.WebClient
        $webClient.Headers.Add("User-Agent", "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36")
        
        $htmlContent = $webClient.DownloadString($url)
        $matches = [regex]::Matches($htmlContent, $pattern, [System.Text.RegularExpressions.RegexOptions]::IgnoreCase)
        
        if ($matches.Count -gt 0 -and $matches[0].Groups.Count -gt $versionGroup) {
            return $matches[0].Groups[$versionGroup].Value.Trim()
        }
        
        return "No match found"
    }
    catch {
        return "ERROR: $($_.Exception.Message)"
    }
    finally {
        if ($webClient) { $webClient.Dispose() }
    }
}

# Test each product
Write-Host "Testing product configurations...`n"

foreach ($product in $config.products) {
    Write-Host "Testing: $($product.name)"
    Write-Host "URL: $($product.url)"
    
    $version = $null
    
    switch ($product.strategy) {
        "custom" {
            $version = Test-CustomStrategy -url $product.url -scriptText $product.script
        }
        "regex" {
            $versionGroup = if ($product.versionGroup) { $product.versionGroup } else { 1 }
            $version = Test-RegexStrategy -url $product.url -pattern $product.pattern -versionGroup $versionGroup
        }
    }
    
    if ($version -and $version -notlike "ERROR:*") {
        Write-Host "✓ SUCCESS: Version extracted = $version" -ForegroundColor Green
    }
    else {
        Write-Host "✗ FAILED: $version" -ForegroundColor Red
    }
    
    Write-Host ("-" * 60)
    Write-Host ""
}