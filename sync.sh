#!/bin/bash
# ============================================================
# 天機閣 GitHub Pages — 天機錄自動同步腳本
# 用法：bash sync.sh
# 功能：同步天機錄報告 + 自動產生首頁 + 檢查同步狀態
# ============================================================

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
RECORD_SRC="/c/Users/Administrator/Desktop/Ai助理/天機閣/天機閣-藏經閣/天機錄"
TARGET_DIR="$SCRIPT_DIR"
SITE_URL="https://kensilon015-spec.github.io/stock-analysis-reports"

export PATH="/c/Program Files/GitHub CLI:$PATH"

echo "=== 天機閣 GitHub Pages 自動同步 ==="
echo ""

# --- 步驟 1：同步天機錄 HTML ---
echo "[1/4] 同步天機錄報告..."
mkdir -p "$TARGET_DIR/天機錄"

# 先清空目標（避免已刪除的舊檔殘留）
rm -f "$TARGET_DIR/天機錄"/*.html

# 複製所有 HTML（排除索引頁，首頁本身就是目錄）
for f in "$RECORD_SRC"/*.html; do
    [ -f "$f" ] || continue
    BNAME="$(basename "$f")"
    [ "$BNAME" = "天機錄索引.html" ] && continue
    cp "$f" "$TARGET_DIR/天機錄/$BNAME"
done

LOCAL_COUNT=$(ls "$TARGET_DIR/天機錄/"*.html 2>/dev/null | wc -l)
echo "  天機錄: ${LOCAL_COUNT} 個報告"

# --- 步驟 2：自動產生首頁 ---
echo "[2/4] 自動產生首頁..."

REPORT_CARDS=""
REPORT_COUNT=0

for f in "$TARGET_DIR/天機錄"/*.html; do
    [ -f "$f" ] || continue
    FNAME="$(basename "$f")"
    REPORT_COUNT=$((REPORT_COUNT + 1))

    # 從檔名解析資訊
    case "$FNAME" in
        *投資分析*)
            TAG_TEXT="投資分析"
            TITLE=$(echo "$FNAME" | sed 's/\.html//' | sed 's/^[0-9_-]*//')
            ;;
        *推衍*總結*)
            TAG_TEXT="推衍"
            TITLE=$(echo "$FNAME" | sed 's/\.html//' | sed 's/^[0-9_]*推衍_總結_//')
            ;;
        *)
            TAG_TEXT="報告"
            TITLE=$(echo "$FNAME" | sed 's/\.html//')
            ;;
    esac

    MTIME=$(date -r "$f" "+%Y-%m-%d %H:%M")

    REPORT_CARDS="${REPORT_CARDS}<a class=\"row\" href=\"天機錄/${FNAME}\"><span class=\"tag\">${TAG_TEXT}</span><span class=\"row-title\">${TITLE}</span><span class=\"row-time\">${MTIME}</span></a>
"
done

NOW=$(date "+%Y-%m-%d %H:%M")

