#!/bin/bash
# ============================================================
# 天機閣 GitHub Pages — 天機錄自動同步腳本
# 用法：bash sync.sh
# 功能：同步天機錄報告（含子資料夾）+ 分析覆蓋率儀表板 + 自動產生首頁 + 檢查同步狀態
# 版本：v2.0 — 支援子資料夾結構（個股/主題研究/一般推衍）
# ============================================================

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
RECORD_SRC="/c/Users/Administrator/Desktop/Ai助理/天機閣/天機閣-藏經閣/天機錄"
ANALYSIS_SRC="/c/Users/Administrator/Desktop/Ai助理/天機閣/天機閣-藏經閣/投資分析資料"
TARGET_DIR="$SCRIPT_DIR"
SITE_URL="https://kensilon015-spec.github.io/stock-analysis-reports"

export PATH="/c/Program Files/GitHub CLI:$PATH"

echo "=== 天機閣 GitHub Pages 自動同步 v2.0 ==="
echo ""

# --- 步驟 1：同步天機錄 HTML（含子資料夾）---
echo "[1/5] 同步天機錄報告（含子資料夾）..."
mkdir -p "$TARGET_DIR/天機錄"

# 先清空目標的所有 HTML（含子資料夾，避免已刪除的舊檔殘留）
find "$TARGET_DIR/天機錄" -name "*.html" -type f -delete 2>/dev/null
# 清空空的子資料夾
find "$TARGET_DIR/天機錄" -mindepth 1 -type d -empty -delete 2>/dev/null

# 遞迴複製所有 HTML（排除天機錄索引頁）
find "$RECORD_SRC" -name "*.html" -type f | while read -r f; do
    BNAME="$(basename "$f")"
    [ "$BNAME" = "天機錄索引.html" ] && continue

    # 取得相對路徑（相對於天機錄根目錄）
    REL_PATH="${f#$RECORD_SRC/}"
    REL_DIR="$(dirname "$REL_PATH")"

    # 建立對應的子資料夾
    if [ "$REL_DIR" != "." ]; then
        mkdir -p "$TARGET_DIR/天機錄/$REL_DIR"
    fi

    cp -p "$f" "$TARGET_DIR/天機錄/$REL_PATH"
done

LOCAL_COUNT=$(find "$TARGET_DIR/天機錄" -name "*.html" -type f 2>/dev/null | wc -l)
SUBDIR_COUNT=$(find "$TARGET_DIR/天機錄" -mindepth 1 -type d 2>/dev/null | wc -l)
echo "  天機錄: ${LOCAL_COUNT} 個報告，${SUBDIR_COUNT} 個子資料夾"

# --- 步驟 2：掃描分析覆蓋率 ---
echo "[2/5] 掃描分析覆蓋率..."

COVERAGE_CARDS=""
STOCK_COUNT=0
TOTAL_STEPS=0
STALE_COUNT=0
TODAY_EPOCH=$(date +%s)

