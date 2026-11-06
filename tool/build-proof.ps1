param([string]$VsTools = 'D:\Microsoft Visual Studio\2022\Community\VC\Auxiliary\Build\vcvars64.bat')
$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent $PSScriptRoot
if (!(Test-Path -LiteralPath $VsTools)) { throw "Missing vcvars64.bat: $VsTools" }
# Import the installed compiler environment for this process only.
$environment = & cmd.exe /d /s /c "`"$VsTools`" >nul && set"
if ($LASTEXITCODE -ne 0) { throw 'Visual Studio environment initialization failed.' }
foreach ($line in $environment) {
    if ($line -match '^([^=]+)=(.*)$') { [Environment]::SetEnvironmentVariable($Matches[1], $Matches[2], 'Process') }
}
& cmake -S "$root/companion/windows_host" -B "$root/build/windows_host" -G Ninja -DCMAKE_BUILD_TYPE=Release -DCMAKE_CXX_COMPILER=cl
if ($LASTEXITCODE -ne 0) { throw 'CMake configure failed.' }
& cmake --build "$root/build/windows_host" --config Release
if ($LASTEXITCODE -ne 0) { throw 'C++ build failed.' }
& ctest --test-dir "$root/build/windows_host" -C Release --output-on-failure
if ($LASTEXITCODE -ne 0) { throw 'Native tests failed.' }
