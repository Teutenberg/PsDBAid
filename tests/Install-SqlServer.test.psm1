
<#
    .SYNOPSIS
        Connect to a SQL Server Database Engine and return the server object.

    .PARAMETER ServerName
        String containing the host name of the SQL Server to connect to.

    .PARAMETER InstanceName
        String containing the SQL Server Database Engine instance to connect to.

    .PARAMETER Credential
        PSCredential object with the credentials to use to impersonate a user when connecting.
        If this is not provided then the current user will be used to connect to the SQL Server Database Engine instance.

    .PARAMETER StatementTimeout
        Set the query StatementTimeout in seconds. Default 600 seconds (10mins).
#>
function Install-SqlServer
{
    [CmdletBinding()]
    param
    (
        [Parameter(Mandatory=$true)]
        [ValidateNotNull()]
        [System.String]
        $SqlSetupPath,

        [Parameter(Mandatory=$true)]
        [ValidateNotNull()]
        [System.String]
        $InstanceName,
        
        [Parameter()]
        [ValidateNotNull()]
        [System.String]
        $ProductKey,

        [Parameter()]
        [ValidateNotNull()]
        [System.String]
        $Collation = 'Latin1_General_CI_AS',

        [Parameter()]
        [ValidateNotNull()]
        [System.String]
        $PathInstanceData = 'C:\Program Files\Microsoft SQL Server',

        [Parameter()]
        [ValidateNotNull()]
        [System.String]
        $PathUserData = 'C:\Program Files\Microsoft SQL Server',

        [Parameter()]
        [ValidateNotNull()]
        [System.String]
        $PathUserLog = 'C:\Program Files\Microsoft SQL Server',

        [Parameter()]
        [ValidateNotNull()]
        [System.String]
        $PathTempData = 'C:\Program Files\Microsoft SQL Server',

        [Parameter()]
        [ValidateNotNull()]
        [System.String]
        $PathTempLog = 'C:\Program Files\Microsoft SQL Server',

        [Parameter()]
        [ValidateNotNull()]
        [System.String]
        $PathBackupData = 'C:\Program Files\Microsoft SQL Server',

        [Parameter()]
        [ValidateNotNull()]
        [System.String[]]
        $SysAdminAccounts = [System.Security.Principal.WindowsIdentity]::GetCurrent().Name,

        [Parameter()]
        [ValidateNotNull()]
        [System.Management.Automation.PSCredential]
        $Credential
    )
    # If path is root, add extra \ - e.g. D:\\
    $PathInstanceData = ($PathInstanceData.Trim('\')).ForEach({ if ($_.EndsWith(':')) { "$_\\" } else { $_ }})[0]

    # Get the setup.exe major product version
    $SqlSetupExe = Get-Item -Path "$SqlSetupPath\setup.exe"

    if ($SqlSetupExe) {
        Write-Output "Initiating SqlSetup..."

        $SQLMajorVersion = $SqlSetupExe.VersionInfo.ProductVersion.Split('.')[0]
        
        # Create SqlSetup parameter hastable
        $SqlSetupParams = @{
            SourcePath                 = $SqlSetupPath
            ProductKey                 = $ProductKey
            InstanceName               = $InstanceName
            Features                   = 'SQLEngine,Conn'
            SQLCollation               = $Collation
            SQLSysAdminAccounts        = $SysAdminAccounts
            InstallSharedDir           = 'C:\Program Files\Microsoft SQL Server'
            InstallSharedWOWDir        = 'C:\Program Files (x86)\Microsoft SQL Server'
            InstanceDir                = 'C:\Program Files\Microsoft SQL Server'
            InstallSQLDataDir          = $PathInstanceData
            SQLUserDBDir               = (Join-Path $PathUserData "MSSQL$SQLMajorVersion.$InstanceName\MSSQL\DATA")
            SQLUserDBLogDir            = (Join-Path $PathUserLog  "MSSQL$SQLMajorVersion.$InstanceName\MSSQL\LOG")
            SQLTempDBDir               = (Join-Path $PathTempData "MSSQL$SQLMajorVersion.$InstanceName\MSSQL\TEMPDB")
            SQLTempDBLogDir            = (Join-Path $PathTempLog "MSSQL$SQLMajorVersion.$InstanceName\MSSQL\TEMPDB")
            SQLBackupDir               = (Join-Path $PathBackupData  "MSSQL$SQLMajorVersion.$InstanceName\MSSQL\BACKUP")
            UpdateEnabled              = 'True'
            UpdateSource               = 'MU'
            ForceReboot                = $false
            PsDscRunAsCredential       = $Credential
        }

        if (Invoke-DscResource -ModuleName 'SqlServerDsc' -Name 'SqlSetup' -Property $SqlSetupParams -Method Test) {
            Write-Verbose "Instance with name [$InstanceName] is already installed. Skipping installation..."
        } else {
            Write-Verbose "Installing instance [$InstanceName]"
            Invoke-DscResource -ModuleName 'SqlServerDsc' -Name 'SqlSetup' -Property $SqlSetupParams -Method Set -Verbose
        }
    } else {
        Write-Error "'$SqlSetupPath\setup.exe' not found! Please check that SqlSetupPath is correct."
    }

    Write-Output 'Done.'
}
