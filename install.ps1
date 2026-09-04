# ============================================================================
# WezTerm4Neil · install.ps1 (Windows)
#
# 双模式：
#   ① 捆绑离线模式（默认，推荐）——在 Release 的 .zip 解压目录内运行。
#      脚本检测到同目录捆绑产物（WezTerm\ + starship.exe）后：
#        - WezTerm 便携版复制到 %LOCALAPPDATA%\Programs\wezterm4neil\WezTerm
#        - starship.exe 复制到 %LOCALAPPDATA%\Programs\wezterm4neil\
#        - 注册用户级 PATH（安装目录）
#        - 配置文件写入 ~/.config（wezterm / fish / starship）
#        - fish 说明：官方不提供 Windows 原生二进制 → 提示用 WSL
#          （见 -SetupWslFish 开关，把 config.fish 写入 WSL 家目录）
#   ② 在线回退——脱离捆绑产物单独运行本脚本（例如直接下载 install.ps1）：
#        winget install wez.wezterm / Starship.Starship 后，仅部署配置。
#
# 用法（在 zip 解压目录中执行）:
#   powershell -ExecutionPolicy Bypass -File .\install.ps1            # 默认拷贝
#   powershell -ExecutionPolicy Bypass -File .\install.ps1 -Link      # 软链接
#   powershell -ExecutionPolicy Bypass -File .\install.ps1 -Force     # 跳过幂等判断强制重装
#   powershell -ExecutionPolicy Bypass -File .\install.ps1 -SetupWslFish  # 额外把 config.fish 写入 WSL
#
# 安装目标（%USERPROFILE% = C:\Users\<你>）:
#   wezterm.lua   -> %USERPROFILE%\.config\wezterm\wezterm.lua
#   config.fish   -> %USERPROFILE%\.config\fish\config.fish
#   starship.toml -> %USERPROFILE%\.config\starship.toml
#
# 说明: 创建符号链接需要「开发者模式」或管理员身份；失败时自动回退为拷贝。
# 官方出处: wezterm winget id = wez.wezterm (wezterm.org/install/windows.html)
#           starship winget id = Starship.Starship (starship.rs)
# ============================================================================
param(
    [switch]$Link,
    [switch]$Force,
    [switch]$SetupWslFish
)
$ErrorActionPreference = 'Stop'

$Root       = Split-Path -Parent $MyInvocation.MyCommand.Path
$ConfigRoot = Join-Path $env:USERPROFILE '.config'
$AppDir     = Join-Path $env:LOCALAPPDATA 'Programs\wezterm4neil'

# 捆绑检测
$BundledWezTerm  = Test-Path (Join-Path $Root 'WezTerm')
$BundledStarship = Test-Path (Join-Path $Root 'starship.exe')
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
$Items = @(
    @{ Src = 'wezterm.lua';   Dir = 'wezterm'; File = 'wezterm.lua' },
    @{ Src = 'config.fish';   Dir = 'fish';     File = 'config.fish' },
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

# ---- WSL fish 分支：把 config.fish 写入 WSL 家目录 ----------------------------
function Install-FishToWsl {
    $wsl = Get-Command wsl.exe -ErrorAction SilentlyContinue
    if (-not $wsl) { Write-Warn "未检测到 wsl.exe，跳过 WSL fish 配置"; return }
    $src = Join-Path $Root 'config.fish'
    if (-not (Test-Path $src)) { Write-Warn "找不到 config.fish，跳过 WSL fish 配置"; return }

    Write-Log "检测到 WSL，正在写入 config.fish 到 WSL 家目录..."
    $b64 = [Convert]::ToBase64String([Text.Encoding]::UTF8.GetBytes((Get-Content $src -Raw -Encoding UTF8)))
    & wsl.exe -e sh -lc "mkdir -p ~/.config/fish && printf '%s' '$b64' | base64 -d > ~/.config/fish/config.fish"
    if ($LASTEXITCODE -eq 0) {
        Write-Log "已写入 WSL: ~/.config/fish/config.fish"
        Write-Info "WSL 内请确保已安装 fish 与 starship： sudo apt install fish && curl -sS https://starship.rs/install.sh | sh"
    } else {
        Write-Warn "写入 WSL 失败（exit=$LASTEXITCODE），请手动复制 config.fish"
    }
}

# ============================ 主流程 ==========================================
Write-Host ""
Write-Log "WezTerm4Neil installer (Windows)"
Write-Log "模式: $(if ($Bundled) { '捆绑离线（WezTerm + Starship 已内置）' } else { '在线回退（winget 安装程序后仅部署配置）' })"
Write-Log "脚本目录: $Root"

if ($Bundled) {
    # ---- ① 捆绑离线安装 -----------------------------------------------------
    New-Item -ItemType Directory -Path $AppDir -Force | Out-Null

    $dstWez  = Join-Path $AppDir 'WezTerm'
    $dstStar = Join-Path $AppDir 'starship.exe'

    # NSIS 安装器场景：install.ps1 已在最终安装目录内执行（Root == AppDir），
    # 程序已就地就位 → 跳过程序复制（避免 Copy-Item 同路径自复制报错），只注册 PATH 与配置。
    $rootReal = (Resolve-Path $Root -ErrorAction SilentlyContinue).Path
    $appReal  = (Resolve-Path $AppDir -ErrorAction SilentlyContinue).Path
    if ($rootReal -and $appReal -and $rootReal -eq $appReal) {
        Write-Log "已在安装目录内运行（NSIS 场景），跳过程序复制，仅注册 PATH 与配置"
    } else {
        if (Test-Path $dstWez) {
            if ($Force) { Remove-Item $dstWez -Recurse -Force }
            else { Write-Warn "$dstWez 已存在，将合并/覆盖同名文件" }
        }
        Write-Log "复制 WezTerm 便携版 -> $dstWez"
        Copy-Item (Join-Path $Root 'WezTerm') $dstWez -Recurse -Force

        Write-Log "复制 starship.exe -> $dstStar"
        Copy-Item (Join-Path $Root 'starship.exe') $dstStar -Force
    }
    Add-ToUserPath (Join-Path $AppDir 'WezTerm')
    Add-ToUserPath $AppDir

    Write-Log "已安装: $dstWez"
    Write-Log "已安装: $dstStar"
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

# fish 说明与 WSL 分支
Write-Host ""
Write-Warn "fish 官方不提供 Windows 原生二进制（官方支持 WSL/MSYS2 环境）。"
Write-Warn "config.fish 已写入本机 %USERPROFILE%\.config\fish\ 以备 WSL 使用。"
if ($SetupWslFish) {
    Install-FishToWsl
} else {
    Write-Info "如需把 config.fish 同步进 WSL：重新运行  .\install.ps1 -SetupWslFish"
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
Write-Log "  · Starship —— 新开终端生效；在 fish/bash/powershell 配置里执行 starship init <shell>"
Write-Log "  · 想以 fish 为主 shell？安装 WSL 并在 WSL 终端中: sudo apt install fish"
Write-Host ""
