# deploy.ps1 - installs RealPaints: the jg-mechanic respray tabs AND the standalone "realpaints" resource.
# Safe to run more than once. Makes a backup first. Patches nothing if any anchor is not found.
param(
    [string]$ResourcesRoot = 'E:\MAIN SERVER\txData\QBCoreFramework_635C62.base\resources',
    [string]$Res = '',
    [string]$BackupRoot = 'E:\MAIN SERVER\resource-backups',
    [string]$RepoDir = $PSScriptRoot
)

$ErrorActionPreference = 'Stop'
$Utf8NoBom = New-Object System.Text.UTF8Encoding($false)
$Marker = '-- REALPAINTS'

if ([string]::IsNullOrEmpty($Res)) {
    $Res = Join-Path $ResourcesRoot '[standalone]\[jg]\jg-mechanic'
}
$RpDir = Join-Path $ResourcesRoot '[standalone]\realpaints'

function Count-Occurrences([string]$Text, [string]$Sub) {
    $count = 0
    $idx = 0
    while (($idx = $Text.IndexOf($Sub, $idx, [System.StringComparison]::Ordinal)) -ge 0) {
        $count++
        $idx += $Sub.Length
    }
    return $count
}

function Fail([string]$Msg) {
    Write-Host ""
    Write-Host "ERROR: $Msg" -ForegroundColor Red
    Write-Host "Nothing was changed." -ForegroundColor Red
    exit 1
}

# Copy every file under $Src into $Dst (creates folders, overwrites files). Bracket-safe.
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

# ---------- a. Preflight ----------
$modsPath    = Join-Path $Res 'client\cl-mods.lua'
$propsPath   = Join-Path $Res 'client\cl-vehicleprops.lua'
$manifest    = Join-Path $Res 'fxmanifest.lua'
$loaderSrc   = Join-Path $RepoDir 'jg-mechanic\config\zz-realpaints.loader.lua'
$dataSrc     = Join-Path $RepoDir 'data\realpaints-data.lua'
$rpSrc       = Join-Path $RepoDir 'realpaints'
$loaderDst   = Join-Path $Res 'config\zz-realpaints.lua'
$staleData   = Join-Path $Res 'config\zz-realpaints-data.lua'
$rpDataDst   = Join-Path $RpDir 'shared\realpaints-data.lua'

if (-not (Test-Path -LiteralPath $Res))       { Fail "Resource folder not found: $Res" }
if (-not (Test-Path -LiteralPath $modsPath))  { Fail "File not found: $modsPath" }
if (-not (Test-Path -LiteralPath $propsPath)) { Fail "File not found: $propsPath" }
if (-not (Test-Path -LiteralPath $loaderSrc)) { Fail "Repo file not found: $loaderSrc" }
if (-not (Test-Path -LiteralPath $dataSrc))   { Fail "Repo file not found: $dataSrc" }
foreach ($rel in @('fxmanifest.lua', 'config.lua', 'client.lua', 'server.lua', 'shared\paints.lua')) {
    $p = Join-Path $rpSrc $rel
    if (-not (Test-Path -LiteralPath $p)) { Fail "Repo file not found: $p" }
}
$standaloneDir = Join-Path $ResourcesRoot '[standalone]'
if (-not (Test-Path -LiteralPath $standaloneDir)) { Fail "Folder not found: $standaloneDir" }

if (Test-Path -LiteralPath $manifest) {
    $mf = [System.IO.File]::ReadAllText($manifest)
    if ($mf.IndexOf('v1.6.5', [System.StringComparison]::Ordinal) -lt 0) {
        Write-Host "WARNING: fxmanifest.lua does not mention v1.6.5. This patch was written for v1.6.5. Continuing anyway." -ForegroundColor Yellow
    }
} else {
    Write-Host "WARNING: fxmanifest.lua not found in $Res" -ForegroundColor Yellow
}

# ---------- b. Build patched text in memory ----------
$modsText  = [System.IO.File]::ReadAllText($modsPath)
$propsText = [System.IO.File]::ReadAllText($propsPath)

$modsNl = "`n"
if ($modsText.Contains("`r`n")) { $modsNl = "`r`n" }
$propsNl = "`n"
if ($propsText.Contains("`r`n")) { $propsNl = "`r`n" }

$modsPatched  = $modsText
$propsPatched = $propsText
$modsStatus   = 'skipped (already patched)'
$propsStatus  = 'skipped (already patched)'

# --- cl-mods.lua ---
if ($modsText.Contains($Marker)) {
    # already patched, leave alone
} else {
    $anchorA = 'RegisterNUICallback("preview-pri-sec-colours", function(data, cb)' + $modsNl + '  if not currentVehicle then return cb(false) end' + $modsNl
    $anchorB = 'RegisterNUICallback("preview-other-colours", function(data, cb)' + $modsNl + '  if not currentVehicle then return cb(false) end' + $modsNl

    $countA = Count-Occurrences $modsText $anchorA
    $countB = Count-Occurrences $modsText $anchorB
    if ($countA -ne 1) { Fail "cl-mods.lua: anchor 'preview-pri-sec-colours' found $countA times (expected exactly 1). File: $modsPath" }
    if ($countB -ne 1) { Fail "cl-mods.lua: anchor 'preview-other-colours' found $countB times (expected exactly 1). File: $modsPath" }

    $blockA = (@(
        '  -- REALPAINTS: convert real-world paint swatch into custom RGB',
        '  local rp = RealPaints and RealPaints.Get(data.colourId)',
        '  if rp and not data.enableRgb then',
        '    data.enableRgb = true',
        '    data.rgbColour = { rp.rgb[1], rp.rgb[2], rp.rgb[3] }',
        '    data.paint = rp.finish',
        '  end'
    ) -join $modsNl) + $modsNl

    $blockB = (@(
        '  -- REALPAINTS: pearl/wheel/dash/interior only accept GTA palette indices',
        '  local rp = RealPaints and RealPaints.Get(data.colourId)',
        '  if rp then data.colourId = rp.fallback end'
    ) -join $modsNl) + $modsNl

    $modsPatched = $modsText.Replace($anchorA, $anchorA + $blockA)
    $modsPatched = $modsPatched.Replace($anchorB, $anchorB + $blockB)
    $modsStatus = 'PATCHED'
}

