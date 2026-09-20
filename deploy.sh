#!/usr/bin/env bash
#
# WebGL 演示部署 —— 同步构建产物 + 孤儿提交 + 强推
#
#   用法：./deploy.sh ["提交信息"]
#         WEBGL_BUILD_DIR=/别的/路径 ./deploy.sh
#
# 为什么用「孤儿提交 + 强推」而不是普通 commit：
#   每次部署的构建产物是 92MB 的二进制。普通 commit 会把它永久留在历史里，
#   24 次部署就把仓库堆到 1.23GB（2026-09-13 实测，已清理）。
#   孤儿提交每次把历史重置为 1 个提交，仓库恒定 ~99MB。
#
# 绝不触碰 webgl/index.html —— 那是定制过的响应式画布版，
# 与 E:\webgl-build\index.html（Unity 原始模板）内容不同。

set -euo pipefail

SRC="${WEBGL_BUILD_DIR:-/e/webgl-build}"
DEPLOY="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$DEPLOY"

MSG="${1:-chore(webgl): 更新演示到最新构建}"

# ── 0. 前置检查 ─────────────────────────────────────────────
[ -d "$SRC/Build" ]     || { echo "✗ 找不到构建产物：$SRC/Build"; exit 1; }
git rev-parse --git-dir >/dev/null 2>&1 || { echo "✗ 这里不是 git 仓库"; exit 1; }
[ -f webgl/index.html ] || { echo "✗ 缺 webgl/index.html（定制版），中止"; exit 1; }

CUSTOM_BEFORE=$(md5sum webgl/index.html | cut -d' ' -f1)

# ── 1. 同步构建产物 ─────────────────────────────────────────
# 只同步 Build/ 与 TemplateData/ —— Unity 纯生成物，无定制内容。
# webgl/index.html 在上一层，这个循环碰不到它。
echo "── 同步构建产物（源：$SRC）──"
CHANGED=0
for d in Build TemplateData; do
    [ -d "$SRC/$d" ] || continue
    mkdir -p "webgl/$d"
    for f in "$SRC/$d"/*; do
        [ -f "$f" ] || continue
        n=$(basename "$f")
        if [ ! -f "webgl/$d/$n" ] || ! cmp -s "$f" "webgl/$d/$n"; then
            cp -f "$f" "webgl/$d/$n"
            printf '  更新 webgl/%s/%s\n' "$d" "$n"
            CHANGED=1
        fi
    done
done
[ "$CHANGED" = 1 ] || echo "  （与已部署版本逐字节一致）"

# ── 2. 没有改动就不部署 ─────────────────────────────────────
if git diff --quiet && git diff --cached --quiet \
   && [ -z "$(git ls-files --others --exclude-standard)" ]; then
    echo "✗ 工作区与上次部署完全相同，无需部署"
    echo "  （若只想让 Pages 重建：gh api -X POST repos/MagicRobe/pico4-kingdomdemo-webgl/pages/builds）"
    exit 1
fi

# ── 3. 孤儿提交顶替 main ────────────────────────────────────
echo "── 重置历史 ──"
git branch -D deploy-tmp >/dev/null 2>&1 || true
git checkout --orphan deploy-tmp >/dev/null 2>&1
git add -A
git commit -q -m "$MSG"
git branch -D main >/dev/null 2>&1 || true
git branch -m main

# ── 4. 强推 ─────────────────────────────────────────────────
# --force-with-lease：远端点位与本地记录不符时会拒绝，防止盖掉别人的提交
echo "── 强推 origin main ──"
git push --force-with-lease origin main

# ── 5. 清理旧对象 ───────────────────────────────────────────
# 不做这步，本地 .git 每部署一次涨 ~92MB。
# 注意：git gc 清不干净（它会把不可达对象保留在 cruft pack 里），
# 必须用 repack -a -d —— 只打包可达对象并删掉旧包。
echo "── 清理旧对象 ──"
git reflog expire --expire=now --expire-unreachable=now --all
git repack -a -d
# 陈旧 commit-graph 会让 git fsck 误报 "failed to parse commit"
rm -f .git/objects/info/commit-graph .git/objects/info/commit-graphs/* 2>/dev/null || true
git commit-graph write --reachable >/dev/null 2>&1 || true

# ── 6. 核对 ─────────────────────────────────────────────────
echo
echo "═══════════════ 结果 ═══════════════"
git log --oneline
printf '本地 .git : %s\n' "$(du -sh .git | cut -f1)"
printf '远端 main : %s\n' "$(git ls-remote origin refs/heads/main | cut -f1)"

if [ "$(md5sum webgl/index.html | cut -d' ' -f1)" = "$CUSTOM_BEFORE" ]; then
    echo "✓ webgl/index.html 定制版未被改动"
else
    echo "✗ 警告：webgl/index.html 被改动了，检查一下！"
fi

if git fsck --no-progress >/dev/null 2>&1; then
    echo "✓ 对象库完整性校验通过"
else
    echo "⚠ git fsck 有输出，留意一下"
fi

echo
echo "Pages 约 1 分钟后自动重建：https://magicrobe.github.io/pico4-kingdomdemo-webgl/"
