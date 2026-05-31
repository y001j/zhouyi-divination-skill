#!/usr/bin/env bash
# 发布脚本：从 Go 源码交叉编译五平台二进制 → 打离线 zip → 作为附件传到本仓库的 GitHub Release。
#
# 二进制与离线 zip 都不入 git 仓库，只作为 Release 附件分发；
# ensure_binary.sh 会在用户首次运行时从 Release 自动下载对应平台二进制。
#
# 用法：
#   bash scripts/release.sh                       # 默认源码在 ../zhouyi，发到 latest 之外的 v 标签由 git 决定
#   bash scripts/release.sh --src /path/to/zhouyi # 指定 Go 源码目录
#   bash scripts/release.sh --tag v1.1.0          # 指定 Release tag（默认取本仓库最新 git tag）
#   bash scripts/release.sh --no-upload           # 只编译+打包，不上传（本地验证用）
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SKILL_REPO="$(cd "$SCRIPT_DIR/.." && pwd)"        # 本（发行）仓库根
REPO="y001j/zhouyi-divination-skill"

SRC="$SKILL_REPO/../zhouyi"   # Go 源码目录默认假设与本仓库相邻
TAG=""
UPLOAD=1

while [[ $# -gt 0 ]]; do
  case "$1" in
    --src)       SRC="$2"; shift 2 ;;
    --tag)       TAG="$2"; shift 2 ;;
    --no-upload) UPLOAD=0; shift ;;
    *) echo "未知参数：$1" >&2; exit 2 ;;
  esac
done

SRC="$(cd "$SRC" && pwd)"
[[ -f "$SRC/go.mod" ]] || { echo "✗ 源码目录无 go.mod：$SRC" >&2; exit 1; }
command -v go >/dev/null 2>&1 || { echo "✗ 未安装 Go" >&2; exit 1; }

# 产物落到临时构建目录（不入仓库）
BUILD="$SKILL_REPO/.build"
BIN="$BUILD/bin"
rm -rf "$BUILD"; mkdir -p "$BIN"

echo "==> 源码：$SRC"
echo "==> 交叉编译五平台二进制"
build() {
  local os=$1 arch=$2 ext=${3:-}
  local out="$BIN/zhouyi-${os}-${arch}${ext}"
  ( cd "$SRC" && GOOS="$os" GOARCH="$arch" go build -trimpath -ldflags="-s -w" -o "$out" . )
  printf "    ✅ %-22s %s\n" "${os}-${arch}${ext}" "$(du -h "$out" | cut -f1)"
}
build darwin  arm64
build darwin  amd64
build linux   amd64
build linux   arm64
build windows amd64 .exe

# —— 打离线 zip：内含 skill 文本 + 全部二进制，解压即用 ——
echo "==> 打离线 zip"
STAGE="$BUILD/zhouyi-divination-skill-offline/zhouyi-divination"
mkdir -p "$STAGE/scripts" "$STAGE/bin"
cp "$SKILL_REPO/SKILL.md" "$SKILL_REPO/README.md" "$SKILL_REPO/VERSION" "$STAGE/"
cp "$SKILL_REPO/scripts/ensure_binary.sh" "$STAGE/scripts/"
cp "$BIN"/* "$STAGE/bin/"
ZIP="$BUILD/zhouyi-divination-skill-offline.zip"
( cd "$BUILD/zhouyi-divination-skill-offline" && zip -rq "$ZIP" zhouyi-divination -x '*.DS_Store' )
echo "    离线包：${ZIP}（$(du -h "$ZIP" | cut -f1)）"

if [[ "$UPLOAD" == "0" ]]; then
  echo ""
  echo "==> --no-upload：跳过上传。产物在 $BUILD"
  exit 0
fi

# —— 确定 tag ——
if [[ -z "$TAG" ]]; then
  TAG="$(git -C "$SKILL_REPO" describe --tags --abbrev=0 2>/dev/null || true)"
fi
[[ -n "$TAG" ]] || { echo "✗ 无可用 tag。请先 git tag vX.Y.Z，或用 --tag 指定。" >&2; exit 1; }
command -v gh >/dev/null 2>&1 || { echo "✗ 未安装 gh CLI，无法上传。装好后重试，或用 --no-upload 仅本地打包。" >&2; exit 1; }

echo "==> 上传到 Release：$REPO @ $TAG"
# Release 不存在则创建（用 tag 名作标题），存在则复用
if ! gh release view "$TAG" -R "$REPO" >/dev/null 2>&1; then
  gh release create "$TAG" -R "$REPO" -t "$TAG" -n "周易三式占卜 Skill $TAG"
fi
# 上传裸二进制（供在线下载）+ 离线 zip，--clobber 覆盖同名旧附件
gh release upload "$TAG" -R "$REPO" --clobber \
  "$BIN"/zhouyi-* "$ZIP"

echo ""
echo "==> 完成。Release 附件："
gh release view "$TAG" -R "$REPO" --json assets -q '.assets[].name' | sed 's/^/    /'
