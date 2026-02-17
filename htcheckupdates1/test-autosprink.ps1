# Test script for AutoSPRINK product version extraction
Write-Host "Testing AutoSPRINK Version Extraction" -ForegroundColor Cyan
Write-Host "======================================" -ForegroundColor Gray
Write-Host ""

# Test configuration for AutoSPRINK
$config = @{
    Name = "AutoSPRINK"
    Url = "https://api-v2.mepcad.com/api/news-autosprink/news/releases?pageType=released&sectionTitle=2025"
    Strategy = "JSON API"
    KeyVaultKey = "AutoSPRINKVersion"
}

Write-Host "Testing: $($config.Name)" -ForegroundColor Yellow
Write-Host "  URL: $($config.Url)" -ForegroundColor Gray
Write-Host "  Strategy: $($config.Strategy)" -ForegroundColor Gray
Write-Host ""

try {
    Write-Host "  Fetching JSON API..." -ForegroundColor Cyan
    $json = Invoke-RestMethod -Uri $config.Url -Method Get -UseBasicParsing

    if ($json.currentSection.releases -and $json.currentSection.releases.Count -gt 0) {
        $version = $json.currentSection.releases[0].version
        $releaseDate = $json.currentSection.releases[0].date
        $releaseTitle = $json.currentSection.releases[0].title

        Write-Host "  SUCCESS: Version extracted: $version" -ForegroundColor Green
        Write-Host ""
        Write-Host "Test Result Summary" -ForegroundColor Cyan
        Write-Host "===================" -ForegroundColor Gray
        Write-Host "Product: $($config.Name)" -ForegroundColor White
        Write-Host "Version: $version" -ForegroundColor Green
        Write-Host "Release: $releaseTitle" -ForegroundColor Gray
        Write-Host "Date: $releaseDate" -ForegroundColor Gray
        Write-Host "Key Vault Key: $($config.KeyVaultKey)" -ForegroundColor Gray
        Write-Host ""
        Write-Host "Configuration is working correctly!" -ForegroundColor Green
        Write-Host "You can now run: .\upload-config-with-tenant.ps1" -ForegroundColor Cyan
    } else {
        Write-Host "  FAILED: No releases found in JSON response" -ForegroundColor Red
        Write-Host ""
        Write-Host "Debugging Information:" -ForegroundColor Yellow
        Write-Host "=====================" -ForegroundColor Gray
        Write-Host "JSON structure:" -ForegroundColor Gray
        Write-Host ($json | ConvertTo-Json -Depth 2) -ForegroundColor DarkGray
    }
} catch {
    Write-Host "  ERROR: $($_.Exception.Message)" -ForegroundColor Red
    Write-Host ""
    Write-Host "Failed to fetch or parse the JSON API." -ForegroundColor Red
    Write-Host "Error details: $($_.Exception.Message)" -ForegroundColor DarkRed
}
