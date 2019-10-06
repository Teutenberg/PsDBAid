<#
    .SYNOPSIS
        Connect to a computer and format a list of disk drives to 64KB.

    .PARAMETER ComputerName
        String containing the Computer where you want to get CIM instance from.

    .PARAMETER DrivesLettersToFormat
        String containing the CIM SQL class you want.

    .PARAMETER Credential
        PSCredential object to impersonate when connecting. 
#>
function Format-WinDrive64KB
{
    [CmdletBinding()]
    param
    (
        [Parameter()]
        [ValidateNotNull()]
        [System.String]
        $ComputerName = $env:COMPUTERNAME,

        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [System.String[]]
        $DrivesLettersToFormat,

        [Parameter()]
        [ValidateNotNull()]
        [System.Management.Automation.PSCredential]
        $Credential
    )

    if ($Credential) {
        $CimSession = New-CimSession -ComputerName $ComputerName -Credential $Credential
    }
    else {
        $CimSession = New-CimSession -ComputerName $ComputerName 
    }

    $DrivesToFormat = Get-CimInstance -CimSession $CimSession -ClassName 'Win32_Volume' -Filter 'BlockSize <> 65536' | 
        Where-Object { $DrivesLettersToFormat -match $_.DriveLetter }

    # confirmpreference is a workaround for Format-Volume bug
    $currentconfirm = $confirmpreference
    $confirmpreference = 'none'

    if ($DrivesToFormat) {
        foreach ($drive in $DrivesToFormat) {
            $DriveLetter = $drive.DriveLetter
            <# CHECK for FILES #>
            $Files = Get-CimInstance -CimSession $CimSession -ClassName CIM_LogicalFile `
                -Filter "FileType = 'File Folder' AND System = 'False' AND Drive LIKE '%$DriveLetter%'" | Select-Object -first 1
            
            # if drive empty format volume
            if ($Files) {
                Write-Output "Disk '$($drive.DriveLetter)' requires formatting with 64KB block size, but is not empty so no action will be taken..."
            } else {
                Write-Output "Formatting disk '$($drive.DriveLetter)' with 64KB block size..."
                Format-Volume -CimSession $CimSession -DriveLetter $drive.Name[0] -NewFileSystemLabel $drive.FileSystemLabel -FileSystem 'NTFS' -AllocationUnitSize '64KB' -Force
            }
        }
    }
    else {
        Write-Output 'All disks are in expected state with 64KB block size...'
    }

    $confirmpreference = $currentconfirm
    Remove-CimSession -CimSession $CimSession
}