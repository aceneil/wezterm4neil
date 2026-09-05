<div align="center">

# 🖥️ WezTerm4Neil

**开箱即用的跨平台终端环境：WezTerm + Fish / Nushell(Win) + Starship 一键安装包**

适用于 Windows · Linux（每周自动更新，拿走就能用）；macOS 规划中，见下方说明。

[![GitHub Release](https://img.shields.io/badge/Release-下载安装包-blue?logo=github)](https://github.com/aceneil/wezterm4neil/releases)
[![Build](https://github.com/aceneil/wezterm4neil/actions/workflows/release.yml/badge.svg)](https://github.com/aceneil/wezterm4neil/actions/workflows/release.yml)
[![License: MIT](https://img.shields.io/badge/License-MIT-green.svg)](LICENSE)

</div>

---

## 这是什么？

WezTerm4Neil 是一个**跨平台终端环境（Cross-platform Terminal Environment）**一键安装包：
把几款好评如潮的开源终端工具（Terminal + Shell + Prompt）打包在一起，安装后不用折腾任何配置，
Windows、macOS、Linux 三端长得一样、快捷键一样、开箱即用。

## ✨ 特性一览

- 🚀 **[WezTerm](https://wezterm.org/)** —— 现代 GPU 加速终端模拟器（Terminal Emulator），
  自动读取你的 `~/.ssh/config`，菜单里一键 SSH 直达任意主机
- 🐟 **[Fish Shell](https://fishshell.com/)** —— macOS / Linux 的默认 Shell：开箱即用的自动补全、语法高亮、拼写建议
- 🐚 **[Nushell](https://www.nushell.sh/)** —— Windows 的默认 Shell：**原生跨平台**的现代 Shell，无需 WSL
- ✨ **[Starship](https://starship.rs/)** —— 极速、可定制的跨 Shell 提示符（Prompt），显示 git 分支、目录、语言版本等
- 🔤 **CaskaydiaCove Nerd Font** —— 随包自动安装的图标字体，让终端里的箭头、图标、徽标都正常显示
- ⏰ **每周自动更新** —— GitHub Actions 每周自动从上游拉取最新版打包；上游发布新版后，下一轮自动构建就会带上
- 📦 **离线可装** —— 每个安装包都内置软件本体，下载后不联网也能装

![WezTerm + Fish + Starship 终端效果预览（每周自动渲染更新）](assets/preview.gif)

## 🖥️ 支持平台与内含组件

| 平台 | 安装包 | 默认 Shell | 随包组件 |
| :--- | :--- | :--- | :--- |
| 🐧 Linux | `.deb` 安装包 | Fish（→ Zellij 第二层） | WezTerm + Zellij + **neilwz-nav-tui（自研）** + Fish + Starship + 字体 |
| 🍎 macOS | `.dmg`（**规划中**） | Fish | 组件/脚本已就绪，待 Apple 真机验收后发布 |

> 📌 macOS：目前处于**规划中** —— 流水线与安装脚本已备好（见 [PIPELINE.md](PIPELINE.md)），
> 但因团队暂无 Apple 真机可验收，暂不发布 `.dmg`；待有真机后启用并纳入每周自动构建。
| 🪟 Windows | `.exe` 安装器 | Nushell | WezTerm + Nushell + Starship + 字体 |

每个安装包内都附一份 `VERSIONS.txt`：这次捆绑了哪些组件的哪个版本、来源在哪。
（Windows 默认用 Nushell 是因为 fish 官方不提供 Windows 原生版——Nushell 同样原生、无需 WSL，体验不打折。）

## 🚀 快速开始

到 [Releases](https://github.com/aceneil/wezterm4neil/releases) 下载对应平台的安装包即可。

### 🐧 Linux（.deb）

```bash
sudo apt install ./wezterm4neil_*.deb
# 装完后，用【你自己的账号】把配置激活到用户目录：
bash /etc/wezterm4neil/install.sh      # 拷贝配置；想软链接用 --link
wezterm                                # 打开终端
```

> ⚠️ 本包会替换系统里官方安装的 wezterm/fish/starship 三个命令（见安装时的提示；
> 卸载后按官方渠道重装即可恢复）。

### 🍎 macOS（.dmg）— 规划中（有 Apple 真机后启用）

> 安装步骤已按真实流程编写并保留于此，作为 macOS 版的目标行为：
> 待有真机完成验收后，这些步骤即对应正式发布的 `.dmg`。

1. 双击下载的 `.dmg`，把内容拖到桌面或下载目录
2. 双击里面的 **`install.command`**，按提示输入管理员密码
3. 脚本自动完成：WezTerm.app → 应用程序目录 → 装好 starship（和缺失的 fish）→ 配置落到 `~/.config`
4. 打开 WezTerm 即可（首次如被 Gatekeeper 拦截：右键 WezTerm.app → 打开）

### 🪟 Windows（.exe）

1. 双击 `wezterm4neil-*.exe`（或命令行加 `/S` 静默安装；默认装到
   `%LOCALAPPDATA%\Programs\wezterm4neil`，安装时可自定义目录）
2. 安装器自动完成：注册 PATH → 写入 `~/.config` 配置 → 安装字体 → 配置 Nushell 提示符
3. 从开始菜单或桌面快捷方式打开 WezTerm —— **默认就是 Nushell + Starship**，真正的开箱即用

### 📄 只想用配置文件？（软件已自己装好）

```bash
git clone https://github.com/aceneil/wezterm4neil.git
cd wezterm4neil
./install.sh            # macOS / Linux：拷贝配置到 ~/.config
# ./install.sh --link   # 或者软链接：仓库里改完立即生效
# Windows：以 PowerShell 运行 .\install.ps1
```

## 🎨 想自定义？改这几个文件就够了

| 文件 | 管什么 |
| :--- | :--- |
| `wezterm.lua` | 终端外观（配色/字体/字号）、标签栏、快捷键、鼠标行为、Windows 默认 Shell（Nushell） |
| `config.fish` | Fish（macOS / Linux）：别名 + 自动加载 Starship |
| `nushell.nu` | Nushell（Windows）：别名 |
| `starship.toml` | 提示符（Prompt）长什么样：显示哪些模块、什么配色 |

改完两个选择：**本地生效**（`./install.sh --copy` / `--link` 重新部署到 `~/.config`），
或 **推送 GitHub**——几分钟后 Actions 会自动构建一版含你改动的新安装包。

## ❓ 常见问题（FAQ）

- **Nerd Font 字体会自动装吗？装到哪？**
  会。Windows → `%LOCALAPPDATA%\Microsoft\Windows\Fonts`；macOS → `~/Library/Fonts`；
  Linux → `~/.local/share/fonts`。想让终端更漂亮，可以改 `wezterm.lua` 里的字体链。

- **提示符上的时间不显示？**
  按用户偏好默认关闭了。想打开：编辑 `starship.toml`，把 `[time]` 下 `disabled = true` 改成 `false`。

- **Windows 想找回系统标题栏？**
  编辑 `wezterm.lua`，找到 `IS_WINDOWS` 分支里的 `window_decorations = 'RESIZE'`，
  改成 `'TITLE | RESIZE'` 即可（默认隐藏标题栏是为了更沉浸 + 用标签栏拖拽窗口）。

- **改完配置没生效？**
  WezTerm 里按 `Ctrl+Shift+R` 重载配置（macOS 用 `Cmd+Shift+R`）；如果是 shell 提示符，
  记得开一个**新终端**——Starship 只在新的 Shell 会话里生效。

- **Windows 想用回 PowerShell 当默认？**
  编辑 `~/.config/wezterm/wezterm.lua` 里的 `default_prog`；或删掉
  `~/.config/wezterm4neil/nu-path.txt` 后重跑 `install.ps1`。
  平时想快速开 PowerShell / Cmd：`Ctrl+Shift+Space` 启动菜单，或 `Ctrl+Shift+1`（PowerShell）、`Ctrl+Shift+2`（Cmd）。

- **不想要 Starship，想用纯文本短路径提示符？**
  `nushell.nu` 里有注释好的三行短路径写法（Byxs20 风格），取消注释并把
  `%APPDATA%\nushell\vendor\autoload\starship.nu` 移走即可。

- **安装包坏了 / 构建失败了？**
  流水线不会静默产出坏包：上游改版导致失败时会列出上游实际资产名并明确报错。
  也可以去 [Actions](https://github.com/aceneil/wezterm4neil/actions) 页点「Run workflow」手动重跑。

## 🤝 开发 & 贡献

- 整套流水线每周自动构建三端安装包，细节见 **[PIPELINE.md](PIPELINE.md)**（触发方式 / 7 个构建步骤 / 常见失败对照）。
- 想改进配色、快捷键、别名？直接改对应文件提 PR；想手动触发一次构建？Actions 页点按钮即可。
- 觉得好用请 ⭐ Star，遇到问题欢迎提 [Issue](https://github.com/aceneil/wezterm4neil/issues)。

## 📄 许可证与致谢

- 本仓库配置与脚本：**MIT License**（见 [LICENSE](LICENSE)），© aceneil。
- 配置灵感参考自 [Byxs20/terminal_config](https://github.com/Byxs20/terminal_config)
  （wezterm / nushell 部分；已按本项目「跨平台 + 无硬编码路径」的护栏裁剪改写）。
- 内置组件均为开源软件，各自许可证见安装包内 `licenses/`：
  [WezTerm](https://github.com/wezterm/wezterm)（MIT）· [Fish](https://github.com/fish-shell/fish-shell)（GPL-2）·
  [Nushell](https://github.com/nushell/nushell)（MIT）· [Starship](https://github.com/starship/starship)（ISC）·
  [Nerd Fonts](https://github.com/ryanoasis/nerd-fonts)（MIT）· 预览图录制 [VHS](https://github.com/charmbracelet/vhs)（MIT）