# --- cl-vehicleprops.lua ---
if ($propsText.Contains($Marker)) {
    # already patched
} else {
    $anchorC = '      SetVehicleColours(vehicle, props.color1 or colorPrimary, props.color2)'
    $countC = Count-Occurrences $propsText $anchorC
    if ($countC -ne 1) { Fail "cl-vehicleprops.lua: anchor 'SetVehicleColours(vehicle, props.color1 or colorPrimary, props.color2)' found $countC times (expected exactly 1). File: $propsPath" }

    $blockC = (@(
        '      -- REALPAINTS: fix table passed to numeric native when primary is custom RGB',
        '      local rpPri = type(props.color1) == "number" and props.color1 or colorPrimary',
        '      SetVehicleColours(vehicle, rpPri, props.color2)',
        '      if type(props.color1) == "table" then',
        '        SetVehicleCustomPrimaryColour(vehicle, props.color1[1], props.color1[2], props.color1[3])',
        '      end'
    ) -join $propsNl)

    $propsPatched = $propsText.Replace($anchorC, $blockC)
    $propsStatus = 'PATCHED'
}

# ---------- c. Backup ----------
$stamp = Get-Date -Format 'yyyyMMdd-HHmmss'
$bk = Join-Path $BackupRoot ("realpaints-" + $stamp)
$n = 1
while (Test-Path -LiteralPath $bk) {
    $bk = Join-Path $BackupRoot ("realpaints-" + $stamp + "-" + $n)
    $n++
}
[void][System.IO.Directory]::CreateDirectory((Join-Path $bk 'client'))
[void][System.IO.Directory]::CreateDirectory((Join-Path $bk 'config'))

[System.IO.File]::Copy($modsPath,  (Join-Path $bk 'client\cl-mods.lua'), $true)
[System.IO.File]::Copy($propsPath, (Join-Path $bk 'client\cl-vehicleprops.lua'), $true)

$loaderWasNew = 'true'
if (Test-Path -LiteralPath $loaderDst) {
    $loaderWasNew = 'false'
    [System.IO.File]::Copy($loaderDst, (Join-Path $bk 'config\zz-realpaints.lua'), $true)
}
$staleExisted = 'false'
if (Test-Path -LiteralPath $staleData) {
    $staleExisted = 'true'
    [System.IO.File]::Copy($staleData, (Join-Path $bk 'config\zz-realpaints-data.lua'), $true)
}
$rpWasNew = 'true'
if (Test-Path -LiteralPath $RpDir) {
    $rpWasNew = 'false'
    Copy-Tree $RpDir (Join-Path $bk 'realpaints-resource')
}
$manifestLines = @(
    "zz-realpaints-was-new=$loaderWasNew",
    "zz-realpaints-stale-data-existed=$staleExisted",
    "realpaints-resource-was-new=$rpWasNew",
    "res=$Res",
    "realpaints-dir=$RpDir"
)
[System.IO.File]::WriteAllText((Join-Path $bk 'manifest.txt'), (($manifestLines -join "`r`n") + "`r`n"), $Utf8NoBom)

# ---------- d. Write ----------
[void][System.IO.Directory]::CreateDirectory((Join-Path $Res 'config'))
# ONE merged file: data + loader, so FiveM's glob order between our own files does not matter.
$dataText   = [System.IO.File]::ReadAllText($dataSrc).TrimEnd("`r", "`n")
$loaderText = [System.IO.File]::ReadAllText($loaderSrc).TrimStart("`r", "`n")
$merged = $dataText + "`n" + '-- ===== loader (from jg-mechanic/config/zz-realpaints.lua in repo) =====' + "`n" + $loaderText
[System.IO.File]::WriteAllText($loaderDst, $merged, $Utf8NoBom)
if ($staleExisted -eq 'true') { Remove-Item -LiteralPath $staleData -Force }
if ($modsStatus -eq 'PATCHED')  { [System.IO.File]::WriteAllText($modsPath,  $modsPatched,  $Utf8NoBom) }
if ($propsStatus -eq 'PATCHED') { [System.IO.File]::WriteAllText($propsPath, $propsPatched, $Utf8NoBom) }

Copy-Tree $rpSrc $RpDir
[void][System.IO.Directory]::CreateDirectory((Join-Path $RpDir 'shared'))
[System.IO.File]::Copy($dataSrc, $rpDataDst, $true)

# ---------- e. Summary ----------
Write-Host ""
Write-Host "RealPaints deploy complete." -ForegroundColor Green
Write-Host "  jg-mechanic config\zz-realpaints.lua      : written (data + loader merged)"
Write-Host "  jg-mechanic client\cl-mods.lua            : $modsStatus"
Write-Host "  jg-mechanic client\cl-vehicleprops.lua    : $propsStatus"
Write-Host "  [standalone]\realpaints resource          : copied (new: $rpWasNew)"
Write-Host "  Backup                                    : $bk"
Write-Host ""
Write-Host "NEXT: in txAdmin Live Console type these three lines, one at a time:"
Write-Host "  refresh"
Write-Host "  ensure realpaints"
Write-Host "  restart jg-mechanic"
Write-Host "Check the console for '[realpaints] loaded'"
