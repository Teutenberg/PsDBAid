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
function Set-SqlServerMaxDop
{
    [CmdletBinding()]
    param
    (
        [Parameter()]
        [ValidateNotNull()]
        [System.String]
        $SqlServer = $env:COMPUTERNAME,

        [Parameter()]
        [ValidateRange("NonNegative")]
        [System.Int32]
        $MaxDop,

        [Parameter()]
        [ValidateNotNull()]
        [Switch]
        $DynamicAlloc,

        [Parameter()]
        [ValidateNotNull()]
        [System.Management.Automation.PSCredential]
        $Credential
    )

    Write-Output "Checking SqlServerMaxDop: $SqlServer"

    if ($Credential) {
        $Server = Connect-SqlServer -SqlServer $SourceSqlServer -Credential $Credential
    }
    else {
        $Server = Connect-SqlServer -SqlServer $SourceSqlServer
    }

    $SqlMaxDopParams = @{
        ServerName     = $Server.NetName
        InstanceName   = $Server.InstanceName
    }

    Write-Verbose -Message ("ServerName: {0}" -f $Server.NetName)
    Write-Verbose -Message ("InstanceName: {0}" -f $Server.InstanceName)

    if ($Credential) { 
        $SqlMaxDopParams.Add("PsDscRunAsCredential",$Credential)
        Write-Verbose -Message ("PsDscRunAsCredential: {0}" -f $Credential.UserName)
    }

    if ($DynamicAlloc -or [string]::IsNullOrEmpty($MaxDop)) {
        $SqlMaxDopParams.Add('DynamicAlloc', $true)
        Write-Verbose -Message ("DynamicAlloc: {0}" -f $true)
    }
    elseif ($MaxDop -ge 0) {
        $SqlMaxDopParams.Add('MaxDop', $MaxDop)
        Write-Verbose -Message ("MaxDop: {0}" -f $MaxDop)
    }
    
    if (Invoke-DscResource -ModuleName SqlServerDsc -Name SqlServerMaxDop -Property $SqlMaxDopParams -Method Test) {
        Write-Output 'In desired state - SqlServerMaxDop reported to be in desired state.'
    } 
    else {
        Write-Output "Configuring SqlServerMaxDop to desired state."
        Invoke-DscResource -ModuleName SqlServerDsc -Name SqlServerMaxDop -Property $SqlMaxDopParams -Method Set -Verbose
    }

    Write-Output "Done."
}
