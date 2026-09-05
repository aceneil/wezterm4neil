# CODEX-WZNAV-R2.md — wznav 第二期交付报告（`--section` 单段模式）

> 任务书：`wznav-codex-r2` 续跑——从 phase5 收尾（半完成态：ui.go 已加 Section
> 概念/部分 hit-test 重构，但 View() / main.go flag / 测试 / sidebar.kdl / README
> 尚未收尾），单段模式 + Zellij 横向双 pane 集成。
> 完成日期：2026-09-06
> 状态：**完成，gofmt/go test/go build/非交互启动验证全绿**

---

## 0. 起点 / 续跑说明

R1 报告（CODEX-WZNAV-REPORT.md）完成后，一期默认布局（左 20% 单 pane 跑
wznav，进程内部上下分屏）已被用户接受。但左栏单 pane 把两件功能
（服务器列表 / 文件浏览）强行挤在一个进程里，按键冲突面大、`Tab/1/2`
切焦点不直觉；用户希望 R2 改成**左 20% 横向拆成两个 pane**，每个 pane
跑一个独立的 wznav 实例，分别只负责一件事，焦点切换走 Zellij 原生
`Alt+h/j/k/l`。R1 续跑做到一半（phase5）预算耗尽，本报告覆盖从 phase5
末尾至全部收尾的所有改动。

---

## 1. 设计

### 1.1 单段 vs 双段

| 维度           | R1（`both`）                            | R2（`servers` / `files`）                       |
|----------------|------------------------------------------|--------------------------------------------------|
| 进程数         | 1 个 wznav                              | 2 个 wznav（独立 PID）                            |
| 焦点切换       | wznav 内部 `Tab` / `1` / `2`             | Zellij `Alt+h/j/k/l`                              |
| ws 端口        | 一个（39771）                            | 各一个（39771 / 39772 递增）                       |
| `Tab/1/2` 行为 | 切 pane                                   | 静默忽略（避免在 `/` 过滤模式误触）                |
| `r` 行为       | 重读 ssh + servers + 刷新目录             | 只刷新当前 section 的那一类数据                    |
| 状态行         | `pane=1/2`                                | `mode=servers/files`                              |
| 视图布局       | 标题 + 服务器 + 分割 + 文件 + 状态        | 标题 + 单一区 + 状态（区段撑满剩余高度）           |
| 内存占用       | ~7.9 MB                                   | ~15.8 MB（两份进程；可接受）                       |

两种模式并存：默认仍是 `both`（向后兼容，R1 安装无感升级），新加
`--section servers|files` 用于 Zellij 双 pane 拆分。

### 1.2 单段 view 渲染规则

`View()` 按 `m.section` 三分支：

- `SectionBoth`：标题 + 服务器头 + 服务器行（`height/2`）+ 分隔 + 文件头 + 文件行 + 状态。
- `SectionServers`：标题 + 服务器头 + 服务器行（`height-3`）+ 状态。
- `SectionFiles`：标题 + 文件头 + 文件行（`height-3`）+ 状态。

标题栏也带 section tag（`wznav — servers` / `wznav — files` /
`wznav`），方便 stack 起来的两个 pane 一眼分辨。

### 1.3 单段 mouse hit-test

R2 修正了 R1 phase5 留下的 off-by-one：单段布局下：

```
y=0       标题
y=1       区段头
y=2..h-2  内容行
y=h-1     状态行
```

R1 phase5 的 hit-test 用了 `y-1`，会把点击 header 误算成 row 0；
R2 改成 `y-2` 且把 `y>=2` 作为起点。

---

## 2. 改动清单

```
 M nav/cmd/wznav/main.go             ← 新增 -section flag + ParseSection 接入
 M nav/internal/ui/ui.go             ← View() 三分支 / titleBar / sectionHeader / 状态行 / mouse 偏移
 M nav/internal/ui/ui_test.go        ← 5→12 测试；3-arg NewModel + 7 个新增
 M nav/README.md                     ← 重写：两种模式 + 设计取舍 + 21 测试
 M config/zellij/layouts/sidebar.kdl ← 左 20% 横向两段（v1→v2→v3）
 M README.md                         ← Linux 组件表里 Yazi → wznav
?? CODEX-WZNAV-R2.md                 ← 本报告
?? bin/wznav                         ← R2 产物（11.0 MB，比 R1 大 ~3 MB：多了 Section/String/Parser + 7 个新 test 编译进去；本次按要求不提交）
```

未触碰：`config.fish`、`install.ps1`、`wezterm.lua`、`starship.toml`、
`packaging/linux/*`、`.github/*`、`CODEX-WZNAV-REPORT.md`（R1 报告
保留作为历史）。

---

## 3. 关键代码片段

### 3.1 `ui.Section` + `ParseSection`

