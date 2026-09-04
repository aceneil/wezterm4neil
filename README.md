# WezTerm4Neil · 跨平台终端全家桶（WezTerm + Fish + Starship）

![WezTerm4Neil 终端预览（GitHub Actions 每周用 VHS 自动生成）](assets/preview.gif)

> 每周一自动构建、跨平台开箱即用的一整套现代终端环境。
> **核心模式 =「随源更新全家桶」**：GitHub Actions 每次运行都会从 WezTerm / Fish / Starship
> 三个上游的官方 GitHub Release **拉取当时最新版本**，与本仓库的配置（`wezterm.lua` /
> `config.fish` / `starship.toml`）组合，产出**内置全部软件本体**的安装包发布到 Release——
> 下载、安装、激活配置三步即用，无需再逐个装软件。

[![Release](https://img.shields.io/github/v/release/aceneil/wezterm4neil?label=Release)](https://github.com/aceneil/wezterm4neil/releases)
[![Workflow](https://img.shields.io/github/actions/workflow/status/aceneil/wezterm4neil/release.yml?label=Weekly%20Build)](https://github.com/aceneil/wezterm4neil/actions)
[![License: MIT](https://img.shields.io/badge/License-MIT-blue.svg)](LICENSE)

---

## 功能特性

- 🖥️ **WezTerm 配置**：自动读取 `~/.ssh/config` 别名生成 SSH 域（`ssh_domains`），
  无需手动维护主机列表；内置字体回退链（含中文字体）、Catppuccin 配色、Vim 风分屏快捷键。
- 🐟 **Fish 配置**：常用快捷别名（Git / 目录 / 文件），自动加载 Starship 提示符。
- 🚀 **Starship 提示符**：自定义 format 模板，跨 shell / 跨平台一致体验。
- 🔁 **随源每周构建**：每周一 00:00 UTC（北京时间 08:00）+ 手动触发 + push 到 main，
  三种触发都会从上游拉取当时最新产物重新打包。
- 📦 **开箱即用安装包**：Linux 标准 `.deb`、macOS 标准 `.dmg`、Windows 标准 `.exe` 安装器，
  **软件本体（WezTerm / Fish / Starship）已捆绑在包内**，离线可装。
- 📋 **VERSIONS.txt**：每个安装包内置捆绑组件的版本 / 来源 URL / 构建日期 / 本仓库 commit。
- ⚡ **一键部署**：`install.sh` / `install.ps1` 支持**软链接或拷贝**到 `~/.config`，
  幂等可重复、自动备份旧配置、`--force` 语义。

## 各平台安装包 = 自动做什么

| 平台 | Release 产物 | 包内自动包含 / 安装后自动完成 |
| :--- | :--- | :--- |
| Linux | `wezterm4neil_<版本>_amd64.deb` | 捆绑上游官方 **wezterm**（Ubuntu22.04 deb）、**fish**（官方预编译单文件，取不到才回退发行版 apt deb）、**starship**（官方二进制）→ 解包到 `/usr/bin` 与 `/usr/share`；配置模板装到 `/etc/wezterm4neil/skel/`，`VERSIONS.txt` 与 `install.sh` 装到 `/etc/wezterm4neil/`；postinst 打印激活指引。`sudo apt install ./xxx.deb` 后执行 `bash /etc/wezterm4neil/install.sh` 即把配置激活到 `~/.config` |
| macOS | `wezterm4neil-<版本>-macos.dmg` | DMG 内含官方 **WezTerm.app**（Universal）、**starship** darwin 二进制、官方 **fish-<版本>.pkg**（该版本没出 pkg 就自动改用 brew）、配置文件与 `install.command`。双击 `install.command` 按提示输入管理员密码 → WezTerm.app 装入 `/Applications`、starship 装入 `/usr/local/bin`、fish 缺失时自动装、配置落到 `~/.config` |
| Windows | `wezterm4neil-<版本>-windows.exe` | NSIS 安装器内含官方便携 **WezTerm**、**starship.exe**、`install.ps1` 与全部配置。双击运行（或 `/S` 静默安装）→ 装到 `%LOCALAPPDATA%\Programs\wezterm4neil\`，自动注册用户 PATH 并把配置写入 `~/.config`；自带卸载器 |
| 全部 | 每个包内均有 `VERSIONS.txt` | 见下节 |

> ⚠️ fish-on-Windows 的取舍：fish 官方**不提供 Windows 原生二进制**（官方支持 WSL/MSYS2），
> 所以 Windows 侧不捆绑 fish 本体：`config.fish` 会写入 `~/.config/fish` 备用，
> 若检测到 WSL 可用 `.\install.ps1 -SetupWslFish` 把它同步进 WSL 家目录；
> 在 WSL 终端里 `fish` 即可获得与 macOS/Linux 一致的环境。没有假装 fish 原生可用。

> ⚠️ **Linux 安装警告**：`.deb` 声明了 `Conflicts/Replaces/Provides: wezterm, fish, starship`，
> 安装本包会**替换/移除**系统里通过官方渠道安装的这三个软件（同抢 `/usr/bin` 路径所致）。
> 卸载本包（`sudo apt remove wezterm4neil`）**不会**自动恢复它们。如需恢复官方版请按官方渠道重装：
> WezTerm 官方 apt 源：`curl -fsSL https://apt.fury.io/wez/gpg.key | sudo gpg --yes --dearmor -o /usr/share/keyrings/wezterm-fury.gpg`，
> 再写入 `deb [signed-by=/usr/share/keyrings/wezterm-fury.gpg] https://apt.fury.io/wez/ * *` 到 `/etc/apt/sources.list.d/wezterm.list`，然后 `sudo apt update && sudo apt install wezterm`（详见 https://wezterm.org/install/linux.html）；
> fish 见 https://fishshell.com/；starship：`curl -sS https://starship.rs/install.sh | sh`（https://starship.rs）。

> ℹ️ GitHub 每次发布会自动附带 **Source code (zip)** 与 **Source code (tar.gz)** 两个源码包，本项目不额外上传源码资产。

## VERSIONS.txt 说明

每次 CI 解析上游三个仓库 `releases/latest` 后生成 `VERSIONS.txt` 并内嵌到每个安装包。
内容示例（字段以实际生成为准）：

```text
# 生成时间(UTC): 2026-09-07T00:00:00Z
# 本仓库 commit: 3f9c1a2...
[component:wezterm]
version=20240203-110809-5046fc22
source=https://github.com/wezterm/wezterm/releases/tag/<tag>
linux=wezterm-<ver>.Ubuntu22.04.deb / macos=WezTerm-macos-<ver>.zip / windows=WezTerm-windows-<ver>.zip
[component:fish]
version=4.9.1
source=https://github.com/fish-shell/fish-shell/releases/tag/v<ver>
linux=fish-<ver>-linux-x86_64.tar.xz（官方自包含） / macos=fish-<ver>.pkg / windows=官方不提供原生二进制
[component:starship]
version=v1.26.0
source=https://github.com/starship/starship/releases/tag/v<ver>
linux=starship-x86_64-unknown-linux-gnu.tar.gz / macos=...-apple-darwin... / windows=...-pc-windows-msvc.zip
```

## 快速开始

### 方式 A：下载 Release 安装包（推荐，开箱即用）

1. 到 [Releases](https://github.com/aceneil/wezterm4neil/releases) 下载对应平台产物；
2. 按上表「安装包自动做什么」安装并激活；
3. 打开 WezTerm，开始使用（默认 shell 若为 fish 会直接见到 Starship 提示符）。

### 方式 B：只用本仓库配置（软件自己装好了）

```bash
git clone https://github.com/aceneil/wezterm4neil.git
cd wezterm4neil

# 拷贝（默认，最稳妥，可重复执行）
./install.sh

# 软链接（推荐开发使用，git pull 后配置即时生效）
./install.sh --link

# 强制重装（跳过「已是最新链接」判断，旧配置先备份）
./install.sh --link --force
```

Windows（在仓库目录执行）：

```powershell
powershell -ExecutionPolicy Bypass -File .\install.ps1          # 拷贝（默认）
powershell -ExecutionPolicy Bypass -File .\install.ps1 -Link    # 软链接（需开发者模式/管理员）
powershell -ExecutionPolicy Bypass -File .\install.ps1 -SetupWslFish  # 顺带同步 config.fish 到 WSL
```

安装目标：

| 文件 | 安装位置 |
| :--- | :--- |
| `wezterm.lua` | `~/.config/wezterm/wezterm.lua` |
| `config.fish` | `~/.config/fish/config.fish` |
| `starship.toml` | `~/.config/starship.toml` |

### Linux .deb 安装示例

```bash
# 下载 wezterm4neil_<版本>_amd64.deb 后：
sudo apt install ./wezterm4neil_<版本>_amd64.deb

# 以你的普通用户身份激活配置到 ~/.config（拷贝模式）：
bash /etc/wezterm4neil/install.sh
# 想软链接（推荐）则：
bash /etc/wezterm4neil/install.sh --link
```

> 注意：本 deb 用 `Conflicts/Replaces/Provides` 声明会替换系统自带的
> `wezterm` / `fish` / `starship` 包（因为 /usr/bin 下同名文件所有权冲突是 dpkg 不允许的）。
> 卸载 `wezterm4neil` 后，如需官方原版请按上文「Linux 安装警告」⚠️ 块中的官方渠道命令重装。

## 工作原理

1. **触发**（三条，见 `on:`）：
   - `schedule` cron `0 0 * * 1`（每周一 00:00 UTC）；
   - `workflow_dispatch`（手动，Actions 页面点 Run workflow）；
   - `push` 到 `main`（含手动改配置立即出包）。
2. **fetch-upstreams job**：解析 `wezterm/wezterm`、`fish-shell/fish-shell`、
   `starship/starship` 三个仓库 `releases/latest` → 下载各平台官方产物 + 官方许可证
   → 生成 `VERSIONS.txt`（含本仓库 `$GITHUB_SHA`）→ 上传 artifact。
3. **build-* 三平台 job**（并行，依赖 fetch-upstreams）：拉取 artifact + checkout 本仓库，
   按上表逻辑组装 `.deb` / `.dmg` / `.exe`，各自内置 `VERSIONS.txt` 与许可证目录；
   随后 **smoke-test-linux** 解包 `.deb` 实测捆绑二进制与 `install.sh`（CI 自证可用）。
4. **release job**：汇总三件产物 → `gh release create/upload`（同一天重复触发则清理旧资产后
   只保留 deb/dmg/exe 补传，幂等）；Source code 源码包由 GitHub 自动附赠。
5. **preview job**：用 [VHS](https://github.com/charmbracelet/vhs) 渲染
   `preview/terminal-demo.tape` 为 `assets/preview.gif`，**内容有变化才 commit 回仓库**
   （防空提交）；README 用带 `alt` 的 Markdown 引用该图，便于搜索引擎抓取。
   为避免 gif-commit 再触发一轮全量打包，fetch/build/release 对
   `docs: update terminal preview GIF` 开头的 push 自动跳过。

## 目录结构

```text
wezterm4neil/
├── README.md                          # 项目说明（本文件）
├── LICENSE                            # MIT（作者 aceneil）
├── wezterm.lua                        # WezTerm 配置：SSH 域自动生成 + 字体/外观/快捷键
├── config.fish                        # Fish 配置：别名 + 自动加载 Starship
├── starship.toml                      # Starship 提示符模板
├── install.sh                         # macOS/Linux 一键部署（拷贝/软链接/--force）
├── install.ps1                        # Windows 一键部署（离线捆绑优先，winget 兜底）
├── assets/preview.gif                 # 终端预览 GIF（首次 CI 运行后自动生成并提交）
├── preview/terminal-demo.tape         # VHS 录制脚本
├── packaging/
│   ├── linux/                         # .deb 组装
│   │   ├── DEBIAN/control             #   control 模板（Depends 由脚本按上游并集重写）
│   │   ├── DEBIAN/postinst            #   postinst（纯文本激活指引）
│   │   └── build-deb.sh               #   组装脚本（CI 与本机验证共用）
│   ├── macos/                         # .dmg 内容物
│   │   ├── install.command            #   双击一键安装（app/二进制/fish/配置）
│   │   └── README.txt                 #   DMG 内说明
│   └── windows/README.txt             #   .zip 内说明（离线安装 / WSL fish）
└── .github/workflows/release.yml      # 随源拉取-组合-打包-发布管线
```

## 自定义与进阶

- SSH 快捷主机：编辑 `~/.ssh/config` 的 `Host` 段，WezTerm 会自动重载并出现在域启动器
  （`Ctrl+Shift+Space`）。
- 快捷键（Leader = `Ctrl+A`，1.5s 内再按第二键）：

  | 快捷键 | 作用 |
  | :--- | :--- |
  | `Ctrl+A` `-` | 垂直分屏 |
  | `Ctrl+A` `Shift+\|` | 水平分屏 |
  | `Ctrl+A` `h/j/k/l` | 窗格间移动（Vim 风格） |
  | `Ctrl+A` `c` | 新建标签页 |

- 提示符：编辑 `starship.toml`（含中文注释，可安全删改）。
- Fish 别名：编辑 `config.fish` 的 alias 段。

## 已知限制 / 待 CI 验证

- `assets/preview.gif` 需首次 GitHub Actions 运行后才会真实存在（仓库内暂无静态占位）。
- 三平台打包与 DMG/zip/ps1 行为需在 GitHub 托管 runner 上验证（本仓库本地不做远端操作）。
- 上游 release asset 命名若改变，fetch-upstreams 会如实失败并在日志给出提示（不会假装成功）。

## License

[MIT](LICENSE) © aceneil

捆绑的上游组件许可证：wezterm (MIT) / fish (GPL-2) / starship (ISC)，均随安装包内 `licenses/` 分发。
