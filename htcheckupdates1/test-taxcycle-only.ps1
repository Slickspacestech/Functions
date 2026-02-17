# Test TaxCycle detection only
Write-Host "Testing TaxCycle version detection..." -ForegroundColor Cyan
Write-Host ""

# Load configuration
$config = Get-Content -Path ".\products-config.json" -Raw | ConvertFrom-Json
$taxcycle = $config.products | Where-Object { $_.id -eq 'taxcycle' }

if (-not $taxcycle) {
    Write-Host "TaxCycle configuration not found!" -ForegroundColor Red
    exit 1
}

Write-Host "Configuration Details:" -ForegroundColor Yellow
Write-Host "  Product ID: $($taxcycle.id)"
Write-Host "  Product Name: $($taxcycle.name)"
Write-Host "  URL: $($taxcycle.url)"
Write-Host "  Strategy: $($taxcycle.strategy)"
Write-Host "  Pattern: $($taxcycle.pattern)"
Write-Host "  Key Vault Key: $($taxcycle.keyVaultKey)"
Write-Host ""

Write-Host "Fetching content from website..." -ForegroundColor Yellow

try {
    $webClient = New-Object System.Net.WebClient
    $webClient.Headers.Add("User-Agent", "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36")

    $htmlContent = $webClient.DownloadString($taxcycle.url)
    Write-Host "✓ Content fetched successfully (Length: $($htmlContent.Length) chars)" -ForegroundColor Green
    Write-Host ""

    Write-Host "Applying regex pattern..." -ForegroundColor Yellow
    $matches = [regex]::Matches($htmlContent, $taxcycle.pattern, [System.Text.RegularExpressions.RegexOptions]::IgnoreCase)

    if ($matches.Count -gt 0) {
        $extractedVersion = $matches[0].Groups[1].Value.Trim()
        Write-Host "✓ Version extracted successfully!" -ForegroundColor Green
        Write-Host ""
        Write-Host "============================================" -ForegroundColor Cyan
        Write-Host "  DETECTED VERSION: $extractedVersion" -ForegroundColor White
        Write-Host "============================================" -ForegroundColor Cyan
        Write-Host ""

        # Show what was matched
        Write-Host "Full match: $($matches[0].Value)" -ForegroundColor Gray

        # Search for all version patterns to see if there are multiple
        Write-Host ""
        Write-Host "All version matches found on the page:" -ForegroundColor Yellow
        $allMatches = [regex]::Matches($htmlContent, $taxcycle.pattern, [System.Text.RegularExpressions.RegexOptions]::IgnoreCase)
        for ($i = 0; $i -lt [Math]::Min($allMatches.Count, 5); $i++) {
            Write-Host "  Match $($i+1): $($allMatches[$i].Groups[1].Value)" -ForegroundColor Gray
        }
        if ($allMatches.Count -gt 5) {
            Write-Host "  ... and $($allMatches.Count - 5) more matches" -ForegroundColor Gray
        }
    }
    else {
        Write-Host "✗ No version match found!" -ForegroundColor Red
        Write-Host ""
        Write-Host "Searching for any text containing 'TaxCycle Version'..." -ForegroundColor Yellow
        $simpleMatches = [regex]::Matches($htmlContent, "TaxCycle Version[^<]{0,50}", [System.Text.RegularExpressions.RegexOptions]::IgnoreCase)
        if ($simpleMatches.Count -gt 0) {
            Write-Host "Found these snippets:" -ForegroundColor Gray
            foreach ($match in $simpleMatches | Select-Object -First 3) {
                Write-Host "  - $($match.Value)" -ForegroundColor Gray
            }
        }
    }
}
catch {
    Write-Host "✗ Error: $($_.Exception.Message)" -ForegroundColor Red
}
finally {
    if ($webClient) {
        $webClient.Dispose()
    }
}

Write-Host ""
Write-Host "Note: The Azure Function would compare this with the version stored in Key Vault" -ForegroundColor DarkGray
Write-Host "Key Vault Key: $($taxcycle.keyVaultKey)" -ForegroundColor DarkGray
Write-Host "If you're seeing 14.2.57585.0 in notifications, that's the OLD version stored in Key Vault" -ForegroundColor DarkGray