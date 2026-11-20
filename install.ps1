<#
    PotPlayer AI 实时字幕翻译扩展 —— 安装脚本

    作用：
      1) 把 SubtitleTranslate - AI Translate.as / .ico 复制到
         <PotPlayer>\Extension\Subtitle\Translate\
      2) 可选：在该目录生成 ai-translate.json（模型 / 接口地址 / 密钥）

    用法示例：
      # 只装插件（不写配置，之后在 PotPlayer 设置面板里填）
      powershell -ExecutionPolicy Bypass -File install.ps1

      # 装插件并预置配置（DeepSeek 示例）
      powershell -ExecutionPolicy Bypass -File install.ps1 `
          -ApiKey sk-xxxxxxxx -Model deepseek-chat `
          -ApiUrl https://api.deepseek.com/v1/chat/completions

      # 用现成的配置文件
      powershell -ExecutionPolicy Bypass -File install.ps1 -ConfigFile .\my-config.json

      # 卸载（删除已安装的扩展文件，保留 ai-translate.json）
      powershell -ExecutionPolicy Bypass -File install.ps1 -Uninstall

    说明：PotPlayer 装在 Program Files 时需要管理员权限，脚本会自动弹 UAC。
#>
[CmdletBinding()]
param(
    [string]$PotPlayerDir,
    [string]$Model,
    [string]$ApiUrl,
    [string]$ApiKey,
    [string]$ConfigFile,
    [switch]$Uninstall,
    [switch]$Force
)

$ErrorActionPreference = 'Stop'

$AsName  = 'SubtitleTranslate - AI Translate.as'
$IcoName = 'SubtitleTranslate - AI Translate.ico'
$CfgName = 'ai-translate.json'
$RepoRoot = Split-Path -Parent $MyInvocation.MyCommand.Path

function Write-Step([string]$text) { Write-Host "[AI Translate] $text" }

function Find-PotPlayerDir {
    $keys = @(
        'HKLM:\SOFTWARE\DAUM\PotPlayer64',
        'HKCU:\SOFTWARE\DAUM\PotPlayer64',
        'HKLM:\SOFTWARE\DAUM\PotPlayer',
        'HKCU:\SOFTWARE\DAUM\PotPlayer'
    )
    foreach ($k in $keys) {
        try {
            $item = Get-ItemProperty -Path $k -ErrorAction Stop
            if ($item.ProgramPath -and (Test-Path $item.ProgramPath)) {
                return (Split-Path -Parent $item.ProgramPath)
            }
        } catch { }
    }
    foreach ($c in @(
            (Join-Path ${env:ProgramFiles} 'DAUM\PotPlayer'),
            (Join-Path ${env:ProgramFiles(x86)} 'DAUM\PotPlayer'),
            (Join-Path ${env:ProgramFiles} 'PotPlayer'),
            (Join-Path ${env:ProgramFiles(x86)} 'PotPlayer'))) {
        if ($c -and (Test-Path (Join-Path $c 'PotPlayerMini64.exe'))) { return $c }
        if ($c -and (Test-Path (Join-Path $c 'PotPlayerMini.exe'))) { return $c }
    }
    return $null
}

function Test-Writable([string]$dir) {
    if (-not (Test-Path $dir)) { return $false }
    try {
        $tmp = Join-Path $dir ("~aitrans_test_{0}.tmp" -f (Get-Random))
        [System.IO.File]::WriteAllText($tmp, 'x')
        Remove-Item $tmp -Force -ErrorAction SilentlyContinue
        return $true
    } catch {
        return $false
    }
}

function Show-NextSteps {
    Write-Host ''
    Write-Step '接下来在 PotPlayer 里做两步设置：'
    Write-Host '  1) 右键菜单 -> 字幕 -> 实时字幕翻译 -> 实时字幕翻译设置...'
    Write-Host '     - 翻译引擎：选 “AI 翻译(实时)”'
    Write-Host '     - 原始语言：自动检测（或指定具体语言）'
    Write-Host '     - 目标语言：例如 中文(简体)'
    Write-Host '     - 账户/登录：第一个框填  模型|接口地址|温度|上下文行数|延迟ms|重试次数|最大token'
    Write-Host '          例如  deepseek-chat|https://api.deepseek.com/v1/chat/completions|0.2|3|0|1|0'
    Write-Host '       密码框填 API 密钥（本地模型不需要密钥，填 nullkey）'
    Write-Host '     - 显示方式：选 “下面显示翻译” 或 “仅显示翻译”'
    Write-Host '  2) 右键菜单 -> 字幕 -> 实时有声字幕（Whisper AI 语音转文字），按提示下载引擎/模型'
    Write-Host ''
    Write-Step '配置改动后请完全退出并重新打开 PotPlayer，扩展才会重新加载。'
}

# ---------------------------------------------------------------- 定位 PotPlayer
if ([string]::IsNullOrWhiteSpace($PotPlayerDir)) { $PotPlayerDir = Find-PotPlayerDir }
if ([string]::IsNullOrWhiteSpace($PotPlayerDir)) {
    throw '没找到 PotPlayer 安装目录，请用 -PotPlayerDir "C:\Program Files\DAUM\PotPlayer" 指定。'
}
if (-not (Test-Path $PotPlayerDir)) { throw "目录不存在: $PotPlayerDir" }

