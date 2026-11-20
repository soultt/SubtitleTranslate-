<#
    生成 PotPlayer 翻译引擎图标：src\SubtitleTranslate - AI Translate.ico
    用法： powershell -ExecutionPolicy Bypass -File tools\make-icon.ps1

    做法：先用 16x16 点阵画出 “AI” 字形（蓝->紫渐变底、白色字），
          再按整数倍放大成 32x32 / 48x48，打包成 PNG-ICO（Vista 以上可用）。
          完全不依赖 GDI+ 绘图/字体，任何 Windows PowerShell 都能跑。
#>
[CmdletBinding()]
param(
    [string]$OutFile = ''
)

Add-Type -AssemblyName System.Drawing

if ([string]::IsNullOrWhiteSpace($OutFile)) {
    $scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
    $OutFile = Join-Path (Split-Path -Parent $scriptDir) 'src\SubtitleTranslate - AI Translate.ico'
}

# 16x16 点阵：'#' = 白色字形，'.' = 背景（“AI” 居中）
$pattern = @(
    '................'
    '................'
    '................'
    '................'
    '....##.....###..'
    '...#..#.....#...'
    '..#....#....#...'
    '..#....#....#...'
    '..######....#...'
    '..#....#....#...'
    '..#....#....#...'
    '...........###..'
    '................'
    '................'
    '................'
    '................'
)

function New-IcongBitmap {
    param([int]$Scale)

    $src = 16
    $size = $src * $Scale
    $bmp = New-Object System.Drawing.Bitmap($size, $size)
    $white = [System.Drawing.Color]::FromArgb(255, 255, 255, 255)

    for ($y = 0; $y -lt $src; $y++) {
        # 竖直渐变：上蓝下紫
        $t = $y / ($src - 1)
        $r = [int](46 + (138 - 46) * $t)
        $g = [int](108 + (62 - 108) * $t)
        $b = [int](246 + (226 - 246) * $t)
        $bg = [System.Drawing.Color]::FromArgb(255, $r, $g, $b)
        $row = $pattern[$y]
        for ($x = 0; $x -lt $src; $x++) {
            $color = if ($row[$x] -eq '#') { $white } else { $bg }
            for ($dy = 0; $dy -lt $Scale; $dy++) {
                for ($dx = 0; $dx -lt $Scale; $dx++) {
                    $bmp.SetPixel($x * $Scale + $dx, $y * $Scale + $dy, $color)
                }
            }
        }
    }
    return $bmp
}

$sizes = @(32, 48)
$images = New-Object System.Collections.ArrayList
foreach ($size in $sizes) {
    $scale = [int]($size / 16)
    $bmp = New-IcongBitmap -Scale $scale
    $ms = New-Object System.IO.MemoryStream
    $bmp.Save($ms, [System.Drawing.Imaging.ImageFormat]::Png)
    [void]$images.Add(@{ Size = $size; Bytes = $ms.ToArray() })
    $ms.Dispose()
    $bmp.Dispose()
}

$outDir = Split-Path -Parent $OutFile
if (-not (Test-Path $outDir)) { New-Item -ItemType Directory -Path $outDir -Force | Out-Null }

$fs = [System.IO.File]::Create($OutFile)
$bw = New-Object System.IO.BinaryWriter($fs)
try {
    $bw.Write([UInt16]0)                      # reserved
    $bw.Write([UInt16]1)                      # type = icon
    $bw.Write([UInt16]$images.Count)          # image count
    $offset = 6 + 16 * $images.Count
    foreach ($img in $images) {
        $bw.Write([Byte]$img.Size)            # width
        $bw.Write([Byte]$img.Size)            # height
        $bw.Write([Byte]0)                    # palette count
        $bw.Write([Byte]0)                    # reserved
        $bw.Write([UInt16]1)                  # color planes
        $bw.Write([UInt16]32)                 # bits per pixel
        $bw.Write([UInt32]$img.Bytes.Length)  # image size in bytes
        $bw.Write([UInt32]$offset)            # image offset
        $offset += $img.Bytes.Length
    }
    foreach ($img in $images) { $bw.Write($img.Bytes) }
}
finally {
    $bw.Dispose()
    $fs.Dispose()
}

$info = Get-Item $OutFile
"生成成功: {0} ({1} 字节)" -f $info.FullName, $info.Length
