<#
    .SYNOPSIS
        Add one or many databases to an existing availability group. 

    .PARAMETER SqlServer
        String - containing the primary SQL Server, use listener name to guarantee primary.

    .PARAMETER AvailabilityGroupName
        String - AvailabilityGroupName: Availability group to add database(s) to. 

    .PARAMETER AutomatedBackupPreference
        [String] AutomatedBackupPreference (Write): Specifies the automated backup preference for the availability group. 
        When creating a group the default is 'None'. 
        { Primary | SecondaryOnly | Secondary | None }
    
    .PARAMETER AvailabilityMode
        [String] AvailabilityMode (Write): Specifies the replica availability mode. 
        Default when creating a group is 'AsynchronousCommit'. 
        { AsynchronousCommit | SynchronousCommit }
    
    .PARAMETER BackupPriority
        [UInt32] BackupPriority (Write): Specifies the desired priority of the replicas in performing backups. 
        The acceptable values for this parameter are: integers from 0 through 100. 
        Of the set of replicas which are online and available, the replica that has the highest priority performs the backup. 
        When creating a group the default is 50.
    
    .PARAMETER BasicAvailabilityGroup
        [Boolean] BasicAvailabilityGroup (Write): Specifies the type of availability group is Basic. 
        This is only available is SQL Server 2016 and later and is ignored when applied to previous versions.
    
    .PARAMETER DatabaseHealthTrigger
        [Boolean] DatabaseHealthTrigger (Write): Specifies if the option Database Level Health Detection is enabled. 
        This is only available is SQL Server 2016 and later and is ignored when applied to previous versions.
    
    .PARAMETER DtcSupportEnabled
        [Boolean] DtcSupportEnabled (Write): Specifies if the option Database DTC Support is enabled. 
        This is only available is SQL Server 2016 and later and is ignored when applied to previous versions. 
        This can't be altered once the Availability Group is created and is ignored if it is the case.
    
    .PARAMETER ConnectionModeInPrimaryRole
        [String] ConnectionModeInPrimaryRole (Write): Specifies how the availability replica handles connections 
        when in the primary role. 
        { AllowAllConnections | AllowReadWriteConnections }
    
    .PARAMETER ConnectionModeInSecondaryRole
        [String] ConnectionModeInSecondaryRole (Write): Specifies how the availability replica handles connections 
        when in the secondary role. 
        { AllowNoConnections | AllowReadIntentConnectionsOnly | AllowAllConnections }
    
    .PARAMETER EndpointHostName
        [String] EndpointHostName (Write): Specifies the hostname or IP address of the availability group replica endpoint. 
        Default is the instance network name.
    
    .PARAMETER FailureConditionLevel
        [String] FailureConditionLevel (Write): Specifies the automatic failover behavior of the availability group. 
        { OnServerDown | OnServerUnresponsive | OnCriticalServerErrors | OnModerateServerErrors | OnAnyQualifiedFailureCondition }
    
    .PARAMETER FailoverMode
        [String] FailoverMode (Write): Specifies the failover mode. When creating a group the default is 'Manual'. 
        { Automatic | Manual }
    
    .PARAMETER HealthCheckTimeout
        [UInt32] HealthCheckTimeout (Write): Specifies the length of time, in milliseconds, 
        after which AlwaysOn availability groups declare an unresponsive server to be unhealthy. 
        When creating a group the default is 30000.
    
    .PARAMETER ProcessOnlyOnActiveNode
        [Boolean] ProcessOnlyOnActiveNode (Write): Specifies that the resource will only determine if a change is needed 
        if the target node is the active host of the SQL Server Instance.

    .PARAMETER Credential
        PSCredential object to impersonate when connecting. 
        When username contains a domain, windows Auth is used, otherwise SQL auth is used. 
        If $null then integrated security is used.
