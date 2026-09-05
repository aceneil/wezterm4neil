# wznav — WezTerm4Neil 侧栏导航 TUI

一期目标：把当前 Zellij 复合侧栏的「左上 server-menu.sh + 左下 yazi」合并为
**一个自研 Go TUI**，左栏 20% 跑这一个进程就够。整体交互心智参考 WindTerm
的「会话列表 + 文件管理一体」窗口，但**只参考思想、不抄代码**（cleanroom）。

```
┌─ wznav ────────────────────────────────────────────────┐
│ ▶ Servers                                              │
│   github.com                                           │
│   root@db1.example.com          (prod 数据库)          │
│   k8s-master                    (local k8s 控制面)     │
├─────────────────────────────────────────────────────────┤
│ ▶ Files (~/Projects)                                   │
│   ..                                                   │
│   wezterm4neil/                                         │
│   docs.md                                              │
├─────────────────────────────────────────────────────────┤
│ ctx=local pane=1 ws=ws://127.0.0.1:39771  |  → github.com (zellij=zellij) │
└─────────────────────────────────────────────────────────┘
```

## 编译

```bash
./nav/build.sh              # 默认：tidy+vet+build+strip+ sanity check
./nav/build.sh --test       # 加跑单测
./nav/build.sh --no-binary  # 只跑 tidy/vet/test
./nav/build.sh --debug      # 保留可调试符号（不推荐）
```

Go 工具链按下列顺序查找：

1. `/tmp/gotool/go`        （按任务书约定自下载的官方 tar.gz）
2. `/usr/local/go/bin/go`  （系统包）
3. `PATH` 上的 `go`

找不到时脚本会打印安装指引并退出码 2。

产物：`bin/wznav`（仓库根目录下），CGO 关闭、`-trimpath`、strip 符号、
静态链接，Linux amd64；当前大小 ~7.9 MB。

## 运行

```bash
# TUI（需要真实 TTY；Zellij pane 内可正常运行）
./bin/wznav

# 调试用：仅打印解析后的服务器列表（无 TTY 也可）
./bin/wznav --list

# 关闭内嵌 websocket（最小化场景，例如 CI）
./bin/wznav --no-ws

# 覆盖起始端口（环境变量也可：WZNAV_WS）
./bin/wznav --ws-port 40000
```

环境变量：

| 变量           | 作用                                  | 默认          |
|----------------|---------------------------------------|---------------|
| `HOME`         | 起始目录 + `~/.ssh/config` 解析路径   | 当前用户      |
| `XDG_CONFIG_HOME` | `~/.config/wezterm4neil/servers.txt` 根 | `~/.config`   |
| `WZNAV_WS`     | 覆盖 `--ws-port`（`:0` 表系统分配）   | `39771`       |
| `ZELLIJ`       | 由 zellij 注入；存在则用新 tab 启动   | （无）        |

## 快捷键

| 键                         | 行为                                                            |
|----------------------------|-----------------------------------------------------------------|
| `j` / `k` / `↑` / `↓`      | 上下移动当前 pane 的高亮行                                       |
| `g` / `G`                  | 跳到列表首 / 末（仅服务器 pane）                                 |
| `Enter`                    | 服务器：开新 zellij tab 跑 ssh；文件：目录进入 / 文件用 `wz-open.sh` 打开 |
| 双击（500ms 内同位置）      | 等价于 `Enter`（mouse 用户）                                     |
| `h` / `←`                  | 文件 pane：上一级目录                                            |
| `l` / `→`                  | 文件 pane：进入高亮目录                                          |
| `Tab` / `1` / `2`          | 在「服务器 ↔ 文件」pane 间切焦点                                |
| `/`                        | 当前 pane 进入过滤模式（再按 `Enter` 退出过滤）                  |
| `Esc`                      | 退出过滤、还原完整列表                                           |
| `Backspace`                | 过滤模式：删一个字符                                             |
| `r`                        | 重读 `~/.ssh/config` + `servers.txt`，刷新目录                  |
| `?`                        | 在状态行显示一次完整快捷键提示                                   |
| `q` / `Ctrl+C`             | 退出 wznav（zellij pane 回到 shell）                            |

## 鼠标

- 单击 pane：把焦点切到该 pane + 把高亮移到点击行
- 双击（500ms 内同坐标）：立即执行 `Enter` 动作
- 滚轮：在当前 pane 内上下移动

## 设计

### 单一二进制
所有视图（服务器列表、文件树、状态行、ws 服务）都直接内建在 `wznav`
里。**不实现插件目录、动态加载、外部 UI 进程**，只适配我们自己的
打包环境（Linux deb + Zellij 左栏），不为通用化付出额外抽象。

### 服务端动作

- 在 Zellij 内（`$ZELLIJ` 已设且 `zellij` 二进制在 PATH）：
  `zellij action new-tab --name <tab> -- ssh <host>`
  每次点击 = 开新 tab，不会关闭/打断现有窗格与布局。
- 不在 Zellij 但 `zellij` 在 PATH：同样尝试新 tab（用于"开发期
  误启"）。
- 都没有：状态行提示「zellij=off-bin: install zellij」，**不**就地 exec ssh，
  避免销毁侧栏 pane。

### 服务器列表

合并：

1. `~/.ssh/config` 的 `Host` 行（过滤 `*` `?` 通配；多个别名按出现顺序
   去重；首胜）。
