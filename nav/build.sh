#!/usr/bin/env bash
# ============================================================================
# nav/build.sh —— 编译 wznav 单文件静态二进制到 仓库根 bin/wznav
#
# 用法:
#   nav/build.sh              # 默认编译
#   nav/build.sh --debug      # 保留调试符号（仍 strip 内嵌表）
#   nav/build.sh --no-tidy    # 跳过 go mod tidy
#   nav/build.sh --test       # 先跑单测，失败不编
#   nav/build.sh --no-binary  # 只跑 tidy+vet+test，不产二进制
#   nav/build.sh --help
#
# Go 工具链查找顺序（任务书约定）：
#   1) /tmp/gotool/go            （自下载官方 tar.gz）
#   2) /usr/local/go/bin/go      （系统包）
#   3) PATH 上的 go
# 任一可用即可；全部缺失 → 报清晰错误并退出。
#
# 产物：CGO_ENABLED=0 静态二进制，Linux amd64，名字 wznav。
# ============================================================================
set -euo pipefail

PKG_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$PKG_DIR/.." && pwd)"
OUT="$REPO_ROOT/bin/wznav"
VERSION="$(date -u +%Y.%m.%d)"
LDFLAGS="-s -w -X main.version=v${VERSION}"

DEBUG=0
NO_TIDY=0
RUN_TEST=0
NO_BINARY=0

for arg in "$@"; do
  case "$arg" in
    --debug)     DEBUG=1 ;;
    --no-tidy)   NO_TIDY=1 ;;
    --test)      RUN_TEST=1 ;;
    --no-binary) NO_BINARY=1 ;;
    -h|--help)
      sed -n '2,20p' "$0" | sed 's/^# \{0,1\}//'
      exit 0 ;;
    *)
      echo "未知参数: $arg" >&2; exit 2 ;;
  esac
done

# ---- 找 Go ---------------------------------------------------------------
find_go() {
  for cand in /tmp/gotool/go /usr/local/go/bin/go /opt/go/bin/go; do
    if [[ -x "$cand" ]]; then
      echo "$cand"; return 0
    fi
  done
  if command -v go >/dev/null 2>&1; then
    command -v go; return 0
  fi
  return 1
}

GO_BIN="$(find_go || true)"
if [[ -z "$GO_BIN" ]]; then
  cat >&2 <<'EOF'
错误: 未找到 Go 工具链。
请安装下列任一方式后重试：
  1) 下载官方 linux-amd64 tar.gz 到 /tmp/gotool/:
       mkdir -p /tmp/gotool && cd /tmp/gotool
       curl -fsSL -o go.tgz https://go.dev/dl/go1.27.1.linux-amd64.tar.gz
       tar -xzf go.tgz
     # 然后 PATH="/tmp/gotool/go/bin:$PATH"
  2) 系统包: apt/dnf/brew install golang
  3) PATH 上已有 go
EOF
  exit 2
fi
echo "[build] using $("$GO_BIN" version) at $GO_BIN"

cd "$PKG_DIR"

# ---- tidy ----------------------------------------------------------------
if [[ "$NO_TIDY" -eq 0 ]]; then
  echo "[build] go mod tidy"
  "$GO_BIN" mod tidy
fi

# ---- vet -----------------------------------------------------------------
echo "[build] go vet"
"$GO_BIN" vet ./...

# ---- test ----------------------------------------------------------------
if [[ "$RUN_TEST" -eq 1 ]]; then
  echo "[build] go test"
  "$GO_BIN" test ./...
fi

# ---- build ---------------------------------------------------------------
if [[ "$NO_BINARY" -eq 1 ]]; then
  echo "[build] --no-binary: 已跳过链接。"
  exit 0
fi

mkdir -p "$(dirname "$OUT")"
echo "[build] CGO_ENABLED=0 go build → $OUT (version=v${VERSION})"
CGO_ENABLED=0 "$GO_BIN" build -trimpath -ldflags "$LDFLAGS" -o "$OUT" ./cmd/wznav

if [[ "$DEBUG" -eq 0 ]]; then
  echo "[build] 已 strip (debug symbols stripped via -s -w)"
fi

# 简单验证：能跑 --version 与 --list。
echo "[build] sanity check:"
"$OUT" --version
"$OUT" --list | head -5

echo
echo "[build] 完成。"
echo "  产物：$OUT"
echo "  用法：$OUT  （TUI 模式）"
echo "        $OUT --list  （仅打印服务器列表）"
echo "        $OUT --help  （帮助）"
