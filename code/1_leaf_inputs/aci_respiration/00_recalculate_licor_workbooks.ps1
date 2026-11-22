# Recalculate the formula columns of the LI-6800 A-Ci workbooks in Excel
#
# Purpose
#   LI-6800 workbooks (Bluestem firmware) store the derived gas-exchange variables (A, Ci, Ca,
#   gsw, Qin and others) as Excel formulas over the raw analyzer columns. Until Excel recalculates
#   them, the cached values in an exported workbook are zero, and PhotoGEA's read_gasex_file()
#   cannot use the file. This script opens each instrument workbook in Excel, saves it so that the
#   evaluated values are cached, and writes the copy as <instrument>.xlsx in one folder per site
#   and row spacing, with a log row for every workbook. The instrument files are never modified.
#   The recalculated workbooks hold the A-Ci curves behind the dark respiration (Rd25) values in
#   Table S14.
#
#   This step cannot be rerun from the package. It needs Microsoft Excel and the original
#   instrument exports, which are not included. The package ships its products instead. The
#   recalculated workbooks are data/leaf/aci_curves/<cell>/<instrument>.xlsx and the log is
#   data/leaf/aci_curves/recalculation_log.csv. The script documents how they were made. The
#   shipped log gives the instrument file names and the package paths of the recalculated
#   workbooks, with its own column names, and leaves out the original absolute paths.
#
# Inputs
#   <RawRoot>/<cell>/<instrument folder>/*.xlsx   original LI-6800 exports, one folder per
#                                                  instrument. <cell> is SF_15, SF_30, EF_15 or
#                                                  EF_30 (site code and row spacing in inches,
#                                                  15 = 38-cm rows, 30 = 76-cm rows).
#
# Outputs
#   outputs/leaf_inputs/aci_curves_recalculated/<cell>/<instrument>.xlsx   recalculated workbooks
#   outputs/leaf_inputs/aci_curves_recalculated/recalculation_log.csv     source and copy of each
#                                                                          workbook, MD5 checksums
#
# Usage
#   powershell -File code/1_leaf_inputs/aci_respiration/00_recalculate_licor_workbooks.ps1 -RawRoot <folder>
#   Run from the package root. -OnlyCells EF_30 limits the run to one site and row spacing.
#
# Requirements
#   Windows PowerShell 5.1; Microsoft Excel (COM automation)

param(
    [Parameter(Mandatory = $true)]
    [string]$RawRoot,
    [string[]]$OnlyCells = @()
)

$ErrorActionPreference = "Stop"

# -------- Paths --------
$Root     = if ($env:PACKAGE_ROOT) { $env:PACKAGE_ROOT } else { "." }
$EvalDir  = Join-Path $Root "outputs\leaf_inputs\aci_curves_recalculated"
$Manifest = Join-Path $EvalDir "recalculation_log.csv"

# One folder of instrument exports per site and row spacing.
$CellRoots = [ordered]@{
    SF_15 = Join-Path $RawRoot "SF_15"
    SF_30 = Join-Path $RawRoot "SF_30"
    EF_15 = Join-Path $RawRoot "EF_15"
    EF_30 = Join-Path $RawRoot "EF_30"
}
# Folders that sit next to the instrument folders but hold no instrument exports.
$SkipFolders = @("combined","Plots","plots")

# -------- Helpers --------
function Get-InstrumentName {
    param([string]$FolderName)
    # Instrument folders are named after the LI-6800 unit ("Ains2", "RIPE14"), in some cases after
    # an operator prefix. The last word is kept and its capitalization normalized.
    $name = ($FolderName.Trim() -split '\s+')[-1]
    if ($name -match '^(?i)ains(.*)$') { return "Ains$($matches[1])" }
    if ($name -match '^(?i)ripe(.*)$') { return "Ripe$($matches[1])" }
    return $name
}

function Get-MD5Short {
    param([string]$Path)
    $h = (Get-FileHash -Path $Path -Algorithm MD5).Hash
    return $h.Substring(0, 12)
}

# -------- Choose target cells --------
if ($OnlyCells.Count -gt 0) {
    $TargetCells = @($OnlyCells | Where-Object { $CellRoots.Contains($_) })
    Write-Host "Processing: $($TargetCells -join ', ')"
} else {
    $TargetCells = @($CellRoots.Keys)
}

# -------- Prepare output folders --------
New-Item -ItemType Directory -Force -Path $EvalDir | Out-Null
foreach ($cell in $TargetCells) {
    New-Item -ItemType Directory -Force -Path (Join-Path $EvalDir $cell) | Out-Null
}

# -------- Launch Excel --------
Write-Host "Launching Excel.Application..." -ForegroundColor Cyan
$Excel = New-Object -ComObject Excel.Application
$Excel.Visible          = $false
$Excel.DisplayAlerts    = $false
$Excel.ScreenUpdating   = $false
$Excel.AskToUpdateLinks = $false
$Excel.EnableEvents     = $false

$ManifestRows = @()

