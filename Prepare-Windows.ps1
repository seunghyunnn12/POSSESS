$ErrorActionPreference = 'Stop'
Set-Location $PSScriptRoot
New-Item -ItemType Directory -Force -Path .build-tools | Out-Null
$release = 'https://github.com/godotengine/godot-builds/releases/download/4.7.1-stable'
$archive = 'Godot_v4.7.1-stable_export_templates.tpz'
if (-not (Test-Path -LiteralPath '.build-tools/export_templates.tpz')) {
    & curl.exe -L --fail --silent --show-error --retry 2 -o .build-tools/export_templates.tpz "$release/$archive"
    if ($LASTEXITCODE -ne 0) { throw 'Template download failed; remove the incomplete archive before retrying.' }
}
& curl.exe -L --fail --silent --show-error -o .build-tools/SHA512-SUMS.txt "$release/SHA512-SUMS.txt"
if ($LASTEXITCODE -ne 0) { throw 'Checksum download failed.' }
$expected = ((Select-String -LiteralPath .build-tools/SHA512-SUMS.txt -Pattern ([regex]::Escape($archive) + '$')).Line -split '\s+')[0]
$actual = (Get-FileHash -LiteralPath .build-tools/export_templates.tpz -Algorithm SHA512).Hash
if ($actual -ine $expected) { throw 'Template checksum mismatch. Do not use this archive.' }
Add-Type -AssemblyName System.IO.Compression.FileSystem
$zip = [IO.Compression.ZipFile]::OpenRead((Join-Path $PSScriptRoot '.build-tools/export_templates.tpz'))
try {
    foreach ($name in @('windows_debug_x86_64.exe', 'windows_release_x86_64.exe')) {
        $entry = $zip.GetEntry("templates/$name")
        if ($null -eq $entry) { throw "Missing template: $name" }
        [IO.Compression.ZipFileExtensions]::ExtractToFile($entry, (Join-Path $PSScriptRoot ".build-tools/$name"), $true)
    }
} finally { $zip.Dispose() }
foreach ($name in @('LICENSE', 'COPYRIGHT')) {
    & curl.exe -L --fail --silent --show-error -o ".build-tools/GODOT-$name.txt" "https://raw.githubusercontent.com/godotengine/godot/4.7.1-stable/$name.txt"
    if ($LASTEXITCODE -ne 0) { throw "License download failed: $name" }
}
Write-Host 'Verified Godot 4.7.1 Windows templates are ready.'
