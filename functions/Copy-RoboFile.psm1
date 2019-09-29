    <#
    .SYNOPSIS
        Compares logins between SQL Servers and adds missing logins and server roles and server object permissions. This is a useful function to keep Availability Group cluster logins synced.

    .PARAMETER SourceFile
        String - Source file full path . Example "C:\File1.ps1"

    .PARAMETER DestinationDirectory
        String - Destination directory. Example "D:\dir"

    .PARAMETER Restartable
        Switch - ROBOCOPY.exe /z Copies files in restartable mode.

    .PARAMETER MaxExecutionSeconds
        Int32 - Max time to execute copy job. If the job runs longer than MaxExecutionSeconds it will be killed.
        Default 3600 seconds (1 hour)

    .PARAMETER Credential
        PSCredential object with the credentials to use to impersonate a user when connecting.
        If this is not provided then the current user will be used to connect to the SQL Server Database Engine instance.
#>
function Copy-RoboFile
{
    [CmdletBinding()]
    param
    (
        [Parameter()]
        [ValidateNotNullOrEmpty()]
        [System.String]
        $ComputerName = $env:COMPUTERNAME,

        [Parameter(Mandatory)]
        [ValidateNotNull()]
        [System.String]
        $SourceFile,

        [Parameter(Mandatory)]
        [ValidateNotNull()]
        [System.String]
        $DestinationDirectory,

        [Parameter()]
        [Switch]
        $Restartable,

        [Parameter()]
        [ValidateNotNullOrEmpty()]
        [ValidateRange(1,128)]
        [System.Byte]
        $Threads = 8,

        [Parameter()]
        [System.Int32]
        $MaxExecutionSeconds = 3600,

        [Parameter()]
        [ValidateNotNull()]
        [System.Management.Automation.PSCredential]
        $Credential
    )
    
    $Start = Get-Date
    $GetItem = Get-Item -Path $SourceFile
    
    if (-not $GetItem) {
        Write-Error -Message "Failed to access file item '$SourceFile'."
        return
    }

    if (-not (Test-Path -Path $DestinationDirectory)) {
        Write-Error -Message "Failed to access destination directory '$DestinationDirectory'."
        return
    }

    $SourceFile = $GetItem.Name
    $SourceDirectory = $GetItem.Directory.FullName
    
    if ($Restartable) { 
        $RoboScript = { & robocopy @("$Using:SourceDirectory", "$Using:DestinationDirectory", "$Using:SourceFile", "/MT:$Using:Threads", "/z") }
    }
    else {
        $RoboScript = { & robocopy @("$Using:SourceDirectory", "$Using:DestinationDirectory", "$Using:SourceFile", "/MT:$Using:Threads") }
    }

    if ($Credential) {
        $Job = Start-Job -ScriptBlock $RoboScript -Credential $Credential
    }
    else {
        $Job = Start-Job -ScriptBlock $RoboScript
    }

    Write-Output "$Start - Starting ROBOCOPY job for file '$SourceFile'."
    $PercentCompleted = 0

    <# Sleep for 5 then output ROBOCOPY header #>
    Start-Sleep -Seconds 5 # Wait for ROBOCOPY header output.
    $Job | Receive-Job | Select-Object -First 14

    do {
        $Now = Get-Date
        $ExecutionSeconds = ($Now - $Start).Seconds
        $BreakLoop = $true

        if ($Job.State -ieq "Running") {
            $BreakLoop = $false
            $Line = $Job | Receive-Job | Select-Object -Last 1
            
            if ($Line -match '%') {
                $PercentCompleted = $Line.Substring(0,$Line.IndexOf('%'))
                Write-Progress -Activity $SourceFile -Status "$PercentCompleted% Complete" -PercentComplete $PercentCompleted
            }
        }
        else {
            Write-Progress -Activity $SourceFile -Status "100% Complete" -PercentComplete 100 -Completed
            Write-Output "$Now - Completed file copy '$SourceFile'"
        }

        if ($ExecutionSeconds -gt $MaxExecutionSeconds) {
            $BreakLoop=$true;
            Write-Error "$Now - Elapsed time exceeded MaxExecutionSeconds of $MaxExecutionSeconds. Stopping job." 
            $Job | Stop-Job
        }

        if ($BreakLoop) {
            Break;
        }
            
        Start-Sleep -Seconds 2
    } while ($true)

    Write-Output "Finished."
}