# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

This is an Azure Functions project written in PowerShell that monitors software updates for Bluebeam and Autodesk products. The function runs on a scheduled timer trigger and sends email notifications when new updates are detected.

## Project Structure

- `function.json` - Azure Function binding configuration with timer trigger schedule
- `run.ps1` - Main PowerShell script containing all function logic
- `readme.md` - Basic Azure Functions timer trigger documentation
- `sample.dat` - Sample data file for the function

## Architecture

The function operates as a single PowerShell Azure Function with these key components:

### Timer Configuration
- Schedule: `"0 17 5-18 * * 1-5"` (5:00 PM UTC, weekdays 5-18th of month)
- Configured in `function.json:7`

### Core Functions
- `Send-Email` - SMTP email sending using smtp2go service
- `getBlueBeamLatest` - Web scrapes Bluebeam release notes to extract latest version
- `getAutodeskLatest` - Fetches Autodesk product update information from help documentation
- `RunFunction` - Main orchestration function

### External Dependencies
- Azure Key Vault (`huntertechvault`) for storing:
  - SMTP credentials (`smtp2go-secure`)
  - Current software versions (e.g., `BBversion`, `ACDLT2024`, `RVT2025`)
- Azure Managed Identity for authentication
- Required PowerShell modules: `Az.Accounts`, `Az.KeyVault`

### Monitored Software Products
- Bluebeam Revu (web scraping from support site)
- Autodesk products across multiple years (2023-2026):
  - AutoCAD LT (`ACDLT`)
  - AutoCAD (`ACD`)
  - Revit (`RVT`)
  - Revit LT (`RVTLT`)

## New Extensible Architecture (v2.0)

The system has been redesigned with a configuration-driven, strategy-pattern architecture that allows adding new products without code changes.

### Configuration System
Products are defined in JSON configuration stored in Key Vault (`config-products`):
```json
{
  "products": [
    {
      "id": "unique-product-id",
      "name": "Display Name",
      "url": "https://product-releases-url.com",
      "strategy": "regex|json-api|html-parse|custom",
      "keyVaultKey": "ProductVersionKey",
      "enabled": true,
      "pattern": "regex-pattern-here",
      "versionGroup": 1
    }
  ]
}
```

### Version Extraction Strategies
- **RegexStrategy**: Pattern-based extraction from HTML
- **JsonApiStrategy**: Extract from JSON API responses (GitHub releases, etc.)
- **HtmlParseStrategy**: Parse HTML between specific markers
- **CustomScriptStrategy**: PowerShell scriptblock for complex logic

### Adding New Products with Claude

You can help generate product configurations by providing:
1. **Product name** (e.g., "Google Chrome")
2. **URL** where version information is published
3. **Sample content** (optional - helps determine best strategy)

Claude will:
1. Analyze the URL and content structure
2. Determine the optimal extraction strategy
3. Generate the JSON configuration
4. Test the configuration if possible
5. Add it to your products.json

**Example workflow:**
```
User: "Add monitoring for Visual Studio Code using https://code.visualstudio.com/updates"
Claude: [analyzes URL] → suggests json-api strategy using GitHub API → generates config → tests extraction
```

**Helper Functions Available:**
- `Analyze-ProductUrl`: Analyzes URLs and suggests optimal strategies
- `Test-ProductConfiguration`: Tests a configuration before adding it
- `Add-ProductToConfiguration`: Complete workflow to add new products

### Strategy Selection Guidelines

**Use `regex` when:**
- Parsing HTML pages with version numbers in text
- Version appears in consistent HTML patterns
- No structured API available

**Use `json-api` when:**
- Product has GitHub releases (use: `https://api.github.com/repos/owner/repo/releases/latest`)
- REST API returns JSON with version info
- Structured data sources available

**Use `html-parse` when:**
- Version is in specific HTML section
- Need to parse between specific markers
- More targeted than regex approach

**Use `custom` when:**
- Complex logic required (multi-step process)
- Need to combine multiple data sources
- Special authentication or processing needed

### Configuration Management Commands

Within the Azure Function context, you can:
```powershell
# Load current configuration
$products = Get-ProductConfiguration "huntertechvault"

# Add new product
$products += @{
    "id" = "new-product"
    "name" = "New Product"
    "url" = "https://example.com"
    "strategy" = "regex"
    "pattern" = "Version (\d+\.\d+\.\d+)"
    "keyVaultKey" = "NewProductVersion"
    "enabled" = $true
}

# Save updated configuration
Set-ProductConfiguration "huntertechvault" $products
```

### Adding Products to Configuration

When adding new products to `products-config.json`:

1. **Add the product configuration** with a unique `keyVaultKey` (e.g., `AutoSPRINK2025`)
2. **The system will automatically create missing Key Vault keys** for new products on the next run
3. **Update the configuration to Key Vault** so it will be read on subsequent runs
4. The function will detect the new version and store it in the Key Vault secret specified by `keyVaultKey`

**Important**: After adding a new product locally in `products-config.json`, you must update the configuration in Key Vault (`config-products` secret) for the changes to take effect in the deployed Azure Function.

## Development Notes

### Azure Function Context
This is a consumption-plan Azure Function, not a traditional application with build/test commands. The function is deployed directly to Azure and executed by the Azure Functions runtime.

### Key Implementation Details
- Uses Azure Managed Identity for Key Vault access (`Connect-AzAccount -Identity`)
- Version comparison logic assumes semantic versioning strings
- Email notifications sent for both successful updates and parsing failures
- Configuration-driven product monitoring with pluggable strategies
- Legacy support maintained for existing Bluebeam and Autodesk monitoring

### Security Considerations
- SMTP credentials stored securely in Azure Key Vault
- No hardcoded secrets in the codebase
- Uses managed identity for Azure resource authentication
- Product configurations stored in Key Vault for security