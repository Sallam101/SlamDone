import 'dart:convert';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:file_picker/file_picker.dart';
import 'package:intl/intl.dart';

import '../models/models.dart';

/// Creates simple, standards-compliant Word documents without requiring
/// Microsoft Word to be installed. The generated files contain the complete
/// journal or NorthStar text and, when present, the NorthStar image.
class WordExportService {
  const WordExportService._();

  static Future<String?> exportJournal({
    required JournalEntry entry,
    required List<Map<String, dynamic>> prompts,
  }) async {
    final date = DateTime.tryParse(entry.entryDate) ?? DateTime.now();
    final blocks = <_DocBlock>[
      _DocBlock.heading1(
        'Journal - ${DateFormat('MMMM d, yyyy').format(date)}',
      ),
      if (entry.folder.trim().isNotEmpty)
        _DocBlock.paragraph('Folder: ${entry.folder.trim()}'),
    ];

    final custom = entry.customAnswers;
    for (final prompt in prompts) {
      final id = prompt['id']?.toString() ?? '';
      final question = prompt['question']?.toString().trim() ?? '';
      if (question.isEmpty) continue;
      final answer = _journalAnswer(entry, custom, id).trim();
      blocks.add(_DocBlock.heading2(question));
      blocks.add(
        _DocBlock.paragraph(answer.isEmpty ? '(No response)' : answer),
      );
    }

    blocks.add(_DocBlock.heading2('Free journal / brain dump'));
    blocks.add(
      _DocBlock.paragraph(
        entry.body.trim().isEmpty ? '(No journal body)' : entry.body.trim(),
      ),
    );

    final fileName = 'Journal_${entry.entryDate}.docx';
    return _saveDocx(fileName: fileName, blocks: blocks);
  }

  static Future<String?> exportJournalCollection({
    required List<JournalEntry> entries,
    required List<Map<String, dynamic>> prompts,
    String fileName = 'SupeSlam_Journal_All.docx',
  }) async {
    final sorted = entries.where((entry) => entry.deletedAt == null).toList()
      ..sort((a, b) => a.entryDate.compareTo(b.entryDate));
    final blocks = <_DocBlock>[
      _DocBlock.heading1('SupeSlam Journal Collection'),
      _DocBlock.paragraph(
        'Exported ${DateFormat('MMMM d, yyyy - h:mm a').format(DateTime.now())}',
      ),
    ];
    for (var index = 0; index < sorted.length; index++) {
      final entry = sorted[index];
      final date = DateTime.tryParse(entry.entryDate) ?? DateTime.now();
      if (index > 0) blocks.add(_DocBlock.pageBreak());
      blocks.add(
        _DocBlock.heading1(DateFormat('EEEE, MMMM d, yyyy').format(date)),
      );
      if (entry.folder.trim().isNotEmpty) {
        blocks.add(_DocBlock.paragraph('Folder: ${entry.folder.trim()}'));
      }
      if (entry.archived) blocks.add(_DocBlock.paragraph('Status: Archived'));
      final custom = entry.customAnswers;
      for (final prompt in prompts) {
        final id = prompt['id']?.toString() ?? '';
        final question = prompt['question']?.toString().trim() ?? '';
        if (question.isEmpty) continue;
        final answer = _journalAnswer(entry, custom, id).trim();
        blocks.add(_DocBlock.heading2(question));
        blocks.add(
          _DocBlock.paragraph(answer.isEmpty ? '(No response)' : answer),
        );
      }
      blocks.add(_DocBlock.heading2('Free journal / brain dump'));
      blocks.add(
        _DocBlock.paragraph(
          entry.body.trim().isEmpty ? '(No journal body)' : entry.body.trim(),
        ),
      );
    }
    return _saveDocx(fileName: fileName, blocks: blocks);
  }

  static Future<String?> exportJournalBulkZip({
    required List<JournalEntry> entries,
    required List<Map<String, dynamic>> prompts,
  }) async {
    final sorted = entries.where((entry) => entry.deletedAt == null).toList()
      ..sort((a, b) => a.entryDate.compareTo(b.entryDate));
    final archive = Archive();
    for (final entry in sorted) {
      final blocks = _journalBlocks(entry, prompts);
      final bytes = _buildDocx(blocks);
      final fileName = 'Journal_${_safeFileName(entry.entryDate)}.docx';
      archive.addFile(ArchiveFile(fileName, bytes.length, bytes));
    }
    final combinedBlocks = <_DocBlock>[
      _DocBlock.heading1('SupeSlam Journal Collection'),
      _DocBlock.paragraph(
        'Exported ${DateFormat('MMMM d, yyyy - h:mm a').format(DateTime.now())}',
      ),
    ];
    for (var index = 0; index < sorted.length; index++) {
      if (index > 0) combinedBlocks.add(_DocBlock.pageBreak());
      combinedBlocks.addAll(_journalBlocks(sorted[index], prompts));
    }
    final combinedBytes = _buildDocx(combinedBlocks);
    archive.addFile(
      ArchiveFile(
        'SupeSlam_Journal_All.docx',
        combinedBytes.length,
        combinedBytes,
      ),
    );
    final zipBytes = Uint8List.fromList(ZipEncoder().encodeBytes(archive));
    final path = await FilePicker.saveFile(
      dialogTitle: 'Export all journal Word files',
      fileName: 'SupeSlam_Journal_Word_Files.zip',
      type: FileType.custom,
      allowedExtensions: const ['zip'],
      bytes: zipBytes,
    );
    return path?.toString();
  }

