#!/usr/bin/env bash
# ============================================================================
# WezTerm4Neil · .deb 组装脚本（CI 与本机验证共用同一份逻辑）
#
# 功能：把「上游官方产物 + 本仓库配置」合并成一个开箱即用的 .deb：
#   1. dpkg-deb -x 解包官方 wezterm .deb（含 /usr/bin/*、desktop、补全…）
#   2. fish  官方 Linux 预编译单文件（自包含，实测 4.x 静态 PIE）→ /usr/bin/fish
#      （若官方无该产物，则回退：dpkg-deb -x 合并发行版原生 fish .deb）
#   3. starship 官方单二进制 tar.gz → /usr/bin/starship
#   4. 配置文件 → /etc/wezterm4neil/skel/；install.sh、VERSIONS.txt → /etc/wezterm4neil/
#   5. 上游 LICENSE → /usr/share/doc/wezterm4neil/
#   6. 用上游 deb 实际 Depends 并集重写 control；自带 postinst（纯文本指引）
#   7. dpkg-deb --build 产出 wezterm4neil_<VER>_amd64.deb
#
# 用法：
#   packaging/linux/build-deb.sh \
#       --ver 2026.09.07 \
#       --wezterm-deb  /path/wezterm.deb \
#       --fish-tarball /path/fish-4.9.1-linux-x86_64.tar.xz   # 与 --fish-deb 二选一
#       --starship-tar /path/starship-x86_64-unknown-linux-gnu.tar.gz \
#       --config-dir   /repo/root \
#       --versions-txt /path/VERSIONS.txt \
#       [--licenses-dir /path/licenses] \
#       [--out /tmp/deb-out]
# ============================================================================
set -euo pipefail

# ---- 参数解析 ---------------------------------------------------------------
VER=""; WEZTERM_DEB=""; FISH_TARBALL=""; FISH_DEB=""; STARSHIP_TAR=""; ZELLIJ_TAR=""; YAZI_ZIP=""
CONFIG_DIR=""; FONTS_DIR=""; VERSIONS_TXT=""; LICENSES_DIR=""; OUT_DIR="$(pwd)"
while [[ $# -gt 0 ]]; do
  case "$1" in
    --ver)          VER="$2"; shift 2 ;;
    --wezterm-deb)  WEZTERM_DEB="$2"; shift 2 ;;
    --fish-tarball) FISH_TARBALL="$2"; shift 2 ;;
    --fish-deb)     FISH_DEB="$2"; shift 2 ;;
    --starship-tar) STARSHIP_TAR="$2"; shift 2 ;;
    --zellij-tar)   ZELLIJ_TAR="$2"; shift 2 ;;
    --yazi-zip)     YAZI_ZIP="$2"; shift 2 ;;
    --config-dir)   CONFIG_DIR="$2"; shift 2 ;;
    --fonts-dir)    FONTS_DIR="$2"; shift 2 ;;
    --versions-txt) VERSIONS_TXT="$2"; shift 2 ;;
    --licenses-dir) LICENSES_DIR="$2"; shift 2 ;;
    --out)          OUT_DIR="$2"; shift 2 ;;
    -h|--help)      sed -n '1,40p' "$0" | sed 's/^# \{0,1\}//' ; exit 0 ;;
    *) echo "未知参数: $1" >&2; exit 2 ;;
  esac
done

# 脚本所在 packaging/linux 目录
PKG_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

err() { echo "[build-deb] 错误: $*" >&2; exit 1; }
[[ -n "$VER" ]] || err "缺少 --ver"
[[ -n "$WEZTERM_DEB" && -f "$WEZTERM_DEB" ]] || err "缺少/无效 --wezterm-deb"
if [[ -z "$FISH_TARBALL" && -z "$FISH_DEB" ]]; then err "必须提供 --fish-tarball 或 --fish-deb"; fi
if [[ -n "$FISH_TARBALL" && ! -f "$FISH_TARBALL" ]]; then err "fish tarball 不存在: $FISH_TARBALL"; fi
if [[ -n "$FISH_DEB" && ! -f "$FISH_DEB" ]]; then err "fish deb 不存在: $FISH_DEB"; fi
[[ -n "$STARSHIP_TAR" && -f "$STARSHIP_TAR" ]] || err "缺少/无效 --starship-tar"
[[ -n "$CONFIG_DIR" && -d "$CONFIG_DIR" ]] || err "缺少/无效 --config-dir"
[[ -n "$VERSIONS_TXT" && -f "$VERSIONS_TXT" ]] || err "缺少/无效 --versions-txt"

