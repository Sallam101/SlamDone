from pathlib import Path
import json

root = Path(__file__).resolve().parents[1]
web = root / 'web'
manifest_path = web / 'manifest.json'
if manifest_path.exists():
    data = json.loads(manifest_path.read_text(encoding='utf-8'))
    data.update({
        'name': 'SupeSlam',
        'short_name': 'SupeSlam',
        'description': 'Your goals, focus, habits, journal, North Star, calendar and progress command center.',
        'display': 'standalone',
        'start_url': '.',
        'background_color': '#101418',
        'theme_color': '#1565C0',
    })
    manifest_path.write_text(json.dumps(data, indent=2), encoding='utf-8')

index = web / 'index.html'
if index.exists():
    text = index.read_text(encoding='utf-8')
    text = text.replace('<title>supeslam</title>', '<title>SupeSlam</title>')
    text = text.replace('<title>Supeslam</title>', '<title>SupeSlam</title>')
    if 'name="description"' not in text:
        text = text.replace('</head>', '  <meta name="description" content="SupeSlam personal command center">\n</head>')
    index.write_text(text, encoding='utf-8')
