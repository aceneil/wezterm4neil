WezTerm4Neil (Windows EXE 安装器 · NSIS)
=========================================

本安装器由 GitHub Actions 每周一自动从上游官方 Release 拉取「当时最新」产物组装，
双击即可完成：解包 + 注册用户 PATH + 写入 ~/.config 配置 + Nu 自动加载（离线可用）。
默认安装目录：%LOCALAPPDATA%\Programs\wezterm4neil（安装时可自定义）。

安装后目录布局（WezTerm 为最外层主程序，wezterm-gui.exe 在根）：
----------------------------------------------------------------
  <安装目录>\
    ├─ wezterm-gui.exe / wezterm.exe / ...   WezTerm 本体（最外层，绿色便携）
    ├─ nu\nu.exe                             Nushell 原生版（Windows 默认 shell）
    ├─ starship\starship.exe                 Starship 提示符
    ├─ wezterm.lua / starship.toml / nushell.nu / install.ps1
    ├─ fonts\                                随包字体（CaskaydiaCove Nerd Font 子集）
    ├─ VERSIONS.txt                          本安装器捆绑各组件的版本/来源/构建日期/commit
    ├─ licenses\                             上游组件许可证
    └─ Uninstall.exe                         卸载器（保留 ~/.config 用户配置）

快速开始
--------
  1) 双击 wezterm4neil-<版本>-windows.exe（或命令行加 /S 静默安装）
  2) 安装器自动执行随包 install.ps1：
       - 注册用户级 PATH（安装目录 / nu / starship）
       - 配置写入 %USERPROFILE%\.config\（wezterm / starship）
       - 字体装到 %LOCALAPPDATA%\Microsoft\Windows\Fonts（免管理员）
       - 写 Nu 自动加载：%APPDATA%\nushell\vendor\autoload\
           starship.nu     （提示符，用捆绑 starship 现场生成，无 BOM）
           wezterm4neil.nu （别名）
       - 记录 nu.exe 实际路径到 %USERPROFILE%\.config\wezterm4neil\nu-path.txt
  3) 从开始菜单 / 桌面快捷方式启动 WezTerm —— 默认打开 Nushell + Starship

默认 shell：Nushell（说明）
---------------------------
  本包内置 Nushell（nu.exe，官方原生 Windows 版），WezTerm 默认打开 Nu + Starship，
  无需 WSL，开箱即用。想换默认 shell？
    - 改 %USERPROFILE%\.config\wezterm\wezterm.lua 里的 default_prog
    - 或删除/编辑 nu-path.txt 后重跑 install.ps1
  （macOS / Linux 版默认 shell 为 fish；本 Windows 包不含 fish——fish 官方无 Windows
  原生版，如确需 fish 请使用 WSL 并自行安装。）

安装后想要的行为
----------------
  · WezTerm 窗口默认隐藏系统标题栏（更沉浸），标签栏常显可拖拽窗口；
  · Ctrl+Shift+Space 打开启动菜单选 PowerShell / Cmd；
  · Ctrl+Shift+1 / Ctrl+Shift+2 直接开 PowerShell / Cmd 新标签；
  · 想改这些？编辑 ~/.config\wezterm\wezterm.lua（拷贝模式）后重载配置
    （WezTerm 内 Ctrl+Shift+R 或重启）。

命令行选项
----------
  安装器（NSIS）:  /S 静默安装；/D=<目录> 指定安装目录（必须最后、不带引号）
  install.ps1   :  默认拷贝配置；-Link 用软链接（需开发者模式/管理员）；-Force 强制重装

在线回退
--------
  单独下载 install.ps1（脱离捆绑包）运行时检测不到捆绑产物，
  会自动用 winget 安装 wez.wezterm 与 Starship.Starship，然后仅部署配置。

许可证
------
  本仓库配置代码：MIT（见仓库 LICENSE）；捆绑上游组件各自的许可证见 licenses/。
