<#
    .SYNOPSIS
        Connect to a computer and returns the SQL Service information. 

    .PARAMETER ComputerName
        String containing the Computer where you want to get CIM instance from.

    .PARAMETER SqlClass
        String containing the CIM SQL class you want.
    
    .PARAMETER Filter
        String - CIM filter.

    .PARAMETER Credential
        PSCredential object to impersonate when connecting. 
#>
function Get-SqlCimInstance
{
    [CmdletBinding()]
    param
    (
        [Parameter()]
        [ValidateNotNull()]
        [System.String]
        $ComputerName = $env:COMPUTERNAME,

        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [System.String]
        $SqlClass,

        [Parameter()]
        [System.String]
        $Filter,

        [Parameter()]
        [ValidateNotNull()]
        [System.Management.Automation.PSCredential]
        $Credential
    )

    if ($Credential) {
        $Server = Connect-SqlServer -SqlServer $SourceSqlServer -Credential $Credential
        $CimSession = New-CimSession -ComputerName $ComputerName -Credential $Credential
    }
    else {
        $Server = Connect-SqlServer -SqlServer $SourceSqlServer
        $CimSession = New-CimSession -ComputerName $ComputerName
    }

    $NameSpace = 'Root\Microsoft\SqlServer\ComputerManagement' +  $Server.VersionMajor
    
    $CimInstanceParams = @{
        CimSession = $CimSession
        Namespace  = $NameSpace
        Class      = $SqlClass
    }

    if ($Filter) {
        $CimInstanceParams.Add('Filter',$Filter)
    }

    $CimInstance = Get-CimInstance @CimInstanceParams

    Remove-CimSession -CimSession $CimSession
    return $CimInstance
}