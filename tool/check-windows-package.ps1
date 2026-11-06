[CmdletBinding()]
param([Parameter(Mandatory=$true)][string]$BuildDirectory)
$ErrorActionPreference = 'Stop'
$root = (Resolve-Path -LiteralPath $BuildDirectory).Path
$bundle = Join-Path $root 'runner\Release'
foreach ($name in @('revisit.exe','revisit_desktop_host.exe','revisit_notification_setup.exe','flutter_windows.dll','sqlite3.dll','dartjni.dll','url_launcher_windows_plugin.dll','data\icudtl.dat','data\app.so','data\flutter_assets')) {
    if (!(Test-Path -LiteralPath (Join-Path $bundle $name))) { throw "Missing bundle asset: $name" }
}
$installFiles = Get-ChildItem -LiteralPath $root -Filter cmake_install.cmake -Recurse
foreach ($file in $installFiles) {
    if ((Get-Content -LiteralPath $file.FullName -Raw) -match '(?i)file\(INSTALL DESTINATION "[A-Z]:[/\\]Program Files') {
        throw "Unexpected machine-wide destination in $($file.FullName)"
    }
}
Write-Output "PASS: complete local Windows bundle at $bundle; no Program Files install rule."
