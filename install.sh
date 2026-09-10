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

# ---- 环境检测 ---------------------------------------------------------------
if [[ "$(id -u)" -eq 0 ]]; then
  echo "⚠️ 警告: 你正以 root 运行本脚本，配置将写入 /root/.config 而非普通用户目录。"
  echo "   .deb 安装后请用你的普通用户执行: bash /etc/wezterm4neil/install.sh"
  echo "   （仅当确为 root 环境——容器/无普通用户——可忽略本警告）"
fi
if [[ -z "${HOME:-}" || ! -d "${HOME:-}" ]]; then
  echo "错误: 无法确定 HOME（当前值 '${HOME:-}'），请设置 HOME 后重试。" >&2
  exit 2
fi

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
  "config/zellij/config.kdl|zellij|config.kdl"
  "config/zellij/layouts/sidebar.kdl|zellij/layouts|sidebar.kdl"
  "config/yazi/keymap.toml|yazi|keymap.toml"
  "config/yazi/yazi.toml|yazi|yazi.toml"
  "config/yazi/init.lua|yazi|init.lua"
  "config/yazi/plugins/no-status.yazi/main.lua|yazi/plugins/no-status.yazi|main.lua"
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

# 配套脚本（server-menu 远程菜单 / wz-open 文件打开器…）→ ~/.local/bin（可执行）
if [[ -d "$SRC_DIR/scripts" ]]; then
  mkdir -p "$HOME/.local/bin"
  for f in "$SRC_DIR"/scripts/*.sh; do
    [[ -e "$f" ]] || continue
    cp -f "$f" "$HOME/.local/bin/$(basename "$f")"
    chmod +x "$HOME/.local/bin/$(basename "$f")"
  done
  log "已部署脚本到 ~/.local/bin: $(ls "$SRC_DIR"/scripts | tr '\n' ' ')"
fi

# neilwz-nav-tui 单二进制（可选；存在 bin/neilwz-nav-tui 就拷到 ~/.local/bin/zwnav）。
# 缺省的源 layout 用 PATH 找 neilwz-nav-tui，所以这步是开发者便利而不是必需。
if [[ -x "$SRC_DIR/bin/neilwz-nav-tui" ]]; then
  mkdir -p "$HOME/.local/bin"
  cp -f "$SRC_DIR/bin/neilwz-nav-tui" "$HOME/.local/bin/neilwz-nav-tui"
  chmod +x "$HOME/.local/bin/neilwz-nav-tui"
  log "已部署 neilwz-nav-tui 二进制到 ~/.local/bin/neilwz-nav-tui（侧栏 TUI）"
fi

# ---- Nerd Font 自动安装（fonts/ 与脚本同级时：.deb=/etc/wezterm4neil/fonts、DMG=根 fonts）----
# 目标目录按平台区分：macOS 的 WezTerm 用 CoreText 枚举字体，必须装到
# ~/Library/Fonts（~/.local/share/fonts 是 fontconfig 约定，装那里 mac 上读不到）；
# Linux 走 XDG 字体目录（fc-cache 刷新 fontconfig 缓存）。
if [[ -d "$SCRIPT_DIR/fonts" ]]; then
  if [[ "$(uname -s)" == "Darwin" ]]; then
    FONTS_TARGET="${HOME}/Library/Fonts"
  else
    FONTS_TARGET="${XDG_DATA_HOME:-$HOME/.local/share}/fonts"
  fi
  mkdir -p "$FONTS_TARGET"
  installed=0
  for f in "$SCRIPT_DIR"/fonts/*.ttf; do
    [[ -e "$f" ]] || continue
    cp -f "$f" "$FONTS_TARGET/" && installed=$((installed+1))
  done
  if command -v fc-cache >/dev/null 2>&1; then fc-cache -f >/dev/null 2>&1 || true; fi
  log "Nerd Font 已安装到 $FONTS_TARGET（$installed 个）"
fi

# ---- 桌面启动图标（仅 Linux；与 Windows 安装器创建的桌面快捷方式观感一致）----
if [[ "$(uname -s)" != "Darwin" ]]; then
  DESKTOP_DIR="$(xdg-user-dir DESKTOP 2>/dev/null || true)"
  if [[ -z "$DESKTOP_DIR" || ! -d "$DESKTOP_DIR" ]]; then
    DESKTOP_DIR="$HOME/Desktop"
  fi
  if [[ -d "$DESKTOP_DIR" ]]; then
    cat > "$DESKTOP_DIR/WezTerm4Neil.desktop" <<'EOF'
[Desktop Entry]
Type=Application
Name=WezTerm4Neil
Comment=开箱即用的 WezTerm + Fish + Starship 终端
Exec=/usr/bin/wezterm-gui
Icon=org.wezfurlong.wezterm
Terminal=false
Categories=System;TerminalEmulator;
EOF
    chmod +x "$DESKTOP_DIR/WezTerm4Neil.desktop"
    log "已创建桌面图标: $DESKTOP_DIR/WezTerm4Neil.desktop"
  fi
fi

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
