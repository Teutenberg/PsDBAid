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
function Set-CisHardening
{
    [CmdletBinding()]
    param
    (
        [Parameter()]
        [ValidateNotNull()]
        [System.String]
        $SqlServer = $env:COMPUTERNAME,

        [Parameter()]
        [Switch]
        $HideInstance,

        [Parameter()]
        [ValidatePattern('^[a-zA-Z0-9]+$')]
        [System.String]
        $NewSaLoginName,

        [Parameter()]
        [Switch]
        $IncreaseNumOfErrorLogs,

        [Parameter()]
        [Switch]
        $EnableServerAudit,

        [Parameter()]
        [ValidateNotNull()]
        [System.Management.Automation.PSCredential]
        $Credential
    )

    Write-Output "Setting CIS Hardening Standard: $SqlServer"

    if ($Credential) {
        $Server = Connect-SqlServer -SqlServer $SourceSqlServer -Credential $Credential
    }
    else {
        $Server = Connect-SqlServer -SqlServer $SourceSqlServer
    }

    Write-Verbose -Message ("HideInstance: {0}" -f $HideInstance)
    Write-Verbose -Message ("NewSaLoginName: {0}" -f $NewSaLoginName)
    Write-Verbose -Message ("IncreaseNumOfErrorLogs: {0}" -f $IncreaseNumOfErrorLogs)
    Write-Verbose -Message ("EnableServerAudit: {0}" -f $EnableServerAudit)

    if ($HideInstance) {
        $NameSpace = 'Root\Microsoft\SqlServer\ComputerManagement' +  $Server.VersionMajor

        $WmiParams = @{
            ComputerName = $Server.NetName
            Namespace    = $NameSpace
            Class        = 'ServerSettingsGeneralFlag'
        }

        if ($Credential) {
            $WmiParams.Add('Credential',$Credential)
        }

        $wmi = Get-WmiObject @WmiParams | Where-Object { $_.FlagName -eq "HideInstance" -and $_.InstanceName -eq $SQLInstanceName }
        $wmi.SetValue($true) | Out-Null
    }

    if ($NewSaLoginName) {
        $NewSaLoginNameCmd = "IF EXISTS (SELECT [name] FROM sys.server_principals WHERE [name] = 'sa' AND [sid] = 0x01) ALTER LOGIN [sa] WITH NAME = [$NewSaLoginName];"
        $Server.Databases['master'].ExecuteNonQuery($NewSaLoginNameCmd)
    }

    if ($IncreaseNumOfErrorLogs) {
        $IncreaseNumOfErrorLogsCmd = "EXEC master.sys.xp_instance_regwrite N'HKEY_LOCAL_MACHINE', N'Software\Microsoft\MSSQLServer\MSSQLServer', N'NumErrorLogs', REG_DWORD, 12"
        $Server.Databases['master'].ExecuteNonQuery($IncreaseNumOfErrorLogsCmd)
    }

    if ($EnableServerAudit) {
        $ErrorLogPath = $Server.ErrorLogPath
        $EnableServerAuditCmd = "IF NOT EXISTS (SELECT * FROM sys.server_audits WHERE name = N'ServerAudit')
        CREATE SERVER AUDIT [ServerAudit]
        TO FILE (FILEPATH=N'$ErrorLogPath',MAXSIZE=1024MB,MAX_ROLLOVER_FILES=10,RESERVE_DISK_SPACE=ON)
        WITH (QUEUE_DELAY=1000,ON_FAILURE=CONTINUE),STATE=ON;
        IF NOT EXISTS (SELECT * FROM sys.server_audit_specifications WHERE name = N'ServerAuditSpecification')
        CREATE SERVER AUDIT SPECIFICATION [ServerAuditSpecification]
        FOR SERVER AUDIT [ServerAudit]
            ADD (AUDIT_CHANGE_GROUP),
            ADD (DATABASE_CHANGE_GROUP),
            ADD (DATABASE_PRINCIPAL_CHANGE_GROUP),
            ADD (DATABASE_ROLE_MEMBER_CHANGE_GROUP),
            ADD (DBCC_GROUP),
            ADD (FAILED_DATABASE_AUTHENTICATION_GROUP),
            ADD (FAILED_LOGIN_GROUP),
            ADD (SERVER_OBJECT_CHANGE_GROUP),
            ADD (SERVER_OBJECT_OWNERSHIP_CHANGE_GROUP),
            ADD (SERVER_OBJECT_PERMISSION_CHANGE_GROUP),
            ADD (SERVER_PERMISSION_CHANGE_GROUP),
            ADD (SERVER_PRINCIPAL_CHANGE_GROUP),
            ADD (SERVER_ROLE_MEMBER_CHANGE_GROUP),
            ADD (SERVER_ROLE_MEMBER_CHANGE_GROUP),
            ADD (SERVER_STATE_CHANGE_GROUP),
            ADD (SUCCESSFUL_DATABASE_AUTHENTICATION_GROUP),
            ADD (SUCCESSFUL_LOGIN_GROUP)
        WITH (STATE = ON);"
    
        $Server.Databases['master'].ExecuteNonQuery($EnableServerAuditCmd)
    }

    Write-Output "Done."
}
