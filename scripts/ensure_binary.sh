#!/usr/bin/env bash
# 选出适配当前平台的 zhouyi 二进制，把其绝对路径输出到 stdout。
#
# 轻仓库分发模式：仓库本身不带二进制，二进制作为 GitHub Release 附件分发。
# 查找顺序：
#   1) 本地 bin/ 已有该平台二进制 → 直接用（开发者，或解压过离线 zip 的人）
#   2) 从 GitHub Release 自动下载到 bin/ 并缓存（首次需联网，之后离线可用）
#   3) 包内嵌了源码且本机有 Go → 现场编译（仅服务于「连源码一起拿到」的开发者）
#   4) 都不行 → 明确报错
#
# 用法：BIN=$(bash ensure_binary.sh) && "$BIN" cast ...
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SKILL_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"   # skill 根目录
BIN_DIR="$SKILL_DIR/bin"

# —— 发布坐标：下载 URL = .../<REPO>/releases/download/<VERSION>/<二进制名> ——
REPO="y001j/zhouyi-divination-skill"
VERSION="$(tr -d ' \t\r\n' < "$SKILL_DIR/VERSION" 2>/dev/null || true)"
[[ -z "$VERSION" ]] && VERSION="latest"

# —— 识别平台 ——
raw_os="$(uname -s)"
raw_arch="$(uname -m)"
case "$raw_os" in
  Darwin)            os="darwin" ;;
  Linux)             os="linux" ;;
  MINGW*|MSYS*|CYGWIN*) os="windows" ;;
  *)                 os="unknown" ;;
esac
case "$raw_arch" in
  x86_64|amd64)  arch="amd64" ;;
  arm64|aarch64) arch="arm64" ;;
  *)             arch="unknown" ;;
esac

ext=""
[[ "$os" == "windows" ]] && ext=".exe"
name="zhouyi-${os}-${arch}${ext}"
candidate="$BIN_DIR/$name"

# —— 1. 优先用本地已有二进制 ——
if [[ -f "$candidate" ]]; then
  chmod +x "$candidate" 2>/dev/null || true
  echo "$candidate"
  exit 0
fi

# —— 2. 从 GitHub Release 下载并缓存 ——
if [[ "$os" != "unknown" && "$arch" != "unknown" ]]; then
  if [[ "$VERSION" == "latest" ]]; then
    url="https://github.com/${REPO}/releases/latest/download/${name}"
  else
    url="https://github.com/${REPO}/releases/download/${VERSION}/${name}"
  fi
  mkdir -p "$BIN_DIR"
  tmp="${candidate}.download.$$"
  echo "[ensure_binary] 本地无 ${name}，尝试从 Release 下载：" >&2
  echo "[ensure_binary]   $url" >&2
  ok=0
  if command -v curl >/dev/null 2>&1; then
    curl -fsSL --retry 2 -o "$tmp" "$url" && ok=1 || ok=0
  elif command -v wget >/dev/null 2>&1; then
    wget -q -O "$tmp" "$url" && ok=1 || ok=0
  else
    echo "[ensure_binary] 未找到 curl 或 wget，无法自动下载。" >&2
  fi
  if [[ "$ok" == "1" && -s "$tmp" ]]; then
    mv -f "$tmp" "$candidate"
    chmod +x "$candidate" 2>/dev/null || true
    echo "[ensure_binary] 下载完成，已缓存到 bin/。" >&2
    echo "$candidate"
    exit 0
  fi
  rm -f "$tmp" 2>/dev/null || true
  echo "[ensure_binary] 下载失败（网络不通 / Release 中无此平台产物 / 版本号 '$VERSION' 不存在）。" >&2
fi

# —— 3. 回退：若包内嵌了源码且本机有 Go，则现场编译 ——
PROJECT_ROOT="$(cd "$SKILL_DIR/../../.." && pwd 2>/dev/null || echo "")"
if [[ -n "$PROJECT_ROOT" && -f "$PROJECT_ROOT/go.mod" ]] && command -v go >/dev/null 2>&1; then
  built="$PROJECT_ROOT/zhouyi"
  echo "[ensure_binary] 尝试用本机 Go 编译 ..." >&2
  if ( cd "$PROJECT_ROOT" && go build -o "$built" . ) >&2; then
    echo "$built"
    exit 0
  fi
fi

# —— 4. 都不行：明确报错 ——
echo "[ensure_binary] 无法获得可用的 zhouyi 二进制。" >&2
echo "[ensure_binary] 当前平台：${os}-${arch}（uname: $raw_os / $raw_arch）" >&2
echo "[ensure_binary] 解决办法：" >&2
echo "  1) 检查网络后重试（脚本会自动从 Release 下载对应平台二进制）；" >&2
echo "  2) 手动下载：https://github.com/${REPO}/releases" >&2
echo "     下载 ${name} 放到 ${BIN_DIR}/ 下，并 chmod +x；或" >&2
echo "  3) 若你的平台不在支持列表，请拿到 Go 源码后在项目根执行 go build 自行编译。" >&2
exit 1
