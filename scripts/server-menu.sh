#!/usr/bin/env bash
# ============================================================================
# server-menu.sh —— 左上角「远程服务器 / 快捷服务」交互菜单
# 部署：~/.local/bin/server-menu.sh（Zellij sidebar 布局左上 40% 窗格运行）
#
# 功能：
#   1) 列出 ~/.ssh/config 里的 Host（自动过滤 * ? 通配），数字选择 → SSH 连接
#   2) 也读取自定义清单 ~/.config/wezterm4neil/servers.txt（每行: 别名|说明 或 别名）
#      —— 用于放 ssh config 里没有的临时主机
#   3) 非数字输入直接当命令执行（如 htop / ssh user@host / lazygit）
#   4) q 退出（窗格交给 shell）；e 直接留在本机 shell（fish）
# 断开 SSH 后自动回到本菜单，方便连下一台。
# ============================================================================
set -uo pipefail

CONF_FILE="${XDG_CONFIG_HOME:-$HOME/.config}/wezterm4neil/servers.txt"
SSHCFG="${HOME}/.ssh/config"

# ---- 组装主机列表：ssh config Host（按出现顺序去重）------------------------
hosts=()
if [[ -f "$SSHCFG" ]]; then
  while read -r h; do
    [[ -z "$h" ]] && continue
    # 跳过通配/空 Host 行
    case "$h" in *[\*\?]*) continue ;; esac
    hosts+=("$h")
  done < <(awk '/^[[:space:]]*Host[[:space:]]+/ { for (i=2;i<=NF;i++) print $i }' "$SSHCFG")
fi
# 去重保序
hosts=($(printf '%s\n' "${hosts[@]}" | awk '!seen[$0]++'))

# ---- 自定义清单（servers.txt: 每行 “别名” 或 “别名|说明”）------------------
extra=()
if [[ -f "$CONF_FILE" ]]; then
  while IFS='|' read -r alias desc; do
    [[ -z "$alias" || "$alias" == \#* ]] && continue
    extra+=("$alias|${desc:-}")
  done < "$CONF_FILE"
fi

menu() {
  echo "🚀 远程服务器 / 快捷服务（编辑 ~/.ssh/config 或 $CONF_FILE 增删）"
  echo "────────────────────────────────────────────────────────────"
  local i=1
  if [[ ${#hosts[@]} -gt 0 || ${#extra[@]} -gt 0 ]]; then
    for h in "${hosts[@]}"; do
      printf '  %2d) %s\n' "$i" "$h"; i=$((i+1))
    done
    for e in "${extra[@]}"; do
      alias="${e%%|*}"; desc="${e#*|}"
      if [[ -n "$desc" ]]; then printf '  %2d) %s  ( %s )\n' "$i" "$alias" "$desc"; else printf '  %2d) %s\n' "$i" "$alias"; fi
      i=$((i+1))
    done
  else
    echo "  （未发现 SSH 主机：~/.ssh/config 为空或不存在）"
  fi
  echo "────────────────────────────────────────────────────────────"
  echo "  数字 = SSH 连接 | 直接输入 = 当命令执行 | q = 退出 | e = 留本机 shell"
}

while true; do
  echo ""
  menu
  printf '❯ '
  read -r input || break
  [[ -z "$input" ]] && continue
  case "$input" in
    q|Q) echo "退出菜单，本窗格回到 shell（Ctrl+d 关闭）"; exec "${SHELL:-bash}";;
    e|E) echo "留在本机 shell"; exec "${SHELL:-bash}";;
    *)
      if [[ "$input" =~ ^[0-9]+$ ]]; then
        idx=$((10#$input - 1))
        if (( idx >= 0 && idx < ${#hosts[@]} )); then
          echo ">> ssh ${hosts[$idx]}（断开后自动返回菜单）"
          ssh "${hosts[$idx]}" && continue
          echo "!! ssh 返回状态 $?，回到菜单…"
          sleep 1; continue
        fi
        nhosts=${#hosts[@]}
        if (( idx >= nhosts && idx - nhosts < ${#extra[@]} )); then
          target="${extra[$((idx - nhosts))]%%|*}"
          echo ">> ssh $target（断开后自动返回菜单）"
          ssh "$target" && continue
          echo "!! ssh 返回状态 $?，回到菜单…"
          sleep 1; continue
        fi
        echo "!! 无效序号 $input"; continue
      fi
      echo ">> 执行: $input"
      bash -c "$input"
      ;;
  esac
done
exit 0
