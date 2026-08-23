import 'dart:convert';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:file_picker/file_picker.dart';

/// Writes a compact standards-compliant .xlsx workbook without requiring
/// Microsoft Excel to be installed. Text is stored as inline strings so the
/// workbook is resilient to long cell content.
class SpreadsheetExportService {
  const SpreadsheetExportService._();

  static Future<String?> exportTable({
    required String title,
    required List<String> columns,
    required List<List<String>> rows,
    required List<double> columnWidths,
    required double fontSize,
    required bool wrapText,
  }) async {
    final fileName = '${_safeFileName(title)}.xlsx';
    final bytes = _buildWorkbook(
      title: title,
      columns: columns,
      rows: rows,
      columnWidths: columnWidths,
      fontSize: fontSize,
      wrapText: wrapText,
    );
    final path = await FilePicker.saveFile(
      dialogTitle: 'Export Excel workbook',
      fileName: fileName,
      type: FileType.custom,
      allowedExtensions: const ['xlsx'],
      bytes: bytes,
    );
    return path?.toString();
  }

  static Uint8List _buildWorkbook({
    required String title,
    required List<String> columns,
    required List<List<String>> rows,
    required List<double> columnWidths,
    required double fontSize,
    required bool wrapText,
  }) {
    final archive = Archive();
    void addText(String name, String value) {
      final data = utf8.encode(value);
      archive.addFile(ArchiveFile(name, data.length, data));
    }

    final cols = StringBuffer('<cols>');
    for (var i = 0; i < columns.length; i++) {
      final pixels = i < columnWidths.length ? columnWidths[i] : 160.0;
      final excelWidth = (pixels / 7).clamp(8.0, 80.0).toStringAsFixed(2);
      cols.write(
        '<col min="${i + 1}" max="${i + 1}" width="$excelWidth" customWidth="1"/>',
      );
    }
    cols.write('</cols>');

    final sheetRows = StringBuffer();
    sheetRows.write(_rowXml(1, columns, style: 1));
    for (var rowIndex = 0; rowIndex < rows.length; rowIndex++) {
      final row = List<String>.generate(
        columns.length,
        (index) => index < rows[rowIndex].length ? rows[rowIndex][index] : '',
      );
      sheetRows.write(_rowXml(rowIndex + 2, row, style: 0));
    }

    addText(
      '[Content_Types].xml',
      '''<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<Types xmlns="http://schemas.openxmlformats.org/package/2006/content-types">
<Default Extension="rels" ContentType="application/vnd.openxmlformats-package.relationships+xml"/>
<Default Extension="xml" ContentType="application/xml"/>
<Override PartName="/xl/workbook.xml" ContentType="application/vnd.openxmlformats-officedocument.spreadsheetml.sheet.main+xml"/>
<Override PartName="/xl/worksheets/sheet1.xml" ContentType="application/vnd.openxmlformats-officedocument.spreadsheetml.worksheet+xml"/>
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
<workbook xmlns="http://schemas.openxmlformats.org/spreadsheetml/2006/main" xmlns:r="http://schemas.openxmlformats.org/officeDocument/2006/relationships">
<sheets><sheet name="${_xmlEscape(_sheetName(title))}" sheetId="1" r:id="rId1"/></sheets>
</workbook>''',
    );
    addText(
      'xl/_rels/workbook.xml.rels',
      '''<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">
<Relationship Id="rId1" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/worksheet" Target="worksheets/sheet1.xml"/>
<Relationship Id="rId2" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/styles" Target="styles.xml"/>
</Relationships>''',
    );
    addText(
      'xl/worksheets/sheet1.xml',
      '''<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<worksheet xmlns="http://schemas.openxmlformats.org/spreadsheetml/2006/main">
<sheetViews><sheetView workbookViewId="0"><pane ySplit="1" topLeftCell="A2" activePane="bottomLeft" state="frozen"/></sheetView></sheetViews>
${cols.toString()}<sheetData>${sheetRows.toString()}</sheetData>
<autoFilter ref="A1:${_columnName(columns.length)}${rows.length + 1}"/>
</worksheet>''',
    );
    final size = fontSize.clamp(8.0, 32.0).toStringAsFixed(1);
    addText(
      'xl/styles.xml',
      '''<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<styleSheet xmlns="http://schemas.openxmlformats.org/spreadsheetml/2006/main">
<fonts count="2"><font><sz val="$size"/><name val="Aptos"/></font><font><b/><sz val="$size"/><name val="Aptos"/></font></fonts>
<fills count="2"><fill><patternFill patternType="none"/></fill><fill><patternFill patternType="gray125"/></fill></fills>
<borders count="1"><border><left/><right/><top/><bottom/><diagonal/></border></borders>
<cellStyleXfs count="1"><xf numFmtId="0" fontId="0" fillId="0" borderId="0"/></cellStyleXfs>
<cellXfs count="2"><xf numFmtId="0" fontId="0" fillId="0" borderId="0" xfId="0" applyAlignment="1"><alignment vertical="top" wrapText="${wrapText ? 1 : 0}"/></xf><xf numFmtId="0" fontId="1" fillId="0" borderId="0" xfId="0" applyAlignment="1"><alignment vertical="top" wrapText="1"/></xf></cellXfs>
<cellStyles count="1"><cellStyle name="Normal" xfId="0" builtinId="0"/></cellStyles>
</styleSheet>''',
    );
    final now = DateTime.now().toUtc().toIso8601String();
    addText(
      'docProps/core.xml',
      '''<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<cp:coreProperties xmlns:cp="http://schemas.openxmlformats.org/package/2006/metadata/core-properties" xmlns:dc="http://purl.org/dc/elements/1.1/" xmlns:dcterms="http://purl.org/dc/terms/" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance"><dc:title>${_xmlEscape(title)}</dc:title><dc:creator>SupeSlam</dc:creator><dcterms:created xsi:type="dcterms:W3CDTF">$now</dcterms:created></cp:coreProperties>''',
    );
    addText(
      'docProps/app.xml',
      '''<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<Properties xmlns="http://schemas.openxmlformats.org/officeDocument/2006/extended-properties"><Application>SupeSlam</Application></Properties>''',
    );
    return ZipEncoder().encodeBytes(archive);
  }

  static String _rowXml(int number, List<String> cells, {required int style}) {
    final buffer = StringBuffer('<row r="$number">');
    for (var i = 0; i < cells.length; i++) {
      buffer.write(
        '<c r="${_columnName(i + 1)}$number" t="inlineStr" s="$style"><is><t xml:space="preserve">${_xmlEscape(cells[i])}</t></is></c>',
      );
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
    final safe = cleaned.isEmpty ? 'Study Table' : cleaned;
    return safe.length <= 31 ? safe : safe.substring(0, 31);
  }

  static String _safeFileName(String value) {
    final cleaned = value.replaceAll(RegExp(r'[<>:"/\\|?*]'), '_').trim();
    return cleaned.isEmpty ? 'SupeSlam_Study_Table' : cleaned;
  }

  static String _xmlEscape(String value) => value
      .replaceAll('&', '&amp;')
      .replaceAll('<', '&lt;')
      .replaceAll('>', '&gt;')
      .replaceAll('"', '&quot;')
      .replaceAll("'", '&apos;');
}
