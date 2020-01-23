<#
    .SYNOPSIS
        Connect to a computer and returns the SQL Service information. 

    .PARAMETER ComputerName
        String containing the Computer where you want to get SQL Services from.

    .PARAMETER Credential
        PSCredential object to impersonate when connecting. 
#>
function Get-SqlService
{
    [CmdletBinding()]
    param
    (
        [Parameter()]
        [ValidateNotNull()]
        [System.String]
        $ComputerName = $env:COMPUTERNAME,

        [Parameter()]
        [ValidateNotNull()]
        [System.Management.Automation.PSCredential]
        $Credential
    )

    <# Get SqlService CIM instance #>
    if ($Credential) {
        $CimObject = Get-SqlCimInstance -ComputerName $ComputerName -SqlClass 'SqlService' -Credential $Credential
    }
    else {
        $CimObject = Get-SqlCimInstance -ComputerName $ComputerName -SqlClass 'SqlService'
    }

    # Loop through CimObject and process properties and create custom PSObject to return.
    foreach ($Object in $CimObject) {
        $SqlServiceType = $(
            switch ($Object.SqlServiceType) {
                1  {'MSSQLSERVER'}
                2  {'SQLSERVERAGENT'}
                3  {'MSFTESQL'} 
                4  {'MsDtsServer'}
                5  {'MSSQLServerOLAPService'}
                6  {'ReportServer'}
                7  {'SQLBrowser'}
                8  {'NsService'}
                9  {'MSSQLFDLauncher'}
                10 {'SQLPBENGINE'}
                11 {'SQLPBDMS'}
                12 {'MSSQLLaunchpad'}
        })

        $ServiceState = $(
            switch ($Object.State) {
                1 {'Stopped'}
                2 {'Start Pending'}
                3 {'Stop Pending'}
                4 {'Running'}
                5 {'Continue Pending'}
                6 {'Pause Pending'}
                7 {'Paused'}
        })

        $ServiceStartMode = $(
            switch ($Agent.StartMode) {
                0 {'Boot'}
                1 {'System'}
                2 {'Automatic'}
                3 {'Manual'}
                4 {'Disabled'}
        })

        $SqlInstanceName = $(
            switch ($SqlServiceType) {
                'MSSQLSERVER'    { $Object.BinaryPath.Substring($Object.BinaryPath.IndexOf('-s')+2).Trim() }
                'SQLSERVERAGENT' { $Object.BinaryPath.Substring($Object.BinaryPath.IndexOf('-i')+2).Trim() }
                default          { '' }
        })

        $TcpPort = $(
            switch ($SqlServiceType) {
                'MSSQLSERVER'   { (Get-SqlCimInstance -ComputerName $ComputerName -SqlClass 'ServerNetworkProtocolProperty' -Filter "InstanceName = '$InstanceName' AND IPAddressName = 'IPAll' AND PropertyStrVal <> ''").PropertyStrVal }
                default         { '' }
        })

        $ServiceProperties = @{
            SqlServiceType = $SqlServiceType
            ComputerName   = $Object.HostName
            InstanceName   = $SqlInstanceName
            ServiceAccount = $Object.StartName
            State          = $ServiceState
            StartMode      = $ServiceStartMode
            BinaryPath     = $Object.BinaryPath
            TcpPort        = $TcpPort
        }

        $SqlServices += New-Object PSCustomObject -Property $ServiceProperties
    }

    # Return custom PSObject
    return $SqlServices 
}