cat > "$TARGET_DIR/index.html" << 'HTMLEOF'
<!DOCTYPE html>
<html lang="zh-TW">
<head>
<meta charset="UTF-8"><meta name="viewport" content="width=device-width,initial-scale=1.0">
<title>天機閣 — 天機錄</title>
<link href="https://fonts.googleapis.com/css2?family=Inter:wght@400;500;600;700;900&family=Noto+Sans+TC:wght@300;400;500;700&display=swap" rel="stylesheet">
<style>
*{margin:0;padding:0;box-sizing:border-box}
:root{--bg:#d6d0c8;--panel:#e6e1da;--border:#b8b0a5;--txt:#2c2a26;--txt2:#4a453e;--txt3:#7a7268;--accent:#5a7d60;--base:#3d3a36;--link:#5a7d8c}
body{font-family:'Inter','Noto Sans TC',sans-serif;background:var(--bg);color:var(--txt);line-height:1.6;padding:0}
.wrap{max-width:720px;margin:0 auto;padding:24px 20px}
.hero{text-align:center;padding:20px 16px 16px;margin-bottom:16px;border-bottom:1.5px solid var(--border)}
.hero h1{font-size:1.6em;font-weight:900;color:var(--base)}
.hero .sub{font-size:.85em;color:var(--accent);font-weight:600;margin-top:2px}
.section-head{display:flex;align-items:center;gap:8px;margin:12px 0 8px;padding-top:12px;border-top:1.5px solid var(--border)}
.section-head h2{font-size:1.1em;font-weight:800;color:var(--base)}
.badge{background:var(--accent);color:#fff;font-size:.7em;font-weight:700;padding:1px 7px;border-radius:8px}
.row{display:flex;align-items:center;gap:10px;padding:10px 14px;margin:4px 0;background:var(--panel);border:1px solid var(--border);border-radius:8px;text-decoration:none;color:var(--txt);transition:transform .15s,box-shadow .15s}
.row:hover{transform:translateY(-1px);box-shadow:0 2px 8px rgba(0,0,0,.08)}
.tag{flex-shrink:0;padding:2px 8px;border-radius:4px;font-size:.7em;font-weight:700;color:#fff;background:var(--accent)}
.row-title{flex:1;font-size:.88em;font-weight:600;color:var(--base);overflow:hidden;text-overflow:ellipsis;white-space:nowrap}
.row-time{flex-shrink:0;font-size:.75em;color:var(--txt3)}
.footer{text-align:center;padding:16px;color:var(--txt3);font-size:.75em;border-top:1.5px solid var(--border);margin-top:20px}
</style>
</head>
<body>
<div class="wrap">
<div class="hero">
    <h1>天機閣</h1>
    <div class="sub">推衍系統 / 情報中心 / 投資分析</div>
</div>
<div class="section-head">
    <h2>天機錄</h2>
HTMLEOF

# 插入動態報告數量
echo "    <span class=\"badge\">${REPORT_COUNT}</span>" >> "$TARGET_DIR/index.html"

cat >> "$TARGET_DIR/index.html" << 'HTMLEOF'
</div>
HTMLEOF

# 插入報告列表
echo "${REPORT_CARDS}" >> "$TARGET_DIR/index.html"

cat >> "$TARGET_DIR/index.html" << HTMLEOF
<div class="footer">
    <p>天機閣 — 推衍系統 / 情報中心</p>
    <p>最後同步：${NOW}</p>
    <p style="margin-top:4px">免責聲明：所有分析報告僅供個人研究參考，不構成任何投資建議。</p>
</div>
</div>
</body>
</html>
HTMLEOF

echo "  首頁已自動產生（${REPORT_COUNT} 篇報告）"

# --- 步驟 3：檢查同步狀態 ---
echo "[3/4] 檢查同步狀態..."

SRC_FILES=$(ls "$RECORD_SRC"/*.html 2>/dev/null | xargs -I{} basename {} | grep -v '天機錄索引' | sort)
DST_FILES=$(ls "$TARGET_DIR/天機錄"/*.html 2>/dev/null | xargs -I{} basename {} | sort)

if [ "$SRC_FILES" = "$DST_FILES" ]; then
    echo "  [OK] 本地天機錄與發布目錄完全一致"
else
    echo "  [WARN] 發現差異："
    diff <(echo "$SRC_FILES") <(echo "$DST_FILES") || true
fi

# --- 步驟 4：推送 ---
echo "[4/4] 檢查變更並推送..."
cd "$TARGET_DIR"
git add -A

if git diff --cached --quiet 2>/dev/null; then
    echo ""
    echo "[INFO] 沒有變更，本地與遠端已同步"
    exit 0
fi

CHANGED=$(git diff --cached --name-only | wc -l)
git commit -m "同步天機錄 $(date +%Y-%m-%d\ %H:%M)（${CHANGED} 個檔案變更）"
git push origin master

echo ""
echo "=========================================="
echo "[OK] 同步完成！共 ${CHANGED} 個檔案變更"
echo "首頁：${SITE_URL}/"
echo "=========================================="
