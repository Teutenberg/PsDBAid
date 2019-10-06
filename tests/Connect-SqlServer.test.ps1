Import-Module Pester

$script:modulePath = Split-Path -Path $PSScriptRoot -Parent
$script:module = Join-Path -Path $script:modulePath -ChildPath 'PsDBAid.psm1'

Import-Module -Name $script:module -Force

Describe 'Connect-SqlServer' {
    Context 'When connecting using integrated authentication' {
        It 'Should return the correct service instance' {
            $Smo = Connect-SqlServer
            $Smo.ConnectionContext.ServerInstance | Should -BeExactly $env:COMPUTERNAME

            #Assert-MockCalled -CommandName New-Object -Exactly -Times 1 -Scope It -ParameterFilter $mockNewObject_MicrosoftDatabaseEngine_ParameterFilter
        }
    }
}