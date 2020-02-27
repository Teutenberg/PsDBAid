<#
    .SYNOPSIS
        Deploy the DBAid2 solution to a SQL instance. 

    .PARAMETER SqlServer
        String containing the SQL Server to connect to.

    .PARAMETER Credential
        PSCredential object to impersonate when connecting. 
        When username contains a domain, windows Auth is used, otherwise SQL auth is used. 
        If $null then integrated security is used.

    .PARAMETER ReleaseZipFile
        Path to the downloaded release zip file.
#>
function Deploy-Dacpac
{
    [CmdletBinding()]
    param
    (
        [Parameter()]
        [ValidateNotNull()]
        [System.String]
        $SqlServer = $env:COMPUTERNAME,
        
    $SqlDatabase = ''
    $DacPath = ''
    $RegisterDataTierApplication = 'True'
    $BlockWhenDriftDetected = 'False'
    $DropObjectsNotInSource = 'False'
    $SqlPackageExe = 'C:\Program Files\Microsoft SQL Server\150\DAC\bin\SqlPackage.exe'

        [Parameter()]
        [ValidateNotNull()]
        [System.Management.Automation.PSCredential]
        $Credential,
    )

    $Smo = Connect-SqlServer -SqlServer $SqlServer -Credential $Credential

    $Arguments = [System.Text.StringBuilder]::new()
    [void]$sb.Append("/sf:$DacPath ")
    [void]$sb.Append("/a:Publish ")
    [void]$sb.Append("/tsn:$SqlServer ")
    [void]$sb.Append("/TargetDatabaseName:$SqlDatabase ")
    [void]$sb.Append("/p:RegisterDataTierApplication=$RegisterDataTierApplication ")
    [void]$sb.Append("/p:BlockWhenDriftDetected=$BlockWhenDriftDetected ")
    [void]$sb.Append("/p:DropObjectsNotInSource=$DropObjectsNotInSource ")

    $sessionOptions = New-PSSessionOption -IncludePortInSPN
    $Session = New-PSSession -Computername $env:COMPUTERNAME -Credential $Credential -SessionOption $sessionOptions

    Write-Output "Deploying dacpac to [$SqlServer].[$SqlDatabase]"

    Invoke-Command -Session $Session -ScriptBlock {
        $pinfo = New-Object System.Diagnostics.ProcessStartInfo
        $pinfo.CreateNoWindow = $true
        $pinfo.UseShellExecute = $false
        $pinfo.RedirectStandardError = $true
        $pinfo.RedirectStandardOutput = $true
        $pinfo.FileName = $Using:SqlPackageExe
        $pinfo.Arguments = $Using:Arguments.ToString()
        $p = New-Object System.Diagnostics.Process
        $p.StartInfo = $pinfo
        $p.Start() | Out-Null
        # To avoid deadlocks, always read the output stream first and then wait. 
        $stdout = $p.StandardOutput.ReadToEnd()
        $stderr = $p.StandardError.ReadToEnd()
        # Timeout 300000 = 5mins
        $p.WaitForExit(300000)
        Write-Output "stdout: $stdout"
        Write-Output "stderr: $stderr"
        Write-Output "exit code: $($p.ExitCode)"

        if ($p.ExitCode -ne 0){
            Write-Error "Failed to deploy package..."
        }
    }
}
