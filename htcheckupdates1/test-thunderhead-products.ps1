# Test script for Thunderhead Engineering products (Pathfinder and PyroSim)
# This script tests the version extraction logic for the new product configurations

Write-Host "Testing Thunderhead Engineering Product Configurations" -ForegroundColor Cyan
Write-Host "=" * 55 -ForegroundColor Gray
Write-Host ""

# Load the product configuration
$configPath = ".\products-config.json"
if (-not (Test-Path $configPath)) {
    Write-Host "Error: Configuration file not found: $configPath" -ForegroundColor Red
    exit 1
}

$config = Get-Content $configPath -Raw | ConvertFrom-Json

# Filter for Thunderhead products (Pathfinder and PyroSim)
$thunderheadProducts = $config.products | Where-Object { $_.id -like "*pathfinder*" -or $_.id -like "*pyrosim*" }

if ($thunderheadProducts.Count -eq 0) {
    Write-Host "Error: No Thunderhead products found in configuration" -ForegroundColor Red
    exit 1
}

Write-Host "Found $($thunderheadProducts.Count) Thunderhead products to test:" -ForegroundColor Green
foreach ($product in $thunderheadProducts) {
    Write-Host "  - $($product.name) (ID: $($product.id))" -ForegroundColor Gray
}
Write-Host ""

# Function to test version extraction using regex strategy
function Test-RegexExtraction {
    param(
        [string]$Url,
        [string]$Pattern,
        [int]$VersionGroup,
        [string]$ProductName
    )
    
    Write-Host "Testing: $ProductName" -ForegroundColor Yellow
    Write-Host "  URL: $Url" -ForegroundColor Gray
    Write-Host "  Pattern: $Pattern" -ForegroundColor Gray
    
    try {
        # Fetch the webpage content
        Write-Host "  Fetching webpage..." -ForegroundColor Cyan
        $response = Invoke-RestMethod -Uri $Url -Method Get -UseBasicParsing
        
        # Apply the regex pattern
        if ($response -match $Pattern) {
            $extractedVersion = $matches[$VersionGroup]
            Write-Host "  Success: Version extracted: $extractedVersion" -ForegroundColor Green
            return @{
                Success = $true
                Version = $extractedVersion
                Error = $null
            }
        } else {
            Write-Host "  Failed: No version found matching pattern" -ForegroundColor Red
            return @{
                Success = $false
                Version = $null
                Error = "Pattern did not match any content"
            }
        }
    } catch {
        Write-Host "  Error: $($_.Exception.Message)" -ForegroundColor Red
        return @{
            Success = $false
            Version = $null
            Error = $_.Exception.Message
        }
    }
}

# Test each Thunderhead product
$results = @()
foreach ($product in $thunderheadProducts) {
    if ($product.strategy -eq "regex") {
        $result = Test-RegexExtraction -Url $product.url -Pattern $product.pattern -VersionGroup $product.versionGroup -ProductName $product.name
        $results += [PSCustomObject]@{
            ProductId = $product.id
            ProductName = $product.name
            Success = $result.Success
            Version = $result.Version
            Error = $result.Error
            KeyVaultKey = $product.keyVaultKey
        }
    } else {
        Write-Host "Skipping $($product.name) - Strategy '$($product.strategy)' not implemented in test" -ForegroundColor Yellow
        $results += [PSCustomObject]@{
            ProductId = $product.id
            ProductName = $product.name
            Success = $false
            Version = $null
            Error = "Strategy not implemented in test"
            KeyVaultKey = $product.keyVaultKey
        }
    }
    Write-Host ""
}

# Summary
Write-Host "Test Results Summary" -ForegroundColor Cyan
Write-Host "===================" -ForegroundColor Gray
Write-Host ""

$successCount = ($results | Where-Object { $_.Success }).Count
$totalCount = $results.Count

Write-Host "Successful extractions: $successCount/$totalCount" -ForegroundColor $(if ($successCount -eq $totalCount) { "Green" } else { "Yellow" })
Write-Host ""

# Detailed results
foreach ($result in $results) {
    $status = if ($result.Success) { "SUCCESS" } else { "FAILED" }
    Write-Host "$status $($result.ProductName)" -ForegroundColor $(if ($result.Success) { "Green" } else { "Red" })
    if ($result.Success) {
        Write-Host "    Version: $($result.Version)" -ForegroundColor Gray
        Write-Host "    Key Vault Key: $($result.KeyVaultKey)" -ForegroundColor Gray
    } else {
        Write-Host "    Error: $($result.Error)" -ForegroundColor Red
    }
    Write-Host ""
}

# Recommendations
if ($successCount -lt $totalCount) {
    Write-Host "Recommendations:" -ForegroundColor Yellow
    $failedResults = $results | Where-Object { -not $_.Success }
    foreach ($failed in $failedResults) {
        Write-Host "  - Review regex pattern for $($failed.ProductName)" -ForegroundColor Gray
        $pattern = ($thunderheadProducts | Where-Object { $_.id -eq $failed.ProductId }).pattern
        Write-Host "    Current pattern: $pattern" -ForegroundColor Gray
    }
} else {
    Write-Host "All configurations are working correctly!" -ForegroundColor Green
    Write-Host "You can now run: .\upload-config-with-tenant.ps1" -ForegroundColor Cyan
}