for stock_dir in "$ANALYSIS_SRC"/*/; do
    [ -d "$stock_dir" ] || continue
    DIRNAME=$(basename "$stock_dir")

    # 只處理股票資料夾（格式：代號_名稱 或 TICKER_名稱）
    echo "$DIRNAME" | grep -qE '^[0-9]{4}_|^[A-Z]+_' || continue

    STOCK_CODE=$(echo "$DIRNAME" | cut -d_ -f1)
    STOCK_NAME=$(echo "$DIRNAME" | cut -d_ -f2-)

    STOCK_COUNT=$((STOCK_COUNT + 1))

    # 計算完成步驟數（只計不重複步驟，忽略多版本檔案如 _v2/_v3）
    STEP_COUNT=$(ls "$stock_dir"第*步_*.html 2>/dev/null | grep -oE '第.步' | sort -u | wc -l)

    # 檢查附加報告
    HAS_SUPPLY=""
    HAS_PEER=""
    [ -f "${stock_dir}供應鏈圖譜.html" ] && HAS_SUPPLY="1"
    [ -f "${stock_dir}同業比較矩陣.html" ] && HAS_PEER="1"

    # 取得最新檔案日期
    LATEST_MTIME=0
    for f in "$stock_dir"*.html; do
        [ -f "$f" ] || continue
        FMTIME=$(date -r "$f" +%s 2>/dev/null || echo 0)
        [ "$FMTIME" -gt "$LATEST_MTIME" ] && LATEST_MTIME=$FMTIME
    done

    # 計算天數與鮮度
    DAYS_OLD=0
    FRESH_CLASS="fresh"
    FRESH_LABEL=""
    if [ "$LATEST_MTIME" -gt 0 ]; then
        DAYS_OLD=$(( (TODAY_EPOCH - LATEST_MTIME) / 86400 ))
        LATEST_DATE=$(date -d "@$LATEST_MTIME" "+%Y-%m-%d" 2>/dev/null || echo "未知")
        if [ "$DAYS_OLD" -gt 90 ]; then
            FRESH_CLASS="stale"
            FRESH_LABEL="${DAYS_OLD}天前"
            STALE_COUNT=$((STALE_COUNT + 1))
        elif [ "$DAYS_OLD" -gt 30 ]; then
            FRESH_CLASS="aging"
            FRESH_LABEL="${DAYS_OLD}天前"
        else
            FRESH_LABEL="${LATEST_DATE}"
        fi
    else
        LATEST_DATE="未知"
        FRESH_LABEL="未知"
    fi

    TOTAL_STEPS=$((TOTAL_STEPS + STEP_COUNT))
    PROGRESS_PCT=$((STEP_COUNT * 100 / 9))

    # 附加標籤 HTML
    BONUS_HTML=""
    [ -n "$HAS_SUPPLY" ] && BONUS_HTML="${BONUS_HTML}<span class=\"bonus-tag\">供應鏈</span>"
    [ -n "$HAS_PEER" ] && BONUS_HTML="${BONUS_HTML}<span class=\"bonus-tag\">同業比較</span>"

    # 組裝覆蓋率卡片
    COVERAGE_CARDS="${COVERAGE_CARDS}<div class=\"cov-card\">
  <div class=\"cov-header\">
    <span class=\"cov-code\">${STOCK_CODE}</span>
    <span class=\"cov-name\">${STOCK_NAME}</span>
    <span class=\"cov-fresh ${FRESH_CLASS}\">${FRESH_LABEL}</span>
  </div>
  <div class=\"cov-bar-wrap\">
    <div class=\"cov-bar\" style=\"width:${PROGRESS_PCT}%\"></div>
    <span class=\"cov-pct\">${STEP_COUNT}/9</span>
  </div>
  <div class=\"cov-extras\">${BONUS_HTML}</div>
</div>
"
done

if [ "$STOCK_COUNT" -gt 0 ]; then
    AVG_PCT=$(( TOTAL_STEPS * 100 / (STOCK_COUNT * 9) ))
    echo "  共 ${STOCK_COUNT} 個標的，平均完成 ${AVG_PCT}%"
else
    AVG_PCT=0
    echo "  尚無追蹤標的"
fi
[ "$STALE_COUNT" -gt 0 ] && echo "  [WARN] ${STALE_COUNT} 個標的超過 90 天未更新"

# --- 步驟 3：自動產生首頁（樹狀資料夾版）---
echo "[3/5] 自動產生首頁（樹狀資料夾）..."

REPORT_COUNT=0
NOW=$(date "+%Y-%m-%d %H:%M")

# 收集所有資料夾清單（含根目錄檔案）
declare -A FOLDER_FILES    # folder -> 檔案列表（換行分隔）
declare -A FOLDER_LATEST   # folder -> 最新檔案的 epoch

for f in $(find "$TARGET_DIR/天機錄" -name "*.html" -type f -printf '%T@ %p\n' 2>/dev/null | sort -rn | cut -d' ' -f2-); do
    [ -f "$f" ] || continue
    REPORT_COUNT=$((REPORT_COUNT + 1))

    REL_PATH="${f#$TARGET_DIR/}"
    REL_FROM_RECORD="${f#$TARGET_DIR/天機錄/}"
    SUBDIR="$(dirname "$REL_FROM_RECORD")"
    FNAME="$(basename "$f")"
    MTIME=$(date -r "$f" "+%Y-%m-%d %H:%M")
    MTIME_EPOCH=$(date -r "$f" "+%s" 2>/dev/null || echo "0")

    # 解析標籤
    case "$FNAME" in
        *完整版*)          TAG_TEXT="完整版" ;;
        *推衍版*)          TAG_TEXT="推衍版" ;;
        *供應鏈*)          TAG_TEXT="供應鏈" ;;
        *同業比較*)        TAG_TEXT="同業比較" ;;
        *主題掃描*)        TAG_TEXT="主題掃描" ;;
        *全面產業分析*)    TAG_TEXT="產業分析" ;;
        *推衍*總結*)       TAG_TEXT="推衍" ;;
        *推衍命中率*)      TAG_TEXT="系統" ;;
        *推衍天下*)        TAG_TEXT="推衍天下" ;;
        *)                 TAG_TEXT="報告" ;;
    esac

    TITLE=$(echo "$FNAME" | sed 's/\.html//' | sed 's/^[0-9_-]*//')
    [ -z "$TITLE" ] && TITLE="$FNAME"

    # 子資料夾合併到父資料夾（例如 GOOGL_Alphabet/歷史 → GOOGL_Alphabet）
    if [ "$SUBDIR" = "." ]; then
        FOLDER_KEY="__root__"
        SUB_LABEL=""
    else
        FOLDER_KEY="$(echo "$SUBDIR" | cut -d/ -f1)"
        SUB_PART="$(echo "$SUBDIR" | cut -d/ -f2- -s)"
        if [ -n "$SUB_PART" ]; then
            SUB_LABEL=" <span style=\"font-size:.65em;color:#7a7268;font-weight:400\">[${SUB_PART}]</span>"
        else
            SUB_LABEL=""
        fi
    fi

    ROW_HTML="<a class=\"row\" href=\"${REL_PATH}\"><span class=\"tag\">${TAG_TEXT}</span><span class=\"row-title\">${TITLE}${SUB_LABEL}</span><span class=\"row-time\">${MTIME}</span></a>"

    FOLDER_FILES["$FOLDER_KEY"]="${FOLDER_FILES[$FOLDER_KEY]}${ROW_HTML}
