-- ============================================================================
-- WezTerm4Neil · wezterm.lua
-- 跨平台终端环境核心配置（要求 WezTerm >= 20220319，推荐使用官方最新稳定版）
-- 官方参考:
--   enumerate_ssh_hosts: https://wezterm.org/config/lua/wezterm/enumerate_ssh_hosts.html
--   SshDomain          : https://wezterm.org/config/lua/SshDomain.html
--   Fonts              : https://wezterm.org/config/lua/config/font.html
-- ============================================================================

local wezterm = require 'wezterm'

-- config_builder() 是官方推荐的构造方式；极老版本不存在时回退为空表
local config = wezterm.config_builder and wezterm.config_builder() or {}

-- 平台识别（快捷键 / 启动菜单需区分 macOS / Linux / Windows）
local IS_WINDOWS = wezterm.target_triple and wezterm.target_triple:find('windows') and true or false

-- 启动菜单（CTRL+SHIFT+Space 打开）：仅 Windows 提供 PowerShell / Cmd
if IS_WINDOWS then
  config.launch_menu = {
    { label = 'PowerShell', args = { 'powershell.exe', '-NoLogo' } },
    { label = 'Cmd',        args = { 'cmd.exe' } },
  }
end

-- ----------------------------------------------------------------------------
-- 1) 自动读取 ~/.ssh/config 别名，生成 SSH 域（ssh_domains）
--    wezterm.enumerate_ssh_hosts() 会解析 ~/.ssh/config 与 /etc/ssh/ssh_config，
--    返回 { 别名 = { hostname=, user=, port=, identityfile=, ... } }。
--    ★ 官方示例明确：remote_address 必须设为别名本身（host），
--      这样 ssh 客户端才会命中你 ~/.ssh/config 里的对应 Host 段并套用其配置。
--    ★ 该函数会把读到的 ssh config 文件加入配置热重载监视列表，
--      修改 ~/.ssh/config 后 WezTerm 会自动重载，无需重启。
--    之后可用 Ctrl+Shift+Space（域启动器 / Domain Launcher）选择远程主机连接。
-- ----------------------------------------------------------------------------
if wezterm.enumerate_ssh_hosts then
  local ssh_domains = {}
  for host in pairs(wezterm.enumerate_ssh_hosts()) do
    -- enumerate 只返回字面量 Host 名（自动跳过 *.example.com 这类通配），
    -- 这里再兜底过滤一次含通配符/问号的键
    if not host:find('[*?]') then
      table.insert(ssh_domains, {
        name = host,          -- 域显示名，随便取，这里直接用别名
        remote_address = host, -- 必须 = 别名，ssh 配置才会被应用（官方示例写法）

        -- 若远端未安装 wezterm mux server：
        --   - 保持默认 multiplexing='WezTerm' 会失败；
        --   - 取消下面注释改用直连模式即可多标签/多窗格直连：
        -- multiplexing = 'None',

        -- 远端为 POSIX/Unix 环境时配合 multiplexing='None'，
        -- 新窗格/新标签会尽量保留远端当前目录（shell integration）
        assume_shell = 'Posix',
      })
    end
  end
  config.ssh_domains = ssh_domains
end

-- ----------------------------------------------------------------------------
-- 2) 字体与基础外观（跨平台：优先用户已装字体，逐级回退保证 CJK 显示）
-- ----------------------------------------------------------------------------
config.font = wezterm.font_with_fallback({
  'CaskaydiaCove Nerd Font',   -- 随安装包自动安装（Pastel Powerline 图标所需）
  'Cascadia Mono',           -- Windows 11 自带
  'Consolas',                -- Windows 内置
  'Menlo',                   -- macOS 内置
  'Monaco',                  -- macOS 内置
  'Ubuntu Mono',             -- Linux 常见
  'Noto Sans Mono CJK SC',   -- Linux 常见中文字体
  'PingFang SC',             -- macOS 中文
  'Microsoft YaHei',         -- Windows 中文
})
config.font_size = 13.0
config.line_height = 1.1
config.color_scheme = 'Catppuccin Mocha'
config.scrollback_lines = 10000
config.window_padding = { left = 10, right = 10, top = 10, bottom = 10 }
-- 窗口装饰：Windows 默认隐藏系统标题栏（更沉浸；仍可拖边框调整大小）；
-- 若想要回系统标题栏，把下面 IS_WINDOWS 分支的 'RESIZE' 改回 'TITLE | RESIZE' 即可。
-- macOS/Linux 保留系统标题栏（依赖其原生窗口按钮）。
if IS_WINDOWS then
  config.window_decorations = 'RESIZE'
else
  config.window_decorations = 'TITLE | RESIZE'