STAGE="$(mktemp -d /tmp/wezterm4neil-deb.XXXXXX)"
trap 'rm -rf "$STAGE"' EXIT
mkdir -p "$OUT_DIR"

echo "[build-deb] stage=$STAGE"

# ---- 1) wezterm 官方 deb 全量解包 -------------------------------------------
echo "[build-deb] 解包 wezterm deb: $WEZTERM_DEB"
dpkg-deb -x "$WEZTERM_DEB" "$STAGE"

# 记录上游 DEBIAN 里值得保留的文件（如 triggers），其余维护者脚本丢弃
if [[ -f "$STAGE/DEBIAN/triggers" ]]; then
  mkdir -p /tmp/wz4n-triggers-save
  cp "$STAGE/DEBIAN/triggers" /tmp/wz4n-triggers-save/triggers
  echo "[build-deb] 保留上游 triggers"
fi

# ---- 2) fish ----------------------------------------------------------------
if [[ -n "$FISH_TARBALL" ]]; then
  echo "[build-deb] fish 官方预编译 tarball -> /usr/bin/fish: $FISH_TARBALL"
  TMPF="$(mktemp -d /tmp/wz4n-fish.XXXXXX)"
  tar -xJf "$FISH_TARBALL" -C "$TMPF"
  FISH_BIN="$(find "$TMPF" -maxdepth 2 -type f -name fish | head -n1)"
  [[ -n "$FISH_BIN" ]] || err "tarball 中找不到 fish 可执行文件"
  install -Dm755 "$FISH_BIN" "$STAGE/usr/bin/fish"
  rm -rf "$TMPF"
  echo "[build-deb] fish 来源: official tarball (自包含单文件, 无需额外 share 数据)"
else
  echo "[build-deb] fish 发行版 deb 解包合并: $FISH_DEB"
  dpkg-deb -x "$FISH_DEB" "$STAGE"
  echo "[build-deb] fish 来源: distro apt deb"
fi

# ---- 3) starship ------------------------------------------------------------
echo "[build-deb] starship 官方二进制 tar.gz -> /usr/bin/starship: $STARSHIP_TAR"
TMPF="$(mktemp -d /tmp/wz4n-star.XXXXXX)"
tar -xzf "$STARSHIP_TAR" -C "$TMPF"
STAR_BIN="$(find "$TMPF" -maxdepth 2 -type f -name starship | head -n1)"
[[ -n "$STAR_BIN" ]] || err "starship tar.gz 中找不到 starship 可执行文件"
install -Dm755 "$STAR_BIN" "$STAGE/usr/bin/starship"
rm -rf "$TMPF"

# ---- 4.5) Zellij 官方二进制 -> /usr/bin/zellij（第二层；仅 Linux/macOS）------
if [[ -n "$ZELLIJ_TAR" ]]; then
  [[ -f "$ZELLIJ_TAR" ]] || err "zellij tar 不存在: $ZELLIJ_TAR"
  echo "[build-deb] zellij 官方 tar.gz -> /usr/bin/zellij: $ZELLIJ_TAR"
  TMPF="$(mktemp -d /tmp/wz4n-zj.XXXXXX)"
  tar -xzf "$ZELLIJ_TAR" -C "$TMPF"
  ZJ_BIN="$(find "$TMPF" -maxdepth 2 -type f -name zellij | head -n1)"
  [[ -n "$ZJ_BIN" ]] || err "zellij tar 中找不到 zellij 可执行文件"
  install -Dm755 "$ZJ_BIN" "$STAGE/usr/bin/zellij"
  rm -rf "$TMPF"
