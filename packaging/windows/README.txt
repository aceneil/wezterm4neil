WezTerm4Neil (Windows .zip)
==========================

本 zip 由 GitHub Actions 每周一自动从上游官方 Release 拉取「当时最新」产物组装，
内含开箱即用的便携版 WezTerm + Starship + 配置文件（离线可用），
并附带一键安装脚本 install.ps1。

内容物
------
  WezTerm\           官方便携版 WezTerm（含 wezterm-gui.exe 等，绿色免安装）
  starship.exe       官方 Windows 二进制
  install.ps1        一键安装/静默配置脚本（离线捆绑模式优先）
  wezterm.lua        WezTerm 配置（自动读取 ~/.ssh/config 生成 SSH 域）
  config.fish        fish 配置（别名 + Starship）——供 WSL 内 fish 使用
  starship.toml      Starship 提示符模板
  VERSIONS.txt       本 zip 捆绑各组件的版本 / 来源 URL / 构建日期 / 仓库 commit
  licenses/          上游组件许可证（MIT / ISC）

快速开始（离线，推荐）
----------------------
  1) 解压 zip 到任意目录（如 %USERPROFILE%\Downloads\wezterm4neil）
  2) 在该目录打开 PowerShell，执行：
       powershell -ExecutionPolicy Bypass -File .\install.ps1
     脚本会：
       - 把 WezTerm 便携版复制到 %LOCALAPPDATA%\Programs\wezterm4neil\
       - 注册用户级 PATH
       - 配置写入 %USERPROFILE%\.config\（wezterm / fish / starship）
  3) 从开始菜单或新终端启动 WezTerm

在线回退
--------
  直接单独下载 install.ps1（脱离 zip）运行时，脚本检测不到捆绑产物，
  会自动用 winget 安装：wez.wezterm 与 Starship.Starship，然后仅部署配置。

fish 的取舍（重要）
-------------------
  fish 官方不提供 Windows 原生二进制（官方支持 WSL / MSYS2 环境）。
  因此本包在 Windows 侧不包含 fish 本体，而是：
    - 仍把 config.fish 写到 %USERPROFILE%\.config\fish\，供 WSL 使用；
    - 若本机装有 WSL，可执行:  .\install.ps1 -SetupWslFish
      自动把 config.fish 写入 WSL 家目录（WSL 内请先: sudo apt install fish &&
      curl -sS https://starship.rs/install.sh | sh）。
  在 WSL 终端里运行 fish 即可获得与 macOS/Linux 一致的体验。

命令行选项
----------
  .\install.ps1           默认：拷贝配置
  .\install.ps1 -Link     配置用软链接（需开发者模式/管理员）
  .\install.ps1 -Force    跳过幂等判断，强制重装
  .\install.ps1 -SetupWslFish  额外把 config.fish 写入 WSL

许可证
------
  本仓库配置代码：MIT（见仓库 LICENSE）；捆绑上游组件各自的许可证见 licenses/。
