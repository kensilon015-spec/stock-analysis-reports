#!/bin/bash
# ============================================================
# 天機閣 GitHub Pages — 天機錄同步腳本
# 用法：bash sync.sh
# 功能：同步天機錄報告到 GitHub Pages 並更新首頁
# ============================================================

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
RECORD_SRC="/c/Users/Administrator/Desktop/Ai助理/天機閣/天機閣-藏經閣/天機錄"
TARGET_DIR="$SCRIPT_DIR"

export PATH="/c/Program Files/GitHub CLI:$PATH"

echo "=== 天機閣 GitHub Pages 同步 ==="
echo ""

# --- 同步天機錄 ---
echo "[1/2] 同步天機錄報告..."
mkdir -p "$TARGET_DIR/天機錄"
for f in "$RECORD_SRC"/*.html; do
    [ -f "$f" ] && cp "$f" "$TARGET_DIR/天機錄/$(basename "$f")"
done
echo "  天機錄: $(ls "$TARGET_DIR/天機錄/" | wc -l) 個檔案"

# --- 檢查 & 推送 ---
echo "[2/2] 檢查變更並推送..."
cd "$TARGET_DIR"
git add -A

if git diff --cached --quiet 2>/dev/null; then
    echo ""
    echo "[INFO] 沒有變更，不需要同步"
    exit 0
fi

CHANGED=$(git diff --cached --name-only | wc -l)
git commit -m "同步天機錄 $(date +%Y-%m-%d\ %H:%M)（${CHANGED} 個檔案變更）"
git push origin master

echo ""
echo "=========================================="
echo "[OK] 同步完成！共 ${CHANGED} 個檔案變更"
echo "首頁：https://kensilon015-spec.github.io/stock-analysis-reports/"
echo "=========================================="