2. `~/.config/wezterm4neil/servers.txt`（每行 `别名` 或 `别名|说明`）。
   `#` 开头 / 空行忽略。

合并规则：ssh 先，extra 后；同 alias 不重复出现（ssh 优先）。

### 文件浏览

- 起始目录：`--start-dir` 或 `$HOME`。
- 列表项：目录在前，文件在后；同名大小写不敏感排序；隐藏文件下沉到组尾。
- 上一级 `..` 项：当前目录为 `/` 时不显示，避免无效操作。
- 文件打开：优先 `wz-open.sh`（仓库已有），其次 `xdg-open`；都没有
  就在状态行报错。

### 上下文（context）

TUI 内部维护一个 `ctx` 字段：

- 启动 = `"local"`
- 选中服务器后 = 该 host 的 tab 名（`servers.TabName(e)`）
- 写入内嵌 websocket 的 `context` 字段（也通过 `GET/POST /context` 暴露）

二期规划：外部 daemon 接 `POST /context` 把当前激活 tab 的机器名推给 TUI，
TUI 据此渲染远端文件树、跑 ssh exec 后远程 ls 等。一期不做。

### WebSocket 端点

`wznav` 启动时在同进程内起一个本地 ws 服务（best-effort；端口冲突自动
`+1` 走完）。所有端点**只在 127.0.0.1** 上接受连接。

| Method | Path        | 行为                                                         |
|--------|-------------|--------------------------------------------------------------|
| GET    | `/health`   | `{"ok":true,"pid":N,"context":"<ctx>","port":N,"version":"wznav-v1"}` |
| GET    | `/context`  | `{"context":"<ctx>"}`                                        |
| POST   | `/context`  | body `{"context":"<value>"}`，写后回 `{"context":"<value>"}`  |

ws 故障**绝不**影响 TUI。日志里能看到 `ws: serving on ws://127.0.0.1:39771`。

## 依赖与许可

| 依赖                                       | 版本       | 用途                  | 许可            |
|--------------------------------------------|------------|-----------------------|-----------------|
| github.com/charmbracelet/bubbletea         | v1.3.4     | TUI 框架              | MIT             |
| github.com/gorilla/websocket               | v1.5.3     | 本地 ws server        | BSD-2-Clause    |

间接依赖（bubbletea 拉入）：lipgloss / termenv / x/ansi / x/term / go-osc52 /
erikgeiser/coninput / lucasb-eyer/go-colorful / mattn/go-isatty / go-localereader /
go-runewidth / muesli/ansi / muesli/cancelreader / rivo/uniseg / golang.org/x/sync
/syscrypto/wait / text —— 全部 MIT 或 BSD-*，无 AGPL/SSPL 等传染 / 网络强 copyleft。

## 仓库布局

```
nav/
├── README.md                        # 本文件
├── go.mod / go.sum
├── build.sh                         # 编译入口
├── cmd/
│   ├── wznav/                       # 主二进制（产物：bin/wznav）
│   └── _smoke/                      # 人工调试用，非交付
│       ├── wznav-ws-smoke/          # ws 端到端冒烟（cd nav && go run ./cmd/_smoke/wznav-ws-smoke）
│       └── wznav-plan-smoke/        # 计划构造冒烟
└── internal/
    ├── servers/  (servers.go + _test.go)   # ssh config + servers.txt 解析
    ├── fs/      (fs.go)                     # 文件浏览器
    ├── action/  (action.go + _test.go)      # zellij 计划构造 / 执行
    ├── ws/      (ws.go)                     # 内嵌 ws server
    └── ui/      (ui.go + _test.go)          # bubbletea 视图/键盘/鼠标
```

## 集成

- Zellij 布局：`config/zellij/layouts/sidebar.kdl`（被本任务一并改）
  左栏 20% 改为单 pane 跑 `wznav`（PATH 中找，缺则提示）。
- 安装：`install.sh` 若 `bin/wznav` 存在就复制到 `~/.local/bin/wznav`。
- Debian 打包：`packaging/linux/build-deb.sh` 新增 `--wznav-bin` 可选参数；
  缺省不装（向后兼容）。

## 单测

```bash
cd nav && go test ./...
# ok  github.com/wezterm4neil/wznav/internal/action     3 tests
# ok  github.com/wezterm4neil/wznav/internal/servers    6 tests
# ok  github.com/wezterm4neil/wznav/internal/ui         5 tests
# 14 passing
```

## 二期 / 遗留

- **远端文件浏览**：当 `ctx != "local"` 时把文件操作路由到 daemon；SFTP over
  ws；本地 `fs.Browser` 已为切到 `RemoteBrowser` 留好接口点。
- **真正的 ws 客户端**：把 server 部分抽成 `internal/ws/server`，新增
  `internal/ws/client` 给将来 daemon 用。
- **Zellij 焦点回写**：当用户切到某个 ssh tab，把 `ctx` 反向推到 TUI；今天
  TUI 只主动写 `ctx`，等 daemon 反向连过来再补 POST。
- **持久化**：当前 `~/.ssh/config` 是只读源；servers.txt 是手写列表。
  可以加「最近连接 / 最常用」本地索引（`~/.local/share/wznav/state.json`）。
- **插件/扩展层**：明确**不**做。`internal/ws` 已经提供足够的可观测点，
  任何"插件"想法都应当作为 zellij pane 里**第二个** Go 进程去实现，
  而不是给 wznav 加热加载。
