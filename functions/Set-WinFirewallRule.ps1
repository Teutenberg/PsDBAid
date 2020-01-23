<#
    .SYNOPSIS
        Add local firewall rule on server.

    .PARAMETER RuleName
        String - Firewall rule name.

    .PARAMETER Protocol
        String - TCP or UDP.

    .PARAMETER LocalPorts
        String[] - LocalPort string array.
#>
function Set-WinFirewallRule
{
    [CmdletBinding()]
    param
    (
        [Parameter(Mandatory)]
        [ValidateNotNull()]
        [System.String]
        $RuleName,

        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [ValidateSet('TCP','UDP')]
        [System.String]
        $Protocol,

        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [System.String[]]
        $LocalPorts
    )

    if (Get-NetFirewallRule | Where-Object { $_.DisplayName -ilike $RuleName }) {
        Write-Verbose "Firewall rule for '$RuleName' already exists..."
    }
    else {
        New-NetFirewallRule -DisplayName $RuleName -Direction Inbound -Profile Domain -Action Allow -Protocol $Protocol -LocalPort $LocalPorts -RemoteAddress Any
        Write-Verbose "Firewall rule '$RuleName' allow any inbound domain on local port '$LocalPorts' created successfully."
    }
}