@{
RootModule = if($PSEdition -eq 'Core')
{
    '.\netCore\ExchangeOnlineManagement.psm1'
}
else # Desktop
{
    '.\netFramework\ExchangeOnlineManagement.psm1'
}
FunctionsToExport = @('Connect-ExchangeOnline', 'Connect-IPPSSession', 'Disconnect-ExchangeOnline')
ModuleVersion = '3.7.2'
GUID = 'B5ECED50-AFA4-455B-847A-D8FB64140A22'
Author = 'Microsoft Corporation'
CompanyName = 'Microsoft Corporation'
Copyright = '(c) 2021 Microsoft. All rights reserved.'
Description = 'This is a General Availability (GA) release of the Exchange Online Powershell V3 module. Exchange Online cmdlets in this module are REST-backed and do not require Basic Authentication to be enabled in WinRM. REST-based connections in Windows require the PowerShellGet module, and by dependency, the PackageManagement module.
Please check the documentation here - https://aka.ms/exov3-module.
For issues related to the module, contact Microsoft support.'
PowerShellVersion = '3.0'
CmdletsToExport = @('Add-VivaModuleFeaturePolicy','Add-VivaOrgInsightsDelegatedRole','Get-ConnectionInformation','Get-DefaultTenantBriefingConfig','Get-DefaultTenantMyAnalyticsFeatureConfig','Get-EXOCasMailbox','Get-EXOMailbox','Get-EXOMailboxFolderPermission','Get-EXOMailboxFolderStatistics','Get-EXOMailboxPermission','Get-EXOMailboxStatistics','Get-EXOMobileDeviceStatistics','Get-EXORecipient','Get-EXORecipientPermission','Get-MyAnalyticsFeatureConfig','Get-UserBriefingConfig','Get-VivaFeatureCategory','Get-VivaInsightsSettings','Get-VivaModuleFeature','Get-VivaModuleFeatureEnablement','Get-VivaModuleFeaturePolicy','Get-VivaOrgInsightsDelegatedRole','Remove-VivaModuleFeaturePolicy','Remove-VivaOrgInsightsDelegatedRole','Set-DefaultTenantBriefingConfig','Set-DefaultTenantMyAnalyticsFeatureConfig','Set-MyAnalyticsFeatureConfig','Set-UserBriefingConfig','Set-VivaInsightsSettings','Update-VivaModuleFeaturePolicy')

# Add modules on which ExchangeOnlineManagement depend
RequiredModules = @(
    @{
        ModuleName     = 'PackageManagement'
        ModuleVersion  = '1.0.0.1'
    },
    @{
        ModuleName     = 'PowerShellGet'
        ModuleVersion  = '1.0.0.1'
    }
)

FileList = if($PSEdition -eq 'Core')
{
    @('.\netCore\Azure.Core.dll',
        '.\netCore\Microsoft.Bcl.AsyncInterfaces.dll',
        '.\netCore\Microsoft.Bcl.HashCode.dll',
        '.\netCore\Microsoft.Exchange.Management.AdminApiProvider.dll',
        '.\netCore\Microsoft.Exchange.Management.ExoPowershellGalleryModule.dll',
        '.\netCore\Microsoft.Exchange.Management.RestApiClient.dll',
        '.\netCore\Microsoft.Extensions.ObjectPool.dll',
        '.\netCore\Microsoft.Identity.Client.Broker.dll',
        '.\netCore\Microsoft.Identity.Client.dll',
        '.\netCore\Microsoft.Identity.Client.NativeInterop.dll',
        '.\netCore\Microsoft.IdentityModel.Abstractions.dll',
        '.\netCore\Microsoft.IdentityModel.JsonWebTokens.dll',
        '.\netCore\Microsoft.IdentityModel.Logging.dll',
        '.\netCore\Microsoft.IdentityModel.Tokens.dll',
        '.\netCore\Microsoft.OData.Client.dll',
        '.\netCore\Microsoft.OData.Core.dll',
        '.\netCore\Microsoft.OData.Edm.dll',
        '.\netCore\Microsoft.Online.CSE.RestApiPowerShellModule.Instrumentation.dll',
        '.\netCore\Microsoft.Spatial.dll',
        '.\netCore\Microsoft.Win32.Registry.AccessControl.dll',
        '.\netCore\Microsoft.Win32.SystemEvents.dll',
        '.\netCore\msvcp140.dll',
        '.\netCore\Newtonsoft.Json.dll',
        '.\netCore\System.CodeDom.dll',
        '.\netCore\System.Configuration.ConfigurationManager.dll',
        '.\netCore\System.Diagnostics.EventLog.dll',
        '.\netCore\System.Diagnostics.PerformanceCounter.dll',
        '.\netCore\System.DirectoryServices.dll',
        '.\netCore\System.Drawing.Common.dll',
        '.\netCore\System.IdentityModel.Tokens.Jwt.dll',
        '.\netCore\System.Management.dll',
        '.\netCore\System.Memory.Data.dll',
        '.\netCore\System.Security.Cryptography.Pkcs.dll',
        '.\netCore\System.Security.Cryptography.ProtectedData.dll',
        '.\netCore\System.Security.Permissions.dll',
        '.\netCore\System.Windows.Extensions.dll',
        '.\netCore\vcruntime140.dll',
        '.\netCore\vcruntime140_1.dll',
        '.\license.txt')
}
else # Desktop
{
    @('.\netFramework\Microsoft.Bcl.AsyncInterfaces.dll',
        '.\netFramework\Microsoft.Exchange.Management.AdminApiProvider.dll',
        '.\netFramework\Microsoft.Exchange.Management.ExoPowershellGalleryModule.dll',
        '.\netFramework\Microsoft.Exchange.Management.RestApiClient.dll',
        '.\netFramework\Microsoft.Identity.Client.Broker.dll',
        '.\netFramework\Microsoft.Identity.Client.dll',
        '.\netFramework\Microsoft.Identity.Client.NativeInterop.dll',
        '.\netFramework\Microsoft.IdentityModel.Abstractions.dll',
        '.\netFramework\Microsoft.IdentityModel.JsonWebTokens.dll',
        '.\netFramework\Microsoft.IdentityModel.Logging.dll',
        '.\netFramework\Microsoft.IdentityModel.Tokens.dll',
        '.\netFramework\Microsoft.OData.Client.dll',
        '.\netFramework\Microsoft.OData.Core.dll',
        '.\netFramework\Microsoft.OData.Edm.dll',
        '.\netFramework\Microsoft.Online.CSE.RestApiPowerShellModule.Instrumentation.dll',
        '.\netFramework\Microsoft.Spatial.dll',
        '.\netFramework\Newtonsoft.Json.dll',
        '.\netFramework\System.Buffers.dll',
        '.\netFramework\System.IdentityModel.Tokens.Jwt.dll',
        '.\netFramework\System.Management.Automation.dll',
        '.\netFramework\System.Memory.dll',
        '.\netFramework\System.Numerics.Vectors.dll',
        '.\netFramework\System.Runtime.CompilerServices.Unsafe.dll',
        '.\netFramework\System.Text.Json.dll',
        '.\netFramework\System.Threading.Tasks.Extensions.dll',
        '.\license.txt')
}

PrivateData = @{
    PSData = @{
    # Tags applied to this module. These help with module discovery in online galleries.
    Tags = 'Exchange', 'ExchangeOnline', 'EXO', 'EXOV2', 'EXOV3', 'Mailbox', 'Management'
    ReleaseNotes = '
---------------------------------------------------------------------------------------------
What is new in this release:

v3.7.2 :
    1. Added a new parameter -DisableWAM to the Connect-ExchangeOnline cmdlet, which disables the Web Account Manager (WAM).

---------------------------------------------------------------------------------------------
Previous Releases:

v3.7.1 :
    1. Introduced a new property named ExoExchangeSecurityDescriptor in Get-ExoMailbox response, that is similar to ExchangeSecurityDescriptor property in Get-Mailbox response.
    2. Added new cmdlets Add-VivaOrgInsightsDelegatedRole, Get-VivaOrgInsightsDelegatedRole, and Remove-VivaOrgInsightsDelegatedRole for supporting Viva Org Insights Delegation feature.
v3.7.0 :
    1. Integrated WAM (Web Account Manager) in Authentication flows to enhance security.
    2. Starting with EXO V3.7, use the LoadCmdletHelp parameter alongside Connect-ExchangeOnline to access the Get-Help cmdlet, as it will not be loaded by default.
    3. Fixed connection issues with app only authentication in Security & Compliance PowerShell.
v3.6.0 :
    1. Get-VivaModuleFeature now returns information about the kinds of identities the feature supports creating policies for (e.g., users, groups, or the entire tenant).
    2. Cmdlets for Viva feature access management will now handle continuous access evaluation (CAE) claims challengesAdded new cmdlets Get-VivaFeatureCategory and Get-VivaFeatureCategoryPolicy.
    3. Added fix for compatibility issue with Microsoft.Graph module.
v3.5.1 :
    1. Bug fixes in Get-EXOMailboxPermission and Get-EXOMailbox.
    2. The module has been upgraded to run on .NET 8, replacing the previous version based on .NET 6.
    3. Enhancements in Add-VivaModuleFeaturePolicy.
v3.5.0 :
    1. Added new cmdlet Get-VivaFeatureCategory
    2. Added support for policy operations at a category level for Viva GFAC (aka. VFAM - Viva Feature Access Management).
    3. Added a new return value IsFeatureEnabledByDefault in cmdlet Get-VivaModuleFeaturePolicy. This value informs of the default enablement state for users in the tenant when no tenant or user/group policies have been created.
v3.4.0 :
    1.  Bug fixes in Connect-ExchangeOnline, Get-EXORecipientPermission and Get-EXOMailboxFolderPermission.
    2.  Support to use Constrained Language Mode(CLM) using SigningCertificate parameter.

v3.3.0 :
    1.  Support to skip loading cmdlet help files with Connect-ExchangeOnline.
    2.  Global variable EXO_LastExecutionStatus can now be used to check the status of the last cmdlet that was executed.
    3.  Bug fixes in Connect-ExchangeOnline and Connect-IPPSSession.
    4.  Support of user controls enablement by policy for features that are onboarded to Viva feature access management.

v3.2.0 :
    1.  General Availability of new cmdlets:
        -  Updating Briefing Email Settings of a tenant (Get-DefaultTenantBriefingConfig and Set-DefaultTenantBriefingConfig)
        -  Updating Viva Insights Feature Settings of a tenant (Get-DefaultTenantMyAnalyticsFeatureConfig and Set-DefaultTenantMyAnalyticsFeatureConfig)
        -  View the features in Viva that support setting access management policies (Get-VivaModuleFeature)
        -  Create and manage Viva app feature policies
           -  Get-VivaModuleFeaturePolicy
           -  Add-VivaModuleFeaturePolicy
           -  Remove-VivaModuleFeaturePolicy
           -  Update-VivaModuleFeaturePolicy
        -  View whether or not a Viva feature is enabled for a specific user/group (Get-VivaModuleFeatureEnablement)

    2.  General Availability of REST based cmdlets for Security and Compliance PowerShell.
    3.  Support to get REST connection informations from Get-ConnectionInformation cmdlet and disconnect REST connections using Disconnect-ExchangeOnline cmdlet for specific connection(s).
    4.  Support to sign the temporary generated module with a client certificate to use the module in all PowerShell execution policies.
    5.  Bug fixes in Connect-ExchangeOnline.

v3.1.0 :
    1.  Support for providing an Access Token with Connect-ExchangeOnline.
    2.  Bug fixes in Connect-ExchangeOnline and Get-ConnectionInformation.
    3.  Bug fix in Connect-IPPSSession for connecting to Security and Compliance PowerShell using Certificate Thumbprint.

v3.0.0 :
    1.  General Availability of REST-backed cmdlets for Exchange Online which do not require WinRM Basic Authentication to be enabled.
    2.  General Availability of Certificate Based Authentication for Security and Compliance PowerShell cmdlets.
    3.  Support for System-Assigned and User-Assigned ManagedIdentities to connect to ExchangeOnline from Azure VMs, Azure Virtual Machine Scale Sets and Azure Functions.
    4.  Breaking changes
        -   Get-PSSession cannot be used to get information about the sessions created as PowerShell Remoting is no longer being used. The Get-ConnectionInformation cmdlet has been introduced instead, to get information about the existing connections to ExchangeOnline. Refer https://docs.microsoft.com/en-us/powershell/module/exchange/get-connectioninformation?view=exchange-ps for more information.
        -   Certain cmdlets that used to prompt for confirmation in specific scenarios will no longer have this prompt and the cmdlet will run to completion by default.
        -   The format of the error returned from a failed cmdlet execution has been slightly modified. The Exception contains some additional data such as the exception type, and the FullyQualifiedErrorId does not contain the FailureCategory. The format of the error is subject to further modifications.
        -   Deprecation of the Get-OwnerlessGroupPolicy and Set-OwnerlessGroupPolicy cmdlets.

v2.0.5 :
    1. Manage ownerless Microsoft 365 groups through newly added cmdlets Get-OwnerlessGroupPolicy and Set-OwnerlessGroupPolicy.
    2. Add new cmdlets Get-VivaInsightsSettings and Set-VivaInsightsSettings for Global/ExchangeOnline/Teams administrators to control user access of Headspace features in Viva Insights.

v2.0.4 :
    1. Manage EXO using Linux devices along with Browser based SSO Authentication for enhanced interactive management experience. No need to enter UserName and password everytime you run the PowerShell script.
    2. Manage EXO using Apple Macintosh devices. Supported versions of Apple MAC OS are Mojave, Catalina & Big Sur. Steps for installing PowerShell on MAC OS is documented here - https://docs.microsoft.com/en-us/powershell/scripting/install/installing-powershell-core-on-macos?view=powershell-7.1
    3. Real time policy & security enforcement in all user based authentication. Continuous Access Evaluation (CAE) has been enabled in EXO V2 Module. Read more about CAE here - https://techcommunity.microsoft.com/t5/azure-active-directory-identity/moving-towards-real-time-policy-and-security-enforcement/ba-p/1276933
    4. Use parameter InlineCredential to pass credentials of Non-MFA accounts on the go without the need of storing credentials in a variable
    5. More secure method to fetch access token using safe Reply URLs.
    6. Breaking change :- Change in cmdlet signature to configure MyAnalytics access for users in your tenant. Get/Set-UserAnalyticsConfig has been replaced by Get/Set-MyAnalyticsFeatureConfig Additionally, you can have more granular controls and configure access at feature level. For more steps read here - https://docs.microsoft.com/en-us/workplace-analytics/myanalytics/setup/configure-myanalytics

v2.0.3 :
    1. General availability of Certificate Based Authentication feature which enables using Modern Authentication in Unattended Scripting or background automation scenarios.
    2. Certificate Based Authentication accepts Certificate File directly from terminal thus enabling certificate files to be stored in Azure Key Vault and being fetched Just-In-Time for enhanced security. See parameter Certificate in Connect-ExchangeOnline.
    3. Connect with Exchange Online and Security Compliance Center simultaneously in a single PowerShell window.
    4. Ability to restrict the PowerShell cmdlets imported in a session using CommandName parameter, thus reducing memory footprint in case of high usage PowerShell applications.
    5. Get-ExoMailboxFolderPermission now supports ExternalDirectoryObjectID in the Identity parameter.
    6. Optimized latency of first V2 Cmdlet call. (Lab results show first call latency has been reduced from 8 seconds to ~1 seconds. Actual results will depend on result size and Tenant environment.)
 
v1.0.1 :
    1. This is the General Availability (GA) version of EXO PowerShell V2 Module. It is stable and ready for being used in production environments.
    2. Get-ExoMobileDeviceStatistics cmdlet now supports Identity parameter.
    3. Improved reliability of session auto-connect in certain cases where script was executing for ~50minutes and threw "Cmdlet not found" error due to a bug in auto-reconnect logic.
    4. Fixed data-type issues of two commonly used attributed "User" and "MailboxFolderUser" for easy migration of scripts.
    5. Enhanced support for filters as it now supports 4 more operators - endswith, contains, not and notlike support. Please check online documentation for attributes which are not supported in filter string.
 
---------------------------------------------------------------------------------------------
'
    LicenseUri='http://aka.ms/azps-license'
    }
}
}

