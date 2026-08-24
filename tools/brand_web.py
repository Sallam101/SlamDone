from pathlib import Path
import json
import re
import shutil

root = Path(__file__).resolve().parents[1]
web = root / 'web'
web.mkdir(parents=True, exist_ok=True)

approved_icon = root / 'assets' / 'branding' / 'slamdone_app_icon.png'
approved_icon_192 = root / 'assets' / 'branding' / 'slamdone_app_icon_192.png'
icons_dir = web / 'icons'
icons_dir.mkdir(parents=True, exist_ok=True)
if approved_icon.exists():
    shutil.copyfile(approved_icon, web / 'favicon.png')
    shutil.copyfile(approved_icon, icons_dir / 'Icon-512.png')
    shutil.copyfile(approved_icon, icons_dir / 'Icon-maskable-512.png')
if approved_icon_192.exists():
    shutil.copyfile(approved_icon_192, icons_dir / 'Icon-192.png')
    shutil.copyfile(approved_icon_192, icons_dir / 'Icon-maskable-192.png')

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
try:
    data = json.loads(manifest_path.read_text(encoding='utf-8')) if manifest_path.exists() else {}
except (json.JSONDecodeError, OSError):
    data = {}
data.update({
    'name': 'SlamDone',
    'short_name': 'SlamDone',
    'description': 'SlamDone — STOP PLANNING. START FINISHING.',
    'display': 'standalone',
    'start_url': '.',
    'scope': '.',
    'background_color': '#090D12',
    'theme_color': '#78D12F',
    'icons': [
        {'src': 'icons/Icon-192.png?v=7145', 'sizes': '192x192', 'type': 'image/png', 'purpose': 'any'},
        {'src': 'icons/Icon-512.png?v=7145', 'sizes': '512x512', 'type': 'image/png', 'purpose': 'any'},
        {'src': 'icons/Icon-maskable-192.png?v=7145', 'sizes': '192x192', 'type': 'image/png', 'purpose': 'maskable'},
        {'src': 'icons/Icon-maskable-512.png?v=7145', 'sizes': '512x512', 'type': 'image/png', 'purpose': 'maskable'},
    ],
})
manifest_path.write_text(json.dumps(data, indent=2), encoding='utf-8')

