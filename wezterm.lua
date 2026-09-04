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
  'JetBrains Mono',
  'Fira Code',
  'Menlo',                 -- macOS 内置
  'Consolas',              -- Windows 内置
  'Noto Sans Mono CJK SC', -- Linux 常见中文字体
  'PingFang SC',           -- macOS 中文
  'Microsoft YaHei',       -- Windows 中文
})
config.font_size = 13.0
config.line_height = 1.1
config.color_scheme = 'Catppuccin Mocha'
config.scrollback_lines = 10000
config.window_padding = { left = 10, right = 10, top = 10, bottom = 10 }
config.window_decorations = 'TITLE | RESIZE'
config.window_close_confirmation = 'NeverPrompt'
config.hide_tab_bar_if_only_one_tab = true
-- macOS 专属毛玻璃背景（其它平台自动忽略）
config.macos_window_background_blur = 30

-- ----------------------------------------------------------------------------
-- 3) 光标与窗口标题
-- ----------------------------------------------------------------------------
config.force_reverse_video_cursor = true
config.window_title = 'WezTerm4Neil · ' .. (wezterm.hostname() or 'terminal')

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

return config