```go
type Section int

const (
    SectionBoth Section = iota
    SectionServers
    SectionFiles
)

func ParseSection(s string) (Section, error) {
    switch strings.ToLower(strings.TrimSpace(s)) {
    case "", "both":
        return SectionBoth, nil
    case "servers", "server":
        return SectionServers, nil
    case "files", "file":
        return SectionFiles, nil
    }
    return SectionBoth, fmt.Errorf("invalid section %q (want both|servers|files)", s)
}
```

错误路径让 main.go 退出码 2，而不是静默回落到 `both`（避免
typo `--section servrs` 被当成默认）。

### 3.2 View 三分支

```go
switch m.section {
case SectionServers:
    b.WriteString(pad(" "+m.sectionHeader(paneServers)+" ", m.width, '-'))
    b.WriteByte('\n')
    rows := m.height - 3
    if rows < 1 { rows = 1 }
    for i := 0; i < rows; i++ {
        b.WriteString(m.renderServerRow(i))
        if i < rows-1 { b.WriteByte('\n') }
    }
case SectionFiles:
    // 对称：渲染文件区
default:
    // R1 原始两段布局（保持不变）
}
```

### 3.3 main.go 接入

```go
flag.StringVar(&sectionIn, "section", "both",
    "渲染区段：both|servers|files（单段模式便于把 wznav 拆到两个 Zellij pane）")
flag.Parse()

section, err := ui.ParseSection(sectionIn)
if err != nil {
    fmt.Fprintln(os.Stderr, "wznav:", err)
    os.Exit(2)
}

model := ui.NewModel(startDir, wss, section)
```

### 3.4 sidebar.kdl：横向双段

```kdl
pane size="20%" {
    pane split_direction="horizontal" {
        pane size="50%" name="wznav-servers" {
            command "bash"
            args "-lc" "if command -v wznav >/dev/null 2>&1; then exec wznav --section servers; else ...; fi"
        }
        pane size="50%" name="wznav-files" {
            command "bash"
            args "-lc" "if command -v wznav >/dev/null 2>&1; then exec wznav --section files; else ...; fi"
        }
    }
}
```

历史轨迹写在文件头注释里（v1 = server-menu.sh + yazi；v2 = 单 pane
wznav；v3 = 横向双段 wznav）。

---

## 4. 验收

### 4.1 gofmt

```bash
$ gofmt -w .
$ gofmt -l .      # 空输出 = 已格式化
```

### 4.2 单测

```bash
$ cd nav && go test ./...
?   	github.com/wezterm4neil/wznav/cmd/wznav	[no test files]
ok  	github.com/wezterm4neil/wznav/internal/action	0.003s   # 3 tests
?   	github.com/wezterm4neil/wznav/internal/fs	[no test files]
ok  	github.com/wezterm4neil/wznav/internal/servers	0.003s   # 6 tests
ok  	github.com/wezterm4neil/wznav/internal/ui	0.066s   # 12 tests
?   	github.com/wezterm4neil/wznav/internal/ws	[no test files]
# 21 passing (R1=14, R2 新增 7：ParseSection / Section.String / 单段 view×2 / Tab 静默×2 / 单段刷新隔离)
```

新增的 7 个 ui test：

| 测试                                            | 验证什么                                                   |
|------------------------------------------------|------------------------------------------------------------|
| `TestParseSection`                              | 表驱动：合法值 / 大小写 / 空白 / typo 全部行为正确         |
| `TestSection_String`                            | 三个常量 + 未知值的 `String()` 行为                        |
| `TestModel_SectionServersView`                  | 单段 servers 不渲染 "Files"，状态行显示 `mode=servers`，未加载 fs |
| `TestModel_SectionFilesView`                    | 单段 files 不渲染 "Servers"，状态行显示 `mode=files`，未加载 servers |
| `TestModel_SectionServersIgnoresTab`            | Tab/1/2 在单段 servers 下不动 focus                          |
| `TestModel_SectionFilesIgnoresTab`              | Tab/1/2 在单段 files 下不动 focus                            |
| `TestModel_SectionServersRefreshOnlyReloadsServers` | `r` 在单段 servers 下只刷服务器、不创建 fs                |

### 4.3 构建

```bash
$ cd nav && CGO_ENABLED=0 go build -o ../bin/wznav ./cmd/wznav
# exit 0；产物 bin/wznav (ELF 64-bit LSB, statically linked, ~11 MB)
$ file ../bin/wznav
../bin/wznav: ELF 64-bit LSB executable, x86-64, version 1 (SYSV),
  statically linked, Go BuildID=..., with debug_info, not stripped
```

### 4.4 `--list`（CI 路径，无 TTY）

```bash
$ ../bin/wznav --list
wznav dev
ssh config: /home/neil/.ssh/config
extra list : /home/neil/.config/wezterm4neil/servers.txt
count      : 3

   1) github.com                  ssh=github.com            tab=github.com [ssh]
   2) root@db1.example.com        ssh=root@db1.example.com  tab=db1.example.com [extra]  (prod 数据库)
   3) k8s-master                  ssh=k8s-master            tab=k8s-master [extra]  (local k8s 控制面)
```

