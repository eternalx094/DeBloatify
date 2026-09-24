# Builds the release ZIP: only the files users need, inside a DeBloatify-<version> folder,
# plus a .sha256 checksum file. Used by .github/workflows/release.yml.
#
#   pwsh tools/Build-Release.ps1 -Tag v1.0.0 -OutputDirectory dist

param(
    [Parameter(Mandatory)][string]$Tag,
    [string]$OutputDirectory = 'dist'
)

$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent $PSScriptRoot
$version = $Tag.TrimStart('v')

# The tag must match the version the program shows in its title bar.
$declared = [regex]::Match((Get-Content -Raw -LiteralPath (Join-Path $root 'DeBloatify.ps1')), "\`$script:Version = '([^']+)'").Groups[1].Value
if ($declared -ne $version) { throw "Tag $Tag does not match `$script:Version = '$declared' in DeBloatify.ps1" }

$name = "DeBloatify-$version"
$stage = Join-Path ([System.IO.Path]::GetTempPath()) ([guid]::NewGuid().ToString())
$folder = Join-Path $stage $name
New-Item -ItemType Directory -Path $folder -Force | Out-Null
try {
    foreach ($file in 'DeBloatify.ps1', 'Run-DeBloatify.cmd', 'README.md', 'LICENSE') {
        $path = Join-Path $root $file
        if (Test-Path -LiteralPath $path) { Copy-Item -LiteralPath $path -Destination $folder }
    }
    Copy-Item -LiteralPath (Join-Path $root 'src') -Destination $folder -Recurse

    New-Item -ItemType Directory -Path $OutputDirectory -Force | Out-Null
    $zip = Join-Path (Resolve-Path $OutputDirectory) "$name.zip"
    if (Test-Path -LiteralPath $zip) { Remove-Item -LiteralPath $zip -Force }
    Compress-Archive -Path $folder -DestinationPath $zip
    $hash = (Get-FileHash -LiteralPath $zip -Algorithm SHA256).Hash
    Set-Content -LiteralPath "$zip.sha256" -Value "$hash  $name.zip" -Encoding ascii
    Write-Host "Built $zip"
    Write-Host "SHA-256 $hash"
} finally {
    Remove-Item -LiteralPath $stage -Recurse -Force -ErrorAction SilentlyContinue
}
