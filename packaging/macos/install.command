#!/bin/bash
# ============================================================================
# WezTerm4Neil · macOS 一键安装脚本（.dmg 内 install.command）
# 使用方法：双击本文件（.command 会在 Terminal 中自动运行），按提示操作；
#           或手动执行: bash "/Volumes/WezTerm4Neil/install.command"
#
# 自动完成（可逐项确认/跳过）：
#   1. WezTerm.app            → /Applications          （来自官方 macos zip，Universal）
#   2. starship               → /usr/local/bin/starship（来自官方 darwin 二进制）
#   3. fish                   → 若系统缺失：优先安装捆绑的官方 fish-*.pkg
#                              （sudo installer -pkg），无 pkg 时回退 brew install fish
#   4. 配置文件 wezterm.lua / config.fish / starship.toml
#                            → ~/.config 对应位置（拷贝或软链接，可重复执行、自动备份）
#
# 本 DMG 内同时提供 VERSIONS.txt（捆绑版本/来源）与 README.txt。
# 官方出处:
#   wezterm macos zip:  https://wezterm.org/install/macos.html
#   fish pkg:           https://github.com/fish-shell/fish-shell/releases
#   starship:           https://starship.rs/guide/
# ============================================================================
set -euo pipefail

SRC_DIR="$(cd "$(dirname "$0")" && pwd)"
CONFIG_ROOT="${XDG_CONFIG_HOME:-$HOME/.config}"

echo "============================================================"
echo " WezTerm4Neil 一键安装 (macOS)"
echo " 源目录: $SRC_DIR"
echo "============================================================"

if [ -f "$SRC_DIR/VERSIONS.txt" ]; then
    echo "捆绑版本:"
    sed -n '1,16p' "$SRC_DIR/VERSIONS.txt" | sed 's/^/   /'
    echo ""
fi

ask() { # ask "问题" "默认(y/N|Y/n)"
    local q="$1" d="${2:-y}" ans
    printf "%s [%s] " "$q" "$d"
    read -r ans
    case "${ans:-$d}" in
        y|Y|yes|YES) return 0 ;;
        *) return 1 ;;
    esac
}

# ---- 1) WezTerm.app → /Applications -----------------------------------------
if [ -d "$SRC_DIR/WezTerm.app" ] && ask "安装 WezTerm.app 到 /Applications?" y; then
    if [ -d /Applications/WezTerm.app ]; then
        echo "[wezterm4neil] 检测到旧版 /Applications/WezTerm.app"
        if ask "  删除旧版后安装新版本？（请先退出正在运行的 WezTerm）" y; then
            rm -rf /Applications/WezTerm.app
        else
            echo "[wezterm4neil] 跳过 WezTerm（保留旧版）"
        fi
    fi
    if [ ! -d /Applications/WezTerm.app ]; then
        if [ -w /Applications ]; then
            ditto "$SRC_DIR/WezTerm.app" /Applications/WezTerm.app
        else
            echo "[wezterm4neil] /Applications 需要管理员权限，请输入密码…"
            sudo -p '密码: ' ditto "$SRC_DIR/WezTerm.app" /Applications/WezTerm.app
        fi
        echo "[wezterm4neil] ✅ WezTerm.app -> /Applications"
        echo "   首次打开请右键→打开（绕过 Gatekeeper 提示），或执行:"
        echo "   xattr -dr com.apple.quarantine /Applications/WezTerm.app"
    fi
fi

# ---- 2) starship → /usr/local/bin -------------------------------------------
if [ -f "$SRC_DIR/starship" ] && ask "安装 starship 到 /usr/local/bin?" y; then
    if command -v starship >/dev/null 2>&1 && ask "  已存在 starship，覆盖为捆绑版本？" y; then
        :
    elif command -v starship >/dev/null 2>&1; then
        echo "[wezterm4neil] 保留现有 starship: $(command -v starship)"
    fi
    mkdir -p /usr/local/bin
    if [ -w /usr/local/bin ]; then
        install -m755 "$SRC_DIR/starship" /usr/local/bin/starship
    else
        echo "[wezterm4neil] /usr/local/bin 需要管理员权限，请输入密码…"
        sudo -p '密码: ' install -m755 "$SRC_DIR/starship" /usr/local/bin/starship
    fi
    echo "[wezterm4neil] ✅ starship -> /usr/local/bin/starship"
fi

# ---- 3) fish（缺失才装；官方 pkg 优先，brew 兜底） ----------------------------
if ! command -v fish >/dev/null 2>&1; then
    FISH_PKG="$(ls "$SRC_DIR"/fish-*.pkg 2>/dev/null | head -n1 || true)"
    if [ -n "$FISH_PKG" ] && ask "fish 未安装：用捆绑的 $(basename "$FISH_PKG") 安装（需管理员）?" y; then
        echo "[wezterm4neil] 运行 installer -pkg（输入密码以安装到 /）…"
        sudo -p '密码: ' installer -pkg "$FISH_PKG" -target /
        echo "[wezterm4neil] ✅ fish 已通过官方 pkg 安装"
    elif command -v brew >/dev/null 2>&1 && ask "未找到捆绑 pkg 或跳过 pkg：改用 brew install fish?" n; then
        brew install fish
        echo "[wezterm4neil] ✅ fish 已通过 brew 安装"
    else
        echo "[wezterm4neil] ⚠️ 跳过 fish（提示：brew install fish 或使用 DMG 内 fish-*.pkg）"
    fi
else
    echo "[wezterm4neil] fish 已安装: $(command -v fish)"
fi

# ---- 4) 配置文件 → ~/.config（复用同目录 install.sh 逻辑） --------------------
if [ -f "$SRC_DIR/install.sh" ] && ask "部署配置到 ~/.config?" y; then
    echo "请选择配置部署方式:"
    echo "  1) 拷贝（默认，最稳妥）"
    echo "  2) 软链接（/Volumes 下的 DMG 每次挂载路径相同才推荐；建议选择拷贝）"
    printf "输入 1 或 2 [1]: "
    read -r CHOICE
    case "${CHOICE:-1}" in
        2) bash "$SRC_DIR/install.sh" --link ;;
        *) bash "$SRC_DIR/install.sh" --copy ;;
    esac
fi

echo ""
echo "============================================================"
echo " 全部完成！接下来:"
echo "   · WezTerm   —— 打开 /Applications/WezTerm.app"
echo "   · Fish      —— 打开新终端，或执行: exec fish"
echo "   · Starship  —— 新终端生效（config.fish 已自动加载）"
echo "   · 想用 fish 作为登录 shell: chsh -s /usr/local/bin/fish"
echo "     （或 /opt/homebrew/bin/fish，取决于安装方式）"
echo "============================================================"
read -r -p "按回车键关闭此窗口… " _ || true
