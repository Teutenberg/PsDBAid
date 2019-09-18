<#
    .SYNOPSIS
        Set the minimum and maximum memory configuration for a SQL Server instance. 

    .PARAMETER SqlServer
        String containing the SQL Server to connect to.

    .PARAMETER TcpEnabled
        Boolean - Enables or disables the TCP network protocol. 

    .PARAMETER TcpDynamicPort
        Boolean - Specifies whether the SQL Server instance should use a dynamic port. Value cannot be set to $true if TcpPort is set to a non-empty string.

    .PARAMETER TcpPort
        String - The TCP port(s) that SQL Server should be listening on. 
        If the IP address should listen on more than one port, list all ports separated with a comma ('1433,1500,1501'). 
        To use this parameter set TcpDynamicPort to $false.

    .PARAMETER SuppressRestart
        Switch - True will supress the required service restart. Changes will not take effect until the service is restarted. 

    .PARAMETER Credential
        PSCredential object used for PsDscRunAsCredential.
#>
function Set-SqlServerNetwork
{
    [CmdletBinding()]
    param
    (
        [Parameter()]
        [ValidateNotNull()]
        [System.String]
        $SqlServer = $env:COMPUTERNAME,

        [Parameter()]
        [System.Boolean]
        $TcpEnabled = $true,

        [Parameter()]
        [System.Boolean]
        $TcpDynamicPort = $true,

        [Parameter()]
        [ValidateNotNull()]
        [System.String]
        $TcpPort,

        [Parameter()]
        [Switch]
        $SuppressRestart,

        [Parameter()]
        [ValidateNotNull()]
        [System.Management.Automation.PSCredential]
        $Credential
    )

    Write-Output "Checking SqlServerNetwork: $SqlServer"

    if ($Credential) {
        $Server = Connect-Sql -SqlServer $SourceSqlServer -Credential $Credential
    }
    else {
        $Server = Connect-Sql -SqlServer $SourceSqlServer
    }

    $SqlServerNetworkParams = @{
        ServerName           = $Server.NetName
        InstanceName         = $Server.InstanceName
        ProtocolName         = 'Tcp'
        IsEnabled            = $TcpEnabled
        TCPDynamicPort       = $TcpDynamicPort
        TCPPort              = $TcpPort
        RestartService       = $true
    }

    Write-Verbose -Message ("ServerName: {0}" -f $Server.NetName)
    Write-Verbose -Message ("InstanceName: {0}" -f $Server.InstanceName)
    Write-Verbose -Message ("IsEnabled: {0}" -f $TcpEnabled)
    Write-Verbose -Message ("TCPDynamicPort: {0}" -f $TCPDynamicPort)
    Write-Verbose -Message ("TCPPort: {0}" -f $TCPPort)

    if ($SuppressRestart) {
        $SqlServerNetworkParams.RestartService = $false
        Write-Verbose -Message ("RestartService: {0}" -f $false)
    }
    else {
        Write-Verbose -Message ("RestartService: {0}" -f $true)
    }

    if ($Credential) { 
        $SqlServerNetworkParams.Add("PsDscRunAsCredential",$Credential)
        Write-Verbose -Message ("PsDscRunAsCredential: {0}" -f $Credential.UserName)
    }

    if (Invoke-DscResource -ModuleName SqlServerDsc -Name SqlServerNetwork -Property $SqlServerNetworkParams -Method Test) {
        Write-Output 'Skipping - already configured to desired state.'
    } 
    else {
        Write-Output "Configuring to desired state."
        Invoke-DscResource -ModuleName SqlServerDsc -Name SqlServerNetwork -Property $SqlServerNetworkParams -Method Set -Verbose
    }

    Write-Output "Done."
}
