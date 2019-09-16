<#
    .SYNOPSIS
        Set SQL service account 

    .PARAMETER SqlServer
        String containing the SQL Server to connect to.

    .PARAMETER ServiceType
        The service type for InstanceName. { DatabaseEngine | SQLServerAgent }

    .PARAMETER ServiceAccount
        The service account that should be used when running the service.

    .PARAMETER RestartService
        Determines whether the service is automatically restarted when a change to the configuration was needed.

    .PARAMETER Force
        Forces the service account to be updated. Useful for password changes. This will cause Set-TargetResource to be run on each consecutive run.
#>
function Set-SqlServiceAccount
{
    [CmdletBinding()]
    param
    (
        [Parameter()]
        [ValidateNotNull()]
        [System.String]
        $SqlServer = $env:COMPUTERNAME,

        [Parameter()]
        [ValidateSet('DatabaseEngine','SQLServerAgent')]
        [System.String]
        $ServiceType = 'DatabaseEngine',

        [Parameter()]
        [ValidateNotNull()]
        [System.Management.Automation.PSCredential]
        $ServiceAccount,

        [Parameter()]
        [ValidateNotNull()]
        [switch]
        $RestartService,

        [Parameter()]
        [ValidateNotNull()]
        [switch]
        $Force
    )

    Write-Output "Checking SqlServiceAccount: $SqlServer"

    if ($Credential) {
        $Server = Connect-Sql -SqlServer $SourceSqlServer -Credential $Credential
    }
    else {
        $Server = Connect-Sql -SqlServer $SourceSqlServer
    }

    $SqlServiceParams = @{
        ServerName     = $Server.NetName
        InstanceName   = $Server.InstanceName
        ServiceType    = $ServiceType
        ServiceAccount = $ServiceAccount
        RestartService = $RestartService
        Force          = $Force
    }

    Write-Verbose -Message ("NetName: {0}" -f $Server.NetName)
    Write-Verbose -Message ("InstanceName: {0}" -f $Server.InstanceName)
    Write-Verbose -Message ("ServiceType: {0}" -f $ServiceType)
    Write-Verbose -Message ("ServiceAccount: {0}" -f $ServiceAccount)
    Write-Verbose -Message ("RestartService: {0}" -f $RestartService)
    Write-Verbose -Message ("Force: {0}" -f $Force)

    if (Invoke-DscResource -ModuleName SqlServerDsc -Name SqlServiceAccount -Property $SqlServiceParams -Method Test) {
        Write-Output 'Skipping - already configured to desired state.'
    }
    else {
        Write-Output "Configuring to desired state."
        Invoke-DscResource -ModuleName SqlServerDsc -Name SqlServiceAccount -Property $SqlServiceParams -Method Set -Verbose
    }

    Write-Output "Done."
}