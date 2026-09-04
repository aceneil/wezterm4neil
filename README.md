<div align="center">

# 🖥️ WezTerm4Neil

**开箱即用的跨平台终端环境：WezTerm + Fish + Starship 一键安装包**

适用于 macOS · Windows · Linux，每周自动更新，拿走就能用。

[![GitHub Release](https://img.shields.io/badge/Release-下载安装包-blue?logo=github)](https://github.com/aceneil/wezterm4neil/releases)
[![Build](https://github.com/aceneil/wezterm4neil/actions/workflows/release.yml/badge.svg)](https://github.com/aceneil/wezterm4neil/actions/workflows/release.yml)
[![License: MIT](https://img.shields.io/badge/License-MIT-green.svg)](LICENSE)

</div>

---

WezTerm4Neil 帮你把三款好评如潮的开源终端工具组合成一套**好看、顺手、跨平台一致**的终端环境：

- 🚀 **[WezTerm](https://wezterm.org/)** —— 现代 GPU 加速终端模拟器，自动读取你 `~/.ssh/config` 里的主机别名，一键 SSH 直达
- 🐟 **[Fish Shell](https://fishshell.com/)** —— 号称「开箱即用」的友好 shell：自动补全、语法高亮、拼写建议
- ✨ **[Starship](https://starship.rs/)** —— 极速、可定制的跨 shell 提示符（显示 git 分支、目录、运行时间等）

**不需要折腾配置文件**：每周末 GitHub Actions 自动从上游拉取最新版软件，打包成安装包放到 [Releases](https://github.com/aceneil/wezterm4neil/releases)。

![WezTerm + Fish + Starship 终端效果预览（每周自动更新）](assets/preview.gif)

## ✨ 自动更新，每周一个新包

- ⏰ **每周一自动构建**（北京时间 08:00），上游出新版就跟着出
- 👆 想立刻更新？在 Actions 页点一下「Run workflow」
- 📦 每个安装包都**内置最新软件本体**，下载后离线可装
- 📋 每个包内附 `VERSIONS.txt`：这次捆绑了哪些版本、来源在哪

想知道自动化具体干了什么？看 **[PIPELINE.md](PIPELINE.md)**（流程图 + 每个环节说明）。

## 🚀 快速开始

到 [Releases](https://github.com/aceneil/wezterm4neil/releases) 下载对应平台安装包：

### Linux
```bash
sudo apt install ./wezterm4neil_*.deb
# 装完后把配置激活到你的用户目录（用你自己的账号执行）：
bash /etc/wezterm4neil/install.sh
wezterm
```
> ⚠️ 本包会替换系统里官方安装的 wezterm/fish/starship（见包内 postinst 提示与 [PIPELINE.md](PIPELINE.md) 中的恢复说明）。

### macOS
1. 双击下载的 `.dmg`，把内容拖到桌面/下载目录
2. 双击里面的 **`install.command`**，按提示输入管理员密码
3. 脚本自动：安装 WezTerm.app → 装好 starship（和缺失的 fish）→ 配置落到 `~/.config`
4. 打开 WezTerm 即可

### Windows
1. 双击 `wezterm4neil-*.exe`（或命令行加 `/S` 静默安装）
2. 安装器自动：装到 `%LOCALAPPDATA%\Programs\wezterm4neil` → 注册 PATH → 配置写入 `~/.config`
3. 开始菜单/新窗口打开 WezTerm
4. 想用 Fish？见下方「🐟 Windows 手动安装 fish」

#### 🐟 Windows 手动安装 fish（可选）

fish 官方不提供 Windows 原生版，官方支持的两条路是 **WSL**（推荐，体验完整）和 **MSYS2**（轻量）：

**方案 A：WSL（推荐，体验与 macOS/Linux 一致）**
```bash
# 1) 首次安装 WSL（需要重启一次）——在 Windows 的 cmd/PowerShell 里：
wsl --install

# 2) 进入 Ubuntu 终端后，安装 fish 和 starship：
sudo apt update
sudo apt install -y fish
curl -sS https://starship.rs/install.sh | sh

# 3) 应用本项目配置（直接用 GitHub 上的最新版）：
mkdir -p ~/.config/fish ~/.config/starship
curl -fsSL -o ~/.config/fish/config.fish \
  https://raw.githubusercontent.com/aceneil/wezterm4neil/main/config.fish
curl -fsSL -o ~/.config/starship.toml \
  https://raw.githubusercontent.com/aceneil/wezterm4neil/main/starship.toml

# 4) 进入 fish：
fish
# （可选）把 fish 设为默认 shell：
chsh -s /usr/bin/fish
```

> 💡 如果已经用上面的 `.exe` 安装器装过 WezTerm4Neil，可以偷懒：
> 在 Windows 上运行一次 `install.ps1 -SetupWslFish`，它会自动把 `config.fish` 同步进 WSL 家目录。

**方案 B：MSYS2（更轻量，适合不想装 WSL 的机器）**
```bash
# 在 MSYS2 终端里：
pacman -Syu fish
fish
# 再把 config.fish / starship.toml 放到 MSYS2 家目录 ~/.config/ 下即可
```

装好后回到 **WezTerm**：新建标签页选 **Ubuntu**（或 MSYS2），就能看到带 Starship 提示符的 fish 了。

### 只用配置、软件自己装好了？
```bash
git clone https://github.com/aceneil/wezterm4neil.git
cd wezterm4neil
./install.sh            # 拷贝配置到 ~/.config（macOS/Linux）
# ./install.sh --link   # 或者用软链接，配置文件更新后即时生效
# Windows: 运行 install.ps1
```

## 🎨 里面都有什么配置

| 文件 | 作用 |
| :--- | :--- |
| `wezterm.lua` | WezTerm：自动读取 `~/.ssh/config` 生成 SSH 域、字体与外观、分屏快捷键 |
| `config.fish` | Fish：常用别名（`ll` / git 快捷等）+ 自动加载 Starship |
| `starship.toml` | Starship：干净清爽的提示符模板（可自定义） |

想改配色/字体/快捷键？直接改这三个文件后 `git push`，几十分钟后 Releases 就会出一版新安装包。

## ❓ 常见问题

- **安装后没生效？** 打开的是新终端吗？Starship 只在新的 shell 会话生效。
- **想恢复官方版 wezterm/fish/starship？** 卸载本包后按官方渠道重装即可（命令见 [PIPELINE.md](PIPELINE.md) / 包内 postinst 提示）。
- **上游改名导致构建失败？** 流水线会自动列出上游实际资产名并明确报错，不会静默产出坏包。

## 🤝 贡献 & 许可

配置、脚本、流水线全部开源，欢迎提 Issue / PR / ⭐ Star。

[LICENSE](LICENSE) · MIT License · © aceneil