try {
    foreach ($cellName in $TargetCells) {
        $cellRoot = $CellRoots[$cellName]
        Write-Host ""
        Write-Host "=== $cellName ===" -ForegroundColor Yellow

        if (-not (Test-Path $cellRoot)) {
            Write-Host "  folder not found, skipped" -ForegroundColor Red
            continue
        }

        $machineDirs = Get-ChildItem -Path $cellRoot -Directory |
                       Where-Object { $_.Name -notin $SkipFolders }
        Write-Host "  instrument folders: $($machineDirs.Count)"

        foreach ($mdir in $machineDirs) {
            $machine = Get-InstrumentName $mdir.Name

            # Only the raw exports are recalculated. Files ending in _calibrated.xlsx are skipped.
            $allXlsx = Get-ChildItem -Path $mdir.FullName -Filter "*.xlsx" -File
            $rawXlsx = $allXlsx | Where-Object { $_.Name -notmatch '_calibrated\.xlsx$' }

            if ($rawXlsx.Count -eq 0) {
                Write-Host "  [$machine] no raw workbook, skipped" -ForegroundColor DarkYellow
                continue
            }

            $chosen = $null
            if ($rawXlsx.Count -gt 1) {
                # With several raw workbooks in one folder, the largest (the full data export) is
                # used, and all candidates are listed.
                $chosen = $rawXlsx | Sort-Object Length -Descending | Select-Object -First 1
                Write-Host "  [$machine] $($rawXlsx.Count) raw workbooks found:" -ForegroundColor Yellow
                foreach ($f in $rawXlsx) {
                    $marker = if ($f.Name -eq $chosen.Name) { "  <-- used (largest)" } else { "" }
                    Write-Host "             $($f.Name)  ($($f.Length) bytes)$marker" -ForegroundColor Yellow
                }
            } else {
                $chosen = $rawXlsx[0]
            }

            $src = $chosen.FullName
            $dst = Join-Path $EvalDir "$cellName\$machine.xlsx"

            # Excel COM cannot open paths longer than about 218 characters. Each workbook is
            # therefore recalculated in a short temporary folder and then moved into place.
            $tmpDir = Join-Path ([System.IO.Path]::GetTempPath()) "licor_recalc\$cellName"
            New-Item -ItemType Directory -Force -Path $tmpDir | Out-Null
            $tmpFile = Join-Path $tmpDir "$machine.xlsx"

            Write-Host "  [$machine] $($chosen.Name) -> $cellName/$machine.xlsx ... " -NoNewline

            $srcMD5 = Get-MD5Short $src
            Copy-Item -Path $src -Destination $tmpFile -Force

            $okFlag = $false
            $errMsg = ""
            try {
                $wb = $Excel.Workbooks.Open($tmpFile, 0, $false)  # UpdateLinks = 0, ReadOnly = false
                $wb.Save()
                $wb.Close($false)
                [System.Runtime.Interopservices.Marshal]::ReleaseComObject($wb) | Out-Null
                $wb = $null
                $okFlag = $true
            } catch {
                $errMsg = $_.Exception.Message
            }

            if ($okFlag) {
                Move-Item -Path $tmpFile -Destination $dst -Force
                $dstMD5 = Get-MD5Short $dst
                $unchanged = if ($srcMD5 -eq $dstMD5) { " (unchanged, values were already cached)" } else { "" }
                Write-Host "OK  src=$srcMD5 dst=$dstMD5$unchanged" -ForegroundColor Green
            } else {
                $dstMD5 = ""
                if (Test-Path $tmpFile) { Remove-Item $tmpFile -Force -ErrorAction SilentlyContinue }
                Write-Host "FAILED: $errMsg" -ForegroundColor Red
            }

            $ManifestRows += [PSCustomObject]@{
                cell              = $cellName
                machine           = $machine
                folder_name_raw   = $mdir.Name
                source_path       = $src
                source_md5_short  = $srcMD5
                dest_path         = $dst
                dest_md5_short    = $dstMD5
                n_xlsx_in_folder  = $allXlsx.Count
                n_raw_xlsx        = $rawXlsx.Count
                eval_ok           = $okFlag
                eval_error        = $errMsg
                eval_timestamp    = (Get-Date -Format "yyyy-MM-ddTHH:mm:ss")
            }
        }
    }
}
finally {
    # Release Excel even if a workbook failed part way through.
    Write-Host ""
    Write-Host "Closing Excel..." -ForegroundColor Cyan
    try { $Excel.Quit() } catch {}
    [System.Runtime.Interopservices.Marshal]::ReleaseComObject($Excel) | Out-Null
    [System.GC]::Collect()
    [System.GC]::WaitForPendingFinalizers()
}

# -------- Write the log --------
# When only some cells were processed, the log rows of the other cells are kept and the rows of
# the processed instruments are replaced.
if ((Test-Path $Manifest) -and ($OnlyCells.Count -gt 0)) {
    $existing = Import-Csv -Path $Manifest
    $newKeys  = $ManifestRows | ForEach-Object { "$($_.cell)|$($_.machine)" }
    $preserved = $existing | Where-Object { "$($_.cell)|$($_.machine)" -notin $newKeys }
    $ManifestRows = @($preserved) + @($ManifestRows)
}
$ManifestRows | Export-Csv -Path $Manifest -NoTypeInformation -Encoding UTF8
Write-Host ""
Write-Host "Recalculation log: outputs/leaf_inputs/aci_curves_recalculated/recalculation_log.csv ($($ManifestRows.Count) rows)" -ForegroundColor Cyan
