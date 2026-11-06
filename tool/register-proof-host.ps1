[CmdletBinding()]
param([switch]$Unregister)
$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent $PSScriptRoot
$manifestPath = Join-Path $root 'build/windows_host/com.revisit.context_proof.json'
$exePath = Join-Path $root 'build/windows_host/revisit_host.exe'
$registryPath = 'HKCU:\Software\Google\Chrome\NativeMessagingHosts\com.revisit.context_proof'
$existing = if (Test-Path -LiteralPath $registryPath) { (Get-Item -LiteralPath $registryPath).GetValue('') } else { $null }
if ($existing -and $existing -ne $manifestPath) { throw "Another host is registered at $existing. Refusing to replace it." }
if ($Unregister) {
    if ($existing -eq $manifestPath) { Remove-Item -LiteralPath $registryPath }
    Write-Output 'This checkout native-host registration removed; build files retained.'
    return
}
if (!(Test-Path -LiteralPath $exePath)) { throw 'Build the proof host first.' }
$manifest = @{
    name = 'com.revisit.context_proof'
    description = 'Revisit milestone 1 context receiver bridge'
    path = $exePath
    type = 'stdio'
    allowed_origins = @('chrome-extension://eafjimobboehjlbhhpmcjchagfencibd/')
}
$manifest | ConvertTo-Json | Set-Content -LiteralPath $manifestPath -Encoding utf8
New-Item -Path $registryPath -Force | Out-Null
Set-Item -LiteralPath $registryPath -Value $manifestPath
Write-Output "Registered current-user Chrome native host: $manifestPath"
