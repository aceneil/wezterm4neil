WezTerm4Neil (macOS .dmg)
========================

本 DMG 由 GitHub Actions 每周一自动从各上游官方 Release 拉取「当时最新」产物组装：
一个开箱即用的 WezTerm + Fish + Starship 终端全家桶。

内容物
------
  WezTerm.app        官方最新稳定版（Universal，Intel/Apple Silicon 通用）
  starship           官方 darwin 单二进制（将安装到 /usr/local/bin）
  fish-<版本>.pkg    官方 macOS 安装包（仅在 fish 缺失时按提示安装）
  install.command    一键安装脚本（双击运行）
  install.sh         配置部署脚本（拷贝/软链接到 ~/.config，可重复执行）
  wezterm.lua        WezTerm 配置（自动读取 ~/.ssh/config 生成 SSH 域）
  config.fish        fish 基础配置（别名 + 自动加载 Starship）
  starship.toml      Starship 提示符模板
  VERSIONS.txt       本 DMG 捆绑各组件的版本 / 来源 URL / 构建日期 / 仓库 commit
  licenses/          上游组件许可证（MIT / GPL-2 / ISC）

快速开始
--------
  1) 双击 install.command，按提示输入管理员密码（装到 /Applications 与 /usr/local/bin 需要）
  2) 首次打开 WezTerm 如被 Gatekeeper 拦截：右键 WezTerm.app → 打开
  3) 想用 fish 作为默认 shell：chsh -s /usr/local/bin/fish （或 brew 安装路径）

fish 说明
---------
  若本 DMG 内未附带 fish-*.pkg（上游该版本未发布 pkg），install.command 会改用
  `brew install fish`；若既无 pkg 又无 brew，请自行安装 fish 后重新运行本脚本。

许可证
------
  本仓库配置代码：MIT（见仓库 LICENSE）；捆绑上游组件各自的许可证见 licenses/。
