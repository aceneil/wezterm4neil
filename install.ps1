# ============================================================================
# WezTerm4Neil · install.ps1 (Windows)
#
# 目录布局（WezTerm 作为最外层主程序，直接位于产品根）：
#   %LOCALAPPDATA%\Programs\wezterm4neil\
#     ├─ wezterm-gui.exe / wezterm.exe / ...   ← WezTerm 本体（最外层主程序）
#     ├─ nu\nu.exe                             ← 组件① Nushell（原生默认 shell）
#     ├─ starship\starship.exe                 ← 组件② Starship 提示符
#     ├─ wezterm.lua / starship.toml / nushell.nu / install.ps1 / VERSIONS.txt
#     ├─ licenses\
#     └─ Uninstall.exe
#
# 本脚本在「已展开的安装目录内」运行（NSIS 安装器目录 / zip 解压目录均可），
# 它不会复制程序本体——本体已就地（WezTerm 即最外层）；脚本只负责：
#   ① 注册用户级 PATH（产品根 / nu / starship）
#   ② 把配置写入 ~/.config（wezterm / starship）
#   ③ 写 Nu 自动加载（starship 提示符 + 别名）并记录实际 nu.exe 路径
#   ④ （可选）在线回退：脱离捆绑时用 winget 安装 wezterm/starship
#
# 用法（在安装目录中执行）:
#   powershell -ExecutionPolicy Bypass -File .\install.ps1            # 默认拷贝
#   powershell -ExecutionPolicy Bypass -File .\install.ps1 -Link      # 软链接
#   powershell -ExecutionPolicy Bypass -File .\install.ps1 -Force     # 跳过幂等判断强制重装
#
# 安装目标（%USERPROFILE% = C:\Users\<你>）:
#   wezterm.lua   -> %USERPROFILE%\.config\wezterm\wezterm.lua
#   starship.toml -> %USERPROFILE%\.config\starship.toml
#   Nu 提示符/别名 -> %APPDATA%\nushell\vendor\autoload\{starship.nu, wezterm4neil.nu}
#   Nu 实际路径    -> %USERPROFILE%\.config\wezterm4neil\nu-path.txt
#
# 说明: 创建符号链接需要「开发者模式」或管理员身份；失败时自动回退为拷贝。
# 官方出处: wezterm winget id = wez.wezterm (wezterm.org/install/windows.html)
#           starship winget id = Starship.Starship (starship.rs)
# ============================================================================
param(
    [switch]$Link,
    [switch]$Force
)
$ErrorActionPreference = 'Stop'

$Root       = Split-Path -Parent $MyInvocation.MyCommand.Path
$ConfigRoot = Join-Path $env:USERPROFILE '.config'
$AppDir     = $Root                     # 产品根即安装目录（WezTerm 最外层）

# 捆绑检测
$BundledWezTerm  = Test-Path (Join-Path $Root 'wezterm-gui.exe')
$BundledNu       = Test-Path (Join-Path $Root 'nu\nu.exe')
$BundledStarship = (Test-Path (Join-Path $Root 'starship\starship.exe')) -or (Test-Path (Join-Path $Root 'starship.exe'))
$Bundled         = $BundledWezTerm -and $BundledStarship

function Write-Log  { Write-Host "[wezterm4neil] $args" -ForegroundColor Green }
function Write-Warn { Write-Host "[wezterm4neil] 警告: $args" -ForegroundColor Yellow }
function Write-Info { Write-Host "[wezterm4neil] $args" -ForegroundColor Cyan }

# ---- 用户级 PATH 工具 --------------------------------------------------------
function Add-ToUserPath([string]$dir) {
    $userPath = [Environment]::GetEnvironmentVariable('Path', 'User')
    if (-not $userPath) { $userPath = '' }
    if ($userPath -split ';' -notcontains $dir) {
        $newPath = if ($userPath) { "$userPath;$dir" } else { $dir }
        [Environment]::SetEnvironmentVariable('Path', $newPath, 'User')
        Write-Log "已加入用户 PATH: $dir"
        Write-Info "提示: 新 PATH 需重开终端生效（当前会话请手动 set PATH=$dir;%PATH%）"
    } else {
        Write-Log "PATH 已包含: $dir"
    }
}

# ---- 配置文件部署 ------------------------------------------------------------
# Windows 只部署 wezterm 与 starship 配置；shell 用随包 Nushell（见 Nu 部署节）
$Items = @(
    @{ Src = 'wezterm.lua';   Dir = 'wezterm'; File = 'wezterm.lua' },
    @{ Src = 'starship.toml'; Dir = '.';        File = 'starship.toml' }
)

