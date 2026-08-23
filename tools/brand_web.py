from pathlib import Path
import json

root = Path(__file__).resolve().parents[1]
web = root / 'web'
web.mkdir(parents=True, exist_ok=True)

mark = web / 'slamdone-mark.svg'
mark.write_text('''<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 512 512">
<defs><linearGradient id="g" x1="0" y1="0" x2="1" y2="1"><stop stop-color="#6D28D9"/><stop offset="1" stop-color="#DB2777"/></linearGradient></defs>
<rect width="512" height="512" rx="128" fill="url(#g)"/>
<path d="M286 70 142 282h104l-24 160 148-230H264z" fill="#fff"/>
<circle cx="382" cy="378" r="82" fill="#fff"/>
<path d="m340 378 29 29 57-67" fill="none" stroke="#6D28D9" stroke-width="26" stroke-linecap="round" stroke-linejoin="round"/>
</svg>''', encoding='utf-8')

manifest_path = web / 'manifest.json'
if manifest_path.exists():
    data = json.loads(manifest_path.read_text(encoding='utf-8'))
    data.update({
        'name': 'SlamDone',
        'short_name': 'SlamDone',
        'description': 'SlamDone — Plan • Focus • Finish.',
        'display': 'standalone',
        'start_url': '.',
        'background_color': '#101418',
        'theme_color': '#6D28D9',
        'icons': [{
            'src': 'slamdone-mark.svg',
            'sizes': 'any',
            'type': 'image/svg+xml',
            'purpose': 'any maskable',
        }],
    })
    manifest_path.write_text(json.dumps(data, indent=2), encoding='utf-8')

index = web / 'index.html'
if index.exists():
    text = index.read_text(encoding='utf-8')
    text = text.replace('<title>slamdone</title>', '<title>SlamDone — Plan • Focus • Finish</title>')
    text = text.replace('<title>Slamdone</title>', '<title>SlamDone — Plan • Focus • Finish</title>')
    text = text.replace('href="favicon.png"', 'href="slamdone-mark.svg"')
    if 'name="description"' not in text:
        text = text.replace('</head>', '  <meta name="description" content="SlamDone — Plan • Focus • Finish">\n</head>')
    index.write_text(text, encoding='utf-8')
