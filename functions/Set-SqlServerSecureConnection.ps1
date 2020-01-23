<#
    .SYNOPSIS
        Set the SQL Service network certificate. 

    .PARAMETER SqlServer
        String  - SQL Server to connect to, HOST\INSTANCE.
    
    .PARAMETER CertificateThumbprint
        String - Certificate thumbprint guid.
    
    .PARAMETER ForceEncryption
        Switch - Force connections to be encypted. 
    
    .PARAMETER SuppressRestart
        Switch - Supress restarting the service. Change will not take effect until the service is restarted. 

    .PARAMETER Credential
        PSCredential object used for PsDscRunAsCredential.
#>
function Set-SqlServerSecureConnection
{
    [CmdletBinding()]
    param
    (
        [Parameter()]
        [ValidateNotNull()]
        [System.String]
        $SqlServer = $env:COMPUTERNAME,

        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [System.String]
        $CertificateThumbprint,

        [Parameter()]
        [Switch]
        $ForceEncryption,

        [Parameter()]
        [Switch]
        $SuppressRestart,

        [Parameter()]
        [ValidateNotNull()]
        [System.Management.Automation.PSCredential]
        $Credential
    )

    Write-Output "Checking SqlServerSecureConnection: $SqlServer"

    if ($Credential) {
        $Server = Connect-SqlServer -SqlServer $SourceSqlServer -Credential $Credential
    }
    else {
        $Server = Connect-SqlServer -SqlServer $SourceSqlServer
    }

    $SqlSecureParams = @{
        InstanceName   = $Server.InstanceName
        ServiceAccount = $Server.ServiceAccount
    }

    Write-Verbose -Message ("InstanceName: {0}" -f $Server.InstanceName)
    Write-Verbose -Message ("ServiceAccount: {0}" -f $Server.ServiceAccount)

    if ($Credential) { 
        $SqlSecureParams.Add("PsDscRunAsCredential",$Credential)
        Write-Verbose -Message ("PsDscRunAsCredential: {0}" -f $Credential.UserName)
    }

    if ($ForceEncryption) {
        $SqlSecureParams.Add('ForceEncryption', $true)
        Write-Verbose -Message ("ForceEncryption: {0}" -f $true)
    }
    
    if ($SuppressRestart -ge 0) {
        $SqlSecureParams.Add('SuppressRestart', $true)
        Write-Verbose -Message ("SuppressRestart: {0}" -f $true)
    }
    
    if (Invoke-DscResource -ModuleName SqlServerDsc -Name SqlServerSecureConnection -Property $SqlSecureParams -Method Test) {
        Write-Output 'In desired state - SqlServerSecureConnection reports to be in desired state.'
    }
    else {
        Write-Output "Configuring SqlServerSecureConnection to desired state."
        Invoke-DscResource -ModuleName SqlServerDsc -Name SqlServerSecureConnection -Property $SqlSecureParams -Method Set -Verbose
    }

    Write-Output "Done."
}