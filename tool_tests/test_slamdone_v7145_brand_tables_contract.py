from pathlib import Path
import json
import shutil
import subprocess
import tempfile
import unittest

ROOT = Path(__file__).resolve().parents[1]


class SlamDoneV7145BrandTablesContractTest(unittest.TestCase):
    def read(self, rel: str) -> str:
        return (ROOT / rel).read_text(encoding='utf-8')

    def test_brand_web_restores_browser_and_installed_pwa_icons_after_flutter_create(self):
        with tempfile.TemporaryDirectory() as td:
            temp = Path(td)
            (temp / 'tools').mkdir()
            (temp / 'assets' / 'branding' / 'windows').mkdir(parents=True)
            (temp / 'web').mkdir()
            shutil.copy2(ROOT / 'tools' / 'brand_web.py', temp / 'tools' / 'brand_web.py')
            shutil.copy2(ROOT / 'assets' / 'branding' / 'slamdone_app_icon.png', temp / 'assets' / 'branding' / 'slamdone_app_icon.png')
            shutil.copy2(ROOT / 'assets' / 'branding' / 'slamdone_app_icon_192.png', temp / 'assets' / 'branding' / 'slamdone_app_icon_192.png')
            for source in (ROOT / 'assets' / 'branding' / 'windows').iterdir():
                if source.is_file():
                    shutil.copy2(source, temp / 'assets' / 'branding' / 'windows' / source.name)
            (temp / 'web' / 'index.html').write_text(
                '<!doctype html><html><head><base href="$FLUTTER_BASE_HREF"><title>slamdone</title></head>'
                '<body><script src="flutter_bootstrap.js" async></script></body></html>',
                encoding='utf-8',
            )
            (temp / 'web' / 'manifest.json').write_text(
                json.dumps({'name': 'slamdone', 'icons': []}), encoding='utf-8'
            )
            subprocess.run(['python3', str(temp / 'tools' / 'brand_web.py')], check=True)
            index = (temp / 'web' / 'index.html').read_text(encoding='utf-8')
            manifest = json.loads((temp / 'web' / 'manifest.json').read_text(encoding='utf-8'))
            self.assertIn('rel="icon"', index)
            self.assertIn('rel="shortcut icon"', index)
            self.assertIn('rel="apple-touch-icon"', index)
            self.assertIn('rel="manifest"', index)
            self.assertIn('name="theme-color"', index)
            self.assertIn('favicon.ico?v=7146', index)
            self.assertIn('manifest.json?v=7146', index)
            self.assertTrue(all('?v=7146' in icon['src'] for icon in manifest['icons']))

    def test_tables_use_simple_two_axis_content_grid_without_nested_listview(self):
        src = self.read('lib/src/screens/study_tables_screen.dart')
        start = src.index('Widget _buildTableCanvas(')
        end = src.index('Widget _buildHeaderRow(', start)
        canvas = src[start:end]
        self.assertGreaterEqual(canvas.count('SingleChildScrollView('), 2)
        self.assertIn('scrollDirection: Axis.horizontal', canvas)
        self.assertIn('scrollDirection: Axis.vertical', canvas)
        self.assertIn('_buildSpreadsheetGrid(controller)', canvas)
        self.assertNotIn('ListView.builder(', canvas)
        self.assertNotIn('Expanded(', canvas)

    def test_tables_default_to_compact_rows_and_keep_repeatable_row_column_growth(self):
        src = self.read('lib/src/screens/study_tables_screen.dart')
        self.assertIn('static const double _defaultRowHeight = 42.0;', src)
        self.assertIn('rows.add(List<String>.filled(columns.length, \'\'))', src)
        self.assertIn("columns.add('Column ${columns.length + 1}')", src)
        self.assertIn('rowHeights.add(_defaultRowHeight);', src)
        self.assertIn('columnWidths.add(_defaultColumnWidth);', src)
        self.assertIn('void _normalizeGridShape()', src)

    def test_selected_cell_supports_background_text_color_bold_and_font_size(self):
        src = self.read('lib/src/screens/study_tables_screen.dart')
        self.assertIn("_setSelectedCellFormat('bg', value)", src)
        self.assertIn("_setSelectedCellFormat('fg', value)", src)
        self.assertIn("_setSelectedCellFormat('bold', value)", src)
        self.assertIn("_setSelectedCellFormat('fontSize', value)", src)
        self.assertIn("final fgValue = format['fg'];", src)
        self.assertIn("final cellFontValue = format['fontSize'];", src)
        self.assertIn('color: foreground,', src)
        self.assertIn('fontSize: cellFontSize,', src)

    def test_table_cells_avoid_expanding_textfield_layout_path_and_wrap_within_resized_cell(self):
        src = self.read('lib/src/screens/study_tables_screen.dart')
        start = src.index('Widget _buildEditableCell(')
        end = src.index('void _addColumn(', start)
        cell = src[start:end]
        self.assertNotIn('expands: wrapText', cell)
        self.assertIn('minLines: 1', cell)
        self.assertIn('maxLines: wrapText ? null : 1', cell)
        self.assertIn('textAlignVertical: TextAlignVertical.top', cell)

    def test_release_version_is_7146(self):
        self.assertIn('version: 7.14.6+246', self.read('pubspec.yaml'))


if __name__ == '__main__':
    unittest.main()
