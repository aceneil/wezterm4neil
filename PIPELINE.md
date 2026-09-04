# Pipeline 自动化流水线详解

本仓库的核心是 `.github/workflows/release.yml`（约 530 行）——一个在 **GitHub Actions 云端**运行的全自动流水线。仓库里的「源码」其实只有 3 个配置文件 + 安装/打包脚本，重活（下载上游、打包三平台安装包、自测、发布）全部由这条流水线完成。

## 1. 触发方式（三选一，全自动）

| 触发 | 时间 | 适用场景 |
| :--- | :--- | :--- |
| ⏰ 定时 `schedule` | 每周一 00:00 UTC（北京时间 08:00） | 上游发布新版本 → 自动重新打包 |
| 👆 手动 `workflow_dispatch` | Actions 页点按钮 | 想立刻出一版 |
| 📤 `push` 到 `main` | 每次提交 | 改配置即出新安装包 |

并发控制：同一时间只跑一轮（`concurrency`），不会互相打架。

## 2. 7 个 Job 的详细流程

```
触发
 ├─▶ ① fetch-upstreams  拉取三上游最新官方产物 + 生成 VERSIONS.txt
 ├─▶ ② preview          用 VHS 生成预览 GIF（独立，有变化才提交回仓库）
 └─▶ ③ build-linux ──▶ ④ smoke-test-linux（CI 自证 .deb 能用）
     ⑤ build-macos  （与 ③④⑥ 并行）
     ⑥ build-windows
              └─▶ ⑦ release  只发布 .deb / .dmg / .exe（源码包由 GitHub 自动附赠）
```

### ① `fetch-upstreams` —— 拉取上游最新版
1. GitHub API 解析四个上游仓库的 `releases/latest`：
   - `wezterm/wezterm`、`fish-shell/fish-shell`、`starship/starship`、`nushell/nushell`
   （nushell 仅 Windows 用：作为原生默认 shell）
2. 按平台挑选资产，**对上游命名变化容错**：
   - 主规则：前缀 + 后缀匹配（例如 `WezTerm-macos-*` + `.zip`）
   - 主规则失效 → 放宽的备选规则（例如「任何含 macos 的 .zip」）
   - 全部失效 → 打印该 release 的**全部资产名清单**并明确失败（绝不静默产出空包）
3. 下载 9 个上游文件（wezterm×3 / fish×2 / starship×3 / nushell×1）+ 4 份官方 LICENSE（合规再分发）；所有下载带 curl 重试与空文件守卫
4. 生成 `VERSIONS.txt`（组件版本 / 来源 / commit / 日期），随每个安装包内嵌
5. 上传 artifact：`upstream`（≈300 MB）+ `versions-txt`

