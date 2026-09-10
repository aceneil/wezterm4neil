# DEVBR-M10.md — 隐藏式导航 dock 真正落地（wezterm4neil，2026-09-08）

角色: devbk（备用开发工程师）。未 commit / 未 push / 未调子代理 / 未动 nav4neil 库 /
未触碰用户 ~/.config 现网配置（验证全走 /tmp 隔离 config-dir）。工作树保留了上轮
neilwz→nav4neil 文案清理（README/install.sh/build-deb.sh 的 4 处 M），未回退。

## 1. 结论先行

上轮 M10 只做了改名，**本次把用户要的「隐藏式导航 dock」真正实现了**：

- 默认不显示左导航，主终端**整屏全宽**；
- `Alt+d`（或 Zellij 默认 `Alt+f`）呼出/隐藏 dock —— dock = 两个 floating pane
  覆盖左侧 ~20%（上=服务器列表、下=文件浏览，各跑 nav4neil --section servers/files），
  **不重排右侧、不杀进程**；
- 呼出即焦点进入 dock（落在上方服务器区），dock 内 `Alt+j/k`（↑/↓）在两格间移动；
- 方案 a（floating pane 承载 nav）**可行性经 0.45.1 实机验证通过**，无需降级到
  双布局切换（方案 b）；nav4neil 的 `--section servers/files` 已够用，**无需新增 flag**。

实测证据（本机 zellij 0.45.1 + nav4neil 真实运行）：
启动即 dock 隐藏（`are-floating-panes-visible` = false）；`toggle-floating-panes` 后
两浮窗同时出现且各自坐标正确（x=0、width=23≈20%、height=14×2 上下叠放），nav4neil
servers UI 真实渲染在 dock-servers 内；再次 toggle 隐藏、焦点回到主终端。

## 2. 改动文件清单

| 文件 | 改动 | 内容 |
| :--- | :--- | :--- |
| config/zellij/layouts/sidebar.kdl | **结构性重写**（v3 平铺 → v4 浮窗 dock） | 删 20% 左栏平铺树与 default_tab_template；新增 tab hide_floating_panes=true + 显式 tab-bar/status-bar 兄弟 pane + floating_panes{dock-files,dock-servers}（x=0%/y=50% 与 y=1%/w=20%/h=49%，nav4neil 缺省兜底逻辑保留） |
| config/zellij/config.kdl | +11 行 | 新增 keybinds：shared_except "locked" 内 bind "Alt d" → ToggleFloatingPanes；注释 dock 语义 |
| README.md | +33 行 | 自定义表加 2 行（config.kdl / sidebar.kdl）；Linux 段新增「隐藏式导航 dock」按键表；FAQ +3 条（呼出/为何换浮层/与 herdr 同组） |
| PIPELINE.md | +11 行 | 源码描述补 config/zellij + config/yazi；③ 打包 skel 目录树补两子树（与 build-deb.sh 实际拷贝一致，未夸大） |

预存的 4 处 M（README/install.sh/build-deb.sh 的 nav4neil 文案清理）保持不动。

## 3. 技术方案与取舍

### 3.1 为什么 floating pane 方案可行且被采用（对应目标 a）
Zellij 0.45.1 布局 KDL 原生支持：
- `floating_panes { pane … }` 节点（可放在 layout 根或 tab 内），浮窗 pane 可用
  `x/y/width/height`（字符或百分比）；
- tab 上 `hide_floating_panes=true` → 启动时隐藏该 tab 的全部浮窗。
实机证明「同组两个浮窗一起 toggle」稳定：show/hide/toggle 三动作均同时作用于两格，
各格保持自己的坐标（覆盖同一 dock 区不打架），用户提示的单格兜底（-section both）
**不需要**。两格继续复用 v3 的 `--section servers` / `--section files` 嵌入语义
（点服务器开新 tab、Enter 开悬浮编辑器），体验与 v3 完全一致，只是默认收起。

