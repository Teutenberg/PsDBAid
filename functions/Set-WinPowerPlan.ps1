<#
    .SYNOPSIS
        Set the Windows OS Power Plan. 
#>
function Set-WinPowerPlan
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
        [ValidateSet('High Performance','Balanced','Power saver')]
        [System.String]
        $PowerPlan = 'High Performance',

        [Parameter()]
        [ValidateNotNull()]
        [System.Management.Automation.PSCredential]
        $Credential
    )

    $PowerPlan = Get-CimInstance -Name 'root\cimv2\power' -ClassName 'Win32_PowerPlan' -Filter "ElementName = '$PowerPlan'"
    
    if ($PowerPlan.IsActive -ieq 'True') {
        Write-Output "In desired state - $PowerPlan is already active..."
    }
    else {
        Invoke-CimMethod -InputObject $PowerPlan -MethodName Activate | Out-Null
        Write-Output "Activated $PowerPlan."
    }
}