end
config.window_close_confirmation = 'NeverPrompt'
-- 标签栏：Windows 隐藏标题栏后需用标签栏拖拽窗口 → 单标签也显示；
-- macOS/Linux 保留系统标题栏，单标签可隐藏以省空间。
config.hide_tab_bar_if_only_one_tab = not IS_WINDOWS
config.show_tab_index_in_tab_bar = true
-- 使用 fancy 标签栏（fancy=false 时下方 tab_bar 配色不生效）
config.use_fancy_tab_bar = true
-- inactive_pane_hsb 仅调暗“分屏中非活动窗格”，与标签栏无关（勿用它调标签栏）
config.inactive_pane_hsb = { saturation = 0.9, brightness = 0.8 }
-- 标签栏配色：自动跟随当前配色方案底色（改 color_scheme 即同步，无需手写色值）。
-- 用纯 Lua 十六进制调色派生非活动/悬停色（不依赖 wezterm 颜色 API 版本差异）。
local _scheme = wezterm.color.get_builtin_schemes()['Catppuccin Mocha']
if _scheme and _scheme.background then
  local function _shade(hex, f)
    local h = hex:gsub('^#', '')
    local function ch(c)
      local v = math.floor(c * f)
      if v < 0 then v = 0 elseif v > 255 then v = 255 end
      return string.format('%02x', v)
    end
    return '#' .. ch(tonumber(h:sub(1, 2), 16)) .. ch(tonumber(h:sub(3, 4), 16)) .. ch(tonumber(h:sub(5, 6), 16))
  end
  local _bg = _scheme.background
  local _fg = _scheme.foreground or '#cdd6f4'
  config.colors = {
    tab_bar = {
      background = _bg,
      active_tab = { bg_color = _bg, fg_color = _fg, intensity = 'Bold' },
      inactive_tab = { bg_color = _shade(_bg, 0.95), fg_color = _fg },
      inactive_tab_hover = { bg_color = _shade(_bg, 1.08), fg_color = _fg },
      new_tab = { bg_color = _bg, fg_color = _shade(_bg, 1.18) },
      new_tab_hover = { bg_color = _shade(_bg, 1.08), fg_color = _fg },
      inactive_tab_edge = _shade(_bg, 0.95),
    },
  }
end
config.initial_cols = 140
config.initial_rows = 30
-- macOS 专属毛玻璃背景（其它平台自动忽略）
config.macos_window_background_blur = 30

-- ----------------------------------------------------------------------------
-- 3) 光标
-- ----------------------------------------------------------------------------
config.force_reverse_video_cursor = true
-- 注：窗口标题由 WezTerm 依据当前 shell/SSH 会话自动设置，无需（也无法）静态配置。

-- ----------------------------------------------------------------------------
-- 4) Leader 键 + 常用分屏/标签快捷键
--    Leader = Ctrl+A：先按 Ctrl+A，再按对应键（1.5 秒内）
-- ----------------------------------------------------------------------------
config.leader = { key = 'a', mods = 'CTRL', timeout_milliseconds = 1500 }
config.keys = {
  -- 垂直分屏（左右）
  { key = '-', mods = 'LEADER', action = wezterm.action.SplitVertical { domain = 'CurrentPaneDomain' } },
  -- 水平分屏（上下）：'|' 在键盘上需配合 SHIFT
  { key = '|', mods = 'LEADER|SHIFT', action = wezterm.action.SplitHorizontal { domain = 'CurrentPaneDomain' } },
  -- 新建标签页
  { key = 'c', mods = 'LEADER', action = wezterm.action.SpawnTab 'CurrentPaneDomain' },
  -- 窗格间移动（Vim 风格）
  { key = 'h', mods = 'LEADER', action = wezterm.action.ActivatePaneDirection 'Left' },
  { key = 'l', mods = 'LEADER', action = wezterm.action.ActivatePaneDirection 'Right' },
  { key = 'k', mods = 'LEADER', action = wezterm.action.ActivatePaneDirection 'Up' },
  { key = 'j', mods = 'LEADER', action = wezterm.action.ActivatePaneDirection 'Down' },
}

-- ----------------------------------------------------------------------------
-- 4.5) 附加常用键位（来自 Byxs20/terminal_config 参考，跨平台安全子集）
--   说明：CTRL+T / ALT+W / CTRL+1..8 / 鼠标复制·开链接 在
--         macOS · Linux · Windows 语义一致，可直接使用；
--         原参考里的 WSL/kali 标签快捷键绑定具体发行版，这里不引入。
--         Windows 侧如需快速开 PowerShell / Cmd：上方 launch_menu
--         （默认 CTRL+SHIFT+Space）或下方 CTRL+SHIFT+1/2 固定映射二选一。
-- ----------------------------------------------------------------------------
table.insert(config.keys, { key = 't', mods = 'CTRL', action = wezterm.action.SpawnTab 'DefaultDomain' })
table.insert(config.keys, { key = 'w', mods = 'ALT', action = wezterm.action.CloseCurrentTab { confirm = false } })
for i = 1, 8 do
  table.insert(config.keys, { key = tostring(i), mods = 'CTRL', action = wezterm.action.ActivateTab(i - 1) })
