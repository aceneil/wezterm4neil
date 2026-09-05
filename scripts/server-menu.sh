#!/usr/bin/env bash
# ============================================================================
# server-menu.sh —— 左上角「快捷服务」菜单（WezTerm4Neil 第二层 Zellij 布局用）
# 部署位置：~/.local/bin/server-menu.sh
# 用法：编辑本文件，把常用服务/命令写进下面的 echo 提示即可；
#       菜单面板本质是一个 fish 终端，可直接输入任何命令。
# ============================================================================
set -euo pipefail

echo "🚀 快捷服务面板（编辑 ~/.local/bin/server-menu.sh 自定义）"
echo "------------------------------------------------------------"
echo "  htop      | 系统监控          btop   | 进阶监控"
echo "  lazygit   | Git TUI           ncdu   | 磁盘占用"
echo "  yazi      | 文件管理          zellij | 回到 Zellij 快捷键"
echo "------------------------------------------------------------"
echo "直接输入命令回车即可（此面板默认 shell = fish）"

# 保持面板存活：进入 fish（若不存在则 bash）
if command -v fish >/dev/null 2>&1; then
    exec fish
fi
exec bash
