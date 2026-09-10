# Pipeline 自动化流水线详解

本仓库的核心是 `.github/workflows/release.yml` —— 一条在 **GitHub Actions 云端**运行的
全自动流水线（7 个 Job）。仓库里「手写的源码」其实只有 3 个配置文件
（`wezterm.lua` / `config.fish` / `starship.toml`）+ `nushell.nu`（Windows 用）+
安装/打包脚本；下载上游、组装三平台安装包、自测、发布全部由这条流水线完成。

一句话：**每周自动把上游最新版 WezTerm / Fish / Nushell / Starship / Nerd Font / Zellij / Yazi
与本仓库配置打包成 .deb / .dmg / .exe，发布到 GitHub Releases。**

## 1. 触发方式

| 触发 | 时间 | 适用场景 |
| :--- | :--- | :--- |
| ⏰ 定时 `schedule` | 每周一 00:00 UTC（= 北京时间周一 08:00） | 上游发布新版本 → 自动重新打包 |
| 👆 手动 `workflow_dispatch` | Actions 页点按钮 | 想立刻出一版 |
| 📤 `push` 到 `main` | 每次提交 | 改配置即出新安装包 |

并发控制：`concurrency.group = wezterm4neil-release` + `cancel-in-progress: false`
——同一时刻只跑一轮，新触发的运行会排队等上一轮结束，不会互相打架。

## 2. 7 个 Job 总览

```
触发（schedule / dispatch / push main）
 │
 ├─ ① fetch-upstreams   拉取 7 个上游最新产物 + 字体子集 + VERSIONS.txt
 │
 ├─ ② preview           独立 Job：VHS 渲染 README 预览 GIF（有变化才 commit 回仓库）
 │
 ├─ ③ build-linux ──► ④ smoke-test-linux   （ubuntu-22.04 真机自测 .deb）
 │
 ├─ ⑤ build-macos        （与 ③④⑥ 并行，均依赖 ①）
 │
 └─ ⑥ build-windows      （NSIS 安装器）
         │
         ▼
      ⑦ release           下载三端产物 → 同 tag 删除重建 → 发布 GitHub Release
```

防循环钩子：② 提交的 commit 消息以 `docs: update terminal preview GIF` 开头，
①③④⑤⑥⑦ 对这类 push 一律 `if: false` 跳过 → **那轮只有 preview 会跑**，
不会因为 GIF 更新触发整条打包链。

## 3. ① fetch-upstreams —— 拉取 7 个上游

全部走 GitHub API 解析各仓库 `releases/latest`，带 curl 重试 + 空文件守卫：

| 上游仓库 | 拉什么 | 用途 |
| :--- | :--- | :--- |
| `wezterm/wezterm` | Linux `.deb`、macOS `.zip`、Windows `.zip` | 三端终端本体 |
| `fish-shell/fish-shell` | Linux 自包含 `tar.xz`（取不到回退发行版 apt deb）；macOS `.pkg`（可选） | macOS/Linux 默认 shell |
| `starship/starship` | Linux / macOS / Windows 的 **x86_64** 单文件二进制 | 提示符（三端） |
| `nushell/nushell` | Windows `x86_64-pc-windows-msvc.zip` | Windows 默认 shell（仅 Win） |
| `ryanoasis/nerd-fonts` | `CascadiaCode.zip`（v3.5.1 起并入此名；v3.4 前是 `CaskaydiaCove.zip`） | Powerline 图标字体 |
| `zellij-org/zellij` | Linux（及未来 macOS）`x86_64-unknown-linux-musl.tar.gz`（排除 no-web 变体） | 第二层多路复用器（Linux/macOS；Win 无原生版） |
| `sxyazi/yazi` | Linux `x86_64-unknown-linux-gnu.zip` | 文件管理器（侧边栏） |

对上游命名变化容错（`pick3` 工具）：
- 主规则（前缀+后缀）→ 失效则放宽备选规则 → 全部失效则**列出该 release 全部资产名并 exit 1**，绝不静默产出空包。

Nerd Font 子集化：
1. 解压字体 zip，只取 `CaskaydiaCoveNerdFont-{Regular,Bold,Italic,BoldItalic}.ttf` 4 个文件到 `fonts/`；
2. 兜底：若命名变化导致一个都没抓到，把 zip 内所有 `.ttf` 拷入，避免缺失；
3. `fonts/` 随三端安装包分发，安装时自动装到系统字体目录（见各平台安装行为）。

另下载 4 份上游 LICENSE（wezterm MIT / fish GPL-2 / starship ISC / nushell MIT，
均允许再分发），并生成 `VERSIONS.txt`（组件版本 / 来源 URL / 构建时间 / 本仓库 commit）。
产物上传为 artifact：`upstream`（≈300 MB）+ `versions-txt`。

