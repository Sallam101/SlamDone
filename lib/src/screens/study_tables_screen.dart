import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

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
                          'Study Tables',
                          style: Theme.of(context).textTheme.titleLarge,
                        ),
                        const Text(
                          'Resizable wrapped cells, font controls, CSV import/export, Excel export, archive, rows, and columns.',
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
                    onPressed: () => _importCsv(context),
                    icon: const Icon(Icons.upload_file),
                    label: const Text('Import CSV'),
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
    final title = TextEditingController(text: 'New study table');
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

  Future<void> _importCsv(BuildContext context) async {
    final controller = AppScope.of(context);
    final result = await FilePicker.pickFiles(
      type: FileType.custom,
      allowedExtensions: const ['csv', 'tsv'],
      withData: true,
    );
    final selected = result?.files.single;
    final bytes = selected?.bytes;
    if (selected == null || bytes == null || !context.mounted) return;
    final raw = utf8.decode(bytes);
    final delimiter = selected.name.toLowerCase().endsWith('.tsv') ? '\t' : ',';
    final lines = const LineSplitter()
        .convert(raw)
        .where((line) => line.trim().isNotEmpty)
        .toList();
    if (lines.isEmpty) return;
    final rows = lines.map((line) => _parseLine(line, delimiter)).toList();
    final fileName = selected.name.replaceAll(
      RegExp(r'\.(csv|tsv)$', caseSensitive: false),
      '',
    );
    final table = await controller.createStudyTable(fileName);
    await controller.updateStudyTable(
      table.copyWith(
        columnsJson: jsonEncode(rows.first),
        rowsJson: jsonEncode(rows.skip(1).toList()),
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
  late List<String> columns;
  late List<List<String>> rows;
  List<double> columnWidths = <double>[];
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
        });
        return;
      } catch (_) {}
    }
    setState(() {
      columnWidths = List<double>.filled(columns.length, 180);
    });
  }

  Future<void> _savePreferences() {
    final controller = AppScope.read(context);
    return controller.writeUiSetting(
      _preferenceKey,
      jsonEncode({
        'widths': columnWidths,
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
                    setState(() => rows.add(List.filled(columns.length, '')));
                    _save(controller);
                  },
                  icon: const Icon(Icons.add),
                  label: const Text('Row'),
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
          Expanded(
            child: Scrollbar(
              controller: _horizontalController,
              thumbVisibility: true,
              scrollbarOrientation: ScrollbarOrientation.bottom,
              child: SingleChildScrollView(
                controller: _horizontalController,
                scrollDirection: Axis.horizontal,
                child: SizedBox(
                  width: totalWidth,
                  child: Scrollbar(
                    controller: _verticalController,
                    thumbVisibility: true,
                    child: ListView(
                      controller: _verticalController,
                      padding: const EdgeInsets.fromLTRB(10, 10, 10, 28),
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
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeaderRow(AppController controller) {
    return IntrinsicHeight(
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
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (var columnIndex = 0; columnIndex < columns.length; columnIndex++)
            Container(
              width: columnWidths[columnIndex],
              constraints: const BoxConstraints(minHeight: 48),
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                border: Border.all(
                  color: Theme.of(context).colorScheme.outlineVariant,
                ),
              ),
              child: TextFormField(
                key: ValueKey('${widget.table.id}-$rowIndex-$columnIndex'),
                initialValue: rows[rowIndex][columnIndex],
                minLines: 1,
                maxLines: wrapText ? null : 1,
                style: TextStyle(fontSize: fontSize, height: 1.25),
                onChanged: (value) {
                  rows[rowIndex][columnIndex] = value;
                  _scheduleSave(controller);
                },
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
          SizedBox(
            width: 52,
            child: IconButton(
              tooltip: 'Delete row',
              icon: const Icon(Icons.delete_outline),
              onPressed: () {
                setState(() => rows.removeAt(rowIndex));
                _save(controller);
              },
            ),
          ),
        ],
      ),
    );
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
