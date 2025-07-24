# Load the functions
. .\run.ps1
. .\ProductDetectionHelper.ps1

# Analyze TaxCycle URL
$analysis = Analyze-ProductUrl -ProductName "TaxCycle" -Url "https://www.taxcycle.com/support/download/"

# Display analysis results
Write-Host "Analysis Results:" -ForegroundColor Cyan
Write-Host "Recommended Strategy:" $analysis.RecommendedConfig.strategy -ForegroundColor Yellow

foreach ($suggestion in $analysis.Suggestions) {
    Write-Host "- $($suggestion.strategy) ($($suggestion.confidence) confidence): $($suggestion.reason)"
}

# Show recommended configuration
Write-Host ""
Write-Host "Recommended Configuration:" -ForegroundColor Green
$analysis.RecommendedConfig | ConvertTo-Json -Depth 5