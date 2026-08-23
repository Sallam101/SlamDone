import 'dart:convert';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:file_picker/file_picker.dart';

class OverviewSheetData {
  const OverviewSheetData({
    required this.name,
    required this.columns,
    required this.rows,
  });

  final String name;
  final List<String> columns;
  final List<List<String>> rows;
}

/// Exports the selected Overview period as a multi-sheet Excel workbook.
class OverviewExportService {
  const OverviewExportService._();

  static Future<String?> export({
    required String periodLabel,
    required List<List<String>> summaryRows,
    required List<List<String>> comparisonRows,
    required List<List<String>> hierarchyCompletedRows,
    required List<List<String>> hierarchyTrendRows,
    required List<List<String>> dailyTrendRows,
    required List<List<String>> projectFocusRows,
  }) async {
    final sheets = <OverviewSheetData>[
      OverviewSheetData(
        name: 'Summary',
        columns: const ['Metric', 'Value', 'Detail'],
        rows: summaryRows,
      ),
      OverviewSheetData(
        name: 'Period Comparison',
        columns: const ['Metric', 'Current', 'Previous', 'Current target', 'Previous target'],
        rows: comparisonRows,
      ),
      OverviewSheetData(
        name: 'Hierarchy Completed',
        columns: const ['Type', 'Title', 'Status', 'Completed date', 'Parent ID'],
        rows: hierarchyCompletedRows,
      ),
      OverviewSheetData(
        name: 'Hierarchy Trend',
        columns: const ['Bucket', 'Goals', 'Milestones', 'Projects', 'Subprojects', 'Modules', 'Tasks'],
        rows: hierarchyTrendRows,
      ),
      OverviewSheetData(
        name: 'Daily Trend',
        columns: const ['Date', 'Focus minutes', 'Completed items', 'Habit check-ins', 'Goals hit'],
        rows: dailyTrendRows,
      ),
      OverviewSheetData(
        name: 'Focus by Project',
        columns: const ['Project / goal', 'Focus minutes'],
        rows: projectFocusRows,
      ),
    ];
    final bytes = _buildWorkbook(sheets);
    final fileName = 'SlamDone_Overview_${_safeFileName(periodLabel)}.xlsx';
    final path = await FilePicker.saveFile(
      dialogTitle: 'Export Overview to Excel',
      fileName: fileName,
      type: FileType.custom,
      allowedExtensions: const ['xlsx'],
      bytes: bytes,
    );
    return path?.toString();
  }

