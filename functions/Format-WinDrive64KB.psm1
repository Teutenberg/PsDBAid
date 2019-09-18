[string[]]$DrivesLettersToFormat = $st_DrivesLettersToFormat.Split(';')

if ( Get-Disk | Where-Object IsOffline –eq $true ) {
    Write-Output "Bringing offline disks online..."
    Get-Disk | Where-Object IsOffline –eq $true | Set-Disk –IsOffline $false
    Get-Disk | Where-Object IsReadonly –eq $true | Set-Disk -IsReadonly $false
}

$DriveVolumes = Get-Volume | Where {$DrivesLettersToFormat -match $_.DriveLetter -and $_.DriveLetter -ne $null } | Select @{l="DriveLetter";e={$_.DriveLetter + ":"}}, FileSystemLabel
$DrivesToFormat = Get-WmiObject -Class Win32_Volume | Where {$DriveVolumes.DriveLetter -match $_.DriveLetter -and $_.BlockSize -ne 65536 }

# confirmpreference is a workaround for Format-Volume bug
$currentconfirm = $confirmpreference
$confirmpreference = 'none'

if ($DrivesToFormat) {
    foreach ($drive in $DrivesToFormat) {
	    # if drive empty format volume
        if ((Get-ChildItem -Path $drive.DriveLetter -Force).Where({$_.Name -ine "System Volume Information" -and $_.Name -ine "`$RECYCLE.BIN" }).Count -eq 0) {
    	    Write-Output "Formatting disk '$($drive.DriveLetter)' with 64KB block size..."
            Format-Volume -DriveLetter $drive.Name[0] -NewFileSystemLabel $drive.FileSystemLabel -FileSystem NTFS -AllocationUnitSize 64KB -Force
        } else {
    	    Write-Output "Disk '$($drive.DriveLetter)' requires formatting with 64KB block size, but is not empty so skipping..."
        }
    }
}
else {
    Write-Output 'All disks are in expected state with 64KB block size...'
}

$confirmpreference = $currentconfirm 