<#
    .SYNOPSIS
        Returns a colletion of smo user objects for a collection of databases.

    .PARAMETER SqlServer
        String containing the source SQL Server where the logins and permissions are to be copied from.

    .PARAMETER Databases
        String array containing the list of databases to return users objects.

    .PARAMETER Credential
        PSCredential object with the credentials to use to impersonate a user when connecting.
        If this is not provided then the current user will be used to connect to the SQL Server Database Engine instance.

    .PARAMETER Filter
        String filter returns only users like pattern. Default value = "*"

    .PARAMETER Include
        String array of users that will be included. 

    .PARAMETER Exclude
        String array of users that will be excluded. 
#>
function Restore-SqlDatabase
{
    [CmdletBinding()]
    param
    (
        [Parameter(Mandatory=$true)]
        [ValidateNotNull()]
        [System.String]
        $SqlServer,

        [Parameter(Mandatory=$true)]
        [ValidateNotNull()]
        [System.String]
        $Database,

        [Parameter()]
        [switch]
        $KeepExistingUsers,

        [Parameter()]
        [ValidateNotNull()]
        [System.Management.Automation.PSCredential]
        $Credential    
    )
    
    $Server = Connect-SqlServer -SqlServer $SqlServer -Credential $Credential

    $Users = $Server.Databases[$Database].Users

    #Do restore here...

    foreach ($user in $Users) {
        $Server.Databases[$Database].Users.Add($user)
    }
}