  static List<_DocBlock> _journalBlocks(
    JournalEntry entry,
    List<Map<String, dynamic>> prompts,
  ) {
    final date = DateTime.tryParse(entry.entryDate) ?? DateTime.now();
    final blocks = <_DocBlock>[
      _DocBlock.heading1(DateFormat('EEEE, MMMM d, yyyy').format(date)),
      if (entry.folder.trim().isNotEmpty)
        _DocBlock.paragraph('Folder: ${entry.folder.trim()}'),
      if (entry.archived) _DocBlock.paragraph('Status: Archived'),
    ];
    final custom = entry.customAnswers;
    for (final prompt in prompts) {
      final id = prompt['id']?.toString() ?? '';
      final question = prompt['question']?.toString().trim() ?? '';
      if (question.isEmpty) continue;
      final answer = _journalAnswer(entry, custom, id).trim();
      blocks.add(_DocBlock.heading2(question));
      blocks.add(
        _DocBlock.paragraph(answer.isEmpty ? '(No response)' : answer),
      );
    }
    blocks.add(_DocBlock.heading2('Free journal / brain dump'));
    blocks.add(
      _DocBlock.paragraph(
        entry.body.trim().isEmpty ? '(No journal body)' : entry.body.trim(),
      ),
    );
    return blocks;
  }

  static Future<String?> exportNorthStarNote(NorthStarNote note) async {
    final blocks = _northStarBlocks(note, includeSeparator: false);
    final fileName = '${_safeFileName(note.title)}_NorthStar.docx';
    return _saveDocx(fileName: fileName, blocks: blocks);
  }

  static Future<String?> exportNorthStarCollection(
    List<NorthStarNote> notes,
  ) async {
    final blocks = <_DocBlock>[
      _DocBlock.heading1('SupeSlam NorthStar'),
      _DocBlock.paragraph(
        'Exported ${DateFormat('MMMM d, yyyy - h:mm a').format(DateTime.now())}',
      ),
    ];
    final visible = notes.where((note) => note.deletedAt == null).toList()
      ..sort(
        (a, b) => a.pinned == b.pinned
            ? a.sortKey.compareTo(b.sortKey)
            : (a.pinned ? -1 : 1),
      );
    for (var index = 0; index < visible.length; index++) {
      blocks.addAll(
        _northStarBlocks(visible[index], includeSeparator: index > 0),
      );
    }
    return _saveDocx(
      fileName: 'SupeSlam_NorthStar_Export.docx',
      blocks: blocks,
    );
  }

  static List<_DocBlock> _northStarBlocks(
    NorthStarNote note, {
    required bool includeSeparator,
  }) {
    final blocks = <_DocBlock>[
      if (includeSeparator) _DocBlock.pageBreak(),
      _DocBlock.heading1(
        note.title.trim().isEmpty ? 'NorthStar note' : note.title.trim(),
      ),
      if (note.folder.trim().isNotEmpty)
        _DocBlock.paragraph('Folder: ${note.folder.trim()}'),
      if (note.body.trim().isNotEmpty) _DocBlock.paragraph(note.body.trim()),
    ];

    if (note.imageBase64.isNotEmpty) {
      try {
        blocks.add(_DocBlock.image(base64Decode(note.imageBase64)));
      } catch (_) {
        blocks.add(
          _DocBlock.paragraph('[The stored image could not be decoded.]'),
        );
      }
    }

    try {
      final checklist = (jsonDecode(note.checklistJson) as List)
          .whereType<Map>()
          .map((value) => value.cast<String, dynamic>())
          .toList();
      if (checklist.isNotEmpty) {
        blocks.add(_DocBlock.heading2('Checklist'));
        for (final item in checklist) {
          final marker = item['done'] == true ? '☑' : '☐';
          blocks.add(
            _DocBlock.paragraph('$marker ${item['text']?.toString() ?? ''}'),
          );
        }
      }
    } catch (_) {}

    if (note.link.trim().isNotEmpty) {
      blocks.add(_DocBlock.heading2('Link'));
      blocks.add(_DocBlock.paragraph(note.link.trim()));
    }
    return blocks;
  }

