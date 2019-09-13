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
        $Server = Connect-Sql -SqlServer $SourceSqlServer -Credential $Credential
    }
    else {
        $Server = Connect-Sql -SqlServer $SourceSqlServer
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
        Write-Output 'Skipping - already configured to desired state.'
    } 
    else {
        Write-Output "Configuring to desired state."
        Invoke-DscResource -ModuleName SqlServerDsc -Name SqlServerMaxDop -Property $SqlMaxDopParams -Method Set -Verbose
    }

    Write-Output "Done."
}


<#
    .SYNOPSIS
        Compares logins between SQL Servers and adds missing logins and server roles and server object permissions. This is a useful function to keep Availability Group cluster logins synced.

    .PARAMETER SourceSqlServer
        String containing the source SQL Server where the logins and permissions are to be copied from.

    .PARAMETER DestinationSqlServers
        String array containing the list of destination SQL Servers where the logins and permissions are to be copied to.

    .PARAMETER Credential
        PSCredential object with the credentials to use to impersonate a user when connecting.
        If this is not provided then the current user will be used to connect to the SQL Server Database Engine instance.

    .PARAMETER Filter
        String filter returns only logins like pattern. Default value = "*"

    .PARAMETER Include
        String array of logins that will be included. 

    .PARAMETER Exclude
        String array of logins that will be excluded. 
#>
function Copy-Login
{
    [CmdletBinding()]
    param
    (
        [Parameter(Mandatory=$true)]
        [ValidateNotNull()]
        [System.String]
        $SourceSqlServer,

        [Parameter(Mandatory=$true)]
        [ValidateNotNull()]
        [System.String[]]
        $DestinationSqlServers,

        [Parameter()]
        [ValidateNotNull()]
        [System.Management.Automation.PSCredential]
        $Credential,

        [Parameter()]
        [System.String]
        $Filter = "*",

        [Parameter()]
        [System.String[]]
        $Include,

        [Parameter()]
        [System.String[]]
        $Exclude
    )
    
    $SourceServer = Connect-Sql -SqlServer $SourceSqlServer -Credential $Credential
    $SourceLogins = $SourceServer.Logins.Where({ $_.Sid -ne 1 -and $_.Name -notlike "##*" -and $_.Name -notin $Exclude -and ($_.Name -ilike $Filter -or $_Name -iin $Include) })

    Write-Output -Message "Copying logins from source to destinations..."
    Write-Output -Message "Connected to source server: $SourceSqlServer"
    Write-Verbose -Message "Source logins to be copied:"
    $SourceLogins | ForEach-Object { Write-Verbose -Message "`t$($_.Name)" }

    foreach ($DestSqlServer in $DestinationSqlServers) {
        $DestServer = Connect-Sql -SqlServer $DestSqlServer -Credential $Credential
        
        Write-Output -Message "Connected to destination server: $DestSqlServer"
        
        foreach ($SourceLogin in $SourceLogins) {
            $SourceLogin.Refresh()
            $DestLogin = New-Object -TypeName Microsoft.SqlServer.Management.Smo.Login -ArgumentList $DestServer, $SourceLogin.Name
            $DestLogin.Refresh()

            if (-not $DestLogin.CreateDate) {
                $DestLogin.LoginType = $SourceLogin.LoginType

                if ($SourceLogin.LoginType -eq "WindowsUser") {
                    $DestLogin.Create("")
                    Write-Verbose -Message "Created Windows login: $($DestLogin.Name)"
                }
                elseif ($SourceLogin.LoginType -eq "SqlLogin") {
                    $SqlLoginHash = $SourceServer.Databases['master'].ExecuteWithResults("SELECT [Hash]=CONVERT(NVARCHAR(512), LOGINPROPERTY(N'$($SourceLogin.Name)','PASSWORDHASH'), 1)").Tables.Hash
                    $DestLogin.Create($SqlLoginHash, [Microsoft.SqlServer.Management.Smo.LoginCreateOptions]::IsHashed)
                    Write-Verbose -Message "Created SQL login: $($DestLogin.Name)"
                }
            }
            else {
                Write-Verbose -Message "Login already exists: $($DestLogin.Name)"
            }
    
            foreach ($ServerPermission in $SourceServer.enumServerPermissions($SourceLogin.Name).PermissionType) {
                $DestServer.Grant($ServerPermission, $DestLogin.Name)
                Write-Verbose -Message "Granted server permission [$ServerPermission] to login [$($DestLogin.Name)]"
            }

            foreach ($ServerRole in $SourceLogin.ListMembers()) {
                $DestLogin.AddToRole($ServerRole)
                Write-Verbose -Message "Granted server role [$ServerRole] to login [$($DestLogin.Name)]"
            }
        }
    }

    Write-Output -Message "Copying logins completed..."
}


<#
    .SYNOPSIS
        Backup the service master key to a file.

    .PARAMETER SqlServer
        String - SQL Server HOST\INSTANCE,PORT.

    .PARAMETER Path
        String - path where you want to save the file. 

    .PARAMETER Secret
        String - alphanumeric secret used to protect key file. 

    .PARAMETER Credential
        PSCredential object with the credentials to use to impersonate a user when connecting.
        If this is not provided then the current user will be used to connect to the SQL Server Database Engine instance.
#>
function Backup-ServiceMasterKey
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
        [ValidatePattern('^(\w:\\)[a-zA-Z0-9:\\\/ .!@#$%^&()\-_+=]*')]
        [System.String]
        $Path,

        [Parameter()]
        [ValidateNotNullOrEmpty()]
        [ValidatePattern('^[a-zA-Z0-9]+$')]
        [ValidateLength(8,100)]
        [System.String]
        $Secret,

        [Parameter()]
        [ValidateNotNull()]
        [System.Management.Automation.PSCredential]
        $Credential
    )
    
    if ($Credential) {
        $Server = Connect-Sql -SqlServer $SqlServer -Credential $Credential
    }
    else {
        $Server = Connect-Sql -SqlServer $SqlServer
    }

    if ([String]::IsNullOrEmpty($Path)) { $Path = $Server.BackupDirectory } 
    $FileName = $Server.NetName + '@' + $Server.InstanceName + '.smk'
    $BackupFile = [System.IO.Path]::Combine($Path, $FileName)
    $BackupCommand = "BACKUP SERVICE MASTER KEY TO FILE = '$BackupFile' ENCRYPTION BY PASSWORD = '$Secret';"
    Remove-Variable Secret -Force

    $RemoveItemParams = @{ 
        ComputerName  = $Server.NetName 
        ScriptBlock   = { if (Test-Path $Using:BackupFile) { 
                Remove-Item $Using:BackupFile
                Write-Output -Message "Removed existing backup: '$Using:BackupFile'."
            } 
        }
    }

    if ($Credential) { $RemoveItemParams.Add('Credential', $Credential) }

    <# Remove existing backup file otherwise backup will fail. #>
    Invoke-Command @RemoveItemParams

    Write-Verbose -Message "Attempting to backup service master key to file '$BackupFile'."
    <# Backup service master key to file. #>
    $Server.Databases['master'].ExecuteNonQuery($BackupCommand)
    
    Remove-Variable BackupCommand -Force

    $TestPathParams = @{ 
        ComputerName  = $Server.NetName 
        ScriptBlock   = { if (Test-Path $Using:BackupFile) { 
                Write-Output "Backup successful: $Using:BackupFile" 
            } 
            else { 
                Write-Error "Failed to backup file or file check failed..." 
            } 
        }
    }

    if ($Credential) { $TestPathParams.Add('Credential', $Credential) }
    
    Invoke-Command @TestPathParams
}
