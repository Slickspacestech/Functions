# Test PyroSim detection only
Write-Host "Testing PyroSim version detection..." -ForegroundColor Cyan
Write-Host ""

# Load configuration
$config = Get-Content -Path ".\products-config.json" -Raw | ConvertFrom-Json
$pyrosimProducts = $config.products | Where-Object { $_.id -like '*pyrosim*' }

if ($pyrosimProducts.Count -eq 0) {
    Write-Host "PyroSim configurations not found!" -ForegroundColor Red
    exit 1
}

Write-Host "Found $($pyrosimProducts.Count) PyroSim configurations to test:" -ForegroundColor Green
Write-Host ""

$results = @()

foreach ($product in $pyrosimProducts) {
    Write-Host "Testing: $($product.name)" -ForegroundColor Yellow
    Write-Host "  Product ID: $($product.id)"
    Write-Host "  URL: $($product.url)"
    Write-Host "  Strategy: $($product.strategy)"
    Write-Host "  Pattern: $($product.pattern)"
    Write-Host "  Key Vault Key: $($product.keyVaultKey)"
    Write-Host ""

    Write-Host "  Fetching content from website..." -ForegroundColor Cyan

    try {
        $htmlContent = Invoke-RestMethod -Uri $product.url -Method Get -UseBasicParsing
        Write-Host "  [OK] Content fetched successfully (Length: $($htmlContent.Length) chars)" -ForegroundColor Green

        Write-Host "  Applying regex pattern..." -ForegroundColor Cyan

        if ($htmlContent -match $product.pattern) {
            $extractedVersion = $matches[$product.versionGroup].Trim()
            Write-Host "  [SUCCESS] Version extracted: $extractedVersion" -ForegroundColor Green

            $results += [PSCustomObject]@{
                ProductName = $product.name
                ProductId = $product.id
                Success = $true
                Version = $extractedVersion
                KeyVaultKey = $product.keyVaultKey
                Error = $null
            }
        } else {
            Write-Host "  [FAIL] Pattern did not match any content!" -ForegroundColor Red

            # Try to show some context
            Write-Host "  Attempting to find similar patterns..." -ForegroundColor Yellow
            $searchPattern = "PyroSim\s+\d{4}"
            if ($htmlContent -match $searchPattern) {
                Write-Host "    Found text: $($matches[0])" -ForegroundColor Gray
            }

            $results += [PSCustomObject]@{
                ProductName = $product.name
                ProductId = $product.id
                Success = $false
                Version = $null
                KeyVaultKey = $product.keyVaultKey
                Error = "Pattern did not match"
            }
        }
    } catch {
        Write-Host "  [ERROR] $($_.Exception.Message)" -ForegroundColor Red

        $results += [PSCustomObject]@{
            ProductName = $product.name
            ProductId = $product.id
            Success = $false
            Version = $null
            KeyVaultKey = $product.keyVaultKey
            Error = $_.Exception.Message
        }
    }

    Write-Host ""
}

# Summary
Write-Host "============================================" -ForegroundColor Cyan
Write-Host "  TEST RESULTS SUMMARY" -ForegroundColor White
Write-Host "============================================" -ForegroundColor Cyan
Write-Host ""

$successCount = ($results | Where-Object { $_.Success }).Count
$totalCount = $results.Count

Write-Host "Successful extractions: $successCount/$totalCount" -ForegroundColor $(if ($successCount -eq $totalCount) { "Green" } else { "Yellow" })
Write-Host ""

foreach ($result in $results) {
    $status = if ($result.Success) { "[OK]" } else { "[FAIL]" }
    $color = if ($result.Success) { "Green" } else { "Red" }

    Write-Host "$status $($result.ProductName)" -ForegroundColor $color
    if ($result.Success) {
        Write-Host "    Version: $($result.Version)" -ForegroundColor Gray
        Write-Host "    Key Vault Key: $($result.KeyVaultKey)" -ForegroundColor Gray
    } else {
        Write-Host "    Error: $($result.Error)" -ForegroundColor Red
    }
    Write-Host ""
}

if ($successCount -eq $totalCount) {
    Write-Host "All PyroSim configurations are working correctly!" -ForegroundColor Green
} else {
    Write-Host "Some configurations need adjustment. Review the errors above." -ForegroundColor Yellow
}

Write-Host "============================================" -ForegroundColor Cyan
