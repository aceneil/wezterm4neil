# ============================================================================
# WezTerm4Neil · 终端预览录制脚本 (VHS)
# 语法参考: https://github.com/charmbracelet/vhs（tape 语法见仓库文档）
# 在 GitHub Actions 中由 charmbracelet/vhs-action@v2 执行（见 release.yml preview job）
# 前置：CI 会安装 fish + starship，把 config.fish / starship.toml 布到 $HOME/.config，
#       并在 $HOME/demo-repo 初始化一个演示 git 仓库（tape 首屏 cd 进去）。
# ============================================================================

# 输出 GIF（相对仓库根目录；workflow 已做双路径兜底）
Output assets/preview.gif

# 终端尺寸与外观
Set Shell fish
Set FontSize 18
Set Width 1200
Set Height 520
Set Padding 36
Set Theme "Dracula"
Set TypingSpeed 25ms

# ---- 开场：欢迎语 -----------------------------------------------------------
Type "echo 'WezTerm4Neil - terminal, upgraded'"
Sleep 200ms
Enter
Sleep 600ms

# ---- 进入演示 git 仓库：fish + Starship 提示符已带 git 分支信息 ---------------
Type "cd ~/demo-repo"
Sleep 250ms
Enter
Sleep 600ms

Type "ls -la"
Sleep 250ms
Enter
Sleep 700ms

# ---- 快捷别名（config.fish 内置）：gs = git status -sb ------------------------
Type "gs"
Sleep 250ms
Enter
Sleep 800ms

# ---- 提交一条改动，观察 Starship 的 git 状态指示 ------------------------------
Type "echo demo > demo.txt"
Sleep 200ms
Enter
Sleep 400ms
Type "ga"
Sleep 200ms
Enter
Sleep 500ms
Type "gcm 'add demo.txt'"
Sleep 250ms
Enter
Sleep 900ms

# ---- lg = git log --oneline --graph ------------------------------------------
Type "lg"
Sleep 250ms
Enter
Sleep 1200ms

# ---- 收尾 --------------------------------------------------------------------
Type "echo 'Enjoy!'"
Sleep 150ms
Enter
Sleep 1500ms
