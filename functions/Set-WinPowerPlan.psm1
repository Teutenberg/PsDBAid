$powerPlan = Get-WmiObject -Namespace root\cimv2\power -Class Win32_PowerPlan -Filter "ElementName = 'High Performance'"
$powerPlan.Activate() | Out-Null
Write-Output "Activated high performance power plan..."