### ② `preview` —— 自动生成 README 预览图（不阻塞主流程）
1. 安装 fish + starship，搭一个演示 git 仓库
2. 用 [VHS](https://github.com/charmbracelet/vhs) 录制 `preview/terminal-demo.tape`
3. 渲染 `assets/preview.gif`；**内容有变化才 commit 回仓库**（防空提交）
4. 防死循环：该提交信息以 `docs: update terminal preview GIF` 开头，其余 Job 遇到此前缀自动跳过

### ③ `build-linux` —— 组装 `.deb`
统一由 `packaging/linux/build-deb.sh` 完成（单一事实源）：
1. 解包上游官方 WezTerm Ubuntu22.04 .deb → 提取二进制 + 真实运行库依赖
2. 塞入 fish（官方自包含 tar.xz；取不到回退发行版 apt deb）与 starship 二进制 → `/usr/bin`
3. 配置文件 → `/etc/wezterm4neil/skel/`；`install.sh` + `VERSIONS.txt` → `/etc/wezterm4neil/`
4. 自动重写 control：`Depends` = 上游依赖并集；`Conflicts/Replaces/Provides` 声明
5. `dpkg-deb --build` → `wezterm4neil_<版本>_amd64.deb`（≈40 MB）
6. 校验包内 6 个关键路径 → 上传 artifact `linux-deb`

### ④ `smoke-test-linux` —— CI 自证产物可用（Ubuntu 22.04 真机）
> 用 `ubuntu-22.04` runner：官方 WezTerm deb 面向 22.04（依赖 libssl1.1），在 24.04 上跑不起来属环境错配，所以自测要在目标系统上做。
1. 下载 `linux-deb` → `dpkg-deb -x` 解包
2. 真跑捆绑二进制：`fish --version`、`starship --version`、`wezterm --version`
3. 用假 HOME 执行包内 `install.sh --copy`
4. 断言 `~/.config/wezterm/wezterm.lua`、`config.fish`、`starship.toml` 落位
5. 全过 → `SMOKE TEST PASS ✅`（无需任何人本地验证）

### ⑤ `build-macos` —— 组装 `.dmg`
1. `brew install create-dmg`
2. 解包官方 mac zip 取 **WezTerm.app**（Universal）→ 加 starship darwin 二进制、fish pkg（没有则 brew 兜底）
3. 加配置 + `install.command`（一键装 app / starship / 落 `~/.config`）+ VERSIONS + 许可证
4. `create-dmg` → `wezterm4neil-<版本>-macos.dmg`（≈130 MB）→ artifact `macos-dmg`

### ⑥ `build-windows` —— 组装 `.exe`（NSIS 安装器）
1. 组装离线 payload：解包官方便携 **WezTerm** + `starship.exe` + **Nushell 原生版 `nu.exe`** + `install.ps1` + 配置 + 许可证；并在 windows runner 上**真机跑 `nu.exe --version`** 自证可执行
2. `choco install nsis` → `packaging/windows/installer.nsi` 编译
3. 产物自动移到仓库根：`wezterm4neil-<版本>-windows.exe`（≈60 MB）
   - 安装到 `%LOCALAPPDATA%\Programs\wezterm4neil`（WezTerm / starship / nu）
   - 自动注册用户 PATH
   - Nu 自动加载目录写入 `starship.nu`（提示符，用捆绑 starship 现场生成）与 `wezterm4neil.nu`（别名）
   - **WezTerm 默认打开 Nushell**（开箱即用，无需 WSL）；自带卸载器
4. → artifact `windows-dist`

### ⑦ `release` —— 发布到 GitHub Release
1. 下载三个产物 artifact → 展平
2. tag = `v<日期>`（如 `v2026.09.04`）：
   - 首次：创建 Release，只上传 **.deb / .dmg / .exe**
   - 同日重跑：清理旧资产（仅保留 deb/dmg/exe 与 GitHub 自动的 "Source code"）再补传 → 幂等
3. GitHub **自动附赠** Source code (zip) + Source code (tar.gz)

## 3. 为什么一轮要 10-15 分钟（不是仓库大，是搬运大）

| 耗时来源 | 说明 |
| :--- | :--- |
| 上游全家桶 | 每轮下载/上传 ≈300 MB（新增 Nushell ~57 MB），加上三平台产物（dmg 130 MB / exe 60 MB / deb 40 MB）跨 job 搬运 |
| Runner 冷启动 | macOS / Windows 托管 runner 每次排队 + 开机 2-5 分钟 |
| 真下载与打包 | 7 个上游文件 + NSIS lzma 压缩 200 MB payload 等 |

「组合」本身（脚本逻辑）是秒级的；慢在网络传输与 runner 冷启动。

## 4. 失败时的行为（可信赖性设计）

- 上游改名 → 主/备选规则逐级放宽 → 仍失败则**列出全部资产名**并明确报错
- 下载失败 → curl 重试 3 次 + 空文件守卫
- 产物异常 → build 后校验关键路径；冒烟 job 真机执行验证
- Release 重复 → 幂等：清理旧资产后补传，绝不堆积
- 预览图提交 → 关键字前缀跳过其余 Job，防死循环
