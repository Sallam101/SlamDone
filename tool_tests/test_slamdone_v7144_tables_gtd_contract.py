from pathlib import Path
import re
import unittest

ROOT = Path(__file__).resolve().parents[1]


class SlamDoneV7144TablesGtdContractTest(unittest.TestCase):
    def read(self, rel: str) -> str:
        return (ROOT / rel).read_text(encoding='utf-8')

    def test_tables_canvas_has_bounded_vertical_list_inside_horizontal_viewport(self):
        src = self.read('lib/src/screens/study_tables_screen.dart')
        start = src.index('Widget _buildTableCanvas(')
        end = src.index('Widget _buildHeaderRow(', start)
        canvas = src[start:end]
        self.assertGreaterEqual(canvas.count('SingleChildScrollView('), 2)
        self.assertIn('scrollDirection: Axis.horizontal', canvas)
        self.assertIn('scrollDirection: Axis.vertical', canvas)
        self.assertIn('_buildSpreadsheetGrid(controller)', canvas)
        self.assertNotIn('ListView.builder(', canvas)

    def test_tables_add_helpers_are_repeatable_and_normalize_shape(self):
        src = self.read('lib/src/screens/study_tables_screen.dart')
        self.assertIn('void _addColumn(AppController controller)', src)
        self.assertIn('void _addRow(AppController controller)', src)
        self.assertIn('void _normalizeGridShape()', src)
        self.assertIn("columns.add('Column ${columns.length + 1}')", src)
        self.assertIn("rows.add(List<String>.filled(columns.length, ''))", src)
        self.assertRegex(src, r'while \(columnWidths\.length < columns\.length\)')
        self.assertRegex(src, r'while \(rowHeights\.length < rows\.length\)')
        self.assertIn('while (row.length < columns.length)', src)
        self.assertIn('if (row.length > columns.length)', src)

    def test_table_row_controls_fit_short_rows_and_cells_fill_resized_height(self):
        src = self.read('lib/src/screens/study_tables_screen.dart')
        row_start = src.index('Widget _buildDataRow(')
        row_end = src.index('Widget _buildEditableCell(', row_start)
        row = src[row_start:row_end]
        self.assertIn('Stack(', row)
        self.assertIn("message: 'Drag bottom edge to resize row'", row)
        self.assertIn('height: 10', row)
        self.assertNotIn('child: Column(', row)

        cell_start = src.index('Widget _buildEditableCell(')
        cell_end = src.index('void resizeRow(', cell_start)
        cell = src[cell_start:cell_end]
        self.assertNotIn('expands: wrapText', cell)
        self.assertIn('minLines: 1', cell)
        self.assertIn('maxLines: wrapText ? null : 1', cell)
        self.assertIn('textAlignVertical: TextAlignVertical.top', cell)

    def test_gtd_drop_uses_bidirectional_status_transition(self):
        screen = self.read('lib/src/screens/gtd_para_screen.dart')
        controller = self.read('lib/src/controllers/app_controller.dart')
        self.assertIn('await controller.moveWorkItemToGtdStatus(item, status);', screen)
        self.assertIn('Future<void> moveWorkItemToGtdStatus(', controller)
        method_start = controller.index('Future<void> moveWorkItemToGtdStatus(')
        method_end = controller.index('Future<void> setWorkItemCompleted(', method_start)
        method = controller[method_start:method_end]
        self.assertIn('_cancelPendingAutoArchive(item.id);', method)
        self.assertIn('target == GtdStatus.completed', method)
        self.assertIn('target == GtdStatus.archived', method)
        self.assertIn('item.checklistTotal - 1', method)
        self.assertIn('gtdStatus: target', method)
        self.assertIn('status: targetWorkStatus', method)
        self.assertIn('checklistDone: targetChecklistDone', method)

    def test_release_version_is_7144(self):
        pubspec = self.read('pubspec.yaml')
        self.assertRegex(pubspec, r'(?m)^version:\s*7\.14\.(?:4\+244|5\+245|6\+246)\s*$')


if __name__ == '__main__':
    unittest.main()