fi

# ---- 4.6) Yazi 官方 zip -> /usr/bin/yazi（文件管理；侧边栏用）----------------
if [[ -n "$YAZI_ZIP" ]]; then
  [[ -f "$YAZI_ZIP" ]] || err "yazi zip 不存在: $YAZI_ZIP"
  echo "[build-deb] yazi 官方 zip -> /usr/bin/yazi: $YAZI_ZIP"
  TMPF="$(mktemp -d /tmp/wz4n-yz.XXXXXX)"
  unzip -q "$YAZI_ZIP" -d "$TMPF"
  YZ_BIN="$(find "$TMPF" -maxdepth 3 -type f -name yazi | head -n1)"
  [[ -n "$YZ_BIN" ]] || err "yazi zip 中找不到 yazi 可执行文件"
  install -Dm755 "$YZ_BIN" "$STAGE/usr/bin/yazi"
  rm -rf "$TMPF"
fi

# ---- 4) 移除上游 DEBIAN，装配我们自己的元数据 -------------------------------
rm -rf "$STAGE/DEBIAN"
mkdir -p "$STAGE/DEBIAN"
if [[ -f /tmp/wz4n-triggers-save/triggers ]]; then
  cp /tmp/wz4n-triggers-save/triggers "$STAGE/DEBIAN/triggers"
  rm -rf /tmp/wz4n-triggers-save
fi

# 配置文件模板 + install.sh + VERSIONS.txt -> /etc/wezterm4neil
mkdir -p "$STAGE/etc/wezterm4neil/skel"
for f in wezterm.lua config.fish starship.toml; do
  [[ -f "$CONFIG_DIR/$f" ]] || err "配置源缺失: $CONFIG_DIR/$f"
  cp "$CONFIG_DIR/$f" "$STAGE/etc/wezterm4neil/skel/$f"
done
[[ -f "$CONFIG_DIR/install.sh" ]] && install -Dm755 "$CONFIG_DIR/install.sh" "$STAGE/etc/wezterm4neil/install.sh"
cp "$VERSIONS_TXT" "$STAGE/etc/wezterm4neil/VERSIONS.txt"

# 第二层/配套配置树（Zellij 布局 + Yazi 键位 + server-menu 脚本）→ skel
for sub in config/zellij config/yazi scripts; do
  if [[ -e "$CONFIG_DIR/$sub" ]]; then
    mkdir -p "$STAGE/etc/wezterm4neil/skel/$sub"
    cp -r "$CONFIG_DIR/$sub"/. "$STAGE/etc/wezterm4neil/skel/$sub/"
  fi
done

# 我们自己的应用菜单项（与 Windows 开始菜单观感一致；上游的 WezTerm 项也保留）
mkdir -p "$STAGE/usr/share/applications"
cat > "$STAGE/usr/share/applications/wezterm4neil.desktop" <<'EOF'
[Desktop Entry]
Type=Application
Name=WezTerm4Neil
GenericName=Terminal
Comment=开箱即用的 WezTerm + Zellij + Fish + Starship 终端
Exec=/usr/bin/wezterm-gui
Icon=org.wezfurlong.wezterm
Terminal=false
Categories=System;TerminalEmulator;
StartupWMClass=org.wezfurlong.wezterm
EOF
echo "[build-deb] 已添加应用菜单项: wezterm4neil.desktop"

# Nerd Font 子集（供 install.sh 自动装到 ~/.local/share/fonts）→ /etc/wezterm4neil/fonts
if [[ -n "$FONTS_DIR" && -d "$FONTS_DIR" ]]; then
  mkdir -p "$STAGE/etc/wezterm4neil/fonts"
  cp -r "$FONTS_DIR"/. "$STAGE/etc/wezterm4neil/fonts/"
  echo "[build-deb] 已捆绑字体: $(ls "$STAGE/etc/wezterm4neil/fonts" | wc -l) 个"
fi

