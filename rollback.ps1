# rollback.ps1 - undoes deploy.ps1 (data copies, loader, realpaints resource, both patched client files).
# If -BackupDir is not given, the newest realpaints-* backup folder (by NAME, names sort by timestamp)
# whose client\cl-mods.lua does NOT contain "-- REALPAINTS" is used. That is the original, pre-patch
# backup. Backups made by a repeat deploy run contain the patch already, so they are skipped.
param(
    [string]$ResourcesRoot = 'E:\MAIN SERVER\txData\QBCoreFramework_635C62.base\resources',
    [string]$Res = '',
    [string]$BackupRoot = 'E:\MAIN SERVER\resource-backups',
    [string]$BackupDir
)

$ErrorActionPreference = 'Stop'

if ([string]::IsNullOrEmpty($Res)) {
    $Res = Join-Path $ResourcesRoot '[standalone]\[jg]\jg-mechanic'
}
$RpDir = Join-Path $ResourcesRoot '[standalone]\realpaints'

function Fail([string]$Msg) {
    Write-Host ""
    Write-Host "ERROR: $Msg" -ForegroundColor Red
    exit 1
}

function Copy-Tree([string]$Src, [string]$Dst) {
    [void][System.IO.Directory]::CreateDirectory($Dst)
    $srcFull = (Resolve-Path -LiteralPath $Src).ProviderPath.TrimEnd('\')
    foreach ($f in (Get-ChildItem -LiteralPath $srcFull -Recurse -File)) {
        $rel = $f.FullName.Substring($srcFull.Length).TrimStart('\')
        $target = Join-Path $Dst $rel
        [void][System.IO.Directory]::CreateDirectory([System.IO.Path]::GetDirectoryName($target))
        [System.IO.File]::Copy($f.FullName, $target, $true)
    }
}

if (-not (Test-Path -LiteralPath $Res)) { Fail "Resource folder not found: $Res" }

if ([string]::IsNullOrEmpty($BackupDir)) {
    if (-not (Test-Path -LiteralPath $BackupRoot)) { Fail "Backup folder not found: $BackupRoot" }
    $candidates = Get-ChildItem -LiteralPath $BackupRoot -Directory | Where-Object { $_.Name -like 'realpaints-*' } | Sort-Object Name -Descending
    foreach ($c in $candidates) {
        $f = Join-Path $c.FullName 'client\cl-mods.lua'
        if (Test-Path -LiteralPath $f) {
            $txt = [System.IO.File]::ReadAllText($f)
            if (-not $txt.Contains('-- REALPAINTS')) {
                $BackupDir = $c.FullName
                break
            }
        }
    }
    if ([string]::IsNullOrEmpty($BackupDir)) { Fail "No original (pre-patch) backup found in $BackupRoot" }
}

$modsBk  = Join-Path $BackupDir 'client\cl-mods.lua'
$propsBk = Join-Path $BackupDir 'client\cl-vehicleprops.lua'
if (-not (Test-Path -LiteralPath $modsBk))  { Fail "Backup file missing: $modsBk" }
if (-not (Test-Path -LiteralPath $propsBk)) { Fail "Backup file missing: $propsBk" }

Write-Host "Restoring from: $BackupDir"

[System.IO.File]::Copy($modsBk,  (Join-Path $Res 'client\cl-mods.lua'), $true)
[System.IO.File]::Copy($propsBk, (Join-Path $Res 'client\cl-vehicleprops.lua'), $true)
Write-Host "  restored client\cl-mods.lua"
Write-Host "  restored client\cl-vehicleprops.lua"

$mfText = ''
$mfPath = Join-Path $BackupDir 'manifest.txt'
if (Test-Path -LiteralPath $mfPath) { $mfText = [System.IO.File]::ReadAllText($mfPath) }

function Was-New([string]$Key) {
    # missing line = treat as new
    if ($mfText -match ($Key + '=false')) { return $false }
    return $true
}

# jg-mechanic merged config file (data + loader)
$dst = Join-Path $Res 'config\zz-realpaints.lua'
if (Was-New 'zz-realpaints-was-new') {
    if (Test-Path -LiteralPath $dst) {
        Remove-Item -LiteralPath $dst -Force
        Write-Host "  deleted config\zz-realpaints.lua"
    }
} else {
    $src = Join-Path $BackupDir 'config\zz-realpaints.lua'
    if (Test-Path -LiteralPath $src) {
        [System.IO.File]::Copy($src, $dst, $true)
        Write-Host "  restored config\zz-realpaints.lua"
    }
}

# stale zz-realpaints-data.lua from an earlier deploy version: put it back if it existed before
if ($mfText -match 'zz-realpaints-stale-data-existed=true') {
    $src = Join-Path $BackupDir 'config\zz-realpaints-data.lua'
    if (Test-Path -LiteralPath $src) {
        [System.IO.File]::Copy($src, (Join-Path $Res 'config\zz-realpaints-data.lua'), $true)
        Write-Host "  restored config\zz-realpaints-data.lua"
    }
}

# realpaints resource folder
if (Was-New 'realpaints-resource-was-new') {
    if (Test-Path -LiteralPath $RpDir) {
        Remove-Item -LiteralPath $RpDir -Recurse -Force
        Write-Host "  deleted [standalone]\realpaints"
    }
} else {
    $rpBk = Join-Path $BackupDir 'realpaints-resource'
    if (Test-Path -LiteralPath $rpBk) {
        if (Test-Path -LiteralPath $RpDir) { Remove-Item -LiteralPath $RpDir -Recurse -Force }
        Copy-Tree $rpBk $RpDir
        Write-Host "  restored [standalone]\realpaints"
    }
}

Write-Host ""
Write-Host "Rollback complete." -ForegroundColor Green
Write-Host "NEXT: in txAdmin Live Console type these, one at a time:"
Write-Host "  stop realpaints"
Write-Host "  refresh"
Write-Host "  restart jg-mechanic"
