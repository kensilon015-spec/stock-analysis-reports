#!/bin/bash
# ============================================================
# 天機閣投資分析報告 — GitHub Pages 同步腳本
# 用法：bash sync.sh
# 功能：把天機錄的最新報告同步到 GitHub Pages
# ============================================================

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
SOURCE_DIR="/c/Users/Administrator/Desktop/Ai助理/天機閣/天機閣-藏經閣/天機錄"
TARGET_DIR="$SCRIPT_DIR"

export PATH="/c/Program Files/GitHub CLI:$PATH"

echo "=== 天機閣 GitHub Pages 同步 ==="
echo ""

# 複製最新的華邦電報告為 index.html
REPORT="$SOURCE_DIR/2026-03-20_投資分析_華邦電2344.html"
if [ -f "$REPORT" ]; then
    cp "$REPORT" "$TARGET_DIR/index.html"
    echo "[OK] 已複製華邦電報告 → index.html"
else
    echo "[ERROR] 找不到報告：$REPORT"
    exit 1
fi

# 檢查是否有變更
cd "$TARGET_DIR"
if git diff --quiet index.html 2>/dev/null; then
    echo "[INFO] 沒有變更，不需要同步"
    exit 0
fi

# 提交並推送
git add index.html
git commit -m "更新華邦電投資分析報告 $(date +%Y-%m-%d\ %H:%M)"
git push origin master

echo ""
echo "[OK] 同步完成！"
echo "網址：https://kensilon015-spec.github.io/stock-analysis-reports/"
