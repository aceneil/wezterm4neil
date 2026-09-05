# ============================================================================
# WezTerm4Neil · config.fish
# Fish shell 基础配置（兼容 fish 3.x / 4.x）
# 官方参考: https://fishshell.com/docs/current/index.html
# 安装到: ~/.config/fish/config.fish （由 install.sh / install.ps1 / 安装包负责）
# ============================================================================

# 仅交互式会话加载（别名 / 提示符等）
if status is-interactive

    # ------------------------------------------------------------------
    # Starship 提示符自动加载（若已安装）
    # 官方参考: https://starship.rs/guide/#fish
    #   starship init fish | source
    # ------------------------------------------------------------------
    if type -q starship
        starship init fish | source
    end

    # ------------------------------------------------------------------
    # 编辑器 / 语言环境
    # ------------------------------------------------------------------
    set -gx EDITOR nvim
    set -gx VISUAL nvim
    set -gx LANG en_US.UTF-8

    # ------------------------------------------------------------------
    # 常用快捷别名
    # ------------------------------------------------------------------
    # 目录
    alias ..  'cd ..'
    alias ... 'cd ../..'
    alias ll  'ls -la'
    alias la  'ls -A'
    alias lt  'tree -C --dirsfirst'
    alias docs 'cd ~/Documents'

    # Git（配合 Starship 的 git 模块显示效果最佳）
    alias g   git
    alias gs  'git status -sb'
    alias ga  'git add -A'
    alias gcm 'git commit -m'
    alias gl  'git pull --rebase'
    alias gp  'git push'
    alias gd  'git diff'
    alias gco 'git checkout'
    alias gb  'git branch -vv'
    alias lg  'git log --oneline --graph --decorate -15'

    # 常用工具快捷
    alias ip  'ip -c'
end

# ------------------------------------------------------------------
# 全局环境变量（非交互也会生效）
# ------------------------------------------------------------------
set -gx XDG_CONFIG_HOME ~/.config

# ------------------------------------------------------------------
# 2.5 层：herdr —— Zellij 内输入 herdr → 打开 ~95% 悬浮窗运行 herdr；
#          退出 herdr 自动关闭悬浮窗，回到预设 Zellij 布局。
#          普通终端（无 Zellij）→ 直接执行 herdr。
# ------------------------------------------------------------------
function herdr
    if not command -q herdr
        echo "herdr 未安装（~/.local/bin/herdr 或加入 PATH）" >&2
        return 1
    end
    if set -q ZELLIJ
        zellij action new-pane --floating --close-on-exit --name herdr \
            --width 95% --height 95% --x 2% --y 2% -- command herdr
    else
        command herdr $argv
    end
end
