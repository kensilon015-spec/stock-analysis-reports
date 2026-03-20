#!/bin/bash
# ============================================================
# 天機閣 GitHub Pages — 全量同步腳本
# 用法：bash sync.sh
# 功能：同步 skill 設定檔 + 天機錄報告 到 GitHub Pages
# ============================================================

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
SKILL_SRC="/c/Users/Administrator/Desktop/Ai助理/天機閣/Skills"
RECORD_SRC="/c/Users/Administrator/Desktop/Ai助理/天機閣/天機閣-藏經閣/天機錄"
TARGET_DIR="$SCRIPT_DIR"

export PATH="/c/Program Files/GitHub CLI:$PATH"

echo "=== 天機閣 GitHub Pages 全量同步 ==="
echo ""

# --- 同步 Skill 設定檔 ---
echo "[1/3] 同步 Skill 設定檔..."
mkdir -p "$TARGET_DIR/skills"

# 根層 skill
for f in "$SKILL_SRC"/天機閣-總部.skill "$SKILL_SRC"/天機閣-推衍.skill "$SKILL_SRC"/天機閣-藏經閣.skill "$SKILL_SRC"/天機閣-趨勢探測.skill; do
    [ -f "$f" ] && cp "$f" "$TARGET_DIR/skills/$(basename "$f" .skill).txt"
done

# 子資料夾 skill
for dir in 科技前哨站 生活情報站 興趣研究所 地緣政治局 金融戰情室; do
    f="$SKILL_SRC/$dir/$dir.skill"
    [ -f "$f" ] && cp "$f" "$TARGET_DIR/skills/${dir}.txt"
done

# 推衍子 skill
for f in "$SKILL_SRC/天機閣-推衍/評審團.skill" "$SKILL_SRC/天機閣-推衍/投資分析.skill"; do
    [ -f "$f" ] && cp "$f" "$TARGET_DIR/skills/$(basename "$f" .skill).txt"
done
echo "  Skills: $(ls "$TARGET_DIR/skills/" | wc -l) 個檔案"

# --- 同步天機錄 ---
echo "[2/3] 同步天機錄報告..."
mkdir -p "$TARGET_DIR/天機錄"
for f in "$RECORD_SRC"/*.html; do
    [ -f "$f" ] && cp "$f" "$TARGET_DIR/天機錄/$(basename "$f")"
done
echo "  天機錄: $(ls "$TARGET_DIR/天機錄/" | wc -l) 個檔案"

# --- 檢查 & 推送 ---
echo "[3/3] 檢查變更並推送..."
cd "$TARGET_DIR"
git add -A

if git diff --cached --quiet 2>/dev/null; then
    echo ""
    echo "[INFO] 沒有變更，不需要同步"
    exit 0
fi

CHANGED=$(git diff --cached --name-only | wc -l)
git commit -m "同步天機閣 $(date +%Y-%m-%d\ %H:%M)（${CHANGED} 個檔案變更）"
git push origin master

echo ""
echo "=========================================="
echo "[OK] 同步完成！共 ${CHANGED} 個檔案變更"
echo "首頁：https://kensilon015-spec.github.io/stock-analysis-reports/"
echo "=========================================="
