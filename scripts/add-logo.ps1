<#
.SYNOPSIS
  Overlays the NOKS logo (transparent background) on a base image, top-right corner.

.EXAMPLE
  powershell -ExecutionPolicy Bypass -File scripts\add-logo.ps1 -Base tmp\week-02-base.png
  powershell -ExecutionPolicy Bypass -File scripts\add-logo.ps1 -Base tmp\week-02-base.png -Out posts\2026-10-08-week-02-telegram.png
#>
param(
    [Parameter(Mandatory = $true)][string]$Base,     # base image (jpg/png)
    [string]$Out,                                    # output path; default: posts\<basename>-telegram.png
    [string]$Logo,                                   # logo file; default: first *.jpg in data\
    [double]$Size = 0.13,                            # logo width as share of base width
    [double]$MarginX = 0.025                         # top margin as share of base width
)

$ErrorActionPreference = 'Stop'
Add-Type -AssemblyName System.Drawing

if (-not [IO.Path]::IsPathRooted($Base)) { $Base = Join-Path $PWD $Base }
if (-not (Test-Path -LiteralPath $Base)) { throw "Base image not found: $Base" }

if (-not $Logo) {
    $Logo = (Get-ChildItem -LiteralPath (Join-Path $PWD 'data') -Filter '*.jpg' | Select-Object -First 1).FullName
}
if (-not [IO.Path]::IsPathRooted($Logo)) { $Logo = Join-Path $PWD $Logo }

if (-not $Out) {
    $name = [IO.Path]::GetFileNameWithoutExtension($Base)
    $Out = Join-Path $PWD "posts\$name-telegram.png"
}
$outDir = Split-Path -Parent $Out
if (-not (Test-Path -LiteralPath $outDir)) { New-Item -ItemType Directory -Force $outDir | Out-Null }

$tmpDir = Join-Path $PWD 'tmp'
if (-not (Test-Path -LiteralPath $tmpDir)) { New-Item -ItemType Directory -Force $tmpDir | Out-Null }
$logoTPath = Join-Path $tmpDir 'logo-noks-transparent.png'

# 1) transparent logo: flood fill white background from edges (cached in tmp\)
if (-not (Test-Path -LiteralPath $logoTPath)) {
    $logo = New-Object System.Drawing.Bitmap($Logo)
    $w = $logo.Width; $h = $logo.Height
    $rect = New-Object System.Drawing.Rectangle(0, 0, $w, $h)
    $bd = $logo.LockBits($rect, [System.Drawing.Imaging.ImageLockMode]::ReadWrite, [System.Drawing.Imaging.PixelFormat]::Format32bppArgb)
    $len = $bd.Stride * $h
    $bytes = [byte[]]::new($len)
    [System.Runtime.InteropServices.Marshal]::Copy($bd.Scan0, $bytes, 0, $len)
    $logo.UnlockBits($bd)

    $thresh = 225
    $vis = [byte[]]::new($len)
    $q = New-Object 'System.Collections.Generic.Queue[int]'
    for ($x = 0; $x -lt $w; $x++) {
        foreach ($yi in 0, ($h - 1)) {
            $i = $yi * $bd.Stride + $x * 4
            if ($vis[$i] -eq 0 -and $bytes[$i] -ge $thresh -and $bytes[$i + 1] -ge $thresh -and $bytes[$i + 2] -ge $thresh) { $vis[$i] = 1; $q.Enqueue($i) }
        }
    }
    for ($y = 0; $y -lt $h; $y++) {
        foreach ($xi in 0, ($w - 1)) {
            $i = $y * $bd.Stride + $xi * 4
            if ($vis[$i] -eq 0 -and $bytes[$i] -ge $thresh -and $bytes[$i + 1] -ge $thresh -and $bytes[$i + 2] -ge $thresh) { $vis[$i] = 1; $q.Enqueue($i) }
        }
    }
    while ($q.Count -gt 0) {
        $i = $q.Dequeue()
        $m = [Math]::Min($bytes[$i], [Math]::Min($bytes[$i + 1], $bytes[$i + 2]))
        if ($m -ge 250) { $bytes[$i + 3] = 0 }
        else { $a = (250 - $m) * 12; if ($a -gt 220) { $a = 220 }; $bytes[$i + 3] = $a }
        $col = $i % $bd.Stride
        if ($col -ge 4)              { $n = $i - 4;          if ($vis[$n] -eq 0 -and $bytes[$n] -ge $thresh -and $bytes[$n + 1] -ge $thresh -and $bytes[$n + 2] -ge $thresh) { $vis[$n] = 1; $q.Enqueue($n) } }
        if ($col -le $bd.Stride - 8) { $n = $i + 4;          if ($vis[$n] -eq 0 -and $bytes[$n] -ge $thresh -and $bytes[$n + 1] -ge $thresh -and $bytes[$n + 2] -ge $thresh) { $vis[$n] = 1; $q.Enqueue($n) } }
        if ($i -ge $bd.Stride)       { $n = $i - $bd.Stride; if ($vis[$n] -eq 0 -and $bytes[$n] -ge $thresh -and $bytes[$n + 1] -ge $thresh -and $bytes[$n + 2] -ge $thresh) { $vis[$n] = 1; $q.Enqueue($n) } }
        if ($i -lt $len - $bd.Stride){ $n = $i + $bd.Stride; if ($vis[$n] -eq 0 -and $bytes[$n] -ge $thresh -and $bytes[$n + 1] -ge $thresh -and $bytes[$n + 2] -ge $thresh) { $vis[$n] = 1; $q.Enqueue($n) } }
    }
    $logo.Dispose()
    # 24bpp source loses alpha on lock conversion -> write into a fresh 32bpp bitmap
    $out32 = New-Object System.Drawing.Bitmap($w, $h, [System.Drawing.Imaging.PixelFormat]::Format32bppArgb)
    $bd2 = $out32.LockBits($rect, [System.Drawing.Imaging.ImageLockMode]::ReadWrite, [System.Drawing.Imaging.PixelFormat]::Format32bppArgb)
    [System.Runtime.InteropServices.Marshal]::Copy($bytes, 0, $bd2.Scan0, $len)
    $out32.UnlockBits($bd2)
    $out32.Save($logoTPath, [System.Drawing.Imaging.ImageFormat]::Png)
    $out32.Dispose()
    Write-Output "transparent logo saved: $logoTPath"
}

# 2) overlay logo on base, top-right
$baseImg = [System.Drawing.Image]::FromFile($Base)
$logoT   = [System.Drawing.Image]::FromFile($logoTPath)
$bmp = New-Object System.Drawing.Bitmap($baseImg)
$g = [System.Drawing.Graphics]::FromImage($bmp)
$g.InterpolationMode = [System.Drawing.Drawing2D.InterpolationMode]::HighQualityBicubic
$g.CompositingQuality = [System.Drawing.Drawing2D.CompositingQuality]::HighQuality
$size = [int]($baseImg.Width * $Size)
$x = $baseImg.Width - $size - [int]($baseImg.Width * $MarginX); $y = [int]($baseImg.Width * $MarginX)
$g.DrawImage($logoT, $x, $y, $size, $size)
$g.Dispose(); $baseImg.Dispose(); $logoT.Dispose()
$bmp.Save($Out, [System.Drawing.Imaging.ImageFormat]::Png)
$bmp.Dispose()
Write-Output "saved: $Out"