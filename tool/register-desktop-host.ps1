[CmdletBinding()]
param(
    [Parameter(Mandatory=$true)][string]$AppDirectory,
    [switch]$Unregister,
    [ValidateSet('Chrome', 'Brave')][string]$Browser = 'Chrome'
)
$ErrorActionPreference = 'Stop'
$appDir = (Resolve-Path -LiteralPath $AppDirectory).Path
$exe = Join-Path $appDir 'revisit_desktop_host.exe'
$manifest = Join-Path $appDir 'com.revisit.context.json'
$key = switch ($Browser) {
    'Chrome' { 'HKCU:\Software\Google\Chrome\NativeMessagingHosts\com.revisit.context' }
    'Brave' { 'HKCU:\Software\BraveSoftware\Brave-Browser\NativeMessagingHosts\com.revisit.context' }
}
$existing = if(Test-Path -LiteralPath $key) {(Get-Item -LiteralPath $key).GetValue('')} else {$null}
if($existing -and $existing -ne $manifest) { throw "Another installation is registered at $existing. Refusing to replace it." }
if($Unregister) {
    if($existing -eq $manifest) { Remove-Item -LiteralPath $key }
    Write-Output 'Removed only this installation native-host registration; files retained.'
    return
}
if(!(Test-Path -LiteralPath $exe) -or !(Test-Path -LiteralPath (Join-Path $appDir 'revisit.exe'))) { throw 'Build the complete Windows application first.' }
@{name='com.revisit.context';description='Revisit Windows context bridge';path=$exe;type='stdio';allowed_origins=@('chrome-extension://eafjimobboehjlbhhpmcjchagfencibd/')} |
    ConvertTo-Json | Set-Content -LiteralPath $manifest -Encoding utf8
New-Item -Path $key -Force | Out-Null
Set-Item -LiteralPath $key -Value $manifest
Write-Output "Registered current-user $Browser host: $manifest"
