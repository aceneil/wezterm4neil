# ============================================================================
# WezTerm4Neil · Nushell 别名与环境
# 仅随 Windows 安装包分发（Windows 默认 shell = Nushell，开箱即用）。
# 由 install.ps1 写入 Nu 自动加载目录：
#   %APPDATA%\nushell\vendor\autoload\wezterm4neil.nu
# （Nu 启动时自动 source vendor/autoload/ 下的所有 .nu 文件）
# 官方参考: https://www.nushell.sh/book/configuration.html
# ============================================================================

# ---- 目录 ----
alias ll = ls -la
alias la = ls -a

# ---- Git（配合 Starship 的 git 模块显示效果最佳）----
alias g   = git
alias gs  = git status -sb
alias ga  = git add -A
alias gcm = git commit -m
alias gl  = git pull --rebase
alias gp  = git push
alias gd  = git diff
alias gco = git checkout
alias gb  = git branch -vv
alias lg  = git log --oneline --graph --decorate -15

# ---- 环境 ----
$env.EDITOR = 'notepad'
