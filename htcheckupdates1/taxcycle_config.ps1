# Add TaxCycle to monitoring configuration
# Based on analysis: Version appears as "TaxCycle Version 14.2.56967.0"

# TaxCycle configuration
$taxcycleConfig = @{
    "id" = "taxcycle"
    "name" = "TaxCycle"
    "url" = "https://www.taxcycle.com/support/download/"
    "strategy" = "regex"
    "pattern" = 'TaxCycle Version\s+(\d+\.\d+\.\d+(?:\.\d+)?)'
    "versionGroup" = 1
    "keyVaultKey" = "TaxCycleVersion"
    "enabled" = $true
}

Write-Host "TaxCycle Configuration:" -ForegroundColor Green
$taxcycleConfig | ConvertTo-Json -Depth 5

# Test the regex pattern with sample content
$sampleContent = "TaxCycle Version 14.2.56967.0 (dated 2025-07-02)"
if ($sampleContent -match $taxcycleConfig.pattern) {
    Write-Host ""
    Write-Host "Pattern test successful!" -ForegroundColor Green
    Write-Host "Extracted version: $($matches[1])" -ForegroundColor Yellow
} else {
    Write-Host ""
    Write-Host "Pattern test failed" -ForegroundColor Red
}

Write-Host ""
Write-Host "Configuration Analysis:" -ForegroundColor Cyan
Write-Host "- Strategy: regex (HIGH confidence)" 
Write-Host "- Reason: Clear version pattern found"
Write-Host "- Pattern matches version format: Major.Minor.Build.Revision"
Write-Host "- Key Vault Key: TaxCycleVersion"