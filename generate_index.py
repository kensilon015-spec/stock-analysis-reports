# -*- coding: utf-8 -*-
"""
天機閣 GitHub Pages 首頁自動生成器
用法：python generate_index.py
功能：掃描 天機錄/ 資料夾，自動生成 index.html 的報告清單
"""
import os, re
from datetime import datetime

BASE = os.path.dirname(os.path.abspath(__file__))
TIANJI_DIR = os.path.join(BASE, '天機錄')

def get_tag(filename):
    """根據檔名判斷標籤類型和顏色"""
    fn = filename.lower()
    if '向量版' in filename or '演算版' in filename:
        return '向量版', 'background:#5a7d60'
    elif '完整版' in filename:
        return '完整版', ''
    elif '推演版' in filename or '推衍版' in filename:
        return '推演版', ''
    else:
        return '報告', ''

def get_display_name(filename):
    """生成顯示名稱（去掉 .html）"""
    name = filename.replace('.html', '')
    return name

def scan_folders():
    """掃描天機錄資料夾，回傳排序後的資料夾清單"""
    folders = []
    if not os.path.exists(TIANJI_DIR):
        return folders

    # 不公開資料夾不推送、不顯示
    SKIP_FOLDERS = {'不公開', '3213_茂訊'}

    for folder_name in sorted(os.listdir(TIANJI_DIR)):
        if folder_name in SKIP_FOLDERS:
            continue
        folder_path = os.path.join(TIANJI_DIR, folder_name)
        if not os.path.isdir(folder_path):
            continue

        files = []
        for f in os.listdir(folder_path):
            if f.endswith('.html'):
                fpath = os.path.join(folder_path, f)
                mtime = os.path.getmtime(fpath)
                mtime_str = datetime.fromtimestamp(mtime).strftime('%Y-%m-%d %H:%M')
                tag_name, tag_style = get_tag(f)
                files.append({
                    'name': f,
                    'display': get_display_name(f),
                    'href': f'天機錄/{folder_name}/{f}',
                    'tag': tag_name,
                    'tag_style': tag_style,
                    'mtime': mtime,
                    'mtime_str': mtime_str,
                })

        # 排序：完整版優先 → 推演版 → 其他，同優先級按步驟順序
        def sort_key(x):
            name = x['name']
            if '完整版' in name: priority = 0
            elif '推演版' in name: priority = 1
            elif '向量' in name or '演算' in name: priority = 2
            else: priority = 3
            # 同優先級內按檔名排序（第七步 < 第八步）
            return (priority, name)
        files.sort(key=sort_key)

        if files:
            latest_time = max(f['mtime_str'] for f in files)
            folders.append({
                'name': folder_name,
                'files': files,
                'count': len(files),
                'latest_time': latest_time,
            })

    # 資料夾按最新修改時間降序
    folders.sort(key=lambda x: x['latest_time'], reverse=True)
    return folders

def generate_folder_html(folders):
    """生成資料夾樹 HTML"""
    total_files = sum(f['count'] for f in folders)
    html_parts = []

    for folder in folders:
        rows = []
        for f in folder['files']:
            style_attr = f' style="{f["tag_style"]}"' if f['tag_style'] else ''
            rows.append(
                f'<a class="row" href="{f["href"]}">'
                f'<span class="tag"{style_attr}>{f["tag"]}</span>'
                f'<span class="row-title">{f["display"]}</span>'
                f'<span class="row-time">{f["mtime_str"]}</span>'
                f'</a>'
            )

        html_parts.append(
            f'<details class="folder">\n'
            f'<summary><span class="folder-name">{folder["name"]}</span>'
            f'<span class="folder-count">{folder["count"]} 份</span>'
            f'<span class="folder-time">{folder["latest_time"]}</span></summary>\n'
            f'<div class="folder-body">\n'
            + '\n'.join(rows) + '\n'
            f'</div>\n'
            f'</details>'
        )

    return total_files, '\n'.join(html_parts)

def scan_daily_reports():
    """掃描天機日報資料夾，回傳日報清單（從 index.json 讀取）"""
    daily_dir = os.path.join(BASE, '天機日報')
    index_path = os.path.join(daily_dir, 'index.json')
    reports = []

    if os.path.exists(index_path):
        import json
        with open(index_path, 'r', encoding='utf-8') as f:
            reports = json.load(f)
    elif os.path.exists(daily_dir):
        # 沒有 index.json 就掃描 .html 檔案
        for fname in sorted(os.listdir(daily_dir), reverse=True):
            if fname.endswith('.html') and fname != 'index.html':
                fpath = os.path.join(daily_dir, fname)
                mtime = os.path.getmtime(fpath)
                size = os.path.getsize(fpath)
                date_match = re.search(r'(\d{4}-\d{2}-\d{2})', fname)
                reports.append({
                    'date': date_match.group(1) if date_match else datetime.fromtimestamp(mtime).strftime('%Y-%m-%d'),
                    'file': fname,
                    'title': fname.replace('.html', ''),
                    'size': f'{size/1024:.1f} KB' if size < 1048576 else f'{size/1048576:.1f} MB',
                })

    return reports

