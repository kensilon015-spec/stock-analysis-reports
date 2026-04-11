# -*- coding: utf-8 -*-
"""清洗每日快報內部資料，產出公開版天機日報"""
import re, sys, os

def clean(html):
    # 1. 移除「個人化排序已啟用」那整行 div
    html = re.sub(r'<div[^>]*>&#9733; 個人化排序已啟用</div>', '', html)

    # 2. 移除「追蹤動態」區塊（紫色邊框 #a08bc4）
    html = re.sub(
        r'<div style="background:#3a3535;border-radius:10px;border-left:4px solid #a08bc4;.*?</div>\s*</div>\s*</div>',
        '', html, flags=re.DOTALL
    )

    # 3. 移除「推衍預測驗證」區塊（金色邊框 #c4a96a + 352e3a 背景）
    html = re.sub(
        r'<div style="background:#352e3a;border-radius:10px;border-left:4px solid #c4a96a;.*?</div>\s*</div>',
        '', html, flags=re.DOTALL
    )

    # 4. 移除「金融監控警報」區塊（綠色 #6ecf9a）
    html = re.sub(
        r'<div style="background:#3a2a2a;border-radius:10px;border-left:4px solid #6ecf9a;.*?</div>\s*</div>\s*</div>',
        '', html, flags=re.DOTALL
    )

    # 5. 移除「法說會排程提醒」區塊（藍色 #7bafc4）
    html = re.sub(
        r'<div style="background:#2a3035;border-radius:10px;border-left:4px solid #7bafc4;.*?</div>\s*</div>',
        '', html, flags=re.DOTALL
    )

    # 6. 移除追蹤清單面板
    html = re.sub(
        r'<div class="watchlist-panel"[^>]*>.*?</div>\s*</div>\s*</div>',
        '', html, flags=re.DOTALL
    )

    # 7. 移除 watchlist 相關 CSS（含註解行）
    html = re.sub(r'/\* 追蹤清單面板 \*/', '', html)
    html = re.sub(r'\.watchlist-[^}]+\}', '', html)

    # 8. 移除整段追蹤清單 JS（從 "// 載入追蹤清單" 到 </script> 前所有追蹤功能）
    html = re.sub(r'// 載入追蹤清單\s*\n\s*loadWatchlist\(\);\s*\n', '', html)
    html = re.sub(r'// === 追蹤清單功能 ===.*?(?=</script>)', '', html, flags=re.DOTALL)

    # 8b. 清除殘留的個別追蹤函式（以防上面沒抓到的）
    for fn in ['toggleWatchlist', 'toggleTrack', 'loadWatchlist', 'saveWatchlist',
               'removeFromWatchlist', 'renderWatchlist', 'syncTrackButtons', 'removeTrack']:
        html = re.sub(rf'function {fn}\(.*?(?=function |</script>)', '', html, flags=re.DOTALL)

    # 8c. 移除 API_BASE 變數
    html = re.sub(r"var API_BASE = 'http://localhost:\d+';\s*\n", '', html)
    html = re.sub(r"var watchlistOpen = false;\s*\n", '', html)

    # 9. 移除持倉標記 span
    html = re.sub(
        r'<span style="background:#6a3a3a;color:#e0b0b0;font-size:0.7rem;padding:1px 6px;border-radius:4px;margin-right:6px;"[^>]*>持倉</span>',
        '', html
    )

    # 10. 移除追蹤按鈕
    html = re.sub(r'<button class="track-btn"[^>]*>.*?</button>', '', html)

    # 11. 移除 localhost 情報卡連結
    html = re.sub(
        r'<a href="http://localhost:\d+/[^"]*"[^>]*>.*?</a>',
        '', html
    )

    # 12. 持倉文章背景色恢復為一般（#3a2a2a → #333）
    html = re.sub(
        r'(<div class="art-item"[^>]*data-holding="1"[^>]*style="background:)#3a2a2a;',
        r'\g<1>#333;', html
    )

    # 13. data-holding 屬性移除
    html = re.sub(r'\s*data-holding="\d+"', '', html)

    # 14. 清理多餘空行
    html = re.sub(r'\n{4,}', '\n\n\n', html)

    return html

if __name__ == '__main__':
    src = sys.argv[1]
    dst = sys.argv[2]
    with open(src, 'r', encoding='utf-8') as f:
        content = f.read()
    cleaned = clean(content)
    with open(dst, 'w', encoding='utf-8') as f:
        f.write(cleaned)
    orig_size = os.path.getsize(src)
    new_size = len(cleaned.encode('utf-8'))
    print(f'清洗完成：{orig_size:,} → {new_size:,} bytes（減少 {orig_size-new_size:,} bytes）')
