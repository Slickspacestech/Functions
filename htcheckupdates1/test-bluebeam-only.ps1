# Test Bluebeam detection only
Write-Host "Testing Bluebeam version detection..." -ForegroundColor Cyan
Write-Host ""

# Load configuration
$config = Get-Content -Path ".\products-config.json" -Raw | ConvertFrom-Json
$bluebeam = $config.products | Where-Object { $_.id -eq 'bluebeam-revu' }

if (-not $bluebeam) {
    Write-Host "Bluebeam configuration not found!" -ForegroundColor Red
    exit 1
}

Write-Host "Configuration Details:" -ForegroundColor Yellow
Write-Host "  Product ID: $($bluebeam.id)"
Write-Host "  Product Name: $($bluebeam.name)"
Write-Host "  URL: $($bluebeam.url)"
Write-Host "  Strategy: $($bluebeam.strategy)"
Write-Host "  Pattern: $($bluebeam.pattern)"
Write-Host "  Key Vault Key: $($bluebeam.keyVaultKey)"
Write-Host ""

Write-Host "Fetching content from website..." -ForegroundColor Yellow

try {
    $webClient = New-Object System.Net.WebClient
    $webClient.Headers.Add("User-Agent", "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36")

    $htmlContent = $webClient.DownloadString($bluebeam.url)
    Write-Host "[OK] Content fetched successfully (Length: $($htmlContent.Length) chars)" -ForegroundColor Green
    Write-Host ""

    Write-Host "Applying current regex pattern..." -ForegroundColor Yellow
    $matches = [regex]::Matches($htmlContent, $bluebeam.pattern, [System.Text.RegularExpressions.RegexOptions]::IgnoreCase)

    if ($matches.Count -gt 0) {
        $extractedVersion = $matches[0].Groups[1].Value.Trim()
        Write-Host "[SUCCESS] Current pattern found version: $extractedVersion" -ForegroundColor Green
        Write-Host "Full match: $($matches[0].Value)" -ForegroundColor Gray
    } else {
        Write-Host "[FAIL] Current pattern found no matches!" -ForegroundColor Red
    }

    Write-Host ""
    Write-Host "Testing alternative patterns..." -ForegroundColor Yellow

    # Try pattern for single or double digit version
    $altPattern1 = "Revu\s+(\d{1,2}\.\d{1,2}(?:\.\d+)?)"
    Write-Host "Pattern 1: $altPattern1" -ForegroundColor Gray
    $altMatches1 = [regex]::Matches($htmlContent, $altPattern1, [System.Text.RegularExpressions.RegexOptions]::IgnoreCase)
    if ($altMatches1.Count -gt 0) {
        Write-Host "  Found versions:" -ForegroundColor Green
        for ($i = 0; $i -lt [Math]::Min($altMatches1.Count, 5); $i++) {
            Write-Host "    - $($altMatches1[$i].Groups[1].Value)" -ForegroundColor Gray
        }
    }

    Write-Host ""
    # Look for any text containing "Revu" followed by version-like numbers
    $searchPattern = "Revu\s+\d{1,2}\.\d{1,2}[^<]{0,50}"
    Write-Host "Searching for text matching: $searchPattern" -ForegroundColor Gray
    $searchMatches = [regex]::Matches($htmlContent, $searchPattern, [System.Text.RegularExpressions.RegexOptions]::IgnoreCase)
    if ($searchMatches.Count -gt 0) {
        Write-Host "  Found these snippets:" -ForegroundColor Green
        for ($i = 0; $i -lt [Math]::Min($searchMatches.Count, 5); $i++) {
            Write-Host "    - $($searchMatches[$i].Value)" -ForegroundColor Gray
        }
    }

    Write-Host ""
    # Check specifically for version 21.x patterns
    $v21Pattern = "Revu\s+21\.\d+(?:\.\d+)?"
    Write-Host "Looking specifically for v21.x: $v21Pattern" -ForegroundColor Gray
    $v21Matches = [regex]::Matches($htmlContent, $v21Pattern, [System.Text.RegularExpressions.RegexOptions]::IgnoreCase)
    if ($v21Matches.Count -gt 0) {
        Write-Host "  Found v21 versions:" -ForegroundColor Green
        foreach ($match in $v21Matches | Select-Object -Unique -First 3) {
            Write-Host "    - $($match.Value)" -ForegroundColor Yellow
        }
    }

    Write-Host ""
    Write-Host "============================================" -ForegroundColor Cyan
    Write-Host "  TEST RESULTS SUMMARY" -ForegroundColor White
    if ($matches.Count -gt 0) {
        Write-Host "  [OK] Configuration is working correctly!" -ForegroundColor Green
        Write-Host "  Latest version detected: $extractedVersion" -ForegroundColor Yellow
    } else {
        Write-Host "  [FAIL] Current configuration needs adjustment" -ForegroundColor Red
    }
    Write-Host "============================================" -ForegroundColor Cyan
} catch {
    Write-Host "[ERROR] $($_.Exception.Message)" -ForegroundColor Red
} finally {
    if ($webClient) {
        $webClient.Dispose()
    }
}
