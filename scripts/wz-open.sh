#!/usr/bin/env bash
# ============================================================================
# wz-open.sh —— Yazi「打开文本文件」动作
# 在 Zellij 内 → 打开一个「悬浮窗」(floating pane, 同 Alt+n) 整屏编辑器，
#   不占主视窗/不分屏；退出编辑器自动关闭回到原布局。
# 不在 Zellij（独立终端）→ 直接当前窗格编辑器。
# 编辑器：优先 nvim；未安装则退回 vim 并提示（sudo apt install neovim 后即全 nvim）。
# 部署：~/.local/bin/wz-open.sh（随安装包 scripts/ 分发）
# ============================================================================
set -uo pipefail

f="${1:-}"
if [[ -z "$f" ]]; then
  echo "用法: wz-open.sh <文件路径>" >&2
  exit 1
fi

ED=""
if command -v nvim >/dev/null 2>&1; then
  ED="nvim"
else
  ED="vim"
  echo "提示: 未找到 nvim，改用 vim 打开（安装: sudo apt install neovim）" >&2
fi

if [[ -n "${ZELLIJ:-}" ]]; then
  exec zellij action new-pane --floating --close-on-exit --name "$ED:$(basename "$f")" --width 90% --height 90% --x 5% --y 5% -- "$ED" "$f"
fi
exec "$ED" "$f"