function Install-ConfigFiles {
    foreach ($item in $Items) {
        $srcPath = Join-Path $Root $item.Src
        if (-not (Test-Path $srcPath)) {
            Write-Warn "跳过 $($item.Src)：源文件不存在 ($srcPath)"
            continue
        }

        $dstDir  = if ($item.Dir -eq '.') { $ConfigRoot } else { Join-Path $ConfigRoot $item.Dir }
        $dstPath = Join-Path $dstDir $item.File
        New-Item -ItemType Directory -Path $dstDir -Force | Out-Null

        # 幂等：已是本源的软链接则跳过（除非 -Force）
        if (-not $Force) {
            $link = Get-Item $dstPath -ErrorAction SilentlyContinue
            if ($link -and $link.LinkType -eq 'SymbolicLink' -and $link.Target -eq $srcPath) {
                Write-Log "已是最新链接，跳过: $dstPath"
                continue
            }
        }

        if (Test-Path $dstPath) {
            $bak = "$dstPath.bak.$(Get-Date -Format 'yyyyMMddHHmmss')"
            Move-Item -Path $dstPath -Destination $bak -Force
            Write-Warn "原文件已备份到: $bak"
        }

        if ($Link) {
            try {
                New-Item -ItemType SymbolicLink -Path $dstPath -Target $srcPath | Out-Null
                Write-Log "已创建软链接: $dstPath -> $srcPath"
                continue
            } catch {
                Write-Warn "创建软链接失败（需开发者模式/管理员），回退为拷贝: $($_.Exception.Message)"
            }
        }
        Copy-Item -Path $srcPath -Destination $dstPath -Force
        Write-Log "已拷贝: $dstPath"
    }
}

# ---- Nu 自动加载工具（starship 提示符 + 别名写入 Nu autoload 目录）-----------
function Install-NuAutoload {
    param([string]$RootDir, [string]$NuExePath)
    $nuData = Join-Path $env:APPDATA 'nushell'
    $nuAuto = Join-Path $nuData 'vendor\autoload'
    New-Item -ItemType Directory -Path $nuAuto -Force | Out-Null
    $aliasSrc = Join-Path $RootDir 'nushell.nu'
    if (Test-Path $aliasSrc) {
        Copy-Item $aliasSrc (Join-Path $nuAuto 'wezterm4neil.nu') -Force
        Write-Log "Nu 别名已写入: vendor\autoload\wezterm4neil.nu"
    }
    $star = Join-Path $RootDir 'starship\starship.exe'
    if (-not (Test-Path $star)) { $star = Join-Path $RootDir 'starship.exe' }
    if (Test-Path $star) {
        $initLines = (& $star init nu) -join [Environment]::NewLine
        # Nu 不认 UTF-8 BOM：用无 BOM 写入，避免把首行注释当命令
        [IO.File]::WriteAllText((Join-Path $nuAuto 'starship.nu'), $initLines, [Text.UTF8Encoding]::new($false))
        Write-Log "Nu starship 提示符已写入: vendor\autoload\starship.nu"
    }
    # 记录实际 nu.exe 路径（供 wezterm.lua 作为默认 shell；自定义安装目录同样适用）
    if ($NuExePath -and (Test-Path $NuExePath)) {
        $markerDir = Join-Path $ConfigRoot 'wezterm4neil'
        New-Item -ItemType Directory -Path $markerDir -Force | Out-Null
        # 无 BOM UTF-8 写入：PS5.1 的 -Encoding ascii 会破坏中文安装目录/用户名，
        # -Encoding utf8 会带 BOM（wezterm.lua 读首行会把 BOM 当路径一部分→找不到文件）；
        # 与上方 starship.nu 同款 .NET 写法，PS5.1/7+ 均安全。
        [IO.File]::WriteAllText((Join-Path $markerDir 'nu-path.txt'), $NuExePath, [Text.UTF8Encoding]::new($false))
        Write-Log "已记录 Nu 实际路径: $NuExePath"
    }
    Write-Info "WezTerm 将默认打开 Nushell + Starship（开箱即用）"
}


