# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Runtime & Deployment

This is an **Azure Functions v4 app** using **PowerShell 7** (pwsh). There is no build step — functions are deployed directly.

```powershell
# Run locally (requires Azure Functions Core Tools)
func start

# Deploy to Azure
func azure functionapp publish <function-app-name>

# Run a single function script directly (for local testing)
pwsh -File <FunctionFolder>/run.ps1
```

## Module Management

Managed dependencies (`requirements.psd1`) are **disabled** — all PowerShell modules are pre-loaded from the `/Modules/` folder at the repo root. This avoids cold-start overhead and version drift. When adding a new module dependency, add the module folder under `/Modules/` rather than uncommenting `requirements.psd1`.

## Functions Overview

| Function | Trigger | Schedule / Method | Purpose |
|---|---|---|---|
| `htcheckupdates1` | Timer | `0 17 5-18 * * 1-5` (5 PM UTC, weekdays 5–18th) | Monitors 20+ software products for version updates |
| `SynapseContactSync` | Timer | `0 0 6 * * *` (6 AM UTC daily) | Syncs SharePoint Excel contacts → Exchange Online |
| `CheckMailBoxStats` | Timer | `0 0 16 * * 1-5` (4 PM UTC, weekdays) | Exchange mailbox statistics monitoring |
| `CheckEnterpriseApps` | Timer | `0 0 */2 * * *` (every 2 hours) | M365 enterprise app monitoring via Microsoft Graph |
| `FL-ProjectMailbox` | Timer | `21 */10 16-23,0-2 * * 1-5` | Project mailbox operations |
| `FL-ExchangeManager` | HTTP POST | `authLevel: function` | On-demand Exchange management |
| `SMSToTeamsSynapse` | HTTP POST | `authLevel: function` | SMS-to-Teams bridge for Synapse |

## Shared Infrastructure

- **Azure Key Vault** (`huntertechvault`) — all secrets (SMTP credentials, certificates, product versions, tenant IDs). Access via Managed Identity (`Connect-AzAccount -Identity`).
- **System-Assigned Managed Identity** — the Function App identity needs *Key Vault Secrets User* role on `huntertechvault`.
- **SMTP2GO** — email delivery; credentials in Key Vault secret `smtp2go-secure`.
- `profile.ps1` — cold-start hook; currently a no-op (MSI block commented out, each function connects individually).

## Per-Function Documentation

Both `htcheckupdates1/CLAUDE.md` and `SynapseContactSync/CLAUDE.md` contain detailed architecture notes, configuration schemas, and development workflows for those functions. Read them when working in those folders.
