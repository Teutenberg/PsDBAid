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