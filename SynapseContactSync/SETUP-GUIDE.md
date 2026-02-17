# SynapseContactSync Setup Guide

This guide walks through setting up the Azure AD App Registration and configuring the Azure Function to use certificates from Key Vault.

## Multi-Tenant Architecture

This is a **multi-tenant setup**:
- **App Registration** → Created in **Synapse tenant** (synapsetax.ca)
- **Key Vault & Secrets** → Stored in **HunterTech tenant** (huntertechvault)
- **Azure Function** → Runs in **HunterTech Azure subscription**

The function authenticates to Synapse's SharePoint and Exchange using a certificate, with the certificate stored securely in HunterTech's Key Vault.

## Prerequisites

- **Synapse tenant**: Global Admin or Application Admin rights to create App Registration
- **HunterTech tenant**: Access to Azure Key Vault (huntertechvault)
- PowerShell 7.x with modules:
  - Az.Accounts
  - Az.Resources
  - Az.KeyVault
  - Microsoft.Graph.Applications
  - Microsoft.Graph.Identity.DirectoryManagement

## Step 1: Install Required Modules

```powershell
Install-Module Az.Accounts -Force
Install-Module Az.Resources -Force
Install-Module Az.KeyVault -Force
Install-Module Microsoft.Graph.Applications -Force
Install-Module Microsoft.Graph.Identity.DirectoryManagement -Force
```

## Step 2: Run the App Registration Setup Script

```powershell
cd C:\Users\MathewHunter\Functions\SynapseContactSync
.\Setup-AppRegistration.ps1
```

The script will prompt for:
1. **Synapse Tenant ID** - The tenant ID for synapsetax.ca
2. **Synapse admin login** - To create the App Registration
3. **HunterTech login** - To store secrets in Key Vault

The script will:
1. Connect to **Synapse tenant** and create App Registration "SynapseContactSync"
2. Generate a self-signed certificate (2-year validity)
3. Upload the certificate to the App Registration
4. Create the Service Principal (Enterprise App) in Synapse tenant
5. Grant API permissions (in Synapse tenant):
   - Microsoft Graph: Sites.Read.All
   - SharePoint Online: Sites.Read.All
   - Exchange Online: Exchange.ManageAsApp
6. Assign Exchange Administrator role to the service principal
7. Connect to **HunterTech tenant** and store secrets in Key Vault:
   - `synapse-tenant-id` - Synapse Tenant ID
   - `synapse-app-id` - Application (Client) ID
   - `synapse-cert-thumbprint` - Certificate thumbprint
   - `synapse-certificate` - Full certificate (PFX)

**Save the PFX password displayed at the end!**

## Step 3: Configure Azure Function App to Load Certificate from Key Vault

### Option A: Key Vault Reference (Recommended)

1. Go to Azure Portal > Function App > **Settings** > **Certificates**
2. Click **+ Add certificate**
3. Select **Import from Key Vault**
4. Select your Key Vault: `huntertechvault`
5. Select certificate: `synapse-certificate`
6. Click **Add**

### Option B: Upload Certificate Directly

1. Go to Azure Portal > Function App > **Settings** > **Certificates**
2. Click **+ Add certificate**
3. Select **Upload certificate (.pfx)**
4. Upload `SynapseContactSync.pfx` from the setup folder
5. Enter the PFX password
6. Click **Add**

### Configure Certificate Loading

1. Go to Azure Portal > Function App > **Settings** > **Environment variables**
2. Add new application setting:
   - **Name**: `WEBSITE_LOAD_CERTIFICATES`
   - **Value**: `*` (or the specific thumbprint for security)
3. Click **Apply**

This tells the Function App to load the certificate into the certificate store when the function runs.

## Step 4: Grant Key Vault Access to Function App

The Function App's Managed Identity needs access to read secrets from Key Vault.

### Using Azure Portal:

1. Go to Azure Portal > Key Vault (`huntertechvault`) > **Access configuration**
2. Ensure **Permission model** is set to "Azure role-based access control" or "Vault access policy"

