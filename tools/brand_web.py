from pathlib import Path
import json

root = Path(__file__).resolve().parents[1]
web = root / 'web'
web.mkdir(parents=True, exist_ok=True)

mark = web / 'slamdone-mark.svg'
mark.write_text('''<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 512 512">
<rect width="512" height="512" rx="118" fill="#090D12"/>
<g stroke-linecap="round">
  <path d="M56 148h92M42 211h116" stroke="#fff" stroke-width="23"/>
  <path d="M65 299h88M84 355h68" stroke="#78D12F" stroke-width="23"/>
</g>
<text x="158" y="307" fill="#fff" font-family="Arial Black,Arial,sans-serif" font-size="264" font-style="italic" font-weight="900">S</text>
<path d="M174 332l68 65 154-165" fill="none" stroke="#78D12F" stroke-width="54" stroke-linecap="square" stroke-linejoin="miter"/>
</svg>''', encoding='utf-8')

manifest_path = web / 'manifest.json'
if manifest_path.exists():
    data = json.loads(manifest_path.read_text(encoding='utf-8'))
    data.update({
        'name': 'SlamDone',
        'short_name': 'SlamDone',
        'description': 'SlamDone — STOP PLANNING. START FINISHING.',
        'display': 'standalone',
        'start_url': '.',
        'background_color': '#090D12',
        'theme_color': '#78D12F',
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
    for old in (
        '<title>slamdone</title>',
        '<title>Slamdone</title>',
        '<title>SlamDone — Plan • Focus • Finish</title>',
    ):
        text = text.replace(old, '<title>SlamDone — STOP PLANNING. START FINISHING.</title>')
    text = text.replace('href="favicon.png"', 'href="slamdone-mark.svg"')
    if 'name="description"' not in text:
        text = text.replace(
            '</head>',
            '  <meta name="description" content="SlamDone — STOP PLANNING. START FINISHING.">\n</head>',
        )
    else:
        import re
        text = re.sub(
            r'<meta name="description" content="[^"]*">',
            '<meta name="description" content="SlamDone — STOP PLANNING. START FINISHING.">',
            text,
        )
    index.write_text(text, encoding='utf-8')
