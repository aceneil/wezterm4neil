#!/usr/bin/env bash
# ============================================================================
# wz-open.sh —— Yazi「打开文本文件」动作
# 在 Zellij 内 → 新标签页(整屏)用 vim 打开，不再侧边栏里分半屏；
# 不在 Zellij（独立终端）→ 直接当前窗格 vim。
# 部署：~/.local/bin/wz-open.sh（随安装包 scripts/ 分发）
# 换 nvim：把下面两处 vim 改成 nvim 即可。
# ============================================================================
set -uo pipefail

f="${1:-}"
if [[ -z "$f" ]]; then
  echo "用法: wz-open.sh <文件路径>" >&2
  exit 1
fi

if [[ -n "${ZELLIJ:-}" ]]; then
  exec zellij action new-tab --name "vim:$(basename "$f")" -- vim "$f"
fi
exec vim "$f"