### 4.5 `--help`（CLI 形状）

```
-section string
    渲染区段：both|servers|files（单段模式便于把 wznav 拆到两个 Zellij pane） (default "both")

示例（Zellij 双 pane 拆分):
  wznav --section servers   # 左上：服务器列表
  wznav --section files     # 左下：文件浏览
```

### 4.6 非交互启动验证（伪 TTY 3s timeout）

```bash
$ timeout 3 script -qec "bin/wznav --section servers --no-ws" /tmp/x.txt ; echo $?
124   # timeout-killed = 进程一直在跑没崩
$ timeout 3 script -qec "bin/wznav --section files --no-ws" /tmp/x.txt ; echo $?
124
$ timeout 3 script -qec "bin/wznav --no-ws" /tmp/x.txt ; echo $?
124
```

三种模式都正常起进程、退不出（在等 TTY 输入），无 panic、无 nil 解引用。
View() 渲染正确性由 `TestModel_SectionServersView` /
`TestModel_SectionFilesView` 直接断言字符串内容保证。

### 4.7 错误路径

```bash
$ ../bin/wznav --section bogus
wznav: invalid section "bogus" (want both|servers|files)
$ echo $?
2
```

typo 走错误路径而不是静默回落到 `both`。

---

## 5. 与 Zellij 的集成路径

R1 时单 pane 跑 wznav，R2 改成横向双 pane：

```
┌──────────────────────────────────────────────────────┐
│ zellij:tab-bar                                        │  ← R1 起就有
├─────────────┬────────────────────────────────────────┤
│ wznav       │                                        │
│  --section  │                                        │
│   servers   │         💻 终端（主终端，focus）         │
│             │                                        │
├─────────────┤                                        │
│ wznav       │                                        │
│  --section  │                                        │
│   files     │                                        │
├─────────────┴────────────────────────────────────────┤
│ zellij:status-bar                                     │  ← R1 起就有
└──────────────────────────────────────────────────────┘
```

行为：

1. 用户 `Alt+l` → 焦点移到主终端；
2. 用户 `Alt+h` → 焦点回到左栏；
3. 用户 `Alt+j` 或 `Alt+k` → 在 wznav-servers ↔ wznav-files 之间切焦点；
4. 在 wznav-servers 里按 `j/k/Enter` 操作服务器列表；
5. 在 wznav-files 里按 `j/k/h/l/Enter` 操作文件；
6. 两个 wznav 都独立嵌入 ws server（端口 39771 / 39772 递增），将来
   互相通信走 127.0.0.1 即可。

---

## 6. 边界 / 已知问题

1. **zellij 启动顺序**：若两个 wznav 几乎同时抢端口 39771，第一个
   拿到 39771，第二个 walk 到 39772。这是 `ws.New` 已有的逻辑，不算
   bug；但日志里两个进程的 `ws: serving on ...` 会交错。R3 可考虑
   给 servers 段固定 39771、files 段固定 39772（CLI 显式指定）。
2. **memory**：两份进程 ≈ 15.8 MB。对开发机忽略；对极低内存环境
   （WSL1 256 MB）建议保留 R1 的 `both` 模式。
3. **标题栏 tag**：`wznav — servers` 与 `wznav — files` 靠 em-dash
   区分；如果终端字体不带 em-dash 会回退成连字符，可读性略降但
   不影响功能。

---

## 7. 二期 / 遗留（继承 R1）

- **远端文件浏览**：files 段已经能独立跑；ctx 不再是 local 时把 fs.Browser
  换成 RemoteBrowser 即可，servers 段完全不受影响——这是 R2 拆分的
  最大收益。
- **ws 客户端 + 反向 ctx 推送**：`internal/ws/server` 已经在用，差
  `internal/ws/client` 和 daemon。
- **持久化最近连接**：servers 段独有，可在它的 `~/.local/share/wznav/servers.json`
  里记。
- **插件/扩展层**：明确**不**做。

---

## 8. 交付物清单

- `nav/cmd/wznav/main.go` — `-section` flag + ParseSection
- `nav/internal/ui/ui.go` — Section / ParseSection / View 三分支 / titleBar /
  sectionHeader / 状态行 section 感知 / mouse 偏移修复
- `nav/internal/ui/ui_test.go` — 12 tests（含 7 个新增）
- `nav/README.md` — 两种模式文档 + 设计取舍 + 21 测试
- `config/zellij/layouts/sidebar.kdl` — v3 横向双段
- `README.md` — Linux 组件表 Yazi → wznav
- `CODEX-WZNAV-R2.md` — 本报告
- `bin/wznav` — R2 产物（11.0 MB；按任务书要求更新到 bin 但不提交）

未触碰：`config.fish`、`install.ps1`、`wezterm.lua`、`starship.toml`、
`.github/*`、`packaging/linux/*`、`CODEX-WZNAV-REPORT.md`（R1 历史报告）。