# conffiles（升级时用户改过的 /etc 下文件不会被无脑覆盖）
cat > "$STAGE/DEBIAN/conffiles" <<'EOF'
/etc/wezterm4neil/install.sh
/etc/wezterm4neil/VERSIONS.txt
/etc/wezterm4neil/skel/wezterm.lua
/etc/wezterm4neil/skel/config.fish
/etc/wezterm4neil/skel/starship.toml
/etc/wezterm4neil/skel/config/zellij/config.kdl
/etc/wezterm4neil/skel/config/zellij/layouts/sidebar.kdl
/etc/wezterm4neil/skel/config/yazi/keymap.toml
/etc/wezterm4neil/skel/scripts/server-menu.sh
EOF

# 上游许可证 -> /usr/share/doc/wezterm4neil/
mkdir -p "$STAGE/usr/share/doc/wezterm4neil"
if [[ -n "$LICENSES_DIR" && -d "$LICENSES_DIR" ]]; then
  cp -r "$LICENSES_DIR" "$STAGE/usr/share/doc/wezterm4neil/upstream-licenses"
  {
    echo "WezTerm4Neil bundle — 上游组件许可证汇总"
    echo "========================================"
    echo "本 .deb 内含第三方上游软件，许可证文本见 ./upstream-licenses/："
    echo "  wezterm   : MIT   (https://github.com/wezterm/wezterm/blob/main/LICENSE)"
    echo "  fish      : GPL-2 (https://github.com/fish-shell/fish-shell/blob/master/COPYING)"
    echo "  starship  : ISC   (https://github.com/starship/starship/blob/master/LICENSE)"
    echo "本仓库自身配置代码: MIT（见仓库 LICENSE）"
  } > "$STAGE/usr/share/doc/wezterm4neil/copyright"
else
  echo "[build-deb] 警告: 未提供 licenses-dir，跳过许可证目录（仅写汇总说明）"
  {
    echo "WezTerm4Neil bundle — 上游组件许可证汇总"
    echo "========================================"
    echo "上游组件（wezterm MIT / fish GPL-2 / starship ISC）许可证文本请查阅对应官方仓库。"
  } > "$STAGE/usr/share/doc/wezterm4neil/copyright"
fi

# ---- 5) control：Depends 用上游 deb 实际依赖并集重写 -------------------------
dep_wez="$(dpkg-deb -f "$WEZTERM_DEB" Depends || true)"
dep_fish=""
if [[ -n "$FISH_DEB" ]]; then dep_fish="$(dpkg-deb -f "$FISH_DEB" Depends || true)"; fi
merged="$(printf '%s\n%s' "$dep_wez" "$dep_fish" \
  | tr ',' '\n' \
  | sed -E 's/^[[:space:]]+//; s/[[:space:]]+$//' \
  | grep -v '^$' \
  | sort -u \
  | paste -sd ',' -)"
if [[ -z "$merged" ]]; then
  echo "[build-deb] 警告: 依赖并集为空，回退到 control 模板静态 Depends"
  cp "$PKG_DIR/DEBIAN/control" "$STAGE/DEBIAN/control"
else
  echo "[build-deb] 合并后 Depends: $merged"
  sed -e "s/^Version: .*/Version: ${VER}/" \
      -e "s|^Depends: .*|Depends: ${merged}|" \
      "$PKG_DIR/DEBIAN/control" > "$STAGE/DEBIAN/control"
fi

# postinst（模板本身已含 Version 不敏感文本）
install -Dm755 "$PKG_DIR/DEBIAN/postinst" "$STAGE/DEBIAN/postinst"

# ---- 6) 构建 .deb -----------------------------------------------------------
OUT_DEB="$OUT_DIR/wezterm4neil_${VER}_amd64.deb"
echo "[build-deb] dpkg-deb --build -> $OUT_DEB"
dpkg-deb --root-owner-group --build "$STAGE" "$OUT_DEB"

echo "[build-deb] 完成。校验:"
dpkg-deb -I "$OUT_DEB" | sed -n '1,25p'
echo "[build-deb] 文件总数: $(dpkg-deb -c "$OUT_DEB" | wc -l)"
