# Builds the CurseForge upload zip by hand: .release\Talents4e-<version>.zip, holding one Talents4e folder with the TOC,
# the Lua files it lists, Media\Icon.tga, LICENSE, README.md and CHANGELOG.md. Development files (tests, tools, docs, CLAUDE.md)
# stay out, as in .pkgmeta. Run from anywhere:   powershell -File tools\package.ps1
# Once the repo has the BigWigs packager action, tagging a version does this instead.
$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent $PSScriptRoot
$toc = Join-Path $root 'Talents4e.toc'
$lines = Get-Content $toc
$version = ($lines | Where-Object { $_ -match '^## Version:' }) -replace '^## Version:\s*', ''
if (-not $version) { throw 'No "## Version:" line in Talents4e.toc' }

$files = @('Talents4e.toc', 'LICENSE', 'README.md', 'CHANGELOG.md', 'Media/Icon.tga')
$files += $lines | Where-Object { $_ -match '\.lua\s*$' } | ForEach-Object { $_.Trim() }

$out = Join-Path $root '.release'
New-Item -ItemType Directory -Force $out | Out-Null
$zip = Join-Path $out "Talents4e-$version.zip"
if (Test-Path $zip) { Remove-Item -Force $zip }

# Entries are written as Talents4e/<file> with forward slashes: Windows PowerShell's Compress-Archive writes
# backslashes, which some unzip tools turn into odd file names.
Add-Type -AssemblyName System.IO.Compression, System.IO.Compression.FileSystem
$archive = [System.IO.Compression.ZipFile]::Open($zip, 'Create')
try {
  foreach ($file in $files) {
    $from = Join-Path $root $file
    if (-not (Test-Path $from)) { throw "Missing $file (listed in the TOC?)" }
    [System.IO.Compression.ZipFileExtensions]::CreateEntryFromFile($archive, $from, "Talents4e/$file") | Out-Null
  }
} finally {
  $archive.Dispose()
}
Write-Output "Wrote $zip ($($files.Count) files)"
