param([ValidatePattern('^builds/[A-Za-z0-9_-]+$')][string] $OutputDirectory = 'builds/windows')
$ErrorActionPreference = 'Stop'
Set-Location $PSScriptRoot
$engine = (Get-Command Godot_v4.7.1-stable_win64_console.exe).Source
if (-not (Test-Path -LiteralPath '.build-tools/windows_release_x86_64.exe')) {
    throw 'Godot 4.7.1 Windows export templates are required in .build-tools. See BUILD.md.'
}
New-Item -ItemType Directory -Force -Path $OutputDirectory | Out-Null
function Invoke-GodotChecked([string[]] $arguments) {
    # Windows PowerShell wraps native stderr warnings as ErrorRecords when redirected.
    $ErrorActionPreference = 'Continue'
    & $engine @arguments
    $engineExit = $LASTEXITCODE
    $ErrorActionPreference = 'Stop'
    if ($engineExit -ne 0) { throw "Godot failed with exit code $engineExit" }
}
Invoke-GodotChecked @('--headless', '--path', '.', '--editor', '--import', '--quit')
Invoke-GodotChecked @('--headless', '--path', '.', '--export-release', 'Windows Desktop', "$OutputDirectory/POSSESS.exe")
Copy-Item -LiteralPath assets/fonts/OFL.txt -Destination "$OutputDirectory/FONT-LICENSE.txt"
Copy-Item -LiteralPath .build-tools/GODOT-LICENSE.txt -Destination "$OutputDirectory/GODOT-LICENSE.txt"
Copy-Item -LiteralPath .build-tools/GODOT-COPYRIGHT.txt -Destination "$OutputDirectory/GODOT-COPYRIGHT.txt"
Copy-Item -LiteralPath assets/characters/skeletons/LICENSE.txt -Destination "$OutputDirectory/SKELETONS-LICENSE.txt"
Copy-Item -LiteralPath assets/characters/adventurers/LICENSE.txt -Destination "$OutputDirectory/ADVENTURERS-LICENSE.txt"
Copy-Item -LiteralPath WINDOWS-README.txt -Destination "$OutputDirectory/README.txt"
Get-FileHash -Algorithm SHA256 -LiteralPath "$OutputDirectory/POSSESS.exe","$OutputDirectory/POSSESS.pck" |
    Format-List | Out-File -Encoding utf8 "$OutputDirectory/SHA256.txt"
Write-Host "Built $OutputDirectory/POSSESS.exe"