#### If using RBAC:
1. Go to Key Vault > **Access control (IAM)**
2. Click **+ Add** > **Add role assignment**
3. Select role: **Key Vault Secrets User**
4. Select members: Your Function App's Managed Identity
5. Click **Review + assign**

#### If using Vault Access Policy:
1. Go to Key Vault > **Access policies**
2. Click **+ Add Access Policy**
3. Secret permissions: **Get**, **List**
4. Certificate permissions: **Get**, **List**
5. Select principal: Your Function App's Managed Identity
6. Click **Add**

## Step 5: Verify Key Vault Secrets

Ensure these secrets exist in Key Vault (`huntertechvault`):

| Secret Name | Description |
|-------------|-------------|
| `synapse-tenant-id` | Synapse Azure AD Tenant ID (synapsetax.ca) |
| `synapse-app-id` | SynapseContactSync App ID (registered in Synapse tenant) |
| `synapse-cert-thumbprint` | Certificate thumbprint |
| `synapse-certificate` | Full PFX certificate |
| `smtp2go-secure` | SMTP password for notifications |

## Step 6: Configure SharePoint Permissions

The App Registration needs permission to access the Synapse SharePoint site.

### Grant Site-Level Access (if using Sites.Selected):

```powershell
# Connect to SharePoint Admin
Connect-PnPOnline -Url "https://synapsetax-admin.sharepoint.com" -Interactive

# Grant the app access to the specific site
Grant-PnPAzureADAppSitePermission `
    -AppId "<synapse-app-id>" `
    -DisplayName "SynapseContactSync" `
    -Site "https://synapsetax.sharepoint.com/sites/Administration" `
    -Permissions Read
```

### Or verify Sites.Read.All is working:

If you granted `Sites.Read.All` (application permission), the app should have access to all sites automatically. No additional configuration needed.

## Step 7: Test the Function

### Local Testing:

```powershell
# Ensure you have the certificate installed locally
# Import the PFX to your local certificate store
$certPath = "C:\Users\MathewHunter\Functions\SynapseContactSync\SynapseContactSync.pfx"
$certPassword = Read-Host -AsSecureString "Enter PFX password"
Import-PfxCertificate -FilePath $certPath -CertStoreLocation "Cert:\CurrentUser\My" -Password $certPassword

# Run the function
cd C:\Users\MathewHunter\Functions
func start
```

### Azure Testing:

1. Deploy the function to Azure
2. Go to Function App > **Functions** > **SynapseContactSync**
3. Click **Test/Run**
4. Check the logs for any errors

## Troubleshooting

### "Certificate not found" error
- Ensure `WEBSITE_LOAD_CERTIFICATES` is set in Function App settings
- Verify the certificate is uploaded to the Function App
- Check the thumbprint matches what's in Key Vault

### "Access denied to SharePoint" error
- Verify the App Registration has Sites.Read.All permission
- Check admin consent was granted
- If using Sites.Selected, ensure site-level permission was granted

### "Exchange Online connection failed" error
- Verify Exchange Administrator role is assigned to the Service Principal
- Ensure Exchange.ManageAsApp permission was granted with admin consent
- Check the organization name matches (synapsetax.ca)

### "Key Vault access denied" error
- Verify Function App's Managed Identity has Key Vault Secrets User role
- Check Key Vault firewall allows access from Azure services

## Certificate Renewal

Certificates expire! Set a reminder to renew before expiration.

### Renew Certificate:

```powershell
# Run setup script again with new certificate
.\Setup-AppRegistration.ps1 -AppName "SynapseContactSync"

# Or create certificate manually and update:
# 1. Create new certificate
# 2. Upload to App Registration in Azure Portal
# 3. Upload to Key Vault
# 4. Update Function App certificate
# 5. Remove old certificate after confirming new one works
```

## Security Best Practices

1. **Use specific thumbprint** in `WEBSITE_LOAD_CERTIFICATES` instead of `*`
2. **Rotate certificates** before expiration
3. **Monitor Function logs** for unauthorized access attempts
4. **Use Managed Identity** where possible instead of certificates
5. **Limit Key Vault access** to only required identities
