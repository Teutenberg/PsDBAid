<#
    PsDBAid.psm1 is a helper module for scripted activities. 
    This module will contain functions to help simplify scripting and increase productivity. 
#>

Import-Module SqlServer
Import-Module SqlServerDsc
#Import-Module ReportingServicesTools

$Functions  = @( Get-ChildItem -Path $PSScriptRoot\functions\*.ps1 -ErrorAction SilentlyContinue )
$Functions | Unblock-File

foreach($import in $Functions) {
    try {
        . $import.fullname
    }
    catch {
        Write-Error -Message "Failed to import function $($import.fullname): $_"
    }
}

Export-ModuleMember -Function $Functions.Basename
