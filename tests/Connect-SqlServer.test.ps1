Import-Module Pester

$script:modulePath = Split-Path -Path $PSScriptRoot -Parent
$script:module = Join-Path -Path $script:modulePath -ChildPath 'PsDBAid.psm1'

Import-Module -Name $script:module -Force

Describe 'Connect-SqlServer' {
    BeforeAll {
        $TestWinCred = Get-Credential -Message "Please supply windows credential to impersonate."
        $TestSqlCred = Get-Credential -Message "Please supply sql login to impersonate."
    }

    Context 'When connecting using integrated authentication' {
        It 'Should connect with integrated security' {
            $Smo = Connect-SqlServer
            $Smo.ConnectionContext.ServerInstance | Should -BeExactly $env:COMPUTERNAME
            $Smo.Status | Should -Match '^Online$'
        }

        It 'Should connect with sql authentication' {
            $Smo = Connect-SqlServer -Credential $TestSqlCred
            $Smo.ConnectionContext.ServerInstance | Should -BeExactly $env:COMPUTERNAME
            $Smo.ConnectionContext.LoginSecure | Should -BeExactly $false
            $Smo.ConnectionContext.Login | Should -BeExactly $TestSqlCred.UserName
            $Smo.Status | Should -Match '^Online$'
        }

        It 'Should connect with impersonated windows authentication' {
            $Smo = Connect-SqlServer -Credential $TestWinCred
            $Smo.ConnectionContext.LoginSecure | Should -BeExactly $true
            $Smo.ConnectionContext.ConnectAsUser | Should -BeExactly $true
            $Smo.ConnectionContext.ConnectAsUserName | Should -BeExactly $TestWinCred.GetNetworkCredential().UserName
            $Smo.ConnectionContext.ConnectAsUserPassword | Should -BeExactly $TestWinCred.GetNetworkCredential().Password
            $Smo.Status | Should -Match '^Online$'
        }

        It 'Should throw error when server does not exist' {
            { Connect-SqlServer -SqlServer 'IDONOTEXIST' -ErrorAction Stop } | Should -Throw "Failed to connect to SQL instance IDONOTEXIST"
        }
    }
}