#>
function Set-SqlAG
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
        $AvailabilityGroupName,
        
        [Parameter()]
        [ValidateNotNullOrEmpty()]
        [ValidateSet('Primary','SecondaryOnly','Secondary','None')]
        [System.String]
        $AutomatedBackupPreference,
        
        [Parameter()]
        [ValidateNotNullOrEmpty()]
        [ValidateSet('AsynchronousCommit','SynchronousCommit')]
        [System.String]
        $AvailabilityMode,
        
        [Parameter()]
        [ValidateNotNullOrEmpty()]
        [ValidateRange(0, 100)]
        [System.UInt32]
        $BackupPriority,

        [Parameter()]
        [ValidateNotNullOrEmpty()]
        [System.Boolean]
        $BasicAvailabilityGroup,
        
        [Parameter()]
        [ValidateNotNullOrEmpty()]
        [System.Boolean]
        $DatabaseHealthTrigger,

        [Parameter()]
        [ValidateNotNullOrEmpty()]
        [System.Boolean]
        $DtcSupportEnabled,
        
        [Parameter()]
        [ValidateNotNullOrEmpty()]
        [ValidateSet('AllowAllConnections','AllowReadWriteConnections')]
        [System.String]
        $ConnectionModeInPrimaryRole,
        
        [Parameter()]
        [ValidateNotNullOrEmpty()]
        [ValidateSet('AllowNoConnections','AllowReadIntentConnectionsOnly','AllowAllConnections')]
        [System.String]
        $ConnectionModeInSecondaryRole,
        
        [Parameter()]
        [ValidateNotNullOrEmpty()]
        [System.String]
        $EndpointHostName,

        [Parameter()]
        [ValidateNotNullOrEmpty()]
        [ValidateSet('OnServerDown','OnServerUnresponsive','OnCriticalServerErrors','OnModerateServerErrors','OnAnyQualifiedFailureCondition')]
        [System.String]
        $FailureConditionLevel = 'OnCriticalServerErrors',

        [Parameter()]
        [ValidateNotNullOrEmpty()]
        [ValidateSet('Automatic','Manual')]
        [System.String]
        $FailoverMode,
        
        [Parameter()]
        [ValidateNotNullOrEmpty()]
        [System.String]
        $HealthCheckTimeout,
        
        [Parameter()]
        [ValidateNotNullOrEmpty()]
        [System.Boolean]
        $ProcessOnlyOnActiveNode,
        
        [Parameter()]
        [ValidateNotNull()]
        [System.Management.Automation.PSCredential]
        $Credential
    )

    $ErrorActionPreference = 'STOP'

    if ($Credential) {
        $Smo = Connect-SqlServer -SqlServer $SqlServer -Credential $Credential
    }
    else {
        $Smo = Connect-SqlServer -SqlServer $SqlServer
    }

    $ServerName = $Smo.NetName
    $InstanceName = $Smo.InstanceName

    <# Add the required cluster service login #>
    $SqlServerLogin = @{
        Ensure       = 'Present'
        Name         = 'NT SERVICE\ClusSvc'
        LoginType    = 'WindowsUser'
        ServerName   = $ServerName
        InstanceName = $InstanceName
    }

    if ($Credential) { $SqlServerLogin.Add('PsDscRunAsCredential',$Credential) }

    if (Invoke-DscResource -ModuleName SqlServerDsc -Name SqlServerLogin -Property $SqlServerLogin -Method Test) {
        Write-Output "In desired state - SqlServerLogin reported to be in desired state." 
    }
    else {
        Write-Output "Configuring SqlServerLogin to desired state."
        Invoke-DscResource -ModuleName SqlServerDsc -Name SqlServerLogin -Property $SqlServerLogin -Method Set
    }

    <# Add the required permissions to the cluster service login #>
    $SqlServerPermission = @{
        Ensure       = 'Present'
        ServerName   = $ServerName
        InstanceName = $InstanceName
        Principal    = 'NT SERVICE\ClusSvc'
        Permission   = 'AlterAnyAvailabilityGroup', 'ViewServerState'
    }

    if ($Credential) { $SqlServerPermission.Add('PsDscRunAsCredential',$Credential) }

    if (Invoke-DscResource -ModuleName SqlServerDsc -Name SqlServerPermission -Property $SqlServerPermission -Method Test) {
        Write-Output "In desired state - SqlServerPermission reported to be in desired state." 
    }
    else {
        Write-Output "Configuring SqlServerPermission to desired state."
        Invoke-DscResource -ModuleName SqlServerDsc -Name SqlServerPermission -Property $SqlServerPermission -Method Set
    }

    <# Create a DatabaseMirroring endpoint #>
    $SqlServerEndpoint = @{
        EndPointName = 'HADR'
        Ensure       = 'Present'
        Port         = 5022
        ServerName   = $ServerName
        InstanceName = $InstanceName
    }

    if ($Credential) { $SqlServerEndpoint.Add('PsDscRunAsCredential',$Credential) }

    if (Invoke-DscResource -ModuleName SqlServerDsc -Name SqlServerEndpoint -Property $SqlServerEndpoint -Method Test) {
        Write-Output "In desired state - SqlServerEndpoint reported to be in desired state." 
    }
    else {
        Write-Output "Configuring SqlServerEndpoint to desired state."
        Invoke-DscResource -ModuleName SqlServerDsc -Name SqlServerEndpoint -Property $SqlServerEndpoint -Method Set
    }

    <# Enable the AlwaysOn service #>
    $SqlAlwaysOnService = @{
        Ensure       = 'Present'
        ServerName   = $ServerName
        InstanceName = $InstanceName
    }

    if ($Credential) { $SqlAlwaysOnService.Add('PsDscRunAsCredential',$Credential) }

    if (Invoke-DscResource -ModuleName SqlServerDsc -Name SqlAlwaysOnService -Property $SqlAlwaysOnService -Method Test) {
        Write-Output "In desired state - SqlAlwaysOnService reported to be in desired state." 
    }
    else {
        Write-Output "Configuring SqlAlwaysOnService to desired state."
        Invoke-DscResource -ModuleName SqlServerDsc -Name SqlAlwaysOnService -Property $SqlAlwaysOnService -Method Set
    }

    <# Configure the SQL availability group #>
    $SqlAG = {
        Name         = $AvailabilityGroupName
        ServerName   = $ServerName
        InstanceName = $InstanceName
        Ensure       = 'Present'
    }

    if ($Credential) { $SqlAG.Add('PsDscRunAsCredential',$Credential) }
    if ($ProcessOnlyOnActiveNode) { $SqlAG.Add('ProcessOnlyOnActiveNode',$ProcessOnlyOnActiveNode) }
    if ($AutomatedBackupPreference) { $SqlAG.Add('AutomatedBackupPreference',$AutomatedBackupPreference) }
    if ($AvailabilityMode) { $SqlAG.Add('AvailabilityMode',$AvailabilityMode) }
    if ($BackupPriority) { $SqlAG.Add('BackupPriority',$BackupPriority) }
    if ($ConnectionModeInPrimaryRole) { $SqlAG.Add('ConnectionModeInPrimaryRole',$ConnectionModeInPrimaryRole) }
    if ($ConnectionModeInSecondaryRole) { $SqlAG.Add('ConnectionModeInSecondaryRole',$ConnectionModeInSecondaryRole) }
    if ($FailoverMode) { $SqlAG.Add('FailoverMode',$FailoverMode) }
    if ($HealthCheckTimeout) { $SqlAG.Add('HealthCheckTimeout',$HealthCheckTimeout) }
    if ($BasicAvailabilityGroup) { $SqlAG.Add('BasicAvailabilityGroup',$BasicAvailabilityGroup) }
    if ($DatabaseHealthTrigger) { $SqlAG.Add('DatabaseHealthTrigger',$DatabaseHealthTrigger) }
    if ($DtcSupportEnabled) { $SqlAG.Add('DtcSupportEnabled',$DtcSupportEnabled) }

    if (Invoke-DscResource -ModuleName SqlServerDsc -Name SqlAG -Property $SqlAG -Method Test) {
        Write-Output "In desired state - SqlAG reported to be in desired state." 
    }
    else {
        Write-Output "Configuring SqlAG to desired state."
        Invoke-DscResource -ModuleName SqlServerDsc -Name SqlAG -Property $SqlAG -Method Set
    }
}