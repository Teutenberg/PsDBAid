<#
    .SYNOPSIS
        Add one or many databases to an existing availability group. 

    .PARAMETER SqlServer
        String - containing the primary SQL Server, use listener name to guarantee primary.

    .PARAMETER AvailabilityGroupName
        String - Availability group to add database(s) to. 

    .PARAMETER DatabaseName
        String[] - Database(s) to add to availability group. 

    .PARAMETER AssertState
        Boolean - Assert the state as defined by this function. 
        Other databases in the availability group not in the list provided will be removed. 
        Default $false.

    .PARAMETER Credential
        PSCredential object to impersonate when connecting. 
        When username contains a domain, windows Auth is used, otherwise SQL auth is used. 
        If $null then integrated security is used.
#>
function Set-SqlAGDatabase
{
    [CmdletBinding()]
    param
    (
        [Parameter()]
        [ValidateNotNull()]
        [System.String]
        $SqlServer = $env:COMPUTERNAME,

        [Parameter()]
        [ValidateNotNullOrEmpty()]
        [System.String]
        $AvailabilityGroupName,

        [Parameter()]
        [ValidateNotNullOrEmpty()]
        [System.String[]]
        $DatabaseName,

        [Parameter()]
        [ValidateNotNullOrEmpty()]
        [System.Boolean]
        $AssertState = $false,

        [Parameter()]
        [ValidateNotNull()]
        [System.Management.Automation.PSCredential]
        $Credential
    )

    $ErrorActionPreference = 'STOP'

    if ($Credential) {
        $PrimaryServer = Connect-SqlServer -SqlServer $SqlServer -Credential $Credential
    }
    else {
        $PrimaryServer = Connect-SqlServer -SqlServer $SqlServer
    }

    $PrimaryComputerName = $PrimaryServer.NetName
    $AvailabilityGroup = $PrimaryServer.AvailabilityGroups[$AvailabilityGroupName]
    $AvailabilityReplicas = $AvailabilityGroup.AvailabilityReplicas
    $PrimaryReplica = $AvailabilityReplicas | Where-Object { $_.Role -ieq 'Primary' } | Select-Object -ExpandProperty Name
    $SecondaryReplicas = $AvailabilityReplicas | Where-Object { $_.Role -ieq 'Secondary' } | Select-Object -ExpandProperty Name
    $SqlServiceAccounts = @($PrimaryServer.ServiceAccount) 
    $SqlShareDirectory = [IO.Path]::Combine($Server.BackupDirectory, $AvailabilityGroup.Name)

    if ($PrimaryReplica -inotmatch $PrimaryComputerName) {
        Write-Output "Not the primary replica, aborting. Try using the listener to connect."
        return
    }

    foreach ($Replica in $SecondaryReplicas) {
        if ($Credential) {
            $SecondaryServer = Connect-SqlServer -SqlServer $Replica -Credential $Credential
        }
        else {
            $SecondaryServer = Connect-SqlServer -SqlServer $Replica
        }

        $SqlServiceAccounts += $SecondaryServer.ServiceAccount
    }

    Write-Verbose -Message ("Creating AG backup share: {0}" -f $SqlShareDirectory)
    Set-WinSmbShare -ComputerName $PrimaryComputerName -Directory $SqlShareDirectory -ShareName $AvailabilityGroup.Name -ShareAccounts $SqlServiceAccounts

    foreach ($Database in $DatabaseName) {
        $db = $PrimaryServer.Databases[$Database]

        if ($db.RecoveryModel -ieq 'Simple') {
            $db.RecoveryModel = 'Full'
            $db.DatabaseOptions.Alter()

            Write-Verbose -Message ("Setting database to FULL recovery model: {0}" -f $db.Name)
            Write-Verbose -Message "Backing up database to NUL device."

            $db.ExecuteNonQuery("BACKUP DATABASE $Database TO DISK = N'nul'")
        }
    }

    $SqlAGDatabaseParams = @{
        AvailabilityGroupName   = $AvailabilityGroup.Name
        BackupPath              = $SqlShareDirectory
        DatabaseName            = $DatabaseName
        InstanceName            = $PrimaryServer.InstanceName
        ServerName              = $PrimaryServer.NetName
        MatchDatabaseOwner      = $true
        ReplaceExisting         = $true
        Force                   = $AssertState
        Ensure                  = 'Present'
        PsDscRunAsCredential    = $SqlAdministratorCredential
    }

    Write-Verbose -Message ("AvailabilityGroupName: {0}" -f $AvailabilityGroup.Name)
    Write-Verbose -Message ("BackupPath: {0}" -f $SqlShareDirectory)
    Write-Verbose -Message ("DatabaseName: {0}" -f $DatabaseName)
    Write-Verbose -Message ("InstanceName: {0}" -f $PrimaryServer.InstanceName)
    Write-Verbose -Message ("ServerName: {0}" -f $PrimaryServer.NetName)

    if ($Credential) { 
        $SqlAGDatabaseParams.Add("PsDscRunAsCredential",$Credential)
        Write-Verbose -Message ("PsDscRunAsCredential: {0}" -f $Credential.UserName)
    }

    if (Invoke-DscResource -ModuleName SqlServerDsc -Name SqlAGDatabase -Property $SqlAGDatabaseParams -Method Test) {
        Write-Output "In desired state - SqlAGDatabase reported to be in desired state." 
    }
    else {
        Write-Output "Configuring SqlAGDatabase to desired state."
        Invoke-DscResource -ModuleName SqlServerDsc -Name SqlAGDatabase -Property $SqlAGDatabaseParams -Method Set
    }
}