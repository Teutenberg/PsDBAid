<#
    .SYNOPSIS
        Set the minimum and maximum memory configuration for a SQL Server instance. 

    .PARAMETER SqlServer
        String containing the SQL Server to connect to.

    .PARAMETER Credential
        PSCredential object used for PsDscRunAsCredential.

    .PARAMETER MinMemory
        Int32 - Minimum memory, default 0. 

    .PARAMETER MaxMemory
        Int32 - Maximum memory, ignored if $DynamicAlloc = $true.

    .PARAMETER DynamicAlloc
        Switch - Sets max memory dynamically, set to true if MaxMemory is $null.
#>
function Set-SqlServerMemory
{
    [CmdletBinding()]
    param
    (
        [Parameter()]
        [ValidateNotNull()]
        [System.String]
        $SqlServer = $env:COMPUTERNAME,

        [Parameter()]
        [ValidateNotNull()]
        [System.Management.Automation.PSCredential]
        $Credential,

        [Parameter()]
        [ValidateRange("NonNegative")]
        [System.Int32]
        $MinMemory = 0,

        [Parameter()]
        [ValidateRange("Positive")]
        [System.Int32]
        $MaxMemory,

        [Parameter()]
        [ValidateNotNull()]
        [Switch]
        $DynamicAlloc
    )

    Write-Output "Checking SqlServerMemory: $SqlServer"

    if ($Credential) {
        $Server = Connect-Sql -SqlServer $SourceSqlServer -Credential $Credential
    }
    else {
        $Server = Connect-Sql -SqlServer $SourceSqlServer
    }
 
    $SqlServerMemoryParams = @{
        Ensure               = 'Present'
        ServerName           = $Server.NetName
        InstanceName         = $Server.InstanceName
        MinMemory            = $MinMemory
    }

    Write-Verbose -Message ("ServerName: {0}" -f $Server.NetName)
    Write-Verbose -Message ("InstanceName: {0}" -f $Server.InstanceName)
    Write-Verbose -Message ("MinMemory: {0}" -f $MinMemory)

    if ($DynamicAlloc -or [string]::IsNullOrEmpty($MaxMemory)) {
        $SqlServerMemoryParams.Add("DynamicAlloc",$true)
        Write-Verbose -Message ("DynamicAlloc: {0}" -f $true)
    }
    else {
        $SqlServerMemoryParams.Add("MaxMemory",$MaxMemory)
        Write-Verbose -Message ("MaxMemory: {0}" -f $MaxMemory)
    }

    if ($Credential) { 
        $SqlServerMemoryParams.Add("PsDscRunAsCredential",$Credential)
        Write-Verbose -Message ("PsDscRunAsCredential: {0}" -f $Credential.UserName)
    }

    if (Invoke-DscResource -ModuleName SqlServerDsc -Name SqlServerMemory -Property $SqlServerMemoryParams -Method Test) {
        Write-Output 'Skipping - already configured to desired state.'
    } 
    else {
        Write-Output 'Configuring to desired state.'
        Invoke-DscResource -ModuleName SqlServerDsc -Name SqlServerMemory -Property $SqlServerMemoryParams -Method Set -Verbose
    }

    Write-Output "Done."
}


