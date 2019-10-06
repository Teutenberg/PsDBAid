<#
    PsDBAid.psm1 is a helper module for scripted activities. 
    This module will contain functions to help simplify scripting and increase productivity. 
#>

Import-Module SqlServer
Import-Module SqlServerDsc
#Import-Module ReportingServicesTools

$Functions = Get-ChildItem -Path '.\functions'
Import-Module -Name $Functions.FullName -force