  static Uint8List _buildWorkbook(List<OverviewSheetData> sheets) {
    final archive = Archive();
    void addText(String name, String value) {
      final data = utf8.encode(value);
      archive.addFile(ArchiveFile(name, data.length, data));
    }

    final contentOverrides = StringBuffer();
    final workbookSheets = StringBuffer();
    final workbookRels = StringBuffer();
    for (var i = 0; i < sheets.length; i++) {
      final index = i + 1;
      contentOverrides.write('<Override PartName="/xl/worksheets/sheet$index.xml" ContentType="application/vnd.openxmlformats-officedocument.spreadsheetml.worksheet+xml"/>');
      workbookSheets.write('<sheet name="${_xmlEscape(_sheetName(sheets[i].name))}" sheetId="$index" r:id="rId$index"/>');
      workbookRels.write('<Relationship Id="rId$index" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/worksheet" Target="worksheets/sheet$index.xml"/>');
    }
    final stylesRelId = sheets.length + 1;
    workbookRels.write('<Relationship Id="rId$stylesRelId" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/styles" Target="styles.xml"/>');

    addText(
      '[Content_Types].xml',
      '''<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<Types xmlns="http://schemas.openxmlformats.org/package/2006/content-types">
<Default Extension="rels" ContentType="application/vnd.openxmlformats-package.relationships+xml"/>
<Default Extension="xml" ContentType="application/xml"/>
<Override PartName="/xl/workbook.xml" ContentType="application/vnd.openxmlformats-officedocument.spreadsheetml.sheet.main+xml"/>
${contentOverrides.toString()}
<Override PartName="/xl/styles.xml" ContentType="application/vnd.openxmlformats-officedocument.spreadsheetml.styles+xml"/>
<Override PartName="/docProps/core.xml" ContentType="application/vnd.openxmlformats-package.core-properties+xml"/>
<Override PartName="/docProps/app.xml" ContentType="application/vnd.openxmlformats-officedocument.extended-properties+xml"/>
</Types>''',
    );
    addText(
      '_rels/.rels',
      '''<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">
<Relationship Id="rId1" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/officeDocument" Target="xl/workbook.xml"/>
<Relationship Id="rId2" Type="http://schemas.openxmlformats.org/package/2006/relationships/metadata/core-properties" Target="docProps/core.xml"/>
<Relationship Id="rId3" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/extended-properties" Target="docProps/app.xml"/>
</Relationships>''',
    );
    addText(
      'xl/workbook.xml',
      '''<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<workbook xmlns="http://schemas.openxmlformats.org/spreadsheetml/2006/main" xmlns:r="http://schemas.openxmlformats.org/officeDocument/2006/relationships"><sheets>${workbookSheets.toString()}</sheets></workbook>''',
    );
    addText(
      'xl/_rels/workbook.xml.rels',
      '''<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">${workbookRels.toString()}</Relationships>''',
    );

    for (var i = 0; i < sheets.length; i++) {
      final sheet = sheets[i];
      final rowXml = StringBuffer()..write(_rowXml(1, sheet.columns, style: 1));
      for (var rowIndex = 0; rowIndex < sheet.rows.length; rowIndex++) {
        final row = List<String>.generate(
          sheet.columns.length,
          (columnIndex) => columnIndex < sheet.rows[rowIndex].length ? sheet.rows[rowIndex][columnIndex] : '',
        );
        rowXml.write(_rowXml(rowIndex + 2, row, style: 0));
      }
      final lastColumn = _columnName(sheet.columns.isEmpty ? 1 : sheet.columns.length);
      addText(
        'xl/worksheets/sheet${i + 1}.xml',
        '''<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<worksheet xmlns="http://schemas.openxmlformats.org/spreadsheetml/2006/main">
<sheetViews><sheetView workbookViewId="0"><pane ySplit="1" topLeftCell="A2" activePane="bottomLeft" state="frozen"/></sheetView></sheetViews>
<sheetData>${rowXml.toString()}</sheetData>
<autoFilter ref="A1:$lastColumn${sheet.rows.length + 1}"/>
</worksheet>''',
      );
    }

    addText(
      'xl/styles.xml',
      '''<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<styleSheet xmlns="http://schemas.openxmlformats.org/spreadsheetml/2006/main">
<fonts count="2"><font><sz val="11"/><name val="Aptos"/></font><font><b/><sz val="11"/><name val="Aptos"/></font></fonts>
<fills count="2"><fill><patternFill patternType="none"/></fill><fill><patternFill patternType="gray125"/></fill></fills>
<borders count="1"><border><left/><right/><top/><bottom/><diagonal/></border></borders>
<cellStyleXfs count="1"><xf numFmtId="0" fontId="0" fillId="0" borderId="0"/></cellStyleXfs>
<cellXfs count="2"><xf numFmtId="0" fontId="0" fillId="0" borderId="0" xfId="0" applyAlignment="1"><alignment vertical="top" wrapText="1"/></xf><xf numFmtId="0" fontId="1" fillId="0" borderId="0" xfId="0" applyAlignment="1"><alignment vertical="top" wrapText="1"/></xf></cellXfs>
<cellStyles count="1"><cellStyle name="Normal" xfId="0" builtinId="0"/></cellStyles>
</styleSheet>''',
    );
    final now = DateTime.now().toUtc().toIso8601String();
    addText(
      'docProps/core.xml',
      '''<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<cp:coreProperties xmlns:cp="http://schemas.openxmlformats.org/package/2006/metadata/core-properties" xmlns:dc="http://purl.org/dc/elements/1.1/" xmlns:dcterms="http://purl.org/dc/terms/" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance"><dc:title>SlamDone Overview</dc:title><dc:creator>SlamDone</dc:creator><dcterms:created xsi:type="dcterms:W3CDTF">$now</dcterms:created></cp:coreProperties>''',
    );
    addText(
      'docProps/app.xml',
      '''<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<Properties xmlns="http://schemas.openxmlformats.org/officeDocument/2006/extended-properties"><Application>SlamDone</Application></Properties>''',
    );
    return ZipEncoder().encodeBytes(archive);
  }

  static String _rowXml(int number, List<String> cells, {required int style}) {
    final buffer = StringBuffer('<row r="$number">');
    for (var i = 0; i < cells.length; i++) {
      buffer.write('<c r="${_columnName(i + 1)}$number" t="inlineStr" s="$style"><is><t xml:space="preserve">${_xmlEscape(cells[i])}</t></is></c>');
    }
    buffer.write('</row>');
    return buffer.toString();
  }

  static String _columnName(int number) {
    var value = number < 1 ? 1 : number;
    var output = '';
    while (value > 0) {
      final remainder = (value - 1) % 26;
      output = String.fromCharCode(65 + remainder) + output;
      value = (value - 1) ~/ 26;
    }
    return output;
  }

  static String _sheetName(String value) {
    final cleaned = value.replaceAll(RegExp(r'[\\/*?:\[\]]'), ' ').trim();
    final safe = cleaned.isEmpty ? 'Overview' : cleaned;
    return safe.length <= 31 ? safe : safe.substring(0, 31);
  }

  static String _safeFileName(String value) {
    final cleaned = value.replaceAll(RegExp(r'[<>:"/\\|?*]'), '_').trim();
    return cleaned.isEmpty ? 'Period' : cleaned;
  }

  static String _xmlEscape(String value) => value
      .replaceAll('&', '&amp;')
      .replaceAll('<', '&lt;')
      .replaceAll('>', '&gt;')
      .replaceAll('"', '&quot;')
      .replaceAll("'", '&apos;');
}
