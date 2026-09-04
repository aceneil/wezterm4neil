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

# ============================================================================
# 终端显示微调（weterm3 / Byxs20 参考）
# ============================================================================
# 不显示启动 banner
$env.config.show_banner = false
# 避免输入回车出现换行位移（与部分终端兼容问题）
$env.config.shell_integration.osc133 = false

# 提示符默认交给 Starship（vendor/autoload/starship.nu 已自动加载，开箱即用）。
# 若想改用「短路径」纯文本提示符（Byxs20 风格、不带 git 信息），
# 取消下面三行注释，并把 vendor/autoload/starship.nu 移走即可：
# $env.PROMPT_COMMAND_RIGHT = ""
# $env.PROMPT_COMMAND = {||
#     let parts = (pwd | path split)
#     let display = if ($parts | length) > 3 {
#         "..\" + ($parts | last 3 | path join)
#     } else {
#         ($parts | path join)
#     }
#     $"($display) "
# }
