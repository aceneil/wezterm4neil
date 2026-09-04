<div align="center">

# 🖥️ WezTerm4Neil

**开箱即用的跨平台终端环境：WezTerm + Fish + Starship 一键安装包**

适用于 macOS · Windows · Linux，每周自动更新，拿走就能用。

[![GitHub Release](https://img.shields.io/badge/Release-下载安装包-blue?logo=github)](https://github.com/aceneil/wezterm4neil/releases)
[![Build](https://github.com/aceneil/wezterm4neil/actions/workflows/release.yml/badge.svg)](https://github.com/aceneil/wezterm4neil/actions/workflows/release.yml)
[![License: MIT](https://img.shields.io/badge/License-MIT-green.svg)](LICENSE)

</div>

---

WezTerm4Neil 帮你把几款好评如潮的开源终端工具组合成一套**好看、顺手、跨平台一致**的终端环境：

- 🚀 **[WezTerm](https://wezterm.org/)** —— 现代 GPU 加速终端模拟器，自动读取你 `~/.ssh/config` 里的主机别名，一键 SSH 直达
- 🐟 **[Fish Shell](https://fishshell.com/)** —— macOS / Linux 的默认 shell：自动补全、语法高亮、拼写建议
- 🐚 **[Nushell](https://www.nushell.sh/)** —— Windows 的默认 shell：**原生跨平台**的现代 shell，无需 WSL
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
2. 安装器自动：装到 `%LOCALAPPDATA%\Programs\wezterm4neil` → 注册 PATH → 写入 Nu 自动加载
3. 打开 WezTerm —— **默认就是 Nushell + Starship**（nu.exe 已随包内置，真正的开箱即用，不需要 WSL）

#### 🐚 Nushell 与 Starship 是怎么生效的
安装器会替你做三件事（等价于 Nu 官方推荐的配置步骤）：
1. 把随包的 `nu.exe` 装好并加入 PATH
2. 在 Nu 自动加载目录写入别名：`%APPDATA%\nushell\vendor\autoload\wezterm4neil.nu`
3. 用随包 starship 现场生成提示符：`%APPDATA%\nushell\vendor\autoload\starship.nu`

（Nu 每次启动会自动加载该目录下所有 `.nu` 文件。）

> 如果你没用本安装包、而是单独装的 Nushell，可以手动执行 Nu 官方推荐的两行：
> ```nu
> mkdir ($nu.data-dir | path join "vendor/autoload")
> starship init nu | save -f ($nu.data-dir | path join "vendor/autoload/starship.nu")
> ```

> 🐟 想用 fish？macOS / Linux 安装包默认就是 fish；Windows 因 fish 官方不提供原生版，
> 所以默认 Nushell（原生、无需 WSL）——体验不打折，还省一层虚拟机。

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
| `wezterm.lua` | WezTerm：自动读取 `~/.ssh/config` 生成 SSH 域、字体与外观、分屏快捷键（Windows 默认打开 Nushell） |
| `config.fish` | Fish（macOS / Linux）：常用别名（`ll` / git 快捷等）+ 自动加载 Starship |
| `nushell.nu` | Nushell（Windows）：常用别名，装进 Nu 自动加载目录 |
| `starship.toml` | Starship：干净清爽的提示符模板（可自定义） |

想改配色/字体/快捷键？直接改这几个文件后 `git push`，几十分钟后 Releases 就会出一版新安装包。

## ❓ 常见问题

- **安装后没生效？** 打开的是新终端吗？Starship 只在新的 shell 会话生效。
- **想恢复官方版 wezterm/fish/starship？** 卸载本包后按官方渠道重装即可（命令见 [PIPELINE.md](PIPELINE.md) / 包内 postinst 提示）。
- **上游改名导致构建失败？** 流水线会自动列出上游实际资产名并明确报错，不会静默产出坏包。

## 🤝 贡献 & 许可

配置、脚本、流水线全部开源，欢迎提 Issue / PR / ⭐ Star。

[LICENSE](LICENSE) · MIT License · © aceneil
