Import-Module Pester

$script:modulePath = Split-Path -Path (Split-Path -Path $PSScriptRoot -Parent) -Parent
$script:module = Join-Path -Path $script:modulePath -ChildPath 'PsDBAid.psm1'

Import-Module -Name $script:module -Force
