from pathlib import Path
import json
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
        'icons': [
            {'src': 'icons/Icon-192.png', 'sizes': '192x192', 'type': 'image/png', 'purpose': 'any'},
            {'src': 'icons/Icon-512.png', 'sizes': '512x512', 'type': 'image/png', 'purpose': 'any'},
            {'src': 'icons/Icon-maskable-192.png', 'sizes': '192x192', 'type': 'image/png', 'purpose': 'maskable'},
            {'src': 'icons/Icon-maskable-512.png', 'sizes': '512x512', 'type': 'image/png', 'purpose': 'maskable'},
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
    { name: 'SlamDone', background: '#10150F', accent: '#78D12F', foreground: '#F7FAF5' },
    { name: 'Royal blue', background: '#0E1830', accent: '#4C7DFF', foreground: '#F7F9FF' },
    { name: 'Teal', background: '#07201D', accent: '#25B8A8', foreground: '#F3FFFC' },
    { name: 'Violet', background: '#211028', accent: '#B968E0', foreground: '#FFF7FF' },
    { name: 'Crimson', background: '#2A0D0D', accent: '#E05252', foreground: '#FFF7F7' },
    { name: 'Amber', background: '#2A1705', accent: '#FF9D3A', foreground: '#FFFAF2' },
    { name: 'Slate', background: '#10181C', accent: '#78909C', foreground: '#F6FAFC' },
    { name: 'Berry', background: '#2A0B19', accent: '#E2558C', foreground: '#FFF6FA' },
    { name: 'White', background: '#FFFFFF', accent: '#65B52B', foreground: '#111827' },
    { name: 'Soft gray', background: '#F2F4F7', accent: '#2457D6', foreground: '#111827' },
    { name: 'Cream', background: '#FFF4DF', accent: '#D97706', foreground: '#3B2A12' },
    { name: 'Mint', background: '#E9FBEF', accent: '#238B45', foreground: '#16351F' },
    { name: 'Ice blue', background: '#EAF5FF', accent: '#2C6ECF', foreground: '#132B45' },
    { name: 'Lavender', background: '#F3ECFF', accent: '#7B45B8', foreground: '#2F2140' },
    { name: 'Blush', background: '#FFF0F4', accent: '#C13A6B', foreground: '#462331' },
    { name: 'Pale yellow', background: '#FFF9D9', accent: '#B7791F', foreground: '#3D3211' },
  ];
  const nativeBase = 'http://127.0.0.1:37110';
  let nativeAvailable = false;
  let nativeActive = false;
  let nativePrepared = false;
  let nativeProbeTimer = null;
  let nativeActionSeq = 0;
  let nativePollGeneration = 0;
  let pipWindow = null;
  let snapshot = {};
  let ticker = null;
  let audio = null;
  let lastChimeToken = '';
  let deadlineRequestedForToken = '';

  const clamp = (value, min, max) => Math.min(max, Math.max(min, Number(value) || min));
  const delay = (ms) => new Promise((resolve) => setTimeout(resolve, ms));
  const decode = (raw) => {
    if (!raw) return {};
    if (typeof raw === 'object') return raw;
    try { return JSON.parse(String(raw)); } catch (_) { return {}; }
  };
  const action = (name) => {
    try {
      if (typeof window.slamDoneTimerPipAction === 'function') window.slamDoneTimerPipAction(String(name));
    } catch (error) {
      console.warn('SlamDone desktop timer action failed', error);
    }
  };

  const loopbackFetch = (path, options = {}) => {
    const init = {
      method: 'GET',
      mode: 'cors',
      cache: 'no-store',
      targetAddressSpace: 'loopback',
      ...options,
    };
    return fetch(new Request(`${nativeBase}${path}`, init));
  };

  const probeNative = async () => {
    try {
      const response = await loopbackFetch('/health');
      nativeAvailable = response.ok;
      return nativeAvailable;
    } catch (_) {
      nativeAvailable = false;
      return false;
    }
  };

  const prepare = () => {
    nativePrepared = true;
    void probeNative();
    if (!nativeProbeTimer) {
      nativeProbeTimer = setInterval(() => { if (nativePrepared && !nativeActive) void probeNative(); }, 8000);
    }
  };

  const nativePost = async (path, payload = {}) => {
    const response = await loopbackFetch(path, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify(payload),
    });
    if (!response.ok) throw new Error(`Native timer ${path} failed: ${response.status}`);
    return response;
  };

  const stopNativePolling = () => { nativePollGeneration += 1; };
  const startNativePolling = () => {
    const generation = ++nativePollGeneration;
    void (async () => {
      while (nativeActive && generation === nativePollGeneration) {
        try {
          const response = await loopbackFetch(`/actions?after=${nativeActionSeq}&wait=12000`);
          if (!response.ok) throw new Error(`Actions failed ${response.status}`);
          const payload = await response.json();
          const actions = Array.isArray(payload.actions) ? payload.actions : [];
          for (const item of actions) {
            const seq = Number(item.seq ?? item.Seq ?? 0);
            const name = String(item.action ?? item.Action ?? '');
            if (seq > nativeActionSeq) nativeActionSeq = seq;
            if (name) action(name);
          }
        } catch (_) {
          if (!nativeActive || generation !== nativePollGeneration) break;
          await delay(650);
          await probeNative();
          if (!nativeAvailable) {
            nativeActive = false;
            break;
          }
        }
      }
    })();
  };

  const supportsPip = () =>
    'documentPictureInPicture' in window &&
    window.documentPictureInPicture &&
    typeof window.documentPictureInPicture.requestWindow === 'function';
  const supports = () => nativeAvailable || supportsPip();
  const isPipOpen = () => !!pipWindow && !pipWindow.closed;
  const isOpen = () => nativeActive || isPipOpen();

  const chimeUrl = () => new URL('assets/assets/audio/soft_chime.wav', document.baseURI).href;
  const primeChime = () => {
    if (nativeActive) return;
    try {
      if (!audio) {
        audio = new Audio(chimeUrl());
        audio.preload = 'auto';
      }
      audio.load();
    } catch (_) {}
  };
  const playWebChime = (token = '') => {
    const key = String(token || 'timer-complete');
    if (key && key === lastChimeToken) return;
    lastChimeToken = key;
    try {
      if (!audio) audio = new Audio(chimeUrl());
      audio.currentTime = 0;
      const promise = audio.play();
      if (promise && typeof promise.catch === 'function') promise.catch(() => {});
    } catch (_) {}
  };
  const playChime = (token = '') => {
    const key = String(token || 'timer-complete');
    if (nativeActive) {
      void nativePost('/chime', { token: key }).catch(() => {});
      return;
    }
    playWebChime(key);
  };

  const formatSeconds = (seconds) => {
    seconds = Math.max(0, Math.floor(Number(seconds) || 0));
    const h = Math.floor(seconds / 3600);
    const m = Math.floor((seconds % 3600) / 60);
    const s = seconds % 60;
    return h > 0 ? `${h}:${String(m).padStart(2, '0')}:${String(s).padStart(2, '0')}` : `${String(m).padStart(2, '0')}:${String(s).padStart(2, '0')}`;
  };
  const liveSeconds = () => {
    const now = Date.now();
    if (snapshot.mode === 'stopwatch') {
      let elapsed = Math.max(0, Number(snapshot.elapsedSeconds) || 0);
      if (snapshot.running && !snapshot.paused && snapshot.startedAtMs) elapsed = Math.max(0, Math.floor((now - Number(snapshot.startedAtMs)) / 1000));
      return elapsed;
    }
    if (snapshot.running && !snapshot.paused && snapshot.endAtMs) return Math.max(0, Math.ceil((Number(snapshot.endAtMs) - now) / 1000));
    return Math.max(0, Number(snapshot.remainingSeconds) || 0);
  };

  const currentTheme = () => themes[Math.max(0, Math.min(themes.length - 1, Number(snapshot.colorIndex) || 0))];
  const setPipFade = () => {
    if (!isPipOpen()) return;
    const root = pipWindow.document.getElementById('sd-timer-root');
    if (root) root.style.opacity = String(clamp(snapshot.opacity ?? 1, 0.20, 1));
  };
  const render = () => {
    if (!isPipOpen()) return;
    const doc = pipWindow.document;
    const seconds = liveSeconds();
    const duration = Math.max(1, Number(snapshot.durationSeconds) || 1);
    const progress = snapshot.mode === 'stopwatch' ? ((seconds % 60) / 60) : clamp((duration - seconds) / duration, 0, 1);
    const theme = currentTheme();
    const root = doc.getElementById('sd-timer-root');
    const title = doc.getElementById('sd-title');
    const time = doc.getElementById('sd-time');
    const mode = doc.getElementById('sd-mode');
    const dial = doc.getElementById('sd-dial');
    const toggle = doc.getElementById('sd-toggle');
    if (!root || !title || !time || !mode || !dial || !toggle) return;

    root.style.setProperty('--accent', theme.accent);
    root.style.setProperty('--timer-bg', theme.background);
    root.style.setProperty('--timer-fg', theme.foreground);
    root.style.opacity = String(clamp(snapshot.opacity ?? 1, 0.20, 1));
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
    if (!isPipOpen()) return;
    const doc = pipWindow.document;
    doc.title = 'SlamDone Timer';
    doc.head.innerHTML = `<meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1">
      <style>
        * { box-sizing: border-box; }
        html, body { margin: 0; width: 100%; height: 100%; overflow: hidden; background: transparent; font-family: system-ui, -apple-system, Segoe UI, sans-serif; }
        button, input { font: inherit; }
        #sd-timer-root { --accent:#78D12F; --timer-bg:#10150F; --timer-fg:#F7FAF5; width:100%; height:100%; min-width:156px; min-height:150px; display:grid; grid-template-rows:32px 1fr; overflow:hidden; border-radius:14px; background:var(--timer-bg); color:var(--timer-fg); border:1px solid color-mix(in srgb,var(--accent) 34%,transparent); transition:opacity 120ms ease,background 120ms ease,color 120ms ease; }
        .header { min-width:0; display:flex; align-items:center; gap:2px; padding:2px 3px 2px 9px; background:color-mix(in srgb,var(--accent) 13%,var(--timer-bg)); }
        #sd-title { min-width:0; flex:1; overflow:hidden; white-space:nowrap; text-overflow:ellipsis; font-size:12px; font-weight:800; }
        .icon { width:27px; height:27px; padding:0; border:0; border-radius:7px; background:transparent; color:inherit; cursor:pointer; }
        .icon:hover { background:color-mix(in srgb,var(--accent) 18%,transparent); }
        .body { min-height:0; position:relative; display:grid; grid-template-rows:1fr 34px; padding:7px 8px 8px; }
        .clock-wrap { min-height:0; display:grid; place-items:center; }
        #sd-dial { --progress-angle:0deg; width:min(76%,190px); aspect-ratio:1; border-radius:50%; padding:clamp(6px,4%,11px); background:conic-gradient(from -90deg,var(--accent) var(--progress-angle),color-mix(in srgb,var(--accent) 16%,transparent) 0); box-shadow:inset 0 0 0 1px color-mix(in srgb,var(--accent) 18%,transparent); }
        .dial-inner { width:100%; height:100%; border-radius:50%; display:grid; place-content:center; text-align:center; background:var(--timer-bg); border:1px solid color-mix(in srgb,var(--accent) 13%,transparent); }
        #sd-time { font-size:clamp(24px,14vw,44px); line-height:.95; font-weight:900; font-variant-numeric:tabular-nums; letter-spacing:-1px; }
        #sd-mode { margin-top:5px; color:var(--accent); font-size:9px; font-weight:900; letter-spacing:.8px; }
        .controls { min-width:0; display:flex; align-items:center; justify-content:center; gap:3px; }
        .action { height:29px; min-width:30px; padding:0 7px; border-radius:8px; border:1px solid color-mix(in srgb,var(--accent) 30%,transparent); background:transparent; color:inherit; cursor:pointer; font-size:11px; font-weight:700; white-space:nowrap; }
        .action.primary { background:var(--accent); color:white; border-color:var(--accent); }
        .popover { position:absolute; z-index:5; top:3px; left:7px; right:7px; min-height:38px; padding:5px 8px; border-radius:10px; background:var(--timer-bg); color:var(--timer-fg); border:1px solid color-mix(in srgb,var(--accent) 30%,transparent); box-shadow:0 5px 18px rgba(0,0,0,.18); display:none; align-items:center; gap:8px; }
        .popover.show { display:flex; }
        #sd-opacity-range { width:100%; accent-color:var(--accent); }
        #sd-palette { justify-content:center; flex-wrap:wrap; }
        .dot { width:22px; height:22px; border:2px solid var(--timer-fg); border-radius:50%; cursor:pointer; padding:0; }
        @media (max-width:210px),(max-height:195px) { .body{padding:4px 5px 6px;grid-template-rows:1fr 30px} #sd-dial{width:min(70%,125px)} .action{padding:0 5px;font-size:0} }
      </style>`;
    doc.body.innerHTML = `<main id="sd-timer-root">
      <div class="header">
        <div id="sd-title">General focus</div>
        <button class="icon" id="sd-opacity" title="Fade browser fallback">◐</button>
        <button class="icon" id="sd-color" title="Timer themes">●</button>
        <button class="icon" id="sd-unpin" title="Return timer to SlamDone">📌</button>
      </div>
      <section class="body">
        <div id="sd-opacity-pop" class="popover"><span>◐</span><input id="sd-opacity-range" type="range" min="0.20" max="1" step="0.05" value="1"></div>
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

    const opacityPop = byId('sd-opacity-pop');
    const palettePop = byId('sd-palette');
    byId('sd-opacity').addEventListener('click', () => {
      palettePop.classList.remove('show');
      opacityPop.classList.toggle('show');
    });
    const opacityRange = byId('sd-opacity-range');
    opacityRange.value = String(clamp(snapshot.opacity ?? 1, 0.20, 1));
    opacityRange.addEventListener('input', (event) => {
      const value = clamp(event.target.value, 0.20, 1);
      snapshot.opacity = value;
      setPipFade();
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
      dot.style.background = theme.background;
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
    if (snapshot.completionToken !== deadlineRequestedForToken && liveSeconds() > 0) deadlineRequestedForToken = '';
    if (nativeActive) {
      void nativePost('/state', snapshot).catch(() => {
        nativeActive = false;
        stopNativePolling();
        void probeNative();
      });
      return;
    }
    render();
  };

  const close = () => {
    if (nativeActive) {
      void nativePost('/hide', {}).catch(() => {});
      nativeActive = false;
      stopNativePolling();
    }
    if (ticker) { clearInterval(ticker); ticker = null; }
    if (isPipOpen()) pipWindow.close();
    pipWindow = null;
  };

  const openPip = async () => {
    if (!supportsPip()) return false;
    try {
      const width = clamp(snapshot.windowWidth || 218, 156, 760);
      const height = clamp(snapshot.windowHeight || 214, 150, 840);
      const pipRequest = window.documentPictureInPicture.requestWindow({ width, height });
      primeChime();
      pipWindow = await pipRequest;
      buildPipDocument();
      render();
      if (ticker) clearInterval(ticker);
      ticker = setInterval(render, 250);
      pipWindow.addEventListener('pagehide', () => {
        if (ticker) { clearInterval(ticker); ticker = null; }
        pipWindow = null;
        try { if (typeof window.slamDoneTimerPipClosed === 'function') window.slamDoneTimerPipClosed(); } catch (_) {}
      }, { once: true });
      return true;
    } catch (error) {
      console.warn('SlamDone browser Desktop Pin unavailable', error);
      pipWindow = null;
      return false;
    }
  };

  const open = async (snapshotJson) => {
    snapshot = { ...snapshot, ...decode(snapshotJson) };
    if (nativeAvailable) {
      try {
        await nativePost('/state', snapshot);
        nativeActive = true;
        startNativePolling();
        return true;
      } catch (error) {
        console.warn('SlamDone native timer companion unavailable', error);
        nativeAvailable = false;
        nativeActive = false;
        return false;
      }
    }
    return openPip();
  };

  window.addEventListener('focus', () => { if (nativePrepared) void probeNative(); });
  document.addEventListener('visibilitychange', () => { if (!document.hidden && nativePrepared) void probeNative(); });

  window.slamDoneDesktopTimer = { supports, isOpen, prepare, open, update, close, primeChime, playChime };
  window.slamDoneDesktopTimerSupported = supports;
  window.slamDoneDesktopTimerIsOpen = isOpen;
  window.slamDoneDesktopTimerPrepare = prepare;
  window.slamDoneDesktopTimerOpen = open;
  window.slamDoneDesktopTimerUpdate = update;
  window.slamDoneDesktopTimerClose = close;
  window.slamDoneDesktopTimerPrimeChime = primeChime;
  window.slamDoneDesktopTimerPlayChime = playChime;
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
    text = text.replace('href="favicon.png"', 'href="favicon.png"')
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
    if 'id="slamdone-desktop-timer-bridge"' not in text:
        text = text.replace('</body>', f'{desktop_timer_bridge}\n</body>')
    index.write_text(text, encoding='utf-8')
