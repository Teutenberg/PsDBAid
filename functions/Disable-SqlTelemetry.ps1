<#
    .SYNOPSIS
        Disable SQL Telemetry service. 
#>
function Disable-SqlTelemetry
{
    Write-Output "Checking SQLTELEMETRY Services."

    $GetServices = Get-Service | Where-Object { $_.ServiceName -ilike "SQLTELEMETRY*" } | Select-Object -ExpandProperty Name

    foreach ($Service in $GetServices) {
        $ServiceParams = @{
            Name           = $Service
            StartupType    = 'Disabled'
            State          = 'Stopped'
            BuiltInAccount = 'LocalService' <# Setting to LocalService as patching can fail if GPO removes permissions from virtual account. #>
        }

        if (Invoke-DscResource -ModuleName PSDesiredStateConfiguration -Name Service -Property $ServiceParams -Method Test) {
            Write-Output 'In desired state - Telemetry already disabled.'
        }
        else {
            Write-Output "Disabling Telemetry service '$Service'."
            Invoke-DscResource -ModuleName PSDesiredStateConfiguration -Name Service -Property $ServiceParams -Method Set -Verbose
        }
    }

    Write-Output 'Done.'
}