import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:excel_community/excel_community.dart' as xls;
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';

import '../controllers/app_controller.dart';
import '../controllers/app_scope.dart';
import '../models/models.dart';
import '../services/spreadsheet_export_service.dart';

class StudyTablesScreen extends StatefulWidget {
  const StudyTablesScreen({super.key});

  @override
  State<StudyTablesScreen> createState() => _StudyTablesScreenState();
}

class _StudyTablesScreenState extends State<StudyTablesScreen> {
  String? _selectedId;
  bool _showArchived = false;

  @override
  Widget build(BuildContext context) {
    final controller = AppScope.of(context);
    final tables =
        controller.studyTables
            .where((table) => _showArchived || !table.archived)
            .toList()
          ..sort((a, b) => a.sortKey.compareTo(b.sortKey));
    if (_selectedId == null && tables.isNotEmpty) {
      _selectedId = tables.first.id;
    }
    final selected = tables
        .where((table) => table.id == _selectedId)
        .firstOrNull;

    return Padding(
      padding: const EdgeInsets.all(14),
      child: Column(
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Wrap(
                spacing: 8,
                runSpacing: 8,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  const Icon(Icons.table_chart_outlined),
                  SizedBox(
                    width: (MediaQuery.sizeOf(context).width - 74)
                        .clamp(220, 620)
                        .toDouble(),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Tables',
                          style: Theme.of(context).textTheme.titleLarge,
                        ),
                        const Text(
                          'Excel/CSV import, row + column resizing, cell formatting, export, archive, rows, and columns.',
                        ),
                      ],
                    ),
                  ),
                  FilterChip(
                    label: const Text('Archived'),
                    selected: _showArchived,
                    onSelected: (value) =>
                        setState(() => _showArchived = value),
                  ),
                  OutlinedButton.icon(
                    onPressed: () => _importTable(context),
                    icon: const Icon(Icons.upload_file),
                    label: const Text('Import Excel / CSV'),
                  ),
                  FilledButton.icon(
                    onPressed: () => _newTable(context),
                    icon: const Icon(Icons.add),
                    label: const Text('Table'),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 10),
          if (tables.isNotEmpty)
            SizedBox(
              height: 48,
              child: Scrollbar(
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  children: tables.map((table) {
                    return Padding(
                      padding: const EdgeInsets.only(right: 6),
                      child: ChoiceChip(
                        label: Text(table.title),
                        selected: table.id == _selectedId,
                        onSelected: (_) =>
                            setState(() => _selectedId = table.id),
                      ),
                    );
                  }).toList(),
                ),
              ),
            ),
          const SizedBox(height: 8),
          Expanded(
            child: selected == null
                ? const Center(child: Text('Create or import a study table.'))
                : _EditableTable(key: ValueKey(selected.id), table: selected),
          ),
        ],
      ),
    );
  }

  Future<void> _newTable(BuildContext context) async {
    final title = TextEditingController(text: 'New table');
    final accepted = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        insetPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 24),
        title: const Text('New table'),
        content: TextField(
          controller: title,
          autofocus: true,
          decoration: const InputDecoration(labelText: 'Table name'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Create'),
          ),
        ],
      ),
    );
    final name = title.text.trim();
    title.dispose();
    if (accepted == true && name.isNotEmpty && context.mounted) {
      final table = await AppScope.of(context).createStudyTable(name);
      setState(() => _selectedId = table.id);
    }
  }

  Future<void> _importTable(BuildContext context) async {
    final controller = AppScope.of(context);
    final result = await FilePicker.pickFiles(
      type: FileType.custom,
      allowedExtensions: const ['csv', 'tsv', 'xlsx'],
      withData: true,
    );
    final selected = result?.files.single;
    final bytes = selected?.bytes;
    if (selected == null || bytes == null || !context.mounted) return;

    final lower = selected.name.toLowerCase();
    late final List<List<String>> importedRows;
    if (lower.endsWith('.xlsx')) {
      final workbook = xls.Excel.decodeBytes(bytes);
      if (workbook.tables.isEmpty) return;
      final sheet = workbook.tables.values.first;
      if (sheet == null) return;
      importedRows = sheet.rows
          .map((row) => row.map((cell) => cell?.value?.toString() ?? '').toList())
          .where((row) => row.any((value) => value.trim().isNotEmpty))
          .toList();
    } else {
      final raw = utf8.decode(bytes);
      final delimiter = lower.endsWith('.tsv') ? '\t' : ',';
      importedRows = const LineSplitter()
          .convert(raw)
          .where((line) => line.trim().isNotEmpty)
          .map((line) => _parseLine(line, delimiter))
          .toList();
    }
    if (importedRows.isEmpty) return;

    final extension = lower.endsWith('.xlsx')
        ? '.xlsx'
        : lower.endsWith('.tsv')
        ? '.tsv'
        : '.csv';
    final fileName = selected.name.substring(0, selected.name.length - extension.length);
    final width = importedRows.fold<int>(0, (maxWidth, row) => row.length > maxWidth ? row.length : maxWidth);
    final normalized = importedRows
        .map((row) => [...row, ...List<String>.filled(width - row.length, '')])
        .toList();
    final table = await controller.createStudyTable(fileName);
    await controller.updateStudyTable(
      table.copyWith(
        columnsJson: jsonEncode(normalized.first),
        rowsJson: jsonEncode(normalized.skip(1).toList()),
      ),
    );
    if (mounted) setState(() => _selectedId = table.id);
  }

  List<String> _parseLine(String line, String delimiter) {
    final output = <String>[];
    var buffer = StringBuffer();
    var quoted = false;
    for (var index = 0; index < line.length; index++) {
      final char = line[index];
      if (char == '"') {
        quoted = !quoted;
      } else if (char == delimiter && !quoted) {
        output.add(buffer.toString());
        buffer = StringBuffer();
      } else {
        buffer.write(char);
      }
    }
    output.add(buffer.toString());
    return output;
  }
}

