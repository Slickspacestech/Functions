# Simple test script for Thunderhead Engineering products
Write-Host "Testing Thunderhead Engineering Product Version Extraction" -ForegroundColor Cyan
Write-Host "==========================================================" -ForegroundColor Gray
Write-Host ""

# Test configurations for Thunderhead products
$testConfigs = @(
    @{
        Name = "Pathfinder Major Version"
        Url = "https://support.thunderheadeng.com/release-notes/pathfinder"
        Pattern = "Release Notes for versions of Pathfinder (\d{4})"
        KeyVaultKey = "PathfinderMajor"
    },
    @{
        Name = "Pathfinder 2024 Patches"  
        Url = "https://support.thunderheadeng.com/release-notes/pathfinder/2024/"
        Pattern = "(2024\.(\d+))"
        KeyVaultKey = "Pathfinder2024"
    },
    @{
        Name = "Pathfinder 2025 Patches"
        Url = "https://support.thunderheadeng.com/release-notes/pathfinder/2025/"
        Pattern = "(2025\.(\d+))"
        KeyVaultKey = "Pathfinder2025"
    },
    @{
        Name = "PyroSim Major Version"
        Url = "https://support.thunderheadeng.com/release-notes/pyrosim"
        Pattern = "Release Notes for versions of PyroSim (\d{4})"
        KeyVaultKey = "PyroSimMajor"
    },
    @{
        Name = "PyroSim 2024 Patches"
        Url = "https://support.thunderheadeng.com/release-notes/pyrosim/2024/"
        Pattern = "(2024\.(\d+))"
        KeyVaultKey = "PyroSim2024"
    },
    @{
        Name = "PyroSim 2025 Patches"
        Url = "https://support.thunderheadeng.com/release-notes/pyrosim/2025/"
        Pattern = "(2025\.(\d+))"
        KeyVaultKey = "PyroSim2025"
    }
)

$results = @()

foreach ($config in $testConfigs) {
    Write-Host "Testing: $($config.Name)" -ForegroundColor Yellow
    Write-Host "  URL: $($config.Url)" -ForegroundColor Gray
    Write-Host "  Pattern: $($config.Pattern)" -ForegroundColor Gray
    
    try {
        Write-Host "  Fetching webpage..." -ForegroundColor Cyan
        $response = Invoke-RestMethod -Uri $config.Url -Method Get -UseBasicParsing
        
        if ($response -match $config.Pattern) {
            $version = $matches[1]
            Write-Host "  SUCCESS: Version extracted: $version" -ForegroundColor Green
            $results += [PSCustomObject]@{
                Product = $config.Name
                Success = $true
                Version = $version
                KeyVaultKey = $config.KeyVaultKey
                Error = $null
            }
        } else {
            Write-Host "  FAILED: No version found matching pattern" -ForegroundColor Red
            $results += [PSCustomObject]@{
                Product = $config.Name
                Success = $false
                Version = $null
                KeyVaultKey = $config.KeyVaultKey
                Error = "Pattern did not match"
            }
        }
    } catch {
        Write-Host "  ERROR: $($_.Exception.Message)" -ForegroundColor Red
        $results += [PSCustomObject]@{
            Product = $config.Name
            Success = $false
            Version = $null
            KeyVaultKey = $config.KeyVaultKey
            Error = $_.Exception.Message
        }
    }
    Write-Host ""
}

# Summary
Write-Host "Test Results Summary" -ForegroundColor Cyan
Write-Host "====================" -ForegroundColor Gray
Write-Host ""

$successCount = ($results | Where-Object { $_.Success }).Count
$totalCount = $results.Count

Write-Host "Successful extractions: $successCount/$totalCount" -ForegroundColor $(if ($successCount -eq $totalCount) { "Green" } else { "Yellow" })
Write-Host ""

# Detailed results
foreach ($result in $results) {
    $status = if ($result.Success) { "SUCCESS" } else { "FAILED" }
    Write-Host "$status $($result.Product)" -ForegroundColor $(if ($result.Success) { "Green" } else { "Red" })
    if ($result.Success) {
        Write-Host "    Version: $($result.Version)" -ForegroundColor Gray
        Write-Host "    Key Vault Key: $($result.KeyVaultKey)" -ForegroundColor Gray
    } else {
        Write-Host "    Error: $($result.Error)" -ForegroundColor Red
    }
    Write-Host ""
}

if ($successCount -eq $totalCount) {
    Write-Host "All configurations are working correctly!" -ForegroundColor Green
    Write-Host "You can now run: .\upload-config-with-tenant.ps1" -ForegroundColor Cyan
} else {
    Write-Host "Some configurations need adjustment." -ForegroundColor Yellow
}