# ---- Nerd Font 自动安装（用户级免管理员；CaskaydiaCove 供 Powerline 图标）----
function Install-NerdFonts {
    param([string]$RootDir)
    $src = Join-Path $RootDir 'fonts'
    if (-not (Test-Path $src)) { Write-Warn "未发现 fonts 目录，跳过字体安装"; return }
    $fd = Join-Path $env:LOCALAPPDATA 'Microsoft\Windows\Fonts'
    New-Item -ItemType Directory -Path $fd -Force | Out-Null
    $reg = 'HKCU:\Software\Microsoft\Windows NT\CurrentVersion\Fonts'
    $regNames = @{
        'CaskaydiaCoveNerdFont-Regular.ttf'    = 'CaskaydiaCove Nerd Font (TrueType)'
        'CaskaydiaCoveNerdFont-Bold.ttf'       = 'CaskaydiaCove Nerd Font Bold (TrueType)'
        'CaskaydiaCoveNerdFont-Italic.ttf'     = 'CaskaydiaCove Nerd Font Italic (TrueType)'
        'CaskaydiaCoveNerdFont-BoldItalic.ttf' = 'CaskaydiaCove Nerd Font Bold Italic (TrueType)'
    }
    foreach ($ttf in Get-ChildItem $src -Filter *.ttf) {
        Copy-Item $ttf.FullName (Join-Path $fd $ttf.Name) -Force
        $val = $regNames[$ttf.Name]
        if (-not $val) { $val = ($ttf.BaseName -replace '-', ' ') + ' (TrueType)' }
        New-ItemProperty -Path $reg -Name $val -Value (Join-Path $fd $ttf.Name) -PropertyType String -Force | Out-Null
        Write-Log "字体已安装: $val"
    }
}

# ============================ 主流程 ==========================================
Write-Host ""
Write-Log "WezTerm4Neil installer (Windows)"
Write-Log "模式: $(if ($Bundled) { '捆绑离线（WezTerm + Nushell + Starship 已内置，WezTerm 为最外层）' } else { '在线回退（winget 安装程序后仅部署配置）' })"
Write-Log "安装目录: $Root"

if ($Bundled) {
    # ---- ① 捆绑离线：程序本体已就地，只注册 PATH ---------------------------
    Add-ToUserPath $Root                       # WezTerm 本体（wezterm-gui.exe 在根）
    if ($BundledNu) { Add-ToUserPath (Join-Path $Root 'nu') }
    if (Test-Path (Join-Path $Root 'starship\starship.exe')) { Add-ToUserPath (Join-Path $Root 'starship') }
    Install-NerdFonts -RootDir $Root

    $NuActual = if ($BundledNu) { Join-Path $Root 'nu\nu.exe' } else { '' }
    Write-Log "WezTerm 本体: $Root\wezterm-gui.exe"
    if ($BundledNu) { Write-Log "Nushell: $NuActual" }
} else {
    # ---- ② 在线回退 ---------------------------------------------------------
    Write-Warn "未检测到捆绑产物（wezterm-gui.exe / starship），切换到 winget 安装："
    $wg = Get-Command winget -ErrorAction SilentlyContinue
    if (-not $wg) {
        Write-Warn "未找到 winget，请手动安装：https://wezterm.org / https://starship.rs"
    } else {
        # 官方 winget id: WezTerm = wez.wezterm (wezterm.org/install/windows.html)；Starship = Starship.Starship (starship.rs)
        if (-not (Get-Command wezterm -ErrorAction SilentlyContinue)) {
            Write-Log "winget install --id wez.wezterm ..."
            & winget install --id wez.wezterm -e --accept-package-agreements --accept-source-agreements | Out-Host
        } else {
            Write-Log "wezterm 已在系统中，跳过"
        }
        if (-not (Get-Command starship -ErrorAction SilentlyContinue)) {
            Write-Log "winget install --id Starship.Starship ..."
            & winget install --id Starship.Starship -e --accept-package-agreements --accept-source-agreements | Out-Host
        } else {
            Write-Log "starship 已在系统中，跳过"
        }
    }
}

# 配置文件（两种模式都会执行）
Install-ConfigFiles

# ---- Nushell 自动加载：starship 提示符 + 别名（有随包 nu 才做）---------------
if ($BundledNu) {
    Install-NuAutoload -RootDir $Root -NuExePath $NuActual
}

# 版本信息
if (Test-Path (Join-Path $Root 'VERSIONS.txt')) {
    Write-Host ""
    Write-Log "捆绑版本（VERSIONS.txt）:"
    Get-Content (Join-Path $Root 'VERSIONS.txt') -TotalCount 30 | ForEach-Object { Write-Host "    $_" }
}

Write-Host ""
Write-Log "完成！生效方式:"
Write-Log "  · WezTerm —— 双击桌面/开始菜单的 WezTerm4Neil 图标（或运行 $Root\wezterm-gui.exe）"
Write-Log "  · Shell —— WezTerm 默认打开 Nushell + Starship（随包内置，开箱即用）"
Write-Log "  · 在 Nu 里试试: ll / gs / gcm 'hi' （别名来自 Nu 自动加载目录）"
Write-Host ""