# V7.11 Desktop Pin. This bridge is injected into the Flutter-created web
# shell so Dart can feature-detect Document Picture-in-Picture without making
# browser-only APIs reachable from VM tests or non-web targets.
desktop_timer_bridge = r'''<script id="slamdone-desktop-timer-bridge">
(() => {
  'use strict';

  const themes = [
    { name: 'SlamDone green', accent: '#78D12F', background: null, foreground: null },
    { name: 'Blue', accent: '#2457D6', background: null, foreground: null },
    { name: 'Teal', accent: '#00897B', background: null, foreground: null },
    { name: 'Purple', accent: '#7B1FA2', background: null, foreground: null },
    { name: 'Red', accent: '#C62828', background: null, foreground: null },
    { name: 'Orange', accent: '#EF6C00', background: null, foreground: null },
    { name: 'Slate', accent: '#455A64', background: null, foreground: null },
    { name: 'Berry', accent: '#AD1457', background: null, foreground: null },
    { name: 'White', accent: '#2E7D32', background: '#FFFDFC', foreground: '#182019' },
    { name: 'Soft gray', accent: '#455A64', background: '#F2F4F7', foreground: '#182019' },
    { name: 'Cream', accent: '#8D6E00', background: '#FFF4D6', foreground: '#2A2516' },
    { name: 'Mint', accent: '#2E7D32', background: '#E8F7EE', foreground: '#182019' },
    { name: 'Ice blue', accent: '#1565C0', background: '#E9F4FF', foreground: '#162331' },
    { name: 'Lavender', accent: '#6A1B9A', background: '#F2ECFF', foreground: '#241A2A' },
    { name: 'Blush', accent: '#AD1457', background: '#FFECEF', foreground: '#2A191D' },
    { name: 'Pale yellow', accent: '#7A6100', background: '#FFF8CC', foreground: '#282310' },
  ];
  let pipWindow = null;
  let snapshot = {};
  let ticker = null;
  let audio = null;
  let lastChimeToken = '';
  let deadlineRequestedForToken = '';

  const clamp = (value, min, max) => Math.min(max, Math.max(min, Number(value) || min));
  const action = (name) => {
    try {
      if (typeof window.slamDoneTimerPipAction === 'function') {
        window.slamDoneTimerPipAction(String(name));
      }
    } catch (error) {
      console.warn('SlamDone desktop timer action failed', error);
    }
  };

  const supports = () =>
    'documentPictureInPicture' in window &&
    window.documentPictureInPicture &&
    typeof window.documentPictureInPicture.requestWindow === 'function';

  const isOpen = () => Boolean(pipWindow && !pipWindow.closed);

  const decode = (value) => {
    if (!value) return {};
    if (typeof value === 'string') {
      try { return JSON.parse(value); } catch (_) { return {}; }
    }
    return value;
  };

  const chimeUrl = () => new URL('assets/assets/audio/soft_chime.wav', document.baseURI).href;

  const ensureAudio = () => {
    if (!audio) {
      audio = new Audio(chimeUrl());
      audio.preload = 'auto';
      audio.volume = 0.48;
    }
    return audio;
  };

  const primeChime = () => {
    try {
      const player = ensureAudio();
      player.muted = true;
      const promise = player.play();
      if (promise && typeof promise.then === 'function') {
        promise.then(() => {
          player.pause();
          player.currentTime = 0;
          player.muted = false;
        }).catch(() => {
          player.muted = false;
        });
      } else {
        player.pause();
        player.currentTime = 0;
        player.muted = false;
      }
    } catch (_) {}
  };

  const playChime = (completionToken) => {
    const token = String(completionToken || 'timer-complete');
    if (lastChimeToken === token) return;
    lastChimeToken = token;
    try {
      const player = ensureAudio();
      player.muted = false;
      player.currentTime = 0;
      const promise = player.play();
      if (promise && typeof promise.catch === 'function') promise.catch(() => {});
    } catch (_) {}
  };

  const formatSeconds = (seconds) => {
    const safe = Math.max(0, Math.floor(Number(seconds) || 0));
    const hours = Math.floor(safe / 3600);
    const minutes = Math.floor((safe % 3600) / 60);
    const secs = safe % 60;
    if (hours > 0) {
      return `${String(hours).padStart(2, '0')}:${String(minutes).padStart(2, '0')}:${String(secs).padStart(2, '0')}`;
    }
    return `${String(minutes).padStart(2, '0')}:${String(secs).padStart(2, '0')}`;
  };

  const liveSeconds = () => {
    const now = Date.now();
    if (snapshot.mode === 'stopwatch') {
      let elapsed = Math.max(0, Number(snapshot.elapsedSeconds) || 0);
      if (snapshot.running && !snapshot.paused && snapshot.startedAtMs) {
        elapsed += Math.max(0, Math.floor((now - Number(snapshot.startedAtMs)) / 1000));
      }
      return elapsed;
    }
    if (snapshot.running && !snapshot.paused && snapshot.endAtMs) {
      return Math.max(0, Math.ceil((Number(snapshot.endAtMs) - now) / 1000));
    }
    return Math.max(0, Number(snapshot.remainingSeconds) || 0);
  };

  const setRootOpacity = () => {
    if (!isOpen()) return;
    const root = pipWindow.document.getElementById('sd-timer-root');
    if (root) root.style.opacity = String(clamp(snapshot.opacity ?? 1, 0.25, 1));
  };

  const render = () => {
    if (!isOpen()) return;
    const doc = pipWindow.document;
    const seconds = liveSeconds();
    const duration = Math.max(1, Number(snapshot.durationSeconds) || 1);
    const progress = snapshot.mode === 'stopwatch'
      ? ((seconds % 60) / 60)
      : clamp((duration - seconds) / duration, 0, 1);
    const theme = themes[Math.max(0, Math.min(themes.length - 1, Number(snapshot.colorIndex) || 0))];
    const accent = theme.accent;
    const root = doc.getElementById('sd-timer-root');
    const title = doc.getElementById('sd-title');
    const time = doc.getElementById('sd-time');
    const mode = doc.getElementById('sd-mode');
    const dial = doc.getElementById('sd-dial');
    const toggle = doc.getElementById('sd-toggle');
    if (!root || !title || !time || !mode || !dial || !toggle) return;

    root.style.setProperty('--accent', accent);
    root.style.setProperty('--timer-bg', theme.background || 'Canvas');
    root.style.setProperty('--timer-fg', theme.foreground || 'CanvasText');
    root.style.opacity = String(clamp(snapshot.opacity ?? 1, 0.25, 1));
    title.textContent = String(snapshot.title || 'General focus');
    time.textContent = formatSeconds(seconds);
    mode.textContent = String(snapshot.mode || 'general').toUpperCase();
    dial.style.setProperty('--progress-angle', `${Math.max(0, Math.min(360, progress * 360))}deg`);
    toggle.textContent = !snapshot.running && !snapshot.paused ? '▶ Start' : (snapshot.paused ? '▶ Resume' : 'Ⅱ Pause');

    if (snapshot.mode !== 'stopwatch' && snapshot.running && !snapshot.paused && seconds <= 0) {
      const token = String(snapshot.completionToken || 'timer-complete');
      playChime(token);
      if (deadlineRequestedForToken !== token) {
        deadlineRequestedForToken = token;
        action('deadline');
      }
    }
  };

  const buildPipDocument = () => {
    if (!isOpen()) return;
    const doc = pipWindow.document;
    doc.title = 'SlamDone Timer';
    doc.head.innerHTML = `<meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1">
      <style>
        :root { color-scheme: light dark; }
        * { box-sizing: border-box; }
        html, body { margin: 0; width: 100%; height: 100%; overflow: hidden; background: transparent; font-family: system-ui, -apple-system, Segoe UI, sans-serif; }
        button, input { font: inherit; }
        #sd-timer-root { --accent: #78D12F; --timer-bg: Canvas; --timer-fg: CanvasText; width: 100%; height: 100%; min-width: 156px; min-height: 150px; display: grid; grid-template-rows: 32px 1fr; overflow: hidden; border-radius: 14px; background: color-mix(in srgb, var(--timer-bg) 94%, var(--accent) 6%); color: var(--timer-fg); border: 1px solid color-mix(in srgb, var(--accent) 30%, transparent); transition: opacity 120ms ease; }
        .header { min-width: 0; display: flex; align-items: center; gap: 2px; padding: 2px 3px 2px 9px; background: color-mix(in srgb, var(--accent) 10%, transparent); }
        #sd-title { min-width: 0; flex: 1; overflow: hidden; white-space: nowrap; text-overflow: ellipsis; font-size: 12px; font-weight: 800; }
        .icon { width: 27px; height: 27px; padding: 0; border: 0; border-radius: 7px; background: transparent; color: inherit; cursor: pointer; }
        .icon:hover { background: color-mix(in srgb, var(--accent) 17%, transparent); }
        .body { min-height: 0; position: relative; display: grid; grid-template-rows: 1fr 34px; padding: 7px 8px 8px; }
        .clock-wrap { min-height: 0; display: grid; place-items: center; }
        #sd-dial { --progress-angle: 0deg; width: min(76%, 190px); aspect-ratio: 1; border-radius: 50%; padding: clamp(6px, 4%, 11px); background: conic-gradient(from -90deg, var(--accent) var(--progress-angle), color-mix(in srgb, var(--accent) 16%, transparent) 0); box-shadow: inset 0 0 0 1px color-mix(in srgb, var(--accent) 18%, transparent); }
        .dial-inner { width: 100%; height: 100%; border-radius: 50%; display: grid; place-content: center; text-align: center; background: var(--timer-bg); color: var(--timer-fg); border: 1px solid color-mix(in srgb, var(--accent) 12%, transparent); }
        #sd-time { font-size: clamp(24px, 14vw, 44px); line-height: .95; font-weight: 900; font-variant-numeric: tabular-nums; letter-spacing: -1px; }
        #sd-mode { margin-top: 5px; color: var(--accent); font-size: 9px; font-weight: 900; letter-spacing: .8px; }
        .controls { min-width: 0; display: flex; align-items: center; justify-content: center; gap: 3px; }
        .action { height: 29px; min-width: 30px; padding: 0 7px; border-radius: 8px; border: 1px solid color-mix(in srgb, var(--accent) 28%, transparent); background: transparent; color: inherit; cursor: pointer; font-size: 11px; font-weight: 700; white-space: nowrap; }
        .action.primary { background: var(--accent); color: white; border-color: var(--accent); }
        .popover { position: absolute; z-index: 5; top: 3px; left: 7px; right: 7px; min-height: 38px; padding: 5px 8px; border-radius: 10px; background: color-mix(in srgb, var(--timer-bg) 94%, var(--accent) 6%); color: var(--timer-fg); border: 1px solid color-mix(in srgb, var(--accent) 26%, transparent); box-shadow: 0 5px 18px rgba(0,0,0,.18); display: none; align-items: center; gap: 8px; }
        .popover.show { display: flex; }
        #sd-opacity-range { width: 100%; accent-color: var(--accent); }
        #sd-palette { justify-content: center; flex-wrap: wrap; }
        .dot { width: 22px; height: 22px; border: 2px solid rgba(255,255,255,.72); border-radius: 50%; cursor: pointer; padding: 0; }
        @media (max-width: 210px), (max-height: 195px) { .body { padding: 4px 5px 6px; grid-template-rows: 1fr 30px; } #sd-dial { width: min(70%, 125px); } .action { padding: 0 5px; font-size: 0; } }
      </style>`;
    doc.body.innerHTML = `<main id="sd-timer-root">
      <div class="header">
        <div id="sd-title">General focus</div>
        <button class="icon" id="sd-opacity" title="Transparency">◐</button>
        <button class="icon" id="sd-color" title="Timer color">●</button>
        <button class="icon" id="sd-unpin" title="Return timer to SlamDone">📌</button>
        <button class="icon" id="sd-close" title="Close timer">×</button>
      </div>
      <section class="body">
        <div id="sd-opacity-pop" class="popover"><span>◐</span><input id="sd-opacity-range" type="range" min="0.25" max="1" step="0.05" value="1"></div>
        <div id="sd-palette" class="popover"></div>
        <div class="clock-wrap"><div id="sd-dial"><div class="dial-inner"><div id="sd-time">25:00</div><div id="sd-mode">GENERAL</div></div></div></div>
        <div class="controls">
          <button class="action primary" id="sd-toggle">▶ Start</button>
          <button class="action" id="sd-reset">↻ Reset</button>
          <button class="action" id="sd-stop">■ Stop</button>
          <button class="action" id="sd-stopwatch">⏱ SW</button>
        </div>
      </section>
    </main>`;

    const byId = (id) => doc.getElementById(id);
    byId('sd-toggle').addEventListener('click', () => { primeChime(); action('toggle'); });
    byId('sd-reset').addEventListener('click', () => action('reset'));
    byId('sd-stop').addEventListener('click', () => action('stop'));
    byId('sd-stopwatch').addEventListener('click', () => { primeChime(); action('stopwatch'); });
    byId('sd-unpin').addEventListener('click', () => action('unpin'));
    byId('sd-close').addEventListener('click', () => action('close'));

    const opacityPop = byId('sd-opacity-pop');
    const palettePop = byId('sd-palette');
    byId('sd-opacity').addEventListener('click', () => {
      palettePop.classList.remove('show');
      opacityPop.classList.toggle('show');
    });
    const opacityRange = byId('sd-opacity-range');
    opacityRange.value = String(clamp(snapshot.opacity ?? 1, 0.25, 1));
    opacityRange.addEventListener('input', (event) => {
      const value = clamp(event.target.value, 0.25, 1);
      snapshot.opacity = value;
      setRootOpacity();
      action(`opacity:${value.toFixed(2)}`);
    });
    byId('sd-color').addEventListener('click', () => {
      opacityPop.classList.remove('show');
      palettePop.classList.toggle('show');
    });
    themes.forEach((theme, index) => {
      const dot = doc.createElement('button');
      dot.className = 'dot';
      dot.title = theme.name;
      dot.style.background = theme.background || theme.accent;
      dot.style.borderColor = theme.accent;
      dot.addEventListener('click', () => {
        snapshot.colorIndex = index;
        action(`color:${index}`);
        palettePop.classList.remove('show');
        render();
      });
      palettePop.appendChild(dot);
    });
  };

  const update = (snapshotJson) => {
    snapshot = { ...snapshot, ...decode(snapshotJson) };
    if (snapshot.completionToken !== deadlineRequestedForToken && liveSeconds() > 0) {
      deadlineRequestedForToken = '';
    }
    render();
  };

  const close = () => {
    if (ticker) {
      clearInterval(ticker);
      ticker = null;
    }
    if (isOpen()) pipWindow.close();
    pipWindow = null;
  };

  const open = async (snapshotJson) => {
    if (!supports()) return false;
    snapshot = { ...snapshot, ...decode(snapshotJson) };
    if (isOpen()) {
      render();
      pipWindow.focus();
      return true;
    }
    try {
      const width = clamp(snapshot.windowWidth || 218, 156, 760);
      const height = clamp(snapshot.windowHeight || 214, 150, 840);
      const pipRequest = window.documentPictureInPicture.requestWindow({ width, height });
      // requestWindow must consume the Pin click first; chime priming follows
      // without delaying the privileged window request.
      primeChime();
      pipWindow = await pipRequest;
      buildPipDocument();
      render();
      if (ticker) clearInterval(ticker);
      ticker = setInterval(render, 250);
      pipWindow.addEventListener('pagehide', () => {
        if (ticker) {
          clearInterval(ticker);
          ticker = null;
        }
        pipWindow = null;
        try {
          if (typeof window.slamDoneTimerPipClosed === 'function') window.slamDoneTimerPipClosed();
        } catch (_) {}
      }, { once: true });
      return true;
    } catch (error) {
      console.warn('SlamDone Desktop Pin unavailable', error);
      pipWindow = null;
      return false;
    }
  };

  window.slamDoneDesktopTimer = { supports, isOpen, open, update, close, primeChime, playChime };
  window.slamDoneDesktopTimerSupported = supports;
  window.slamDoneDesktopTimerIsOpen = isOpen;
  window.slamDoneDesktopTimerOpen = open;
  window.slamDoneDesktopTimerUpdate = update;
  window.slamDoneDesktopTimerClose = close;
  window.slamDoneDesktopTimerPrimeChime = primeChime;
  window.slamDoneDesktopTimerPlayChime = playChime;
})();
</script>'''

support_link_bridge = r'''<script id="slamdone-support-link-bridge">
(() => {
  'use strict';
  const patreonUrl = 'https://www.patreon.com/Sallam101/posts/buy-sallam-167511433?utm_medium=clipboard_copy&utm_source=copyLink&utm_campaign=postshare_creator&utm_content=join_link';
  window.slamDoneOpenPatreonSupport = () => {
    const opened = window.open(patreonUrl, '_blank', 'noopener,noreferrer');
    if (opened) opened.opener = null;
    return Boolean(opened);
  };
})();
</script>'''

index = web / 'index.html'
if index.exists():
    text = index.read_text(encoding='utf-8')
    for old in (
        '<title>slamdone</title>',
        '<title>Slamdone</title>',
        '<title>SlamDone — Plan • Focus • Finish</title>',
    ):
        text = text.replace(old, '<title>SlamDone — STOP PLANNING. START FINISHING.</title>')
    # Flutter's generated shell changes between SDK releases. Recreate the
    # browser/PWA identity links every build instead of relying on template
    # defaults, and cache-bust icon references so browsers/taskbars refresh.
    text = re.sub(r'\s*<link[^>]+rel=["\'][^"\']*(?:icon|manifest)[^"\']*["\'][^>]*>', '', text, flags=re.IGNORECASE)
    text = re.sub(r'\s*<meta[^>]+name=["\']theme-color["\'][^>]*>', '', text, flags=re.IGNORECASE)
    brand_links = '''
  <link rel="icon" type="image/png" sizes="512x512" href="favicon.png?v=7145">
  <link rel="shortcut icon" type="image/png" href="favicon.png?v=7145">
  <link rel="apple-touch-icon" sizes="192x192" href="icons/Icon-192.png?v=7145">
  <link rel="manifest" href="manifest.json?v=7145">
  <meta name="theme-color" content="#78D12F">
'''
    text = text.replace('</head>', f'{brand_links}</head>')
    if 'name="description"' not in text:
        text = text.replace(
            '</head>',
            '  <meta name="description" content="SlamDone — STOP PLANNING. START FINISHING.">\n</head>',
        )
    else:
        text = re.sub(
            r'<meta name="description" content="[^"]*">',
            '<meta name="description" content="SlamDone — STOP PLANNING. START FINISHING.">',
            text,
        )
    bridges = []
    if 'id="slamdone-desktop-timer-bridge"' not in text:
        bridges.append(desktop_timer_bridge)
    if 'id="slamdone-support-link-bridge"' not in text:
        bridges.append(support_link_bridge)
    if bridges:
        text = text.replace('</body>', f"{'\n'.join(bridges)}\n</body>")
    index.write_text(text, encoding='utf-8')