# SIG # Begin signature block
# MIIoDAYJKoZIhvcNAQcCoIIn/TCCJ/kCAQExDzANBglghkgBZQMEAgEFADB5Bgor
# BgEEAYI3AgEEoGswaTA0BgorBgEEAYI3AgEeMCYCAwEAAAQQH8w7YFlLCE63JNLG
# KX7zUQIBAAIBAAIBAAIBAAIBADAxMA0GCWCGSAFlAwQCAQUABCBMpyuTWSVr2dN2
# 2h4CqnP5ztkqrtnwPn2bm2nSWp5g8KCCDXYwggX0MIID3KADAgECAhMzAAAEBGx0
# Bv9XKydyAAAAAAQEMA0GCSqGSIb3DQEBCwUAMH4xCzAJBgNVBAYTAlVTMRMwEQYD
# VQQIEwpXYXNoaW5ndG9uMRAwDgYDVQQHEwdSZWRtb25kMR4wHAYDVQQKExVNaWNy
# b3NvZnQgQ29ycG9yYXRpb24xKDAmBgNVBAMTH01pY3Jvc29mdCBDb2RlIFNpZ25p
# bmcgUENBIDIwMTEwHhcNMjQwOTEyMjAxMTE0WhcNMjUwOTExMjAxMTE0WjB0MQsw
# CQYDVQQGEwJVUzETMBEGA1UECBMKV2FzaGluZ3RvbjEQMA4GA1UEBxMHUmVkbW9u
# ZDEeMBwGA1UEChMVTWljcm9zb2Z0IENvcnBvcmF0aW9uMR4wHAYDVQQDExVNaWNy
# b3NvZnQgQ29ycG9yYXRpb24wggEiMA0GCSqGSIb3DQEBAQUAA4IBDwAwggEKAoIB
# AQC0KDfaY50MDqsEGdlIzDHBd6CqIMRQWW9Af1LHDDTuFjfDsvna0nEuDSYJmNyz
# NB10jpbg0lhvkT1AzfX2TLITSXwS8D+mBzGCWMM/wTpciWBV/pbjSazbzoKvRrNo
# DV/u9omOM2Eawyo5JJJdNkM2d8qzkQ0bRuRd4HarmGunSouyb9NY7egWN5E5lUc3
# a2AROzAdHdYpObpCOdeAY2P5XqtJkk79aROpzw16wCjdSn8qMzCBzR7rvH2WVkvF
# HLIxZQET1yhPb6lRmpgBQNnzidHV2Ocxjc8wNiIDzgbDkmlx54QPfw7RwQi8p1fy
# 4byhBrTjv568x8NGv3gwb0RbAgMBAAGjggFzMIIBbzAfBgNVHSUEGDAWBgorBgEE
# AYI3TAgBBggrBgEFBQcDAzAdBgNVHQ4EFgQU8huhNbETDU+ZWllL4DNMPCijEU4w
# RQYDVR0RBD4wPKQ6MDgxHjAcBgNVBAsTFU1pY3Jvc29mdCBDb3Jwb3JhdGlvbjEW
# MBQGA1UEBRMNMjMwMDEyKzUwMjkyMzAfBgNVHSMEGDAWgBRIbmTlUAXTgqoXNzci
# tW2oynUClTBUBgNVHR8ETTBLMEmgR6BFhkNodHRwOi8vd3d3Lm1pY3Jvc29mdC5j
# b20vcGtpb3BzL2NybC9NaWNDb2RTaWdQQ0EyMDExXzIwMTEtMDctMDguY3JsMGEG
# CCsGAQUFBwEBBFUwUzBRBggrBgEFBQcwAoZFaHR0cDovL3d3dy5taWNyb3NvZnQu
# Y29tL3BraW9wcy9jZXJ0cy9NaWNDb2RTaWdQQ0EyMDExXzIwMTEtMDctMDguY3J0
# MAwGA1UdEwEB/wQCMAAwDQYJKoZIhvcNAQELBQADggIBAIjmD9IpQVvfB1QehvpC
# Ge7QeTQkKQ7j3bmDMjwSqFL4ri6ae9IFTdpywn5smmtSIyKYDn3/nHtaEn0X1NBj
# L5oP0BjAy1sqxD+uy35B+V8wv5GrxhMDJP8l2QjLtH/UglSTIhLqyt8bUAqVfyfp
# h4COMRvwwjTvChtCnUXXACuCXYHWalOoc0OU2oGN+mPJIJJxaNQc1sjBsMbGIWv3
# cmgSHkCEmrMv7yaidpePt6V+yPMik+eXw3IfZ5eNOiNgL1rZzgSJfTnvUqiaEQ0X
# dG1HbkDv9fv6CTq6m4Ty3IzLiwGSXYxRIXTxT4TYs5VxHy2uFjFXWVSL0J2ARTYL
# E4Oyl1wXDF1PX4bxg1yDMfKPHcE1Ijic5lx1KdK1SkaEJdto4hd++05J9Bf9TAmi
# u6EK6C9Oe5vRadroJCK26uCUI4zIjL/qG7mswW+qT0CW0gnR9JHkXCWNbo8ccMk1
# sJatmRoSAifbgzaYbUz8+lv+IXy5GFuAmLnNbGjacB3IMGpa+lbFgih57/fIhamq
# 5VhxgaEmn/UjWyr+cPiAFWuTVIpfsOjbEAww75wURNM1Imp9NJKye1O24EspEHmb
# DmqCUcq7NqkOKIG4PVm3hDDED/WQpzJDkvu4FrIbvyTGVU01vKsg4UfcdiZ0fQ+/
# V0hf8yrtq9CkB8iIuk5bBxuPMIIHejCCBWKgAwIBAgIKYQ6Q0gAAAAAAAzANBgkq
# hkiG9w0BAQsFADCBiDELMAkGA1UEBhMCVVMxEzARBgNVBAgTCldhc2hpbmd0b24x
# EDAOBgNVBAcTB1JlZG1vbmQxHjAcBgNVBAoTFU1pY3Jvc29mdCBDb3Jwb3JhdGlv
# bjEyMDAGA1UEAxMpTWljcm9zb2Z0IFJvb3QgQ2VydGlmaWNhdGUgQXV0aG9yaXR5
# IDIwMTEwHhcNMTEwNzA4MjA1OTA5WhcNMjYwNzA4MjEwOTA5WjB+MQswCQYDVQQG
# EwJVUzETMBEGA1UECBMKV2FzaGluZ3RvbjEQMA4GA1UEBxMHUmVkbW9uZDEeMBwG
# A1UEChMVTWljcm9zb2Z0IENvcnBvcmF0aW9uMSgwJgYDVQQDEx9NaWNyb3NvZnQg
# Q29kZSBTaWduaW5nIFBDQSAyMDExMIICIjANBgkqhkiG9w0BAQEFAAOCAg8AMIIC
# CgKCAgEAq/D6chAcLq3YbqqCEE00uvK2WCGfQhsqa+laUKq4BjgaBEm6f8MMHt03
# a8YS2AvwOMKZBrDIOdUBFDFC04kNeWSHfpRgJGyvnkmc6Whe0t+bU7IKLMOv2akr
# rnoJr9eWWcpgGgXpZnboMlImEi/nqwhQz7NEt13YxC4Ddato88tt8zpcoRb0Rrrg
# OGSsbmQ1eKagYw8t00CT+OPeBw3VXHmlSSnnDb6gE3e+lD3v++MrWhAfTVYoonpy
# 4BI6t0le2O3tQ5GD2Xuye4Yb2T6xjF3oiU+EGvKhL1nkkDstrjNYxbc+/jLTswM9
# sbKvkjh+0p2ALPVOVpEhNSXDOW5kf1O6nA+tGSOEy/S6A4aN91/w0FK/jJSHvMAh
# dCVfGCi2zCcoOCWYOUo2z3yxkq4cI6epZuxhH2rhKEmdX4jiJV3TIUs+UsS1Vz8k
# A/DRelsv1SPjcF0PUUZ3s/gA4bysAoJf28AVs70b1FVL5zmhD+kjSbwYuER8ReTB
# w3J64HLnJN+/RpnF78IcV9uDjexNSTCnq47f7Fufr/zdsGbiwZeBe+3W7UvnSSmn
# Eyimp31ngOaKYnhfsi+E11ecXL93KCjx7W3DKI8sj0A3T8HhhUSJxAlMxdSlQy90
# lfdu+HggWCwTXWCVmj5PM4TasIgX3p5O9JawvEagbJjS4NaIjAsCAwEAAaOCAe0w
# ggHpMBAGCSsGAQQBgjcVAQQDAgEAMB0GA1UdDgQWBBRIbmTlUAXTgqoXNzcitW2o
# ynUClTAZBgkrBgEEAYI3FAIEDB4KAFMAdQBiAEMAQTALBgNVHQ8EBAMCAYYwDwYD
# VR0TAQH/BAUwAwEB/zAfBgNVHSMEGDAWgBRyLToCMZBDuRQFTuHqp8cx0SOJNDBa
# BgNVHR8EUzBRME+gTaBLhklodHRwOi8vY3JsLm1pY3Jvc29mdC5jb20vcGtpL2Ny
# bC9wcm9kdWN0cy9NaWNSb29DZXJBdXQyMDExXzIwMTFfMDNfMjIuY3JsMF4GCCsG
# AQUFBwEBBFIwUDBOBggrBgEFBQcwAoZCaHR0cDovL3d3dy5taWNyb3NvZnQuY29t
# L3BraS9jZXJ0cy9NaWNSb29DZXJBdXQyMDExXzIwMTFfMDNfMjIuY3J0MIGfBgNV
# HSAEgZcwgZQwgZEGCSsGAQQBgjcuAzCBgzA/BggrBgEFBQcCARYzaHR0cDovL3d3
# dy5taWNyb3NvZnQuY29tL3BraW9wcy9kb2NzL3ByaW1hcnljcHMuaHRtMEAGCCsG
# AQUFBwICMDQeMiAdAEwAZQBnAGEAbABfAHAAbwBsAGkAYwB5AF8AcwB0AGEAdABl
# AG0AZQBuAHQALiAdMA0GCSqGSIb3DQEBCwUAA4ICAQBn8oalmOBUeRou09h0ZyKb
# C5YR4WOSmUKWfdJ5DJDBZV8uLD74w3LRbYP+vj/oCso7v0epo/Np22O/IjWll11l
# hJB9i0ZQVdgMknzSGksc8zxCi1LQsP1r4z4HLimb5j0bpdS1HXeUOeLpZMlEPXh6
# I/MTfaaQdION9MsmAkYqwooQu6SpBQyb7Wj6aC6VoCo/KmtYSWMfCWluWpiW5IP0
# wI/zRive/DvQvTXvbiWu5a8n7dDd8w6vmSiXmE0OPQvyCInWH8MyGOLwxS3OW560
# STkKxgrCxq2u5bLZ2xWIUUVYODJxJxp/sfQn+N4sOiBpmLJZiWhub6e3dMNABQam
# ASooPoI/E01mC8CzTfXhj38cbxV9Rad25UAqZaPDXVJihsMdYzaXht/a8/jyFqGa
# J+HNpZfQ7l1jQeNbB5yHPgZ3BtEGsXUfFL5hYbXw3MYbBL7fQccOKO7eZS/sl/ah
# XJbYANahRr1Z85elCUtIEJmAH9AAKcWxm6U/RXceNcbSoqKfenoi+kiVH6v7RyOA
# 9Z74v2u3S5fi63V4GuzqN5l5GEv/1rMjaHXmr/r8i+sLgOppO6/8MO0ETI7f33Vt
# Y5E90Z1WTk+/gFcioXgRMiF670EKsT/7qMykXcGhiJtXcVZOSEXAQsmbdlsKgEhr
# /Xmfwb1tbWrJUnMTDXpQzTGCGewwghnoAgEBMIGVMH4xCzAJBgNVBAYTAlVTMRMw
# EQYDVQQIEwpXYXNoaW5ndG9uMRAwDgYDVQQHEwdSZWRtb25kMR4wHAYDVQQKExVN
# aWNyb3NvZnQgQ29ycG9yYXRpb24xKDAmBgNVBAMTH01pY3Jvc29mdCBDb2RlIFNp
# Z25pbmcgUENBIDIwMTECEzMAAAQEbHQG/1crJ3IAAAAABAQwDQYJYIZIAWUDBAIB
# BQCggZAwGQYJKoZIhvcNAQkDMQwGCisGAQQBgjcCAQQwLwYJKoZIhvcNAQkEMSIE
# IObB7/YTqAtDx6p/H9G5TUryJT3e6ZS8teozNB1AQAWGMEIGCisGAQQBgjcCAQwx
# NDAyoBSAEgBNAGkAYwByAG8AcwBvAGYAdKEagBhodHRwOi8vd3d3Lm1pY3Jvc29m
# dC5jb20wDQYJKoZIhvcNAQEBBQAEggEAKlcln3UF/yy5SVnIilJ1GygWiHk01YNw
# BOUsAtACbImO187crxZUvTIOZil8luIf0nurzjQnhzG1tKcebmBsnjpmYjhhwG4b
# ZcAh0admWC+cozr1EK26NMeIjLQOCxmAJLjreRaRK7qvIjBB2ZeQYMmKNF2IYAcm
# 3MC7mOZOPENWgqIr7DZcO507ix9b9QPie8rrRKCHTDSbgpQYFg84aDGJXue6dqmS
# P/53j90fYTt4KdPjdRa+e9AXvVKRhUNeWVX0CiJ9wHYyL6G2Ue3VWXeyllbZpiYM
# lLZsN1lDf9LX6vYiXEoAcOZjy7GLpaA18v4n64ma4POtQq5sYMl3/aGCF5QwgheQ
# BgorBgEEAYI3AwMBMYIXgDCCF3wGCSqGSIb3DQEHAqCCF20wghdpAgEDMQ8wDQYJ
# YIZIAWUDBAIBBQAwggFSBgsqhkiG9w0BCRABBKCCAUEEggE9MIIBOQIBAQYKKwYB
# BAGEWQoDATAxMA0GCWCGSAFlAwQCAQUABCDe3c8I0hgHpA5jNyPRDys/JJLxud5h
# YX3Tz0woxcW7/gIGZ63rF+K4GBMyMDI1MDIyMDAyMjIxMy4zOThaMASAAgH0oIHR
# pIHOMIHLMQswCQYDVQQGEwJVUzETMBEGA1UECBMKV2FzaGluZ3RvbjEQMA4GA1UE
# BxMHUmVkbW9uZDEeMBwGA1UEChMVTWljcm9zb2Z0IENvcnBvcmF0aW9uMSUwIwYD
# VQQLExxNaWNyb3NvZnQgQW1lcmljYSBPcGVyYXRpb25zMScwJQYDVQQLEx5uU2hp
# ZWxkIFRTUyBFU046QTAwMC0wNUUwLUQ5NDcxJTAjBgNVBAMTHE1pY3Jvc29mdCBU
# aW1lLVN0YW1wIFNlcnZpY2WgghHqMIIHIDCCBQigAwIBAgITMwAAAevgGGy1tu84
# 7QABAAAB6zANBgkqhkiG9w0BAQsFADB8MQswCQYDVQQGEwJVUzETMBEGA1UECBMK
# V2FzaGluZ3RvbjEQMA4GA1UEBxMHUmVkbW9uZDEeMBwGA1UEChMVTWljcm9zb2Z0
# IENvcnBvcmF0aW9uMSYwJAYDVQQDEx1NaWNyb3NvZnQgVGltZS1TdGFtcCBQQ0Eg
# MjAxMDAeFw0yMzEyMDYxODQ1MzRaFw0yNTAzMDUxODQ1MzRaMIHLMQswCQYDVQQG
# EwJVUzETMBEGA1UECBMKV2FzaGluZ3RvbjEQMA4GA1UEBxMHUmVkbW9uZDEeMBwG
# A1UEChMVTWljcm9zb2Z0IENvcnBvcmF0aW9uMSUwIwYDVQQLExxNaWNyb3NvZnQg
# QW1lcmljYSBPcGVyYXRpb25zMScwJQYDVQQLEx5uU2hpZWxkIFRTUyBFU046QTAw
# MC0wNUUwLUQ5NDcxJTAjBgNVBAMTHE1pY3Jvc29mdCBUaW1lLVN0YW1wIFNlcnZp
# Y2UwggIiMA0GCSqGSIb3DQEBAQUAA4ICDwAwggIKAoICAQDBFWgh2lbgV3eJp01o
# qiaFBuYbNc7hSKmktvJ15NrB/DBboUow8WPOTPxbn7gcmIOGmwJkd+TyFx7KOnzr
# xnoB3huvv91fZuUugIsKTnAvg2BU/nfN7Zzn9Kk1mpuJ27S6xUDH4odFiX51ICcK
# l6EG4cxKgcDAinihT8xroJWVATL7p8bbfnwsc1pihZmcvIuYGnb1TY9tnpdChWr9
# EARuCo3TiRGjM2Lp4piT2lD5hnd3VaGTepNqyakpkCGV0+cK8Vu/HkIZdvy+z5EL
# 3ojTdFLL5vJ9IAogWf3XAu3d7SpFaaoeix0e1q55AD94ZwDP+izqLadsBR3tzjq2
# RfrCNL+Tmi/jalRto/J6bh4fPhHETnDC78T1yfXUQdGtmJ/utI/ANxi7HV8gAPzi
# d9TYjMPbYqG8y5xz+gI/SFyj+aKtHHWmKzEXPttXzAcexJ1EH7wbuiVk3sErPK9M
# Lg1Xb6hM5HIWA0jEAZhKEyd5hH2XMibzakbp2s2EJQWasQc4DMaF1EsQ1CzgClDY
# IYG6rUhudfI7k8L9KKCEufRbK5ldRYNAqddr/ySJfuZv3PS3+vtD6X6q1H4UOmjD
# KdjoW3qs7JRMZmH9fkFkMzb6YSzr6eX1LoYm3PrO1Jea43SYzlB3Tz84OvuVSV7N
# cidVtNqiZeWWpVjfavR+Jj/JOQIDAQABo4IBSTCCAUUwHQYDVR0OBBYEFHSeBazW
# Vcxu4qT9O5jT2B+qAerhMB8GA1UdIwQYMBaAFJ+nFV0AXmJdg/Tl0mWnG1M1Gely
# MF8GA1UdHwRYMFYwVKBSoFCGTmh0dHA6Ly93d3cubWljcm9zb2Z0LmNvbS9wa2lv
# cHMvY3JsL01pY3Jvc29mdCUyMFRpbWUtU3RhbXAlMjBQQ0ElMjAyMDEwKDEpLmNy
# bDBsBggrBgEFBQcBAQRgMF4wXAYIKwYBBQUHMAKGUGh0dHA6Ly93d3cubWljcm9z
# b2Z0LmNvbS9wa2lvcHMvY2VydHMvTWljcm9zb2Z0JTIwVGltZS1TdGFtcCUyMFBD
# QSUyMDIwMTAoMSkuY3J0MAwGA1UdEwEB/wQCMAAwFgYDVR0lAQH/BAwwCgYIKwYB
# BQUHAwgwDgYDVR0PAQH/BAQDAgeAMA0GCSqGSIb3DQEBCwUAA4ICAQCDdN8voPd8
# C+VWZP3+W87c/QbdbWK0sOt9Z4kEOWng7Kmh+WD2LnPJTJKIEaxniOct9wMgJ8yQ
# ywR8WHgDOvbwqdqsLUaM4NrertI6FI9rhjheaKxNNnBZzHZLDwlkL9vCEDe9Rc0d
# GSVd5Bg3CWknV3uvVau14F55ESTWIBNaQS9Cpo2Opz3cRgAYVfaLFGbArNcRvSWv
# SUbeI2IDqRxC4xBbRiNQ+1qHXDCPn0hGsXfL+ynDZncCfszNrlgZT24XghvTzYMH
# cXioLVYo/2Hkyow6dI7uULJbKxLX8wHhsiwriXIDCnjLVsG0E5bR82QgcseEhxbU
# 2d1RVHcQtkUE7W9zxZqZ6/jPmaojZgXQO33XjxOHYYVa/BXcIuu8SMzPjjAAbujw
# TawpazLBv997LRB0ZObNckJYyQQpETSflN36jW+z7R/nGyJqRZ3HtZ1lXW1f6zEC
# AeP+9dy6nmcCrVcOqbQHX7Zr8WPcghHJAADlm5ExPh5xi1tNRk+i6F2a9SpTeQnZ
# XP50w+JoTxISQq7vBij2nitAsSLaVeMqoPi+NXlTUNZ2NdtbFr6Iir9ZK9ufaz3F
# xfvDZo365vLOozmQOe/Z+pu4vY5zPmtNiVIcQnFy7JZOiZVDI5bIdwQRai2quHKJ
# 6ltUdsi3HjNnieuE72fT4eWhxtmnN5HYCDCCB3EwggVZoAMCAQICEzMAAAAVxedr
# ngKbSZkAAAAAABUwDQYJKoZIhvcNAQELBQAwgYgxCzAJBgNVBAYTAlVTMRMwEQYD
# VQQIEwpXYXNoaW5ndG9uMRAwDgYDVQQHEwdSZWRtb25kMR4wHAYDVQQKExVNaWNy
# b3NvZnQgQ29ycG9yYXRpb24xMjAwBgNVBAMTKU1pY3Jvc29mdCBSb290IENlcnRp
# ZmljYXRlIEF1dGhvcml0eSAyMDEwMB4XDTIxMDkzMDE4MjIyNVoXDTMwMDkzMDE4
# MzIyNVowfDELMAkGA1UEBhMCVVMxEzARBgNVBAgTCldhc2hpbmd0b24xEDAOBgNV
# BAcTB1JlZG1vbmQxHjAcBgNVBAoTFU1pY3Jvc29mdCBDb3Jwb3JhdGlvbjEmMCQG
# A1UEAxMdTWljcm9zb2Z0IFRpbWUtU3RhbXAgUENBIDIwMTAwggIiMA0GCSqGSIb3
# DQEBAQUAA4ICDwAwggIKAoICAQDk4aZM57RyIQt5osvXJHm9DtWC0/3unAcH0qls
# TnXIyjVX9gF/bErg4r25PhdgM/9cT8dm95VTcVrifkpa/rg2Z4VGIwy1jRPPdzLA
# EBjoYH1qUoNEt6aORmsHFPPFdvWGUNzBRMhxXFExN6AKOG6N7dcP2CZTfDlhAnrE
# qv1yaa8dq6z2Nr41JmTamDu6GnszrYBbfowQHJ1S/rboYiXcag/PXfT+jlPP1uyF
# Vk3v3byNpOORj7I5LFGc6XBpDco2LXCOMcg1KL3jtIckw+DJj361VI/c+gVVmG1o
# O5pGve2krnopN6zL64NF50ZuyjLVwIYwXE8s4mKyzbnijYjklqwBSru+cakXW2dg
# 3viSkR4dPf0gz3N9QZpGdc3EXzTdEonW/aUgfX782Z5F37ZyL9t9X4C626p+Nuw2
# TPYrbqgSUei/BQOj0XOmTTd0lBw0gg/wEPK3Rxjtp+iZfD9M269ewvPV2HM9Q07B
# MzlMjgK8QmguEOqEUUbi0b1qGFphAXPKZ6Je1yh2AuIzGHLXpyDwwvoSCtdjbwzJ
# NmSLW6CmgyFdXzB0kZSU2LlQ+QuJYfM2BjUYhEfb3BvR/bLUHMVr9lxSUV0S2yW6
# r1AFemzFER1y7435UsSFF5PAPBXbGjfHCBUYP3irRbb1Hode2o+eFnJpxq57t7c+
# auIurQIDAQABo4IB3TCCAdkwEgYJKwYBBAGCNxUBBAUCAwEAATAjBgkrBgEEAYI3
# FQIEFgQUKqdS/mTEmr6CkTxGNSnPEP8vBO4wHQYDVR0OBBYEFJ+nFV0AXmJdg/Tl
# 0mWnG1M1GelyMFwGA1UdIARVMFMwUQYMKwYBBAGCN0yDfQEBMEEwPwYIKwYBBQUH
# AgEWM2h0dHA6Ly93d3cubWljcm9zb2Z0LmNvbS9wa2lvcHMvRG9jcy9SZXBvc2l0
# b3J5Lmh0bTATBgNVHSUEDDAKBggrBgEFBQcDCDAZBgkrBgEEAYI3FAIEDB4KAFMA
# dQBiAEMAQTALBgNVHQ8EBAMCAYYwDwYDVR0TAQH/BAUwAwEB/zAfBgNVHSMEGDAW
# gBTV9lbLj+iiXGJo0T2UkFvXzpoYxDBWBgNVHR8ETzBNMEugSaBHhkVodHRwOi8v
# Y3JsLm1pY3Jvc29mdC5jb20vcGtpL2NybC9wcm9kdWN0cy9NaWNSb29DZXJBdXRf
# MjAxMC0wNi0yMy5jcmwwWgYIKwYBBQUHAQEETjBMMEoGCCsGAQUFBzAChj5odHRw
# Oi8vd3d3Lm1pY3Jvc29mdC5jb20vcGtpL2NlcnRzL01pY1Jvb0NlckF1dF8yMDEw
# LTA2LTIzLmNydDANBgkqhkiG9w0BAQsFAAOCAgEAnVV9/Cqt4SwfZwExJFvhnnJL
# /Klv6lwUtj5OR2R4sQaTlz0xM7U518JxNj/aZGx80HU5bbsPMeTCj/ts0aGUGCLu
# 6WZnOlNN3Zi6th542DYunKmCVgADsAW+iehp4LoJ7nvfam++Kctu2D9IdQHZGN5t
# ggz1bSNU5HhTdSRXud2f8449xvNo32X2pFaq95W2KFUn0CS9QKC/GbYSEhFdPSfg
# QJY4rPf5KYnDvBewVIVCs/wMnosZiefwC2qBwoEZQhlSdYo2wh3DYXMuLGt7bj8s
# CXgU6ZGyqVvfSaN0DLzskYDSPeZKPmY7T7uG+jIa2Zb0j/aRAfbOxnT99kxybxCr
# dTDFNLB62FD+CljdQDzHVG2dY3RILLFORy3BFARxv2T5JL5zbcqOCb2zAVdJVGTZ
# c9d/HltEAY5aGZFrDZ+kKNxnGSgkujhLmm77IVRrakURR6nxt67I6IleT53S0Ex2
# tVdUCbFpAUR+fKFhbHP+CrvsQWY9af3LwUFJfn6Tvsv4O+S3Fb+0zj6lMVGEvL8C
# wYKiexcdFYmNcP7ntdAoGokLjzbaukz5m/8K6TT4JDVnK+ANuOaMmdbhIurwJ0I9
# JZTmdHRbatGePu1+oDEzfbzL6Xu/OHBE0ZDxyKs6ijoIYn/ZcGNTTY3ugm2lBRDB
# cQZqELQdVTNYs6FwZvKhggNNMIICNQIBATCB+aGB0aSBzjCByzELMAkGA1UEBhMC
# VVMxEzARBgNVBAgTCldhc2hpbmd0b24xEDAOBgNVBAcTB1JlZG1vbmQxHjAcBgNV
# BAoTFU1pY3Jvc29mdCBDb3Jwb3JhdGlvbjElMCMGA1UECxMcTWljcm9zb2Z0IEFt
# ZXJpY2EgT3BlcmF0aW9uczEnMCUGA1UECxMeblNoaWVsZCBUU1MgRVNOOkEwMDAt
# MDVFMC1EOTQ3MSUwIwYDVQQDExxNaWNyb3NvZnQgVGltZS1TdGFtcCBTZXJ2aWNl
# oiMKAQEwBwYFKw4DAhoDFQCABol1u1wwwYgUtUowMnqYvbul3qCBgzCBgKR+MHwx
# CzAJBgNVBAYTAlVTMRMwEQYDVQQIEwpXYXNoaW5ndG9uMRAwDgYDVQQHEwdSZWRt
# b25kMR4wHAYDVQQKExVNaWNyb3NvZnQgQ29ycG9yYXRpb24xJjAkBgNVBAMTHU1p
# Y3Jvc29mdCBUaW1lLVN0YW1wIFBDQSAyMDEwMA0GCSqGSIb3DQEBCwUAAgUA62D6
# 5DAiGA8yMDI1MDIyMDAwNTA0NFoYDzIwMjUwMjIxMDA1MDQ0WjB0MDoGCisGAQQB
# hFkKBAExLDAqMAoCBQDrYPrkAgEAMAcCAQACAgibMAcCAQACAhH4MAoCBQDrYkxk
# AgEAMDYGCisGAQQBhFkKBAIxKDAmMAwGCisGAQQBhFkKAwKgCjAIAgEAAgMHoSCh
# CjAIAgEAAgMBhqAwDQYJKoZIhvcNAQELBQADggEBALi9h6i2qipgezCowLDan7W6
# B/J7uFXjVtw7NtfRRkRo9wwkgM5qdjAkEM0DAmGgm32LqRYIjEHRtc+29Rrc3kCP
# 2O2EohAWjOvrK3nftrL9Pv/XAv6Op6wOBdGzdPYZ1PXiV+hs6n/ZM6gtCt8YhsK3
# cbaQyT32VUYAWDAh85C+XNrkFQJ/Hj5zPH7RE2u7Ug7iuCt/cW+TU+CP4QAICP8i
# pGYINvP2kdd5l69mybP1obNglgLUBF5lJYmaZGs/r5Z5BgGro8OJCVC1mQ1VuXze
# n9R9TJdtnpzPpcznbmkB5uCmQKk+nhyWteLBYkfvZ0Wm3WeA8Y3mNaq7chzK9CIx
# ggQNMIIECQIBATCBkzB8MQswCQYDVQQGEwJVUzETMBEGA1UECBMKV2FzaGluZ3Rv
# bjEQMA4GA1UEBxMHUmVkbW9uZDEeMBwGA1UEChMVTWljcm9zb2Z0IENvcnBvcmF0
# aW9uMSYwJAYDVQQDEx1NaWNyb3NvZnQgVGltZS1TdGFtcCBQQ0EgMjAxMAITMwAA
# AevgGGy1tu847QABAAAB6zANBglghkgBZQMEAgEFAKCCAUowGgYJKoZIhvcNAQkD
# MQ0GCyqGSIb3DQEJEAEEMC8GCSqGSIb3DQEJBDEiBCAgL7EdSGGnLYrBH9uN0I6S
# 7lRDkyJfunEJ/GLyRwd/WTCB+gYLKoZIhvcNAQkQAi8xgeowgecwgeQwgb0EIM63
# a75faQPhf8SBDTtk2DSUgIbdizXsz76h1JdhLCz4MIGYMIGApH4wfDELMAkGA1UE
# BhMCVVMxEzARBgNVBAgTCldhc2hpbmd0b24xEDAOBgNVBAcTB1JlZG1vbmQxHjAc
# BgNVBAoTFU1pY3Jvc29mdCBDb3Jwb3JhdGlvbjEmMCQGA1UEAxMdTWljcm9zb2Z0
# IFRpbWUtU3RhbXAgUENBIDIwMTACEzMAAAHr4BhstbbvOO0AAQAAAeswIgQg/9uW
# fvhkI/8YV9FQeREWAeZRia4QJKQvEdrm0sO5lqQwDQYJKoZIhvcNAQELBQAEggIA
# XhDkGJ2KvHdBH16wpw/ir2LFxb8kTtcZi6p53x5Qpt16eYlznWiHSfVXTxUvBOC8
# 67IbcCTMupXA5+V6k1l28tk3zC0ZMztMFh1c2R4dZJc0+zvveDj3O8eMzSMQ7Cbh
# ZfpuZJsY8RIP14732HKk4JeJrGmQuuSakvZGYMikQGm/GSXGr2daIhzffGUED2Od
# 2Gh9pUvDA/wQNaR2l1PMKTzBQ5QlJi7TzOVbbR+mHY4CCkZ7J6MFvMWbc9NWx0yI
# OXamMMFYLXDDdOqlqsYx4RCERmmvX8NwrLTuVn95vKACC40z5OUlDokf0v018EPN
# FkBfxOkyzSNZTID8ZA/afwtUaKg7o55vZx/cwHfEIWrzXJJ2R1v2WKEjAvGwK4gl
# Nz1+C8QEOMD9mRcq3WN8LSpzU06noaLPGLvcRpJHxxUT+UGqNTaF/KVBtHeyDOqI
# oB3iXqIJlemPRqM0ln7hWC6nuM1NQ9k3maS+vwfjtQ5fRZsIuzMn/8ffL8PDq6bu
# ppI7cebnkdr3uI300WVQmU0CspZvMAc46jkOf7acL+62PD3XzHyl+tMF6ttSlWdq
# gLo8SifmDlv/DY8Kpjn2I0QMFkg9sVH7C4q6Ks0bNX040Ja3/SuZzDZjkFCPU4UK
# ID+PzsjvhofTF9ME+Vg/3x8i1o2lpPUhsOMRt+zufl4=
# SIG # End signature block
