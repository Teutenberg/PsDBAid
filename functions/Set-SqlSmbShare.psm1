<#
    .SYNOPSIS
        Creates a new SMB share. If a share already exists, this will remove and recreate based on the parameters passed to this function. 

    .PARAMETER ComputerName
        String computer to create share on. 
    
    .PARAMETER Directory
        String directory on computer to share. 

    .PARAMETER ShareName
        String name of the SMB share.

    .PARAMETER ShareAccounts
        String[] list of accounts to be granted FullControl permissions to share. 

    .PARAMETER Credential
        PSCredential object to impersonate when connecting. 
        When username contains a domain, windows Auth is used, otherwise SQL auth is used. 
        If $null then integrated security is used.
#>
function Set-SqlSmbShare
{
    [CmdletBinding()]
    param
    (
        [Parameter()]
        [ValidateNotNull()]
        [System.String]
        $ComputerName,

        [Parameter()]
        [ValidateNotNull()]
        [System.String]
        $Directory,

        [Parameter()]
        [ValidateNotNull()]
        [System.String]
        $ShareName,

        [Parameter()]
        [ValidateNotNull()]
        [System.String[]]
        $ShareAccounts,

        [Parameter()]
        [ValidateNotNull()]
        [System.Management.Automation.PSCredential]
        $Credential
    )

    $ScriptBlock = {
        Param($dir, $smbname, $accounts)

        if (!(Test-Path $dir)) { 
            New-Item $dir -type directory | Out-Null
            Write-Verbose -Message "Created directory '$dir'."
        }

        $acl = Get-Acl $dir

        foreach ($obj in $accounts) {
            $rule = New-Object system.security.accesscontrol.filesystemaccessrule($obj,"FullControl","ContainerInherit,ObjectInherit","None","Allow")
            $acl.SetAccessRule($rule) 
            Write-Verbose -Message "Granted FullControl to '$obj' on '$dir'."
        }

        Set-Acl $dir $acl
        Get-SmbShare | Where-Object { $_.Name -eq $smbname } | Remove-SmbShare -Force
        New-SmbShare -Name $smbname -Path $dir -FullAccess $accounts | Out-Null
        Write-Verbose -Message "Created share '$smbname'."
    }

    $Parameters = @{
        ComputerName = $ComputerName
        ScriptBlock = $ScriptBlock
        ArgumentList = $Directory, $ShareName, $ShareAccounts
    }

    if ($Credential) {
        $Parameters.Add('Credential', $Credential)
    }

    Invoke-Command @Parameters
}