# Run a SQL file non-interactively; optionally save the output (UTF-8, no BOM) for PR submission
#   .\scripts\run.ps1 weeks\week00-setup\02_lab.sql
#   .\scripts\run.ps1 weeks\week00-setup\02_lab.sql weeks\week00-setup\submissions\<id>\lab.txt
param(
    [Parameter(Mandatory = $true)][string]$Script,
    [string]$Out
)
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8

$rel = ($Script -replace '\\', '/') -replace '^\./', ''
$idx = $rel.LastIndexOf('/')
if ($idx -ge 0) { $dir = $rel.Substring(0, $idx); $file = $rel.Substring($idx + 1) }
else { $dir = '.'; $file = $rel }

$output = docker exec -w "/workspace/$dir" sqlp-oracle sqlplus -L -s "study/study@//localhost:1521/FREEPDB1" "@$file"
$output

if ($Out) {
    $outDir = Split-Path -Parent $Out
    if ($outDir -and -not (Test-Path $outDir)) { New-Item -ItemType Directory -Path $outDir | Out-Null }
    $full = $ExecutionContext.SessionState.Path.GetUnresolvedProviderPathFromPSPath($Out)
    [System.IO.File]::WriteAllLines($full, [string[]]$output, (New-Object System.Text.UTF8Encoding $false))
    Write-Host "saved: $Out"
}
