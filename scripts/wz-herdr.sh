#!/usr/bin/env bash
# ============================================================================
# wz-herdr.sh —— 在 Zellij 悬浮窗内启动 herdr 并“锁定” Zellij 快捷键，
#   herdr 独占全部输入；退出 herdr 后自动解锁回 Zellij 正常模式。
# 部署：~/.local/bin/wz-herdr.sh（随安装包 scripts/ 分发）
# ============================================================================
set -uo pipefail

# 定位 herdr（zellij 新窗格可能不带 ~/.local/bin）
H="$(command -v herdr 2>/dev/null || true)"
if [[ -z "$H" ]]; then
  for c in "$HOME/.local/bin/herdr" /usr/local/bin/herdr /usr/bin/herdr; do
    if [[ -x "$c" ]]; then H="$c"; break; fi
  done
fi
if [[ -z "$H" ]]; then
  echo "herdr 未找到（安装到 ~/.local/bin 或加入 PATH 后重试）" >&2
  exit 1
fi

# 让 herdr 内部终端使用 fish（登录 SHELL 可能是 bash，会丢 fish 提示/自动补全）
if command -v fish >/dev/null 2>&1; then
  export SHELL="$(command -v fish)"
fi

# 锁定 Zellij 快捷键 → 全部按键直达 herdr
zellij action switch-mode locked >/dev/null 2>&1 || true

"$H" "$@"
rc=$?

# herdr 退出 → 解锁回 Zellij 正常模式
zellij action switch-mode normal >/dev/null 2>&1 || true
exit $rc
