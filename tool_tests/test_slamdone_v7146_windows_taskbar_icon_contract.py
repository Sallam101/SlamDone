import json
import unittest
from pathlib import Path
import struct

ROOT = Path(__file__).resolve().parents[1]
WEB = ROOT / 'web'
WINDOWS_TARGET_SIZES = [16, 20, 24, 30, 32, 36, 40, 44, 48, 60, 64, 72, 80, 96, 256]
WINDOWS_APP_SIZES = [55, 66, 88, 176]


class V7146WindowsTaskbarIconContractTest(unittest.TestCase):
    def test_manifest_has_stable_slamdone_identity_and_windows_taskbar_icons(self):
        manifest = json.loads((WEB / 'manifest.json').read_text(encoding='utf-8'))
        self.assertEqual(manifest.get('id'), '/SlamDone/')
        icons = {(entry['src'].split('?')[0], entry.get('sizes'), entry.get('purpose')) for entry in manifest['icons']}
        for size in WINDOWS_TARGET_SIZES + WINDOWS_APP_SIZES:
            expected = (f'icons/Icon-{size}.png', f'{size}x{size}', 'any')
            self.assertIn(expected, icons, f'missing manifest icon {expected}')

    def test_windows_taskbar_icon_files_have_exact_dimensions(self):
        for size in WINDOWS_TARGET_SIZES + WINDOWS_APP_SIZES:
            path = WEB / 'icons' / f'Icon-{size}.png'
            self.assertTrue(path.exists(), f'missing {path.name}')
            raw = path.read_bytes()
            self.assertEqual(raw[:8], b'\x89PNG\r\n\x1a\n')
            width, height = struct.unpack('>II', raw[16:24])
            self.assertEqual((width, height), (size, size))

    def test_web_shell_exposes_small_favicons_and_multisize_ico(self):
        index = (WEB / 'index.html').read_text(encoding='utf-8')
        self.assertIn('href="favicon.ico?v=7146"', index)
        self.assertIn('sizes="16x16" href="icons/Icon-16.png?v=7146"', index)
        self.assertIn('sizes="32x32" href="icons/Icon-32.png?v=7146"', index)
        self.assertIn('sizes="48x48" href="icons/Icon-48.png?v=7146"', index)
        self.assertIn('manifest.json?v=7146', index)
        ico_path = WEB / 'favicon.ico'
        self.assertTrue(ico_path.exists())
        raw = ico_path.read_bytes()
        reserved, image_type, count = struct.unpack('<HHH', raw[:6])
        self.assertEqual((reserved, image_type), (0, 1))
        sizes = set()
        for i in range(count):
            entry = raw[6 + i * 16: 6 + (i + 1) * 16]
            width = entry[0] or 256
            height = entry[1] or 256
            sizes.add((width, height))
        for size in [(16, 16), (32, 32), (48, 48), (64, 64), (256, 256)]:
            self.assertIn(size, sizes)

    def test_brand_script_regenerates_windows_icon_set_after_flutter_create(self):
        script = (ROOT / 'tools' / 'brand_web.py').read_text(encoding='utf-8')
        self.assertIn('WINDOWS_TASKBAR_ICON_SIZES', script)
        self.assertIn('favicon.ico', script)
        self.assertTrue("'/SlamDone/'" in script or '"/SlamDone/"' in script)
        self.assertIn('7146', script)


if __name__ == '__main__':
    unittest.main()