## 4. ② preview —— 自动更新 README 预览 GIF（不阻塞主流程）

1. 装 fish + starship，准备演示 HOME（真实使用仓库内 `config.fish` / `starship.toml`）；
2. 用 [VHS](https://github.com/charmbracelet/vhs) 录制 `preview/terminal-demo.tape`；
3. 渲染出 `assets/preview.gif`，**内容有变化才 commit 回仓库**（防空提交、防循环）；
4. 该提交以 `docs: update terminal preview GIF` 开头 → 其余 Job 自动跳过（见第 2 节）。

## 5. ③ build-linux —— 组装 .deb

统一由 `packaging/linux/build-deb.sh` 完成（CI 与本机共用同一份逻辑）：

1. 解包上游 WezTerm Ubuntu22.04 `.deb` → 二进制进 `/usr/bin`，保留上游 `DEBIAN/triggers`；
2. 塞 fish（官方自包含 tar.xz，或发行版 apt deb）与 starship 单二进制 → `/usr/bin`；
3. 配置与脚本进 **`/etc/wezterm4neil`**：

```
/etc/wezterm4neil/
  ├─ install.sh           用户手动执行：把配置激活到 ~/.config
  ├─ VERSIONS.txt
  ├─ fonts/               随包 Nerd Font 子集（install.sh 自动装）
  └─ skel/                配置模板
      ├─ wezterm.lua
      ├─ config.fish
      └─ starship.toml
```

4. `DEBIAN/conffiles` 声明上面 5 个路径（升级不覆盖用户改动）；
5. 自动重写 control：`Depends` = 上游 deb 实际依赖**并集**；`Conflicts/Replaces/Provides` 声明 wezterm/fish/starship；
6. 上游 LICENSE → `/usr/share/doc/wezterm4neil/upstream-licenses/` + 汇总 `copyright`；
7. `dpkg-deb --build` → `wezterm4neil_<版本>_amd64.deb`（≈40 MB）；
8. 校验包内 6 个关键路径 → 上传 artifact `linux-deb`。

> 安装本包会**替换**系统里的 wezterm/fish/starship（同抢 `/usr/bin` 路径所致）；
> 装完后以普通用户执行 `bash /etc/wezterm4neil/install.sh`（或 `--link`）激活配置。

## 6. ④ smoke-test-linux —— CI 自证产物可用（Ubuntu 22.04）

> runner 用 `ubuntu-22.04`：官方 WezTerm deb 面向 22.04（依赖 libssl3 等 22.04 库），
> 自测要在目标系统上做才有意义。

1. 下载 `linux-deb` → `dpkg-deb -x` 解包到临时目录；
2. 真跑捆绑二进制：`fish --version`、`starship --version`、`wezterm --version`；
3. 用假 HOME 执行包内 `install.sh --copy`；
4. 断言 `~/.config/wezterm/wezterm.lua`、`~/.config/fish/config.fish`、`~/.config/starship.toml` 落位；
5. 全过 → `SMOKE TEST PASS ✅`。

## 7. ⑤ build-macos —— 组装 .dmg

1. 解包官方 mac zip 取 **WezTerm.app**（Universal）→ 加 starship darwin 二进制 + fish 官方 pkg（缺失则 install.command 回退 brew）；
2. 加配置（`wezterm.lua` / `config.fish` / `starship.toml` / `install.sh`）、`install.command`、`README.txt`、`VERSIONS.txt`、`licenses/`、`fonts/`；
3. `create-dmg` → `wezterm4neil-<版本>-macos.dmg`（≈130 MB）→ artifact `macos-dmg`。

用户侧 `install.command` 行为：WezTerm.app → `/Applications`；starship → `/usr/local/bin`；
fish 缺失才装（捆绑 pkg → brew 兜底）；配置 → `~/.config`（拷/链接可选）；
**Nerd Font 子集 → `~/Library/Fonts`**（macOS 的 WezTerm 走 CoreText，只能认这里）。

## 8. ⑥ build-windows —— 组装 .exe（NSIS 安装器）

Windows 产物是**离线捆绑 EXE**：程序本体全部打进安装器，装完即可用，不依赖网络。

1. 组装 payload（wezterm-gui.exe 在根 = 最外层；nu / starship 在子目录）：

```
<安装目录>/
  ├─ wezterm-gui.exe / wezterm.exe / …   WezTerm 本体（官方 windows zip 拍平）
  ├─ nu\nu.exe                           Nushell 原生版（Windows 默认 shell）
  ├─ starship\starship.exe               Starship
  ├─ wezterm.lua / starship.toml / nushell.nu / install.ps1
  ├─ fonts\  licenses\  VERSIONS.txt  README.txt
  └─ Uninstall.exe
```

2. 在 windows runner 上**真机跑 `nu.exe --version`** 自证可执行；`choco install nsis` → `makensis` 编译 `packaging/windows/installer.nsi`；
3. 产物 → 仓库根 `wezterm4neil-<版本>-windows.exe`（≈60 MB）→ artifact `windows-dist`。

安装器行为（`installer.nsi` + 随包 `install.ps1`）：
- 默认装到 `%LOCALAPPDATA%\Programs\wezterm4neil`，安装时可**自定义路径**（静默参数 `/S`）；
- 注册用户级 PATH（安装目录 / `nu` / `starship`）；
- 配置 → `%USERPROFILE%\.config\`（wezterm / starship）；可重跑 `install.ps1 -Link` 改软链接模式；
- Nu 自动加载目录 `%APPDATA%\nushell\vendor\autoload\` 写入两份文件：
  - `starship.nu`：用捆绑 starship **现场生成**的提示符（**无 BOM** UTF-8，Nu 不认 BOM）；
  - `wezterm4neil.nu`：别名（拷贝自 `nushell.nu`）；
- 记录 `nu.exe` 实际路径 → `%USERPROFILE%\.config\wezterm4neil\nu-path.txt`（无 BOM UTF-8，支持中文路径/自定义目录）；
- **Nerd Font 子集 → `%LOCALAPPDATA%\Microsoft\Windows\Fonts`** + HKCU 注册（免管理员）；
- 开始菜单 + 桌面快捷方式 → 自带卸载器（卸载保留 `~/.config` 用户配置）。

Windows 开箱体验（wezterm.lua 内）：默认 shell = 随包 Nushell + Starship；
窗口隐藏系统标题栏（`window_decorations = 'RESIZE'`）且单标签也显示标签栏（作拖拽把手）；
`Ctrl+Shift+Space` 启动菜单开 PowerShell/Cmd；`Ctrl+Shift+1/2` 直接开 PowerShell/Cmd 新标签。

## 9. ⑦ release —— 发布 GitHub Release

1. 下载三个 artifact → 展平到同一目录；
2. tag = `v<日期>`（如 `v2026.09.04`，由 UTC 日期生成）：
   - 已存在同 tag → **删除重建**（刷新「发布时间」，避免每次 push 叠出历史 tag 堆积）；
   - 不存在 → 直接创建；
3. 只上传 `.deb` / `.dmg` / `.exe`；Source code (zip/tar.gz) 由 GitHub 自动附赠；
4. Release notes 注明：随源更新全家桶、三端安装方式、每个包内含 `VERSIONS.txt`。

## 10. 一轮要多久：时间构成粗估

| 耗时来源 | 说明 |
| :--- | :--- |
| 上游下载 | ≈350 MB（wezterm×3 / fish / starship×3 / nu ~57 MB / zellij ~19 MB / yazi ~14 MB / 字体 zip） |
| artifact 跨 job 搬运 | 上游包 + 三端产物（dmg 130 MB / exe 60 MB / deb 40 MB）来回上传下载 |
| runner 冷启动 | macOS / Windows 托管 runner 排队 + 开机 2-5 分钟 |
| 真打包 | VHS 录屏、NSIS lzma 压缩 ≈200 MB payload 等 |

「组合」本身（脚本逻辑）是秒级；慢在网络传输与 runner 冷启动。一轮总计约 **10-20 分钟**。

## 11. 常见失败对照（排障速查）

| 现象 | 原因 | 处理 |
| :--- | :--- | :--- |
| fetch 报「未匹配到下载资产」并列出资产名 | 上游 release 改了资产命名 | 更新 `pick3` 谓词（工作流内注释已写主/备选规则） |
| nerd-fonts 抓不到 CaskaydiaCove | v3.5.1 起资产改名 `CascadiaCode.zip` | 谓词已同时容错两种名字；再变就按上一条更新 |
| smoke-test 跑 wezterm 报 127 / 缺 .so | deb 依赖与 runner 环境错配 | runner 固定 `ubuntu-22.04`（官方 deb 面向 22.04）；勿改 latest |
| Release 重复/资产残留 | 旧 tag 未清理 | release job 会先 `gh release delete --cleanup-tag` 再重建，幂等 |
| 上游下载中断 | 网络抖动 | 所有下载带 `curl --retry 3` + 空文件守卫 |
| GIF 提交触发整条流水线 | 预览图 commit 造成死循环 | 该 commit 带 `docs: update terminal preview GIF` 前缀，其余 Job 自动跳过 |