def generate_daily_html(reports):
    """生成天機日報區塊 HTML"""
    if not reports:
        return ''

    rows = []
    for r in reports:
        alerts = r.get('alerts', '')
        alerts_badge = f'<span style="background:#b8960c;color:#fff;padding:1px 6px;border-radius:4px;font-size:.65em;font-weight:700;margin-left:6px">{alerts} 則警報</span>' if alerts else ''
        rows.append(
            f'<a class="row" href="天機日報/{r["file"]}">'
            f'<span class="tag" style="background:#5a7d8c">日報</span>'
            f'<span class="row-title">{r.get("title", r["file"].replace(".html",""))}{alerts_badge}</span>'
            f'<span class="row-time">{r["date"]}　{r.get("size","")}</span>'
            f'</a>'
        )

    html = (
        f'<div class="section-head">\n'
        f'    <h2>天機日報</h2>\n'
        f'    <span class="badge">{len(reports)}</span>\n'
        f'</div>\n'
        f'<div class="root-files">\n'
        + '\n'.join(rows) + '\n'
        f'</div>'
    )
    return html

def generate_index():
    """生成完整 index.html"""
    folders = scan_folders()
    total_files, folder_html = generate_folder_html(folders)
    daily_reports = scan_daily_reports()
    daily_html = generate_daily_html(daily_reports)

    # 讀取現有 index.html 的覆蓋率區塊（保留不動）
    existing_path = os.path.join(BASE, 'index.html')
    coverage_html = ''
    footer_html = ''
    if os.path.exists(existing_path):
        with open(existing_path, 'r', encoding='utf-8') as f:
            existing = f.read()
        # 提取覆蓋率區塊
        cov_start = existing.find('<div class="section-head">\n    <h2>分析覆蓋率</h2>')
        if cov_start < 0:
            cov_start = existing.find('分析覆蓋率')
            if cov_start > 0:
                cov_start = existing.rfind('<div class="section-head">', 0, cov_start)
        footer_start = existing.find('<div class="footer">')

        if cov_start > 0 and footer_start > 0:
            coverage_html = existing[cov_start:footer_start]
        elif cov_start > 0:
            coverage_html = existing[cov_start:existing.rfind('</div>')]

        if footer_start > 0:
            end = existing.find('</div>', footer_start) + 6
            footer_html = existing[footer_start:end]

    if not footer_html:
        footer_html = f'<div class="footer">天機閣 — 自動生成於 {datetime.now().strftime("%Y-%m-%d %H:%M")}</div>'

    # CSS（從現有模板）
    css = """*{margin:0;padding:0;box-sizing:border-box}
:root{--bg:#d6d0c8;--panel:#e6e1da;--border:#b8b0a5;--txt:#2c2a26;--txt2:#4a453e;--txt3:#7a7268;--accent:#5a7d60;--base:#3d3a36;--link:#5a7d8c}
body{font-family:'Inter','Noto Sans TC',sans-serif;background:var(--bg);color:var(--txt);line-height:1.6;padding:0}
.wrap{max-width:720px;margin:0 auto;padding:24px 20px}
.hero{text-align:center;padding:20px 16px 16px;margin-bottom:16px;border-bottom:1.5px solid var(--border)}
.hero h1{font-size:1.6em;font-weight:900;color:var(--base)}
.hero .sub{font-size:.85em;color:var(--accent);font-weight:600;margin-top:2px}
.section-head{display:flex;align-items:center;gap:8px;margin:12px 0 8px;padding-top:12px;border-top:1.5px solid var(--border)}
.section-head h2{font-size:1.1em;font-weight:800;color:var(--base)}
.badge{background:var(--accent);color:#fff;font-size:.7em;font-weight:700;padding:1px 7px;border-radius:8px}
details.folder{margin:6px 0;background:var(--panel);border:1px solid var(--border);border-radius:10px;overflow:hidden}
details.folder[open]{border-color:var(--accent)}
details.folder>summary{padding:12px 16px;cursor:pointer;list-style:none;display:flex;align-items:center;gap:10px;font-weight:700;color:var(--base);user-select:none;transition:background .12s}
details.folder>summary:hover{background:rgba(90,125,96,.06)}
details.folder>summary::-webkit-details-marker{display:none}
details.folder>summary::before{content:'\\1f4c1';font-size:1.1em}
details.folder[open]>summary::before{content:'\\1f4c2'}
details.folder>summary .folder-name{flex:1;font-size:.95em}
details.folder>summary .folder-count{font-size:.7em;color:var(--txt3);background:var(--border);padding:1px 8px;border-radius:10px}
details.folder>summary .folder-time{font-size:.72em;color:var(--txt3)}
details.folder>summary::after{content:'\\25b6';font-size:.6em;color:var(--txt3);transition:transform .2s}
details.folder[open]>summary::after{transform:rotate(90deg)}
details.folder>.folder-body{padding:2px 10px 10px}
.row{display:flex;align-items:center;gap:10px;padding:9px 14px;margin:3px 0;background:rgba(255,255,255,.45);border:1px solid var(--border);border-radius:8px;text-decoration:none;color:var(--txt);transition:transform .12s,box-shadow .12s}
.row:hover{transform:translateY(-1px);box-shadow:0 2px 8px rgba(0,0,0,.07);background:rgba(255,255,255,.7)}
.tag{flex-shrink:0;padding:2px 8px;border-radius:4px;font-size:.7em;font-weight:700;color:#fff;background:var(--accent)}
.row-title{flex:1;font-size:.85em;font-weight:600;color:var(--base);overflow:hidden;text-overflow:ellipsis;white-space:nowrap}
.row-time{flex-shrink:0;font-size:.72em;color:var(--txt3)}
.root-files{margin:6px 0}
.footer{text-align:center;padding:16px;color:var(--txt3);font-size:.75em;border-top:1.5px solid var(--border);margin-top:20px}
.toggle-btns{display:flex;gap:6px;margin:8px 0 4px}
.toggle-btns button{padding:3px 12px;border:1px solid var(--border);border-radius:6px;background:var(--panel);font-size:.75em;font-weight:600;color:var(--txt2);cursor:pointer;transition:all .15s;font-family:inherit}
.toggle-btns button:hover{background:var(--border);color:var(--base)}
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
.bonus-tag{font-size:.65em;padding:1px 6px;border-radius:3px;background:var(--link);color:#fff;font-weight:600}"""

    html = f"""<!DOCTYPE html>
<html lang="zh-TW">
<head>
<meta charset="UTF-8"><meta name="viewport" content="width=device-width,initial-scale=1.0">
<title>天機閣 — 天機錄</title>
<link href="https://fonts.googleapis.com/css2?family=Inter:wght@400;500;600;700;900&family=Noto+Sans+TC:wght@300;400;500;700&display=swap" rel="stylesheet">
<style>
{css}
</style>
</head>
<body>
<div class="wrap">
<div class="hero">
    <h1>天機閣</h1>
    <div class="sub">推衍系統 / 情報中心 / 投資分析</div>
    <div style="display:flex;gap:8px;justify-content:center;flex-wrap:wrap;margin-top:10px">
    <a href="天機閣服務介紹.html" style="display:inline-block;padding:6px 18px;background:#5a7d60;color:#fff;border-radius:8px;font-size:.82em;font-weight:600;text-decoration:none;transition:opacity .15s" onmouseover="this.style.opacity='.85'" onmouseout="this.style.opacity='1'">核心服務介紹</a>
    <a href="天機閣演講稿.html" style="display:inline-block;padding:6px 18px;background:#5a7d8c;color:#fff;border-radius:8px;font-size:.82em;font-weight:600;text-decoration:none;transition:opacity .15s" onmouseover="this.style.opacity='.85'" onmouseout="this.style.opacity='1'">演講稿</a>
    <a href="天機閣簡報.html" style="display:inline-block;padding:6px 18px;background:#7d5a6e;color:#fff;border-radius:8px;font-size:.82em;font-weight:600;text-decoration:none;transition:opacity .15s" onmouseover="this.style.opacity='.85'" onmouseout="this.style.opacity='1'">簡報</a>
    <a href="天機閣更新日誌.html" style="display:inline-block;padding:6px 18px;background:#3d3a36;color:#e0dcd4;border-radius:8px;font-size:.82em;font-weight:600;text-decoration:none;transition:opacity .15s" onmouseover="this.style.opacity='.85'" onmouseout="this.style.opacity='1'">更新日誌</a>
    </div>
</div>
<div class="section-head">
    <h2>天機錄</h2>
    <span class="badge">{total_files}</span>
</div>
<div class="toggle-btns">
    <button onclick="document.querySelectorAll('details.folder').forEach(d=>d.open=true)">全部展開</button>
    <button onclick="document.querySelectorAll('details.folder').forEach(d=>d.open=false)">全部收合</button>
</div>
<div id="folder-tree">
{folder_html}
</div>
{daily_html}
{coverage_html}
{footer_html}
</div>
</body>
</html>"""

    output_path = os.path.join(BASE, 'index.html')
    with open(output_path, 'w', encoding='utf-8') as f:
        f.write(html)

    print(f'index.html 已生成')
    print(f'  資料夾數：{len(folders)}')
    print(f'  報告總數：{total_files}')
    print(f'  檔案大小：{len(html.encode("utf-8")):,} bytes')
    for folder in folders:
        print(f'  {folder["name"]}：{folder["count"]} 份（最新 {folder["latest_time"]}）')

def git_push():
    """自動 git add + commit + push"""
    import subprocess
    os.chdir(BASE)
    subprocess.run(['git', 'add', '-A'], check=True)
    # 檢查是否有變更
    result = subprocess.run(['git', 'diff', '--cached', '--quiet'])
    if result.returncode == 0:
        print('沒有變更，不需要推送')
        return
    msg = f'自動更新首頁（{datetime.now().strftime("%Y-%m-%d %H:%M")}）'
    subprocess.run(['git', 'commit', '-m', msg], check=True)
    subprocess.run(['git', 'push', 'origin', 'master'], check=True)
    print('Git 推送完成！')

if __name__ == '__main__':
    generate_index()
    git_push()
