#!/usr/bin/env bash
# ============================================================================
# WezTerm4Neil · install.sh (macOS / Linux)
#
# 用法:
#   ./install.sh             # 默认：拷贝到 ~/.config 对应位置
#   ./install.sh --copy      # 同上（显式拷贝）
#   ./install.sh --link      # 软链接（Symlink），git pull / 包升级后即时生效
#   ./install.sh --force     # 强制重建：跳过「已是最新链接」检测，覆盖安装
#   ./install.sh --help      # 帮助
#
# 本脚本可在这两种位置运行，自动识别配置源目录：
#   1) 仓库根目录   : wezterm.lua / config.fish / starship.toml 与脚本同级
#   2) .deb 安装后  : /etc/wezterm4neil/install.sh
#                    配置文件在 /etc/wezterm4neil/skel/ 子目录
#
# 安装目标（$XDG_CONFIG_HOME 缺省为 ~/.config）:
#   wezterm.lua   -> ~/.config/wezterm/wezterm.lua
#   config.fish   -> ~/.config/fish/config.fish
#   starship.toml -> ~/.config/starship.toml
#
# 幂等性：可重复执行；目标已存在且正是指向本配置源的软链接时直接跳过；
#         其它情况先备份（*.bak.<时间戳>）再替换；--force 跳过幂等判断。
# ============================================================================
set -euo pipefail

# ---- 参数解析 ---------------------------------------------------------------
MODE="copy"
FORCE=0
for arg in "$@"; do
  case "$arg" in
    --copy)          MODE="copy" ;;
    --link)          MODE="link" ;;
    --force|-f)      FORCE=1 ;;
    -h|--help)
      echo "用法: $0 [--copy|--link] [--force]"
      echo "  --copy  (默认) 拷贝配置文件"
      echo "  --link          建立软链接（配置源更新后即时生效）"
      echo "  --force         跳过幂等检测，强制重新安装（旧目标会先备份）"
      exit 0 ;;
    *)
      echo "未知参数: $arg （支持 --copy / --link / --force）" >&2
      exit 2 ;;
  esac
done

# 本脚本所在目录（仓库根 或 .deb 安装到的 /etc/wezterm4neil）
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# 配置源目录：优先脚本同级目录，否则取 skel/（.deb 布局）
if [[ -f "$SCRIPT_DIR/wezterm.lua" ]]; then
  SRC_DIR="$SCRIPT_DIR"
else
  SRC_DIR="$SCRIPT_DIR/skel"
fi
CONFIG_ROOT="${XDG_CONFIG_HOME:-$HOME/.config}"

# ---- 安装清单: "源文件|目标子目录|目标文件名" -------------------------------
ITEMS=(
  "wezterm.lua|wezterm|wezterm.lua"
  "config.fish|fish|config.fish"
  "starship.toml|.|starship.toml"
)

log()  { printf '\033[1;32m[wezterm4neil]\033[0m %s\n' "$*"; }
warn() { printf '\033[1;33m[wezterm4neil] 警告: \033[0m%s\n' "$*" >&2; }

install_one() {
  local src="$1" dst_dir="$2" dst_file="$3"
  local src_path="$SRC_DIR/$src"
  local dst_path="$CONFIG_ROOT/$dst_dir/$dst_file"

  if [[ ! -f "$src_path" ]]; then
    warn "跳过 $src：源文件不存在（$src_path）"
    return 0
  fi

  mkdir -p "$(dirname "$dst_path")"

  # 已是最新链接（幂等）→ 跳过，除非 --force
  if [[ "$FORCE" -eq 0 && -L "$dst_path" && "$(readlink "$dst_path")" == "$src_path" ]]; then
    log "已是最新链接，跳过: $dst_path"
    return 0
  fi

  # 备份已存在的旧文件/旧链接
  if [[ -e "$dst_path" || -L "$dst_path" ]]; then
    local bak="${dst_path}.bak.$(date +%Y%m%d%H%M%S)"
    mv "$dst_path" "$bak"
    warn "原文件已备份到: $bak"
  fi

  if [[ "$MODE" == "link" ]]; then
    ln -s "$src_path" "$dst_path"
    log "已创建软链接: $dst_path -> $src_path"
  else
    cp "$src_path" "$dst_path"
    log "已拷贝: $dst_path"
  fi
}

# ---- 主流程 ------------------------------------------------------------------
log "安装模式: $MODE"
log "配置根目录: $CONFIG_ROOT"
log "配置源目录: $SRC_DIR"

for item in "${ITEMS[@]}"; do
  IFS='|' read -r src dst_dir dst_file <<< "$item"
  install_one "$src" "$dst_dir" "$dst_file"
done

# .deb 环境下额外提示捆绑的 VERSIONS.txt
if [[ -f "$SCRIPT_DIR/VERSIONS.txt" ]]; then
  echo
  log "本机捆绑版本（VERSIONS.txt）:"
  sed -n '1,40p' "$SCRIPT_DIR/VERSIONS.txt" 2>/dev/null | sed 's/^/    /'
fi

echo
log "完成！生效方式:"
log "  · WezTerm   —— 重新打开窗口，或执行配置重载（Cmd/Ctrl+Shift+R）"
log "  · Fish      —— 打开新终端，或执行: exec fish"
log "  · 提示      —— Starship 需要先安装（brew install starship / apt install starship / winget）"
echo