### 3.2 关键坑：hide_floating_panes × default_tab_template（实测 + upstream issue）
把 `hide_floating_panes=true` 放在带 `default_tab_template` 的布局里**不生效**
（启动时浮窗仍显示，且初始焦点被拽到浮窗）——与 zellij-org/zellij#2974 同类。
实测对照：去掉 default_tab_template、在 tab 内显式摆 tab-bar/status-bar 兄弟 pane 后，
hide 立即生效（docktest3/4 vs docktest5 对照）。
代价与缓解：不用 default_tab_template 后，手动新开的 tab（Ctrl+t→n；dock 内点服务器
由 nav4neil 开的新 tab 同理）不带顶/底信息栏——README FAQ 已写明；功能不受影响。

### 3.3 焦点/方向键语义（0.45.1 浮窗 = 独立焦点层）
- 呼出后焦点落在浮窗组内**最后声明的 pane** → 布局里 dock-files 先声明、dock-servers
  后声明，使呼出聚焦上方服务器区（已实测）；
- MoveFocus（Alt+h/j/k/l/方向）只能在 dock 两格之间移动；从主区「Alt+方向移入 nav」
  在 0.45.1 不存在（移出浮窗=自动隐藏浮窗，已实测 focus-pane-id/move-focus 均如此）。
  因此目标 2 的「移入」由呼出动作承担：**Alt+d = 呼出即进入 nav**，再按 = 收起回主终端。
- 与 herdr 悬浮窗同属一个浮窗开关组（ToggleFloatingPanes 是全组开关）：README 已注明
  （herdr 用 --close-on-exit，正常用完即关，不打扰 dock）。

### 3.4 校验
- 布局/配置真机校验（比 `zellij setup --check` 更强）：/tmp 隔离 config-dir +
  pty 起真实 session 加载本仓库 sidebar.kdl/config.kdl → 会话正常、dock 默认隐藏、
  toggle 显隐、焦点与几何断言全过；`zellij setup --check`（现网配置）也显示 Well defined；
- `bash -n` 过：install.sh / scripts/*.sh（本次未改脚本，防回归检查）；
- 无 kdl 专用 linter：以 zellij 实际解析为准（解析失败会拒绝启动并打印 KDL 诊断，
  本方案 0 错误）。

## 4. 已知风险 / 限制

1. **手动新开 tab 无顶/底栏**（见 3.2）。若后续想恢复：需 nav4neil 的“开新 tab”
   带布局参数，属 nav 库改动，本次按约束不动；报告另派。
2. **浮窗组全局开关**：dock 与 herdr（或任何浮动窗）同显同隐；同时开着 herdr 时按
   Alt+d 会把 herdr 一起收起。属 Zellij 浮窗设计，非 bug。
3. **启动即起两个 nav4neil 进程**（隐藏态也在跑，同 v3 常驻开销，无新增成本）；
   若想懒加载需 zellij 布局脚本能力或 nav 端改动。
4. 百分比坐标在极小终端（宽 <50 列）下 20% dock 会偏窄，属预期。
5. 现网 ~/.config/zellij/ 还是旧拷贝，需重跑 install.sh（或 --link）后新布局才生效
   ——属用户侧部署动作，交给用户/devops，devbk 未代跑。

## 5. 目测步骤（验收清单）

1. 仓库内 `bash install.sh`（或 `--link`）→ 更新 ~/.config/zellij/{config.kdl,layouts/sidebar.kdl}；
   或手动 cp 这两个文件到 ~/.config/zellij/ 对应位置。
2. 打开 WezTerm（进 Zellij）→ **左侧应无导航**，主终端整屏；底部状态栏仍在。
3. 按 `Alt+d`（或 `Alt+f`）→ 左侧浮出 dock：上方服务器列表（localhost/herdr/github…）、
   下方文件浏览；主终端右侧未被重排（整屏宽度不变，左 20% 被浮窗覆盖）。
4. dock 内 `Alt+j`/`Alt+k` 或 ↑/↓ 在两格间切焦点；点服务器=开新 tab（新 tab 无顶底栏，
   预期内），Enter 文件=开悬浮编辑器。
5. 再按 `Alt+d` → dock 收起，焦点回主终端，主区恢复全宽。
6. 缺 nav4neil 环境（卸载/未装）：dock 显示提示行，主终端不受影响。
7. 回归：`herdr` 悬浮窗功能不变（与 dock 同浮窗组，见风险 2）。
