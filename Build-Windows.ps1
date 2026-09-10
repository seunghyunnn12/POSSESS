$ErrorActionPreference = 'Stop'
Set-Location $PSScriptRoot
$engine = (Get-Command Godot_v4.7.1-stable_win64_console.exe).Source
if (-not (Test-Path -LiteralPath '.build-tools/windows_release_x86_64.exe')) {
    throw 'Godot 4.7.1 Windows export templates are required in .build-tools. See BUILD.md.'
}
New-Item -ItemType Directory -Force -Path builds/windows | Out-Null
function Invoke-GodotChecked([string[]] $arguments) {
    # Windows PowerShell wraps native stderr warnings as ErrorRecords when redirected.
    $ErrorActionPreference = 'Continue'
    & $engine @arguments
    $engineExit = $LASTEXITCODE
    $ErrorActionPreference = 'Stop'
    if ($engineExit -ne 0) { throw "Godot failed with exit code $engineExit" }
}
Invoke-GodotChecked @('--headless', '--path', '.', '--editor', '--import', '--quit')
Invoke-GodotChecked @('--headless', '--path', '.', '--export-release', 'Windows Desktop', 'builds/windows/POSSESS.exe')
Copy-Item -LiteralPath assets/fonts/OFL.txt -Destination builds/windows/FONT-LICENSE.txt
Copy-Item -LiteralPath .build-tools/GODOT-LICENSE.txt -Destination builds/windows/GODOT-LICENSE.txt
Copy-Item -LiteralPath .build-tools/GODOT-COPYRIGHT.txt -Destination builds/windows/GODOT-COPYRIGHT.txt
Copy-Item -LiteralPath assets/characters/skeletons/LICENSE.txt -Destination builds/windows/SKELETONS-LICENSE.txt
Copy-Item -LiteralPath assets/characters/adventurers/LICENSE.txt -Destination builds/windows/ADVENTURERS-LICENSE.txt
Copy-Item -LiteralPath WINDOWS-README.txt -Destination builds/windows/README.txt
Get-FileHash -Algorithm SHA256 -LiteralPath builds/windows/POSSESS.exe,builds/windows/POSSESS.pck |
    Format-List | Out-File -Encoding utf8 builds/windows/SHA256.txt
Write-Host 'Built builds/windows/POSSESS.exe'
