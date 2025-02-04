# This file enables modules to be automatically managed by the Functions service.
# See https://aka.ms/functionsmanageddependency for additional information.
#
@{
    # Script module or binary module files associated with this manifest.
    RootModule = @()

    # Version number of this module.
    ModuleVersion = '1.0.0'

    # ID used to uniquely identify this module
    GUID = '12345678-1234-1234-1234-123456789012'

    # Author of this module
    Author = 'Mathew Hunter'

    # Company or vendor of this module
    CompanyName = 'Huntertech'

    # Copyright statement for this module
    Copyright = '(c) 2025 Huntertech. All rights reserved.'

    # Description of the functionality provided by this module
    Description = 'This module contains functions to check for the latest versions of Bluebeam and Autodesk products, and send email notifications if updates are found.'

    # Minimum version of the Windows PowerShell engine required by this module
    PowerShellVersion = '7.4'

    # Modules that must be imported into the global environment prior to importing this module
    RequiredModules = @('Az.Accounts', 'Az.Functions', 'Az.KeyVault')

    # Assemblies that must be loaded prior to importing this module
    RequiredAssemblies = @()

    # Script files (.ps1) that are run in the caller's environment prior to importing this module
    ScriptsToProcess = @()

    # Type files (.ps1xml) to be loaded when importing this module
    TypesToProcess = @()

    # Format files (.ps1xml) to be loaded when importing this module
    FormatsToProcess = @()

    # Modules to import as nested modules of the module specified in RootModule/ModuleToProcess
    NestedModules = @()

    # Functions to export from this module
    FunctionsToExport = @('Send-Email', 'getBlueBeamLatest', 'getAutodeskLatest', 'RunFunction')

    # Cmdlets to export from this module
    CmdletsToExport = @()

    # Variables to export from this module
    VariablesToExport = @()

    # Aliases to export from this module
    AliasesToExport = @()

    # DSC resources to export from this module
    DscResourcesToExport = @()

    # List of all modules packaged with this module
    ModuleList = @()

    # List of all files packaged with this module
    FileList = @()

    # Private data to pass to the module specified in RootModule/ModuleToProcess
    PrivateData = @{}

    # HelpInfo URI of this module
    HelpInfoURI = ''

    # Default prefix for commands exported from this module. Override the default prefix using Import-Module -Prefix.
    DefaultCommandPrefix = ''
}