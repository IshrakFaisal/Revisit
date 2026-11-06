# Dot-source this file: . ./tool/use-local-toolchain.ps1
# Process-only environment; never modifies machine/user PATH or Flutter settings.
$revisitRoot = Split-Path -Parent $PSScriptRoot
$revisitFlutterBin = Join-Path $revisitRoot '.tools\flutter\bin'
$revisitAndroidSdk = if (Test-Path -LiteralPath 'D:\RevisitTools\android-sdk\platform-tools\adb.exe') {
    'D:\RevisitTools\android-sdk'
} else { Join-Path $revisitRoot '.tools\android-sdk' }
if (Test-Path -LiteralPath $revisitFlutterBin) { $env:PATH = "$revisitFlutterBin;$env:PATH" }
if (Test-Path -LiteralPath $revisitAndroidSdk) {
    $env:ANDROID_HOME = $revisitAndroidSdk
    $env:ANDROID_SDK_ROOT = $revisitAndroidSdk
    $env:PATH = "$revisitAndroidSdk\platform-tools;$revisitAndroidSdk\cmdline-tools\latest\bin;$env:PATH"
}
if (!$env:JAVA_HOME) {
    $revisitJdk = Get-ChildItem -LiteralPath 'D:\RevisitTools\jdk17' -Directory -ErrorAction SilentlyContinue |
        Where-Object { Test-Path -LiteralPath (Join-Path $_.FullName 'bin\jlink.exe') } |
        Select-Object -First 1
    if ($revisitJdk) {
        $env:JAVA_HOME = $revisitJdk.FullName
    }
}
if ($env:JAVA_HOME) { $env:PATH = "$env:JAVA_HOME\bin;$env:PATH" }
