# ============================================================================
# WezTerm4Neil · install.ps1 (Windows)
#
# 离线捆绑安装（默认，推荐）——在 .exe 安装目录 / zip 解压目录内运行。
#   检测到同目录捆绑产物（WezTerm\ + starship.exe + nu\）后：
#        - WezTerm 便携版复制到 %LOCALAPPDATA%\Programs\wezterm4neil\WezTerm
#        - starship.exe 复制到 %LOCALAPPDATA%\Programs\wezterm4neil\
#        - 注册用户级 PATH（安装目录）
#        - 配置文件写入 ~/.config（wezterm / starship）
#        - Nushell 原生 shell：nu\ 复制到 %LOCALAPPDATA%\Programs\wezterm4neil\nu
#          （WezTerm 默认启动 Nu；Nu 自动加载目录写入 starship 提示符与别名）
#   ② 在线回退——脱离捆绑产物单独运行本脚本（例如直接下载 install.ps1）：
#        winget install wez.wezterm / Starship.Starship 后，仅部署配置。
#
# 用法（在 zip 解压目录中执行）:
#   powershell -ExecutionPolicy Bypass -File .\install.ps1            # 默认拷贝
#   powershell -ExecutionPolicy Bypass -File .\install.ps1 -Link      # 软链接
#   powershell -ExecutionPolicy Bypass -File .\install.ps1 -Force     # 跳过幂等判断强制重装
#
# 安装目标（%USERPROFILE% = C:\Users\<你>）:
#   wezterm.lua   -> %USERPROFILE%\.config\wezterm\wezterm.lua
#   starship.toml -> %USERPROFILE%\.config\starship.toml
#   Nushell       -> %LOCALAPPDATA%\Programs\wezterm4neil\nu\nu.exe
#   Nu 提示符/别名 -> %APPDATA%\nushell\vendor\autoload\{starship.nu, wezterm4neil.nu}
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
$AppDir     = Join-Path $env:LOCALAPPDATA 'Programs\wezterm4neil'

# 捆绑检测
$BundledWezTerm  = Test-Path (Join-Path $Root 'WezTerm')
$BundledStarship = Test-Path (Join-Path $Root 'starship.exe')
$BundledNu       = Test-Path (Join-Path $Root 'nu\nu.exe')
$NsisMode        = Test-Path (Join-Path $Root '.nsis-installed')   # NSIS 安装器标记：Root 即最终安装目录
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
# Windows 只部署 wezterm 与 starship 配置；shell 用随包 Nushell（见下文 Nu 部署）
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
    $star = Join-Path $RootDir 'starship.exe'
    if (Test-Path $star) {
        $initLines = & $star init nu
        $initLines | Set-Content -Path (Join-Path $nuAuto 'starship.nu') -Encoding utf8
        Write-Log "Nu starship 提示符已写入: vendor\autoload\starship.nu"
    }
    # 记录实际 nu.exe 路径（供 wezterm.lua 在自定义安装路径时仍能找到 Nu 作为默认 shell）
    if ($NuExePath -and (Test-Path $NuExePath)) {
        $markerDir = Join-Path $ConfigRoot 'wezterm4neil'
        New-Item -ItemType Directory -Path $markerDir -Force | Out-Null
        Set-Content -Path (Join-Path $markerDir 'nu-path.txt') -Value $NuExePath -Encoding ascii
        Write-Log "已记录 Nu 实际路径: $NuExePath"
    }
    Write-Info "WezTerm 将默认打开 Nushell + Starship（开箱即用）"
}

# ============================ 主流程 ==========================================
Write-Host ""
Write-Log "WezTerm4Neil installer (Windows)"
Write-Log "模式: $(if ($Bundled) { '捆绑离线（WezTerm + Starship 已内置）' } else { '在线回退（winget 安装程序后仅部署配置）' })"
Write-Log "脚本目录: $Root"

if ($Bundled) {
    # ---- ① 捆绑离线安装 -----------------------------------------------------
    # 安装基准目录：NSIS 场景（含用户自定义路径）→ 程序已就地于 $Root=$INSTDIR；
    # 手动解压 zip 场景 → 复制到默认 %LOCALAPPDATA%\Programs\wezterm4neil
    New-Item -ItemType Directory -Path $AppDir -Force | Out-Null
    $InstallBase = if ($NsisMode) { $Root } else { $AppDir }

    $dstWez  = Join-Path $InstallBase 'WezTerm'
    $dstStar = Join-Path $InstallBase 'starship.exe'
    if (-not $NsisMode) {
        if (Test-Path $dstWez) {
            if ($Force) { Remove-Item $dstWez -Recurse -Force }
            else { Write-Warn "$dstWez 已存在，将合并/覆盖同名文件" }
        }
        Write-Log "复制 WezTerm 便携版 -> $dstWez"
        Copy-Item (Join-Path $Root 'WezTerm') $dstWez -Recurse -Force

        Write-Log "复制 starship.exe -> $dstStar"
        Copy-Item (Join-Path $Root 'starship.exe') $dstStar -Force
    } else {
        Write-Log "NSIS 安装目录: $InstallBase（程序已就地，跳过复制）"
    }
    Add-ToUserPath (Join-Path $InstallBase 'WezTerm')
    Add-ToUserPath $InstallBase

    Write-Log "已安装: $dstWez"
    Write-Log "已安装: $dstStar"

    # ---- Nushell（Windows 原生默认 shell）→ <InstallBase>\nu\nu.exe ------
    $dstNuDir = Join-Path $InstallBase 'nu'
    $NuActual = ''
    if ($BundledNu) {
        if (-not $NsisMode -and -not (Test-Path (Join-Path $dstNuDir 'nu.exe'))) {
            Write-Log "复制 Nushell -> $dstNuDir"
            Copy-Item (Join-Path $Root 'nu') $dstNuDir -Recurse -Force
        }
        Add-ToUserPath $dstNuDir
        $NuActual = Join-Path $dstNuDir 'nu.exe'
        Write-Log "已安装: $NuActual"
    }
} else {
    # ---- ② 在线回退 ---------------------------------------------------------
    Write-Warn "未检测到捆绑产物（WezTerm\ 与 starship.exe），切换到 winget 安装："
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
Write-Log "  · WezTerm —— 从开始菜单/新窗口启动 WezTerm（便携版无需管理员）"
Write-Log "  · Shell —— WezTerm 默认打开 Nushell + Starship（随包内置，开箱即用）"
Write-Log "  · 在 Nu 里试试: ll / gs / gcm 'hi' （别名来自 Nu 自动加载目录）"
Write-Host ""
