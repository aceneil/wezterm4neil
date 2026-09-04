WezTerm4Neil (Windows EXE 安装器)
================================

本安装器由 GitHub Actions 每周一自动从上游官方 Release 拉取「当时最新」产物组装，
内含开箱即用的便携版 WezTerm + Starship + 配置文件（离线可用），
安装时自动运行一键脚本 install.ps1（注册用户 PATH + 写入 ~/.config）。

内容物
------
  WezTerm\           官方便携版 WezTerm（含 wezterm-gui.exe 等，绿色免安装）
  starship.exe       官方 Windows 二进制
  nu\                Nushell 原生版（Windows 默认 shell，开箱即用）
  install.ps1        一键安装/静默配置脚本（离线捆绑模式优先）
  wezterm.lua        WezTerm 配置（自动读取 ~/.ssh/config 生成 SSH 域）
  config.fish 已不再随 Windows 包分发；Windows 默认 shell 为 Nushell（见下方说明）
  starship.toml      Starship 提示符模板
  VERSIONS.txt       本安装器捆绑各组件的版本 / 来源 URL / 构建日期 / 仓库 commit
  licenses/          上游组件许可证（MIT / ISC）

快速开始（离线，推荐）
----------------------
  1) 解压 zip 到任意目录（如 %USERPROFILE%\Downloads\wezterm4neil）
  2) 在该目录打开 PowerShell，执行：
       powershell -ExecutionPolicy Bypass -File .\install.ps1
     脚本会：
       - 把 WezTerm 便携版复制到 %LOCALAPPDATA%\Programs\wezterm4neil\
       - 注册用户级 PATH
       - 配置写入 %USERPROFILE%\.config\（wezterm / starship）+ Nu 自动加载
  3) 从开始菜单或新终端启动 WezTerm

在线回退
--------
  直接单独下载 install.ps1（脱离 zip）运行时，脚本检测不到捆绑产物，
  会自动用 winget 安装：wez.wezterm 与 Starship.Starship，然后仅部署配置。

默认 shell：Nushell（说明）
---------------------------
  本包在 Windows 侧内置 Nushell（nu.exe，官方原生 Windows 版），
  安装后 WezTerm 默认打开 Nu + Starship，无需 WSL，开箱即用。
    - Nu 别名文件写入:   %APPDATA%\nushell\vendor\autoload\wezterm4neil.nu
    - Starship 提示符:   %APPDATA%\nushell\vendor\autoload\starship.nu
    - 想换别的 shell？改 %USERPROFILE%\.config\wezterm\wezterm.lua 里的 default_prog 即可
  （macOS / Linux 版默认 shell 为 fish；本 Windows 包不含 fish——fish 官方无 Windows
  原生版，如确需 fish 请使用 WSL 并自行安装。）

命令行选项
----------
  .\install.ps1           默认：拷贝配置
  .\install.ps1 -Link     配置用软链接（需开发者模式/管理员）
  .\install.ps1 -Force    跳过幂等判断，强制重装

许可证
------
  本仓库配置代码：MIT（见仓库 LICENSE）；捆绑上游组件各自的许可证见 licenses/。