class _EditableTable extends StatefulWidget {
  const _EditableTable({super.key, required this.table});
  final StudyTable table;

  @override
  State<_EditableTable> createState() => _EditableTableState();
}

class _EditableTableState extends State<_EditableTable> {
  static const double _tableHeaderHeight = 58.0;

  late List<String> columns;
  late List<List<String>> rows;
  List<double> columnWidths = <double>[];
  List<double> rowHeights = <double>[];
  Map<String, Map<String, Object?>> cellFormats = <String, Map<String, Object?>>{};
  int? _selectedRowIndex;
  int? _selectedCellColumnIndex;
  double fontSize = 14;
  bool wrapText = true;
  bool _preferencesLoaded = false;
  int? _selectedColumnIndex;
  final ScrollController _horizontalController = ScrollController();
  final ScrollController _verticalController = ScrollController();
  Timer? _saveTimer;

  String get _preferenceKey => 'study_table_${widget.table.id}_display';

  @override
  void initState() {
    super.initState();
    _copyTableData();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_preferencesLoaded) {
      _preferencesLoaded = true;
      _loadPreferences();
    }
  }

  @override
  void didUpdateWidget(covariant _EditableTable oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.table.id != widget.table.id) {
      _copyTableData();
      _preferencesLoaded = false;
      _loadPreferences();
    } else if (oldWidget.table.updatedAt != widget.table.updatedAt) {
      _copyTableData(keepWidths: true);
    }
  }

  @override
  void dispose() {
    _saveTimer?.cancel();
    _horizontalController.dispose();
    _verticalController.dispose();
    super.dispose();
  }

  void _copyTableData({bool keepWidths = false}) {
    columns = [...widget.table.columns];
    rows = widget.table.rows.map((row) => [...row]).toList();
    if (!keepWidths || columnWidths.length != columns.length) {
      columnWidths = List<double>.filled(columns.length, 180);
    }
    if (!keepWidths || rowHeights.length != rows.length) {
      rowHeights = List<double>.filled(rows.length, 54);
    }
    if (_selectedColumnIndex != null &&
        _selectedColumnIndex! >= columns.length) {
      _selectedColumnIndex = columns.isEmpty ? null : columns.length - 1;
    }
  }

  Future<void> _loadPreferences() async {
    final controller = AppScope.read(context);
    final raw = await controller.readUiSetting(_preferenceKey);
    if (!mounted) return;
    if (raw != null) {
      try {
        final map = (jsonDecode(raw) as Map).cast<String, dynamic>();
        final savedWidths =
            (map['widths'] as List?)
                ?.map((value) => (value as num).toDouble())
                .toList() ??
            const <double>[];
        final savedRowHeights =
            (map['rowHeights'] as List?)
                ?.map((value) => (value as num).toDouble())
                .toList() ??
            const <double>[];
        final savedFormats = <String, Map<String, Object?>>{};
        final rawFormats = map['cellFormats'];
        if (rawFormats is Map) {
          for (final entry in rawFormats.entries) {
            if (entry.value is Map) {
              savedFormats[entry.key.toString()] =
                  (entry.value as Map).map((key, value) => MapEntry(key.toString(), value));
            }
          }
        }
        setState(() {
          fontSize = ((map['fontSize'] as num?)?.toDouble() ?? 14)
              .clamp(9, 28)
              .toDouble();
          wrapText = map['wrapText'] != false;
          columnWidths = List<double>.generate(
            columns.length,
            (index) => index < savedWidths.length
                ? savedWidths[index].clamp(90, 520).toDouble()
                : 180,
          );
          rowHeights = List<double>.generate(
            rows.length,
            (index) => index < savedRowHeights.length
                ? savedRowHeights[index].clamp(38, 360).toDouble()
                : 54,
          );
          cellFormats = savedFormats;
        });
        return;
      } catch (_) {}
    }
    setState(() {
      columnWidths = List<double>.filled(columns.length, 180);
      rowHeights = List<double>.filled(rows.length, 54);
      cellFormats = <String, Map<String, Object?>>{};
    });
  }

  Future<void> _savePreferences() {
    final controller = AppScope.read(context);
    return controller.writeUiSetting(
      _preferenceKey,
      jsonEncode({
        'widths': columnWidths,
        'rowHeights': rowHeights,
        'cellFormats': cellFormats,
        'fontSize': fontSize,
        'wrapText': wrapText,
      }),
    );
  }

  @override
  Widget build(BuildContext context) {
    final controller = AppScope.of(context);
    final totalWidth =
        columnWidths.fold<double>(0, (sum, value) => sum + value) + 84;
    return Card(
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(10),
            child: Wrap(
              spacing: 8,
              runSpacing: 8,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                Text(
                  widget.table.title,
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                FilterChip(
                  tooltip: 'Bold cell',
                  label: const Text('Bold cell'),
                  selected: _selectedCellFormat['bold'] == true,
                  onSelected: _selectedRowIndex == null || _selectedCellColumnIndex == null
                      ? null
                      : (value) => _setSelectedCellFormat('bold', value),
                ),
                PopupMenuButton<int?>(
                  enabled: _selectedRowIndex != null && _selectedCellColumnIndex != null,
                  tooltip: 'Cell color',
                  onSelected: (value) => _setSelectedCellFormat('bg', value),
                  itemBuilder: (context) => [
                    const PopupMenuItem<int?>(value: null, child: Text('Cell color: none')),
                    for (final color in const <Color>[
                      Color(0xFFFFF59D),
                      Color(0xFFC8E6C9),
                      Color(0xFFBBDEFB),
                      Color(0xFFF8BBD0),
                      Color(0xFFD1C4E9),
                    ])
                      PopupMenuItem<int?>(
                        value: color.toARGB32(),
                        child: Row(children: [
                          Container(width: 20, height: 20, decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(4))),
                          const SizedBox(width: 8),
                          const Text('Cell color'),
                        ]),
                      ),
                  ],
                  child: const Chip(avatar: Icon(Icons.format_color_fill, size: 18), label: Text('Cell color')),
                ),
                OutlinedButton.icon(
                  onPressed: () {
                    setState(() {
                      columns.add('Column ${columns.length + 1}');
                      columnWidths.add(180);
                      for (final row in rows) {
                        row.add('');
                      }
                    });
                    _save(controller);
                    _savePreferences();
                  },
                  icon: const Icon(Icons.add),
                  label: const Text('Add column'),
                ),
                OutlinedButton.icon(
                  onPressed: columns.isEmpty
                      ? null
                      : () => _chooseColumnToDelete(controller),
                  icon: const Icon(Icons.delete_outline),
                  label: Text(
                    _selectedColumnIndex == null
                        ? 'Delete column'
                        : 'Delete column ${_selectedColumnIndex! + 1}',
                  ),
                ),
                OutlinedButton.icon(
                  onPressed: columns.isEmpty
                      ? null
                      : () => _deleteEmptyColumns(controller),
                  icon: const Icon(Icons.delete_sweep_outlined),
                  label: const Text('Delete empty columns'),
                ),
                OutlinedButton.icon(
                  onPressed: () {
                    setState(() {
                      rows.add(List.filled(columns.length, ''));
                      rowHeights.add(54);
                    });
                    _save(controller);
                    _savePreferences();
                  },
                  icon: const Icon(Icons.add),
                  label: const Text('Add row'),
                ),
                OutlinedButton.icon(
                  onPressed: () => _exportCsv(context),
                  icon: const Icon(Icons.download),
                  label: const Text('CSV'),
                ),
                OutlinedButton.icon(
                  onPressed: () => _exportExcel(context),
                  icon: const Icon(Icons.grid_on),
                  label: const Text('Excel'),
                ),
                SizedBox(
                  width: 210,
                  child: Row(
                    children: [
                      const Text('Font'),
                      Expanded(
                        child: Slider(
                          value: fontSize,
                          min: 9,
                          max: 28,
                          divisions: 19,
                          label: fontSize.round().toString(),
                          onChanged: (value) =>
                              setState(() => fontSize = value),
                          onChangeEnd: (_) => _savePreferences(),
                        ),
                      ),
                      Text('${fontSize.round()}'),
                    ],
                  ),
                ),
                FilterChip(
                  label: const Text('Wrap text'),
                  selected: wrapText,
                  onSelected: (value) {
                    setState(() => wrapText = value);
                    _savePreferences();
                  },
                ),
                OutlinedButton.icon(
                  onPressed: () => controller.updateStudyTable(
                    widget.table.copyWith(archived: !widget.table.archived),
                  ),
                  icon: Icon(
                    widget.table.archived ? Icons.unarchive : Icons.archive,
                  ),
                  label: Text(widget.table.archived ? 'Restore' : 'Archive'),
                ),
                IconButton(
                  tooltip: 'Delete table',
                  onPressed: () => controller.deleteStudyTable(widget.table),
                  icon: const Icon(Icons.delete_outline),
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          Expanded(child: _buildTableCanvas(controller, totalWidth)),
        ],
      ),
    );
  }


  Widget _buildTableCanvas(AppController controller, double totalWidth) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final viewportWidth = constraints.maxWidth.isFinite
            ? constraints.maxWidth
            : totalWidth;
        final canvasWidth = totalWidth < viewportWidth
            ? viewportWidth
            : totalWidth;
        final canvasHeight = constraints.maxHeight.isFinite
            ? constraints.maxHeight
            : 600.0;
        return SingleChildScrollView(
          controller: _horizontalController,
          scrollDirection: Axis.horizontal,
          child: SizedBox(
            width: canvasWidth,
            height: canvasHeight,
            child: SingleChildScrollView(
              controller: _verticalController,
              scrollDirection: Axis.vertical,
              padding: const EdgeInsets.fromLTRB(10, 10, 10, 28),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildHeaderRow(controller),
                  const SizedBox(height: 4),
                  for (
                    var rowIndex = 0;
                    rowIndex < rows.length;
                    rowIndex++
                  )
                    _buildDataRow(controller, rowIndex),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildHeaderRow(AppController controller) {
    return SizedBox(
      height: _tableHeaderHeight,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (var index = 0; index < columns.length; index++)
            _ResizableHeaderCell(
              width: columnWidths[index],
              fontSize: fontSize,
              value: columns[index],
              onChanged: (value) {
                columns[index] = value;
                _scheduleSave(controller);
              },
              selected: _selectedColumnIndex == index,
              onSelected: () => setState(() => _selectedColumnIndex = index),
              onResize: (delta) {
                setState(() {
                  columnWidths[index] = (columnWidths[index] + delta)
                      .clamp(90, 520)
                      .toDouble();
                });
              },
              onResizeEnd: _savePreferences,
              onDelete: () {
                setState(() => _selectedColumnIndex = index);
                _deleteColumn(controller, index);
              },
            ),
          const SizedBox(width: 52),
        ],
      ),
    );
  }

  Widget _buildDataRow(AppController controller, int rowIndex) {
    while (rows[rowIndex].length < columns.length) {
      rows[rowIndex].add('');
    }
    while (rowHeights.length <= rowIndex) rowHeights.add(54);
    final rowHeight = rowHeights[rowIndex].clamp(38, 360).toDouble();
    return SizedBox(
      height: rowHeight,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (var columnIndex = 0; columnIndex < columns.length; columnIndex++)
            _buildEditableCell(controller, rowIndex, columnIndex),
          SizedBox(
            width: 52,
            child: Column(
              children: [
                Expanded(
                  child: MouseRegion(
                    cursor: SystemMouseCursors.resizeRow,
                    child: GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onVerticalDragUpdate: (details) => resizeRow(rowIndex, details.delta.dy),
                      onVerticalDragEnd: (_) => _savePreferences(),
                      child: const Tooltip(
                        message: 'Drag to resize row',
                        child: Icon(Icons.drag_handle),
                      ),
                    ),
                  ),
                ),
                IconButton(
                  tooltip: 'Delete row',
                  icon: const Icon(Icons.delete_outline),
                  onPressed: () {
                    setState(() {
                      rows.removeAt(rowIndex);
                      if (rowIndex < rowHeights.length) rowHeights.removeAt(rowIndex);
                      _removeRowFormats(rowIndex);
                    });
                    _save(controller);
                    _savePreferences();
                  },
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEditableCell(
    AppController controller,
    int rowIndex,
    int columnIndex,
  ) {
    final key = '$rowIndex:$columnIndex';
    final format = cellFormats[key] ?? const <String, Object?>{};
    final selected = _selectedRowIndex == rowIndex && _selectedCellColumnIndex == columnIndex;
    final bgValue = format['bg'];
    final background = bgValue is int ? Color(bgValue) : null;
    return Container(
      width: columnWidths[columnIndex],
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: background,
        border: Border.all(
          color: selected
              ? Theme.of(context).colorScheme.primary
              : Theme.of(context).colorScheme.outlineVariant,
          width: selected ? 2 : 1,
        ),
      ),
      child: TextFormField(
        key: ValueKey('${widget.table.id}-$rowIndex-$columnIndex'),
        initialValue: rows[rowIndex][columnIndex],
        minLines: 1,
        maxLines: wrapText ? null : 1,
        expands: false,
        style: TextStyle(
          fontSize: fontSize,
          height: 1.25,
          fontWeight: format['bold'] == true ? FontWeight.w800 : FontWeight.normal,
        ),
        onTap: () => setState(() {
          _selectedRowIndex = rowIndex;
          _selectedCellColumnIndex = columnIndex;
        }),
        onChanged: (value) {
          rows[rowIndex][columnIndex] = value;
          _scheduleSave(controller);
        },
        decoration: const InputDecoration(
          border: InputBorder.none,
          isDense: true,
          contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 8),
        ),
      ),
    );
  }

  void resizeRow(int rowIndex, double delta) {
    if (rowIndex < 0 || rowIndex >= rowHeights.length) return;
    setState(() {
      rowHeights[rowIndex] = (rowHeights[rowIndex] + delta).clamp(38, 360).toDouble();
    });
  }

  Map<String, Object?> get _selectedCellFormat {
    final row = _selectedRowIndex;
    final col = _selectedCellColumnIndex;
    if (row == null || col == null) return const <String, Object?>{};
    return cellFormats['$row:$col'] ?? const <String, Object?>{};
  }

  void _setSelectedCellFormat(String key, Object? value) {
    final row = _selectedRowIndex;
    final col = _selectedCellColumnIndex;
    if (row == null || col == null) return;
    final cellKey = '$row:$col';
    setState(() {
      final next = Map<String, Object?>.from(cellFormats[cellKey] ?? const <String, Object?>{});
      if (value == null || value == false) {
        next.remove(key);
      } else {
        next[key] = value;
      }
      if (next.isEmpty) {
        cellFormats.remove(cellKey);
      } else {
        cellFormats[cellKey] = next;
      }
    });
    _savePreferences();
  }

  void _removeRowFormats(int removedRow) {
    final next = <String, Map<String, Object?>>{};
    for (final entry in cellFormats.entries) {
      final parts = entry.key.split(':');
      if (parts.length != 2) continue;
      final row = int.tryParse(parts[0]);
      final col = int.tryParse(parts[1]);
      if (row == null || col == null || row == removedRow) continue;
      next['${row > removedRow ? row - 1 : row}:$col'] = entry.value;
    }
    cellFormats = next;
    _selectedRowIndex = null;
    _selectedCellColumnIndex = null;
  }

  void _deleteColumn(AppController controller, int columnIndex) {
    if (columnIndex < 0 || columnIndex >= columns.length) return;
    setState(() {
      columns.removeAt(columnIndex);
      if (columnIndex < columnWidths.length) {
        columnWidths.removeAt(columnIndex);
      }
      for (final row in rows) {
        if (columnIndex < row.length) row.removeAt(columnIndex);
      }
      cellFormats.clear();
      _selectedRowIndex = null;
      _selectedCellColumnIndex = null;
      if (columns.isEmpty) {
        _selectedColumnIndex = null;
      } else if (_selectedColumnIndex != null) {
        _selectedColumnIndex = columnIndex.clamp(0, columns.length - 1).toInt();
      }
    });
    _save(controller);
    _savePreferences();
  }

  Future<void> _chooseColumnToDelete(AppController controller) async {
    if (columns.isEmpty) return;
    final picked = await showDialog<int>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Delete a column'),
        content: SizedBox(
          width: (MediaQuery.sizeOf(context).width - 48)
              .clamp(240, 470)
              .toDouble(),
          height: (columns.length * 62.0).clamp(120.0, 420.0).toDouble(),
          child: ListView.builder(
            itemCount: columns.length,
            itemBuilder: (context, index) {
              final name = columns[index].trim();
              final populatedCells = rows.where((row) {
                return index < row.length && row[index].trim().isNotEmpty;
              }).length;
              return ListTile(
                selected: index == _selectedColumnIndex,
                leading: CircleAvatar(child: Text('${index + 1}')),
                title: Text(
                  name.isEmpty ? 'Untitled column ${index + 1}' : name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                subtitle: Text('$populatedCells populated cells'),
                trailing: Icon(
                  Icons.delete_outline,
                  color: Theme.of(context).colorScheme.error,
                ),
                onTap: () => Navigator.pop(dialogContext, index),
              );
            },
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancel'),
          ),
        ],
      ),
    );
    if (picked != null && mounted) {
      _deleteColumn(controller, picked);
    }
  }

  void _deleteEmptyColumns(AppController controller) {
    final emptyIndices = <int>[];
    for (var index = 0; index < columns.length; index++) {
      final emptyHeader = columns[index].trim().isEmpty;
      final emptyCells = rows.every(
        (row) => index >= row.length || row[index].trim().isEmpty,
      );
      if (emptyHeader && emptyCells) emptyIndices.add(index);
    }
    if (emptyIndices.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('There are no completely empty columns.')),
      );
      return;
    }
    setState(() {
      for (final index in emptyIndices.reversed) {
        columns.removeAt(index);
        if (index < columnWidths.length) columnWidths.removeAt(index);
        for (final row in rows) {
          if (index < row.length) row.removeAt(index);
        }
      }
      _selectedColumnIndex = null;
    });
    _save(controller);
    _savePreferences();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Deleted ${emptyIndices.length} empty columns.')),
    );
  }

  void _scheduleSave(AppController controller) {
    _saveTimer?.cancel();
    _saveTimer = Timer(const Duration(milliseconds: 450), () {
      _save(controller);
    });
  }

  Future<void> _save(AppController controller) {
    _saveTimer?.cancel();
    return controller.updateStudyTable(
      widget.table.copyWith(
        columnsJson: jsonEncode(columns),
        rowsJson: jsonEncode(rows),
      ),
    );
  }

  Future<void> _exportCsv(BuildContext context) async {
    final fileName = widget.table.title.replaceAll(
      RegExp(r'[^A-Za-z0-9_-]'),
      '_',
    );
    String quote(String value) {
      final escaped = value.replaceAll('"', '""');
      return '"$escaped"';
    }

    final lines = [
      columns.map(quote).join(','),
      ...rows.map(
        (row) => List.generate(
          columns.length,
          (index) => quote(index < row.length ? row[index] : ''),
        ).join(','),
      ),
    ];
    final bytes = Uint8List.fromList(utf8.encode(lines.join('\r\n')));
    final path = await FilePicker.saveFile(
      dialogTitle: 'Export study table',
      fileName: '$fileName.csv',
      type: FileType.custom,
      allowedExtensions: const ['csv'],
      bytes: bytes,
    );
    if (context.mounted && path != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Study table downloaded.')),
      );
    }
  }

  Future<void> _exportExcel(BuildContext context) async {
    final path = await SpreadsheetExportService.exportTable(
      title: widget.table.title,
      columns: columns,
      rows: rows,
      columnWidths: columnWidths,
      fontSize: fontSize,
      wrapText: wrapText,
    );
    if (context.mounted && path != null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Excel workbook saved to $path')));
    }
  }
}

