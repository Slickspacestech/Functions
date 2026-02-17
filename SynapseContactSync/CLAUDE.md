# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

Azure Function that performs daily synchronization of contacts from a SharePoint-hosted Excel file to Exchange Online. The spreadsheet is the source of truth - contacts are created/removed and distribution group membership is managed based on spreadsheet contents.

## Project Structure

- `function.json` - Azure Function binding configuration with timer trigger schedule
- `run.ps1` - Main PowerShell script containing all function logic
- `Setup-AppRegistration.ps1` - Script to create Azure AD App Registration and configure permissions
- `SETUP-GUIDE.md` - Detailed setup instructions
- `CLAUDE.md` - This documentation file

## Architecture

### Timer Configuration
- Schedule: `0 0 6 * * *` (6:00 AM UTC daily)
- Configured in `function.json`

### Core Functions
- `Send-ErrorNotification` - SMTP email notifications for errors
- `New-MailContactWithRetry` - Creates mail contacts with alias conflict handling
- `Sync-ContactsFromExcel` - Main sync logic
- `RunFunction` - Main orchestration function

### External Dependencies

**Multi-Tenant Setup:**
- App Registration lives in **Synapse tenant** (synapsetax.ca)
- Secrets stored in **HunterTech Key Vault** (huntertechvault)
- Azure Function runs in **HunterTech Azure subscription**

**Azure Key Vault (huntertechvault)** stores:
  - `synapse-tenant-id` - Synapse Azure AD Tenant ID
  - `synapse-app-id` - App Registration Client ID (registered in Synapse tenant)
  - `synapse-cert-thumbprint` - Certificate thumbprint
  - `synapse-certificate` - Full PFX certificate
  - `smtp2go-secure` - SMTP password for notifications

### SharePoint Configuration
- **Site**: `https://synapsetax.sharepoint.com/sites/Administration`
- **Excel File**: `/sites/Administration/Shared Documents/Administration/Tax Processes/T1 Processes/2026 T1 Season/T1 Client Email Listing TO BE UPDATED 2026.xlsx`

### Exchange Online Configuration
- **Organization**: `synapsetax.ca`
- **Distribution Group**: `T1Contacts@synapsetax.ca`
- **Custom Attribute**: `CustomAttribute1 = "T1SynapseContact"` (for identifying managed contacts)

## Sync Logic (Spreadsheet as Source of Truth)

1. **Add/Update**: Contacts in spreadsheet are created (if new) or updated in Exchange
2. **Distribution Group**: Contacts are added to `T1Contacts@synapsetax.ca` if not already members
3. **Remove**: Contacts with `CustomAttribute1="T1SynapseContact"` that are NOT in the spreadsheet are removed from the DG and deleted

### Excel Column Mapping
The function supports two column name formats:
- `Email Address` or `Email` - External email address (required)
- `Name` or `DisplayName` - Display name for the contact

### Alias Conflict Handling
When creating contacts, if an alias conflict occurs, the function retries with numbered suffixes (e.g., `johndoe`, `johndoe1`, `johndoe2`) up to 10 attempts.

## Development Notes

### Local Testing
```powershell
# Requires Azure Function Core Tools
func start

# Or run directly (requires manual Exchange/SharePoint connection)
cd SynapseContactSync
pwsh -File run.ps1
```

### Deployment
This function is part of the larger Functions app. Deploy the entire app:
```powershell
func azure functionapp publish <function-app-name>
```

### Required PowerShell Modules
- Az.Accounts
- Az.KeyVault
- PnP.PowerShell
- ImportExcel
- ExchangeOnlineManagement

Note: Modules are loaded from the `Modules` folder in the Functions app root (managed dependencies disabled).

## Azure Function App Requirements

### Application Settings
- `WEBSITE_LOAD_CERTIFICATES` = `*` (or specific thumbprint)

### Certificates
Certificate must be uploaded to Function App (imported from Key Vault) so it's available in the certificate store at runtime.

### Managed Identity
Function App must have a System-Assigned Managed Identity with:
- Key Vault Secrets User role on `huntertechvault`

## Security Considerations
- Uses Azure Managed Identity for Key Vault access
- All credentials stored in Azure Key Vault
- Certificate-based authentication for SharePoint and Exchange
- Certificate stored in Key Vault and loaded at runtime
- SMTP credentials secured via Key Vault