  static String _journalAnswer(
    JournalEntry entry,
    Map<String, String> custom,
    String id,
  ) => switch (id) {
    'winBig' => entry.winBig,
    'feel' => entry.feel,
    'grateful' => entry.grateful,
    'regret' => entry.regret,
    'pretending' => entry.pretending,
    'flow' => entry.flow,
    'notTolerate' => entry.notTolerate,
    _ => custom[id] ?? '',
  };

  static Future<String?> _saveDocx({
    required String fileName,
    required List<_DocBlock> blocks,
  }) async {
    final bytes = _buildDocx(blocks);
    final path = await FilePicker.saveFile(
      dialogTitle: 'Export Word document',
      fileName: fileName,
      type: FileType.custom,
      allowedExtensions: const ['docx'],
      bytes: bytes,
    );
    return path?.toString();
  }

  static Uint8List _buildDocx(List<_DocBlock> blocks) {
    final media = <_DocImage>[];
    final body = StringBuffer();
    var imageIndex = 1;
    for (final block in blocks) {
      switch (block.kind) {
        case _DocBlockKind.heading1:
          body.write(_paragraphXml(block.text, style: 'Heading1'));
          break;
        case _DocBlockKind.heading2:
          body.write(_paragraphXml(block.text, style: 'Heading2'));
          break;
        case _DocBlockKind.paragraph:
          final lines = block.text.replaceAll('\r\n', '\n').split('\n');
          for (final line in lines) {
            body.write(_paragraphXml(line.isEmpty ? ' ' : line));
          }
          break;
        case _DocBlockKind.pageBreak:
          body.write('<w:p><w:r><w:br w:type="page"/></w:r></w:p>');
          break;
        case _DocBlockKind.image:
          final image = _DocImage.fromBytes(block.bytes!, imageIndex++);
          media.add(image);
          body.write(_imageParagraphXml(image));
          break;
      }
    }

    final relationships = StringBuffer();
    for (final image in media) {
      relationships.write(
        '<Relationship Id="${image.relationshipId}" '
        'Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/image" '
        'Target="media/${image.fileName}"/>',
      );
    }

    final documentXml =
        '''<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<w:document xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main"
 xmlns:r="http://schemas.openxmlformats.org/officeDocument/2006/relationships"
 xmlns:wp="http://schemas.openxmlformats.org/drawingml/2006/wordprocessingDrawing"
 xmlns:a="http://schemas.openxmlformats.org/drawingml/2006/main"
 xmlns:pic="http://schemas.openxmlformats.org/drawingml/2006/picture">
<w:body>${body.toString()}<w:sectPr><w:pgSz w:w="12240" w:h="15840"/><w:pgMar w:top="1080" w:right="1080" w:bottom="1080" w:left="1080"/></w:sectPr></w:body></w:document>''';

    final archive = Archive();
    void addText(String name, String value) {
      final data = utf8.encode(value);
      archive.addFile(ArchiveFile(name, data.length, data));
    }

    addText(
      '[Content_Types].xml',
      '''<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<Types xmlns="http://schemas.openxmlformats.org/package/2006/content-types">
<Default Extension="rels" ContentType="application/vnd.openxmlformats-package.relationships+xml"/>
<Default Extension="xml" ContentType="application/xml"/>
<Default Extension="png" ContentType="image/png"/>
<Default Extension="jpg" ContentType="image/jpeg"/>
<Default Extension="jpeg" ContentType="image/jpeg"/>
<Override PartName="/word/document.xml" ContentType="application/vnd.openxmlformats-officedocument.wordprocessingml.document.main+xml"/>
<Override PartName="/word/styles.xml" ContentType="application/vnd.openxmlformats-officedocument.wordprocessingml.styles+xml"/>
</Types>''',
    );
    addText(
      '_rels/.rels',
      '''<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">
<Relationship Id="rId1" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/officeDocument" Target="word/document.xml"/>
</Relationships>''',
    );
    addText('word/document.xml', documentXml);
    addText(
      'word/_rels/document.xml.rels',
      '''<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">
<Relationship Id="rIdStyles" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/styles" Target="styles.xml"/>
${relationships.toString()}</Relationships>''',
    );
    addText('word/styles.xml', _stylesXml);
    for (final image in media) {
      archive.addFile(
        ArchiveFile(
          'word/media/${image.fileName}',
          image.bytes.length,
          image.bytes,
        ),
      );
    }
    return ZipEncoder().encodeBytes(archive);
  }