$translateDir = Join-Path $PotPlayerDir 'Extension\Subtitle\Translate'
$asPath  = Join-Path $translateDir $AsName
$icoPath = Join-Path $translateDir $IcoName
$cfgPath = Join-Path $translateDir $CfgName

Write-Step "PotPlayer    : $PotPlayerDir"
Write-Step "翻译扩展目录 : $translateDir"

# 找到最近的已存在目录，用它判断有没有写权限
$probe = $translateDir
while (-not (Test-Path $probe)) {
    $parent = Split-Path -Parent $probe
    if ([string]::IsNullOrWhiteSpace($parent) -or $parent -eq $probe) { break }
    $probe = $parent
}

if (-not (Test-Writable $probe)) {
    Write-Step "当前没有写入 $probe 的权限，正在申请管理员权限..."
    $argList = @('-ExecutionPolicy', 'Bypass', '-NoProfile', '-File', "`"$PSCommandPath`"",
                 '-PotPlayerDir', "`"$PotPlayerDir`"", '-Force')
    if ($Model)      { $argList += @('-Model', "`"$Model`"") }
    if ($ApiUrl)     { $argList += @('-ApiUrl', "`"$ApiUrl`"") }
    if ($ApiKey)     { $argList += @('-ApiKey', "`"$ApiKey`"") }
    if ($ConfigFile) { $argList += @('-ConfigFile', "`"$ConfigFile`"") }
    if ($Uninstall)  { $argList += '-Uninstall' }

    Start-Process -FilePath 'powershell.exe' -Verb RunAs -ArgumentList $argList -Wait
    if ($Uninstall) {
        Write-Step '卸载命令已提交。'
    } elseif (Test-Path $asPath) {
        Write-Step '已通过管理员权限完成复制。'
        Show-NextSteps
    } else {
        throw '提权后仍未安装成功，请手动把 src 下的两个文件复制到翻译扩展目录。'
    }
    exit 0
}

if (-not (Test-Path $translateDir)) {
    New-Item -ItemType Directory -Path $translateDir -Force | Out-Null
}

# ---------------------------------------------------------------- 卸载
if ($Uninstall) {
    foreach ($f in @($asPath, $icoPath)) {
        if (Test-Path $f) {
            Remove-Item $f -Force
            Write-Step "已删除: $f"
        }
    }
    if (Test-Path $cfgPath) { Write-Step "已保留配置文件: $cfgPath" }
    Write-Step '卸载完成，重启 PotPlayer 生效。'
    exit 0
}

# ---------------------------------------------------------------- 复制插件
$srcAs  = Join-Path $RepoRoot "src\$AsName"
$srcIco = Join-Path $RepoRoot "src\$IcoName"

if (-not (Test-Path $srcAs)) { throw "找不到扩展主体文件: $srcAs" }
if ((Test-Path $asPath) -and -not $Force) { Write-Step '检测到已安装的版本，直接覆盖。' }

Copy-Item $srcAs $asPath -Force
Write-Step "已安装: $asPath"

if (Test-Path $srcIco) {
    Copy-Item $srcIco $icoPath -Force
    Write-Step "已安装: $icoPath"
} else {
    Write-Step '未找到 .ico 图标（可选，跳过）。可先运行 tools\make-icon.ps1 生成。'
}

# ---------------------------------------------------------------- 生成配置
if ($ConfigFile) {
    if (-not (Test-Path $ConfigFile)) { throw "配置文件不存在: $ConfigFile" }
    Copy-Item $ConfigFile $cfgPath -Force
    Write-Step "已写入配置: $cfgPath"
} elseif ($Model -or $ApiUrl -or $ApiKey) {
    $cfg = [ordered]@{
        model                 = 'deepseek-chat'
        apiUrl                = 'https://api.deepseek.com/v1/chat/completions'
        apiKey                = ''
        temperature           = 0.2
        maxTokens             = 0
        contextLines          = 3
        minChars              = 0
        delayMs               = 0
        retries               = 1
        timeoutMs             = 20000
        cache                 = $true
        keepOriginalOnFailure = $true
        debug                 = $false
        defaultTargetLang     = 'zh-CN'
        authHeader            = 'Authorization: Bearer {key}'
        extraHeaders          = ''
        systemPrompt          = ''
        glossary              = ''
    }
    if (Test-Path $cfgPath) {
        try {
            $old = Get-Content $cfgPath -Raw -Encoding UTF8 | ConvertFrom-Json
            foreach ($p in $old.PSObject.Properties) {
                if ($cfg.Contains($p.Name)) { $cfg[$p.Name] = $p.Value }
            }
        } catch { Write-Step '旧配置文件解析失败，重新生成。' }
    }
    if ($Model)  { $cfg['model'] = $Model }
    if ($ApiUrl) { $cfg['apiUrl'] = $ApiUrl }
    if ($ApiKey) { $cfg['apiKey'] = $ApiKey }

    $jsonText = $cfg | ConvertTo-Json -Depth 5
    [System.IO.File]::WriteAllText($cfgPath, $jsonText, (New-Object System.Text.UTF8Encoding($false)))
    Write-Step "已写入配置: $cfgPath"
} else {
    if (Test-Path $cfgPath) {
        Write-Step "沿用已有配置: $cfgPath"
    } else {
        Write-Step "未生成配置（可在 PotPlayer 设置面板里填，或加 -ApiKey/-Model/-ApiUrl 参数重跑）。"
    }
}

Show-NextSteps