end

-- Windows 专用：CTRL+SHIFT+1/2 直接开 PowerShell / Cmd 新标签（固定映射，用户可改）。
-- 说明：SHIFT+数字在 WezTerm 中按字符匹配（US 布局 Shift+1='!'、Shift+2='@'），
--       故键位写 '!' / '@' 并带 CTRL|SHIFT；不写死任何 WSL 发行版或绝对路径。
if IS_WINDOWS then
  table.insert(config.keys, {
    key = '!',
    mods = 'CTRL|SHIFT',
    action = wezterm.action.SpawnCommandInNewTab { args = { 'pwsh' } },
  })
  table.insert(config.keys, {
    key = '@',
    mods = 'CTRL|SHIFT',
    action = wezterm.action.SpawnCommandInNewTab { args = { 'cmd' } },
  })
end

config.mouse_bindings = {
  -- 松开左键自动复制选中内容到剪贴板
  { event = { Up = { streak = 1, button = 'Left' } }, mods = 'NONE', action = wezterm.action.CompleteSelection 'ClipboardAndPrimarySelection' },
  -- CTRL+左键打开光标处链接
  { event = { Up = { streak = 1, button = 'Left' } }, mods = 'CTRL', action = wezterm.action.OpenLinkAtMouseCursor },
}

-- ----------------------------------------------------------------------------
-- 5) Windows：默认 shell = 随包安装的 Nushell（若存在）；找不到则用系统默认
--    （Windows 版安装包内置 nu.exe；macOS/Linux 仍由用户自行选择 shell）
--    路径优先读安装器写下的 nu-path.txt（支持用户自定义安装目录），
--    失败则回退默认 %LOCALAPPDATA%\Programs\wezterm4neil\nu\nu.exe。
--    说明：io.open 使用正斜杠，Windows 文件 API 完全兼容，避免转义歧义。
-- ----------------------------------------------------------------------------
if IS_WINDOWS then
  local function file_exists(p)
    local fh = io.open(p, 'r')
    if fh then fh:close(); return true end
    return false
  end
  local up = os.getenv('USERPROFILE') or ''
  local nu_exe
  local mh = io.open(up .. '/.config/wezterm4neil/nu-path.txt', 'r')
  if mh then
    nu_exe = mh:read('*l')
    mh:close()
  end
  if not nu_exe or not file_exists(nu_exe) then
    local la = os.getenv('LOCALAPPDATA') or ''
    if la ~= '' then
      local fallback = la .. '/Programs/wezterm4neil/nu/nu.exe'
      if file_exists(fallback) then nu_exe = fallback end
    end
  end
  if nu_exe and file_exists(nu_exe) then
    config.default_prog = { nu_exe }
  end
else
  -- 第二层：Zellij 复合侧边栏（仅 Linux/macOS；Zellij 无 Windows 原生版）。
  -- 若系统存在 zellij 且布局已部署 → 默认拉起 `zellij --layout sidebar`；
  -- 否则回退用户默认 shell（fish/bash），保证“只用配置文件”模式也不崩。
  local function file_exists(p)
    local fh = io.open(p, 'r')
    if fh then fh:close(); return true end
    return false
  end
  local home = os.getenv('HOME') or ''
  local zellij_bin
  for _, p in ipairs({ '/usr/bin/zellij', '/usr/local/bin/zellij', home .. '/.local/bin/zellij' }) do
    if file_exists(p) then zellij_bin = p; break end
  end
  local layout_in_home = file_exists(home .. '/.config/zellij/layouts/sidebar.kdl')
  local layout_in_skel = file_exists('/etc/wezterm4neil/skel/config/zellij/layouts/sidebar.kdl')
  if zellij_bin and (layout_in_home or layout_in_skel) then
    config.default_prog = { zellij_bin, '--layout', 'sidebar' }
  end
end

-- ----------------------------------------------------------------------------
-- 6) 说明：窗口居中/开机自启等交给系统与用户偏好处理
--    不再使用 gui-startup + spawn_window —— 该写法在部分 WezTerm 版本会
--    额外多开一个窗口（导致"一个报错页 + 一个 nu 窗口"的双窗现象）。
-- ----------------------------------------------------------------------------

return config