class _ResizableHeaderCell extends StatelessWidget {
  const _ResizableHeaderCell({
    required this.width,
    required this.fontSize,
    required this.value,
    required this.selected,
    required this.onSelected,
    required this.onChanged,
    required this.onResize,
    required this.onResizeEnd,
    required this.onDelete,
  });

  final double width;
  final double fontSize;
  final String value;
  final bool selected;
  final VoidCallback onSelected;
  final ValueChanged<String> onChanged;
  final ValueChanged<double> onResize;
  final Future<void> Function() onResizeEnd;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: width,
      height: _EditableTableState._tableHeaderHeight,
      child: Stack(
        children: [
          Positioned.fill(
            child: Container(
              padding: const EdgeInsets.fromLTRB(4, 4, 42, 4),
              decoration: BoxDecoration(
                color: selected
                    ? Theme.of(context).colorScheme.primaryContainer
                    : Theme.of(context).colorScheme.surfaceContainerHigh,
                border: Border.all(
                  color: selected
                      ? Theme.of(context).colorScheme.primary
                      : Theme.of(context).colorScheme.outlineVariant,
                  width: selected ? 2 : 1,
                ),
              ),
              child: TextFormField(
                initialValue: value,
                minLines: 1,
                maxLines: null,
                style: TextStyle(
                  fontSize: fontSize,
                  fontWeight: FontWeight.w800,
                ),
                onTap: onSelected,
                onChanged: onChanged,
                decoration: const InputDecoration(
                  border: InputBorder.none,
                  isDense: true,
                  contentPadding: EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 8,
                  ),
                ),
              ),
            ),
          ),
          Positioned(
            right: 12,
            top: 5,
            child: Material(
              color: Theme.of(context).colorScheme.errorContainer,
              shape: const CircleBorder(),
              child: IconButton(
                tooltip: 'Delete this column',
                visualDensity: VisualDensity.compact,
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints.tightFor(
                  width: 32,
                  height: 32,
                ),
                onPressed: onDelete,
                icon: Icon(
                  Icons.delete_outline,
                  size: 18,
                  color: Theme.of(context).colorScheme.onErrorContainer,
                ),
              ),
            ),
          ),
          Positioned(
            right: 0,
            top: 0,
            bottom: 0,
            child: MouseRegion(
              cursor: SystemMouseCursors.resizeColumn,
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onHorizontalDragUpdate: (details) => onResize(details.delta.dx),
                onHorizontalDragEnd: (_) => onResizeEnd(),
                child: Container(
                  width: 10,
                  color: Theme.of(
                    context,
                  ).colorScheme.primary.withValues(alpha: .12),
                  child: const Center(
                    child: Icon(Icons.drag_indicator, size: 12),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