  static String _paragraphXml(String text, {String? style}) {
    final escaped = _xmlEscape(text);
    final styleXml = style == null
        ? ''
        : '<w:pPr><w:pStyle w:val="$style"/></w:pPr>';
    return '<w:p>$styleXml<w:r><w:t xml:space="preserve">$escaped</w:t></w:r></w:p>';
  }

  static String _imageParagraphXml(_DocImage image) {
    const cx = 5486400;
    const cy = 3200400;
    return '''<w:p><w:r><w:drawing><wp:inline distT="0" distB="0" distL="0" distR="0">
<wp:extent cx="$cx" cy="$cy"/><wp:docPr id="${image.index}" name="NorthStar image ${image.index}"/>
<a:graphic><a:graphicData uri="http://schemas.openxmlformats.org/drawingml/2006/picture">
<pic:pic><pic:nvPicPr><pic:cNvPr id="${image.index}" name="${image.fileName}"/><pic:cNvPicPr/></pic:nvPicPr>
<pic:blipFill><a:blip r:embed="${image.relationshipId}"/><a:stretch><a:fillRect/></a:stretch></pic:blipFill>
<pic:spPr><a:xfrm><a:off x="0" y="0"/><a:ext cx="$cx" cy="$cy"/></a:xfrm><a:prstGeom prst="rect"><a:avLst/></a:prstGeom></pic:spPr>
</pic:pic></a:graphicData></a:graphic></wp:inline></w:drawing></w:r></w:p>''';
  }

  static String _xmlEscape(String value) => value
      .replaceAll('&', '&amp;')
      .replaceAll('<', '&lt;')
      .replaceAll('>', '&gt;')
      .replaceAll('"', '&quot;')
      .replaceAll("'", '&apos;');

  static String _safeFileName(String value) {
    final cleaned = value.replaceAll(RegExp(r'[<>:"/\\|?*]'), '_').trim();
    return cleaned.isEmpty ? 'NorthStar' : cleaned;
  }
}

enum _DocBlockKind { heading1, heading2, paragraph, pageBreak, image }

class _DocBlock {
  const _DocBlock._(this.kind, {this.text = '', this.bytes});

  factory _DocBlock.heading1(String value) =>
      _DocBlock._(_DocBlockKind.heading1, text: value);
  factory _DocBlock.heading2(String value) =>
      _DocBlock._(_DocBlockKind.heading2, text: value);
  factory _DocBlock.paragraph(String value) =>
      _DocBlock._(_DocBlockKind.paragraph, text: value);
  factory _DocBlock.pageBreak() => const _DocBlock._(_DocBlockKind.pageBreak);
  factory _DocBlock.image(Uint8List bytes) =>
      _DocBlock._(_DocBlockKind.image, bytes: bytes);

  final _DocBlockKind kind;
  final String text;
  final Uint8List? bytes;
}

class _DocImage {
  const _DocImage({
    required this.index,
    required this.fileName,
    required this.relationshipId,
    required this.bytes,
  });

  factory _DocImage.fromBytes(Uint8List bytes, int index) {
    final isPng =
        bytes.length >= 8 &&
        bytes[0] == 0x89 &&
        bytes[1] == 0x50 &&
        bytes[2] == 0x4E &&
        bytes[3] == 0x47;
    return _DocImage(
      index: index,
      fileName: 'northstar_$index.${isPng ? 'png' : 'jpg'}',
      relationshipId: 'rIdImage$index',
      bytes: bytes,
    );
  }

  final int index;
  final String fileName;
  final String relationshipId;
  final Uint8List bytes;
}

const _stylesXml = '''<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<w:styles xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main">
<w:style w:type="paragraph" w:default="1" w:styleId="Normal"><w:name w:val="Normal"/><w:rPr><w:rFonts w:ascii="Aptos" w:hAnsi="Aptos"/><w:sz w:val="22"/></w:rPr></w:style>
<w:style w:type="paragraph" w:styleId="Heading1"><w:name w:val="heading 1"/><w:basedOn w:val="Normal"/><w:next w:val="Normal"/><w:qFormat/><w:pPr><w:spacing w:before="240" w:after="120"/></w:pPr><w:rPr><w:b/><w:sz w:val="34"/></w:rPr></w:style>
<w:style w:type="paragraph" w:styleId="Heading2"><w:name w:val="heading 2"/><w:basedOn w:val="Normal"/><w:next w:val="Normal"/><w:qFormat/><w:pPr><w:spacing w:before="180" w:after="80"/></w:pPr><w:rPr><w:b/><w:sz w:val="26"/></w:rPr></w:style>
</w:styles>''';