"
    # 記錄每個資料夾的最新時間
    PREV_LATEST="${FOLDER_LATEST[$FOLDER_KEY]:-0}"
    [ "$MTIME_EPOCH" -gt "$PREV_LATEST" ] && FOLDER_LATEST["$FOLDER_KEY"]="$MTIME_EPOCH"
done

# === 寫入 index.html ===
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
/* 資料夾樹狀結構 */
details.folder{margin:6px 0;background:var(--panel);border:1px solid var(--border);border-radius:10px;overflow:hidden}
details.folder[open]{border-color:var(--accent)}
details.folder>summary{padding:12px 16px;cursor:pointer;list-style:none;display:flex;align-items:center;gap:10px;font-weight:700;color:var(--base);user-select:none;transition:background .12s}
details.folder>summary:hover{background:rgba(90,125,96,.06)}
details.folder>summary::-webkit-details-marker{display:none}
details.folder>summary::before{content:'📁';font-size:1.1em}
details.folder[open]>summary::before{content:'📂'}
details.folder>summary .folder-name{flex:1;font-size:.95em}
details.folder>summary .folder-count{font-size:.7em;color:var(--txt3);background:var(--border);padding:1px 8px;border-radius:10px}
details.folder>summary .folder-time{font-size:.72em;color:var(--txt3)}
details.folder>summary::after{content:'▶';font-size:.6em;color:var(--txt3);transition:transform .2s}
details.folder[open]>summary::after{transform:rotate(90deg)}
details.folder>.folder-body{padding:2px 10px 10px}
/* 報告列 */
.row{display:flex;align-items:center;gap:10px;padding:9px 14px;margin:3px 0;background:rgba(255,255,255,.45);border:1px solid var(--border);border-radius:8px;text-decoration:none;color:var(--txt);transition:transform .12s,box-shadow .12s}
.row:hover{transform:translateY(-1px);box-shadow:0 2px 8px rgba(0,0,0,.07);background:rgba(255,255,255,.7)}
.tag{flex-shrink:0;padding:2px 8px;border-radius:4px;font-size:.7em;font-weight:700;color:#fff;background:var(--accent)}
.row-title{flex:1;font-size:.85em;font-weight:600;color:var(--base);overflow:hidden;text-overflow:ellipsis;white-space:nowrap}
.row-time{flex-shrink:0;font-size:.72em;color:var(--txt3)}
/* 根目錄檔案（無資料夾） */
.root-files{margin:6px 0}
.footer{text-align:center;padding:16px;color:var(--txt3);font-size:.75em;border-top:1.5px solid var(--border);margin-top:20px}
/* 展開收合按鈕 */
.toggle-btns{display:flex;gap:6px;margin:8px 0 4px}
.toggle-btns button{padding:3px 12px;border:1px solid var(--border);border-radius:6px;background:var(--panel);font-size:.75em;font-weight:600;color:var(--txt2);cursor:pointer;transition:all .15s;font-family:inherit}
.toggle-btns button:hover{background:var(--border);color:var(--base)}
/* 覆蓋率儀表板 */
.cov-summary{display:flex;gap:10px;margin:8px 0;flex-wrap:wrap}
.cov-stat{flex:1;min-width:100px;text-align:center;padding:8px 10px;background:var(--panel);border:1px solid var(--border);border-radius:8px}
.cov-stat .num{font-size:1.4em;font-weight:900;color:var(--accent)}
.cov-stat .label{font-size:.7em;color:var(--txt3);font-weight:500}
.cov-card{background:var(--panel);border:1px solid var(--border);border-radius:8px;padding:10px 14px;margin:4px 0}
.cov-header{display:flex;align-items:center;gap:8px;margin-bottom:6px}
.cov-code{font-weight:700;color:var(--accent);font-size:.85em}
.cov-name{font-weight:600;color:var(--base);font-size:.88em;flex:1}
.cov-fresh{font-size:.7em;padding:1px 6px;border-radius:4px;font-weight:600}
.cov-fresh.fresh{background:var(--accent);color:#fff}
.cov-fresh.aging{background:#b8960c;color:#fff}
.cov-fresh.stale{background:#a0522d;color:#fff}
.cov-bar-wrap{position:relative;height:18px;background:var(--border);border-radius:9px;overflow:hidden}
.cov-bar{height:100%;background:var(--accent);border-radius:9px;transition:width .3s}
.cov-pct{position:absolute;right:8px;top:0;line-height:18px;font-size:.7em;font-weight:700;color:var(--base)}
.cov-extras{margin-top:4px;display:flex;gap:4px;min-height:18px}
.bonus-tag{font-size:.65em;padding:1px 6px;border-radius:3px;background:var(--link);color:#fff;font-weight:600}
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

echo "    <span class=\"badge\">${REPORT_COUNT}</span>" >> "$TARGET_DIR/index.html"

cat >> "$TARGET_DIR/index.html" << 'HTMLEOF'
</div>
<div class="toggle-btns">
    <button onclick="document.querySelectorAll('details.folder').forEach(d=>d.open=true)">全部展開</button>
    <button onclick="document.querySelectorAll('details.folder').forEach(d=>d.open=false)">全部收合</button>
</div>
<div id="folder-tree">
HTMLEOF

# --- 輸出資料夾樹 ---
# 先按最新時間排序資料夾
SORTED_FOLDERS=""
for FKEY in "${!FOLDER_LATEST[@]}"; do
    SORTED_FOLDERS="${SORTED_FOLDERS}${FOLDER_LATEST[$FKEY]} ${FKEY}\n"
done

echo -e "$SORTED_FOLDERS" | sort -rn | while read -r EPOCH FKEY; do
    [ -z "$FKEY" ] && continue
    FILES_HTML="${FOLDER_FILES[$FKEY]}"
    FILE_COUNT=$(echo "$FILES_HTML" | grep -c '<a class' || echo 0)
    LATEST_DATE=$(date -d "@$EPOCH" "+%Y-%m-%d %H:%M" 2>/dev/null || echo "")

    if [ "$FKEY" = "__root__" ]; then
        # 根目錄檔案直接顯示（不包在資料夾裡）
        cat >> "$TARGET_DIR/index.html" << ROOTEOF
<details class="folder">
<summary><span class="folder-name">系統報表</span><span class="folder-count">${FILE_COUNT} 份</span><span class="folder-time">${LATEST_DATE}</span></summary>
<div class="folder-body">
${FILES_HTML}
</div>
</details>
ROOTEOF
    else
        # 資料夾中的檔案
        DISPLAY_NAME="$FKEY"
        cat >> "$TARGET_DIR/index.html" << FOLDEREOF
<details class="folder">
<summary><span class="folder-name">${DISPLAY_NAME}</span><span class="folder-count">${FILE_COUNT} 份</span><span class="folder-time">${LATEST_DATE}</span></summary>
<div class="folder-body">
${FILES_HTML}
</div>
</details>
FOLDEREOF
    fi
done

echo "</div>" >> "$TARGET_DIR/index.html"

# --- 插入覆蓋率儀表板 ---
cat >> "$TARGET_DIR/index.html" << HTMLEOF
<div class="section-head">
    <h2>分析覆蓋率</h2>
    <span class="badge">${STOCK_COUNT} 標的</span>
</div>
<div class="cov-summary">
    <div class="cov-stat"><div class="num">${STOCK_COUNT}</div><div class="label">追蹤標的</div></div>
    <div class="cov-stat"><div class="num">${AVG_PCT}%</div><div class="label">平均完成度</div></div>
    <div class="cov-stat"><div class="num">${STALE_COUNT}</div><div class="label">過期待更新</div></div>
</div>
HTMLEOF

# 插入覆蓋率卡片
echo "${COVERAGE_CARDS}" >> "$TARGET_DIR/index.html"

# 頁尾
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

echo "  首頁已自動產生（${REPORT_COUNT} 篇報告 + ${STOCK_COUNT} 個標的覆蓋率）"

# --- 步驟 4：檢查同步狀態 ---
echo "[4/5] 檢查同步狀態..."

# 遞迴比對（含子資料夾）
SRC_FILES=$(find "$RECORD_SRC" -name "*.html" -type f | sed "s|$RECORD_SRC/||" | grep -v '天機錄索引' | sort)
DST_FILES=$(find "$TARGET_DIR/天機錄" -name "*.html" -type f | sed "s|$TARGET_DIR/天機錄/||" | sort)

if [ "$SRC_FILES" = "$DST_FILES" ]; then
    echo "  [OK] 本地天機錄與發布目錄完全一致"
else
    echo "  [WARN] 發現差異："
    diff <(echo "$SRC_FILES") <(echo "$DST_FILES") || true
fi

# --- 步驟 5：推送 ---
echo "[5/5] 檢查變更並推送..."
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
