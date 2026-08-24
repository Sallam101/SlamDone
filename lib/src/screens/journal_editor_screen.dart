import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../controllers/app_controller.dart';
import '../controllers/app_scope.dart';
import '../models/models.dart';
import '../services/word_export_service.dart';

class JournalEditorScreen extends StatefulWidget {
  const JournalEditorScreen({super.key, required this.entryId});
  final String entryId;
  @override
  State<JournalEditorScreen> createState() => _JournalEditorScreenState();
}

class _JournalEditorScreenState extends State<JournalEditorScreen> {
  final Map<String, TextEditingController> _answers = {};
  final _body = TextEditingController();
  final _folder = TextEditingController();
  Timer? _saveTimer;
  JournalEntry? _entry;
  AppController? _controller;
  final ValueNotifier<String> _status = ValueNotifier<String>('Loading…');
  bool _closing = false;
  bool _dirty = false;
  Future<void>? _saveInFlight;
  List<Map<String, dynamic>> _prompts = [];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  Future<void> _load() async {
    final controller = AppScope.read(context);
    _controller = controller;
    final entry =
        controller.journals
            .where((value) => value.id == widget.entryId)
            .firstOrNull ??
        await controller.database.getJournalById(widget.entryId);
    if (entry == null || !mounted) {
      return;
    }
    controller.beginJournalEdit(entry.id);
    _entry = entry;
    _prompts = controller.journalPrompts
        .map((item) => Map<String, dynamic>.from(item))
        .toList();
    final custom = entry.customAnswers;
    for (final prompt in _prompts) {
      final id = prompt['id'].toString();
      _answers[id] = TextEditingController(text: _valueFor(entry, id, custom));
      _answers[id]!.addListener(_queueSave);
    }
    _body.text = entry.body;
    _folder.text = entry.folder;
    _body.addListener(_queueSave);
    _folder.addListener(_queueSave);
    _status.value = 'Saved locally';
    if (mounted) {
      setState(() {});
    }
  }

  String _valueFor(JournalEntry entry, String id, Map<String, String> custom) =>
      switch (id) {
        'winBig' => entry.winBig,
        'feel' => entry.feel,
        'grateful' => entry.grateful,
        'regret' => entry.regret,
        'pretending' => entry.pretending,
        'flow' => entry.flow,
        'notTolerate' => entry.notTolerate,
        _ => custom[id] ?? '',
      };

  void _queueSave() {
    if (_entry == null || _closing) return;
    _dirty = true;
    _status.value = 'Editing…';
    _saveTimer?.cancel();
    _saveTimer = Timer(
      const Duration(milliseconds: 900),
      () => unawaited(_saveNow(notifyGlobal: false)),
    );
  }

  JournalEntry _draft() {
    final current = _entry!;
    final custom = <String, String>{};
    for (final entry in _answers.entries) {
      if (!const {
        'winBig',
        'feel',
        'grateful',
        'regret',
        'pretending',
        'flow',
        'notTolerate',
      }.contains(entry.key)) {
        custom[entry.key] = entry.value.text;
      }
    }
    String value(String id) => _answers[id]?.text ?? '';
    return current.copyWith(
      winBig: value('winBig'),
      feel: value('feel'),
      grateful: value('grateful'),
      regret: value('regret'),
      pretending: value('pretending'),
      flow: value('flow'),
      notTolerate: value('notTolerate'),
      body: _body.text,
      folder: _folder.text.trim(),
      customJson: jsonEncode(custom),
    );
  }

  Future<void> _saveNow({bool notifyGlobal = false}) async {
    _saveTimer?.cancel();
    final activeSave = _saveInFlight;
    if (activeSave != null) {
      await activeSave;
    }
    if (_entry == null || _controller == null || !_dirty) {
      return;
    }
    final draft = _draft();
    _dirty = false;
    if (mounted) _status.value = 'Saving locally…';

    final saveFuture = _performSave(draft, notifyGlobal: notifyGlobal);
    _saveInFlight = saveFuture;
    try {
      await saveFuture;
    } finally {
      if (identical(_saveInFlight, saveFuture)) {
        _saveInFlight = null;
      }
    }
  }

  Future<void> _performSave(
    JournalEntry draft, {
    required bool notifyGlobal,
  }) async {
    try {
      _entry = await _controller!.saveJournal(
        draft,
        notifyGlobal: notifyGlobal,
      );
      if (mounted) _status.value = 'Saved locally • sync queued';
    } catch (_) {
      _dirty = true;
      if (mounted) _status.value = 'Save waiting — keep this page open';
      rethrow;
    }
  }

  Future<void> _close() async {
    if (_closing) {
      return;
    }
    _closing = true;
    await _saveNow(notifyGlobal: false);
    if (_entry != null && _controller != null) {
      await _controller!.endJournalEdit(_entry!.id);
    }
    if (mounted) {
      Navigator.of(context).pop();
    }
  }

  @override
  void dispose() {
    _saveTimer?.cancel();
    for (final controller in _answers.values) {
      controller.dispose();
    }
    _body.dispose();
    _folder.dispose();
    _status.dispose();
    if (!_closing && _entry != null && _controller != null) {
      unawaited(_controller!.endJournalEdit(_entry!.id));
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final entry = _entry;
    if (entry == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    final date = DateTime.tryParse(entry.entryDate) ?? DateTime.now();
    return PopScope<Object?>(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) async {
        if (!didPop) {
          await _close();
        }
      },
      child: Scaffold(
        appBar: AppBar(
          title: Text('Journal — ${DateFormat('MMMM d, yyyy').format(date)}'),
          actions: [
            Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                child: ValueListenableBuilder<String>(
                  valueListenable: _status,
                  builder: (context, value, child) => Text(value),
                ),
              ),
            ),
            IconButton(
              tooltip: 'Export to Word',
              onPressed: () async {
                await _saveNow();
                final current = _entry;
                if (current == null) {
                  return;
                }
                final path = await WordExportService.exportJournal(
                  entry: current,
                  prompts: _prompts,
                );
                if (!mounted || path == null) {
                  return;
                }
                ScaffoldMessenger.of(this.context).showSnackBar(
                  SnackBar(content: Text('Word document saved to $path')),
                );
              },
              icon: const Icon(Icons.description_outlined),
            ),
            IconButton(
              tooltip: 'Snapshot',
              onPressed: () async {
                await _saveNow();
                if (_entry != null) await _controller!.snapshotJournal(_entry!);
              },
              icon: const Icon(Icons.save_outlined),
            ),
            IconButton(
              tooltip: entry.archived ? 'Restore' : 'Archive',
              onPressed: () async {
                _entry = await _controller!.saveJournal(
                  _draft().copyWith(archived: !entry.archived),
                );
                if (mounted) setState(() {});
              },
              icon: Icon(
                entry.archived
                    ? Icons.unarchive_outlined
                    : Icons.archive_outlined,
              ),
            ),
          ],
        ),
        body: ListView(
          padding: const EdgeInsets.fromLTRB(18, 12, 18, 70),
          children: [
            SizedBox(
              width: 320,
              child: TextField(
                controller: _folder,
                decoration: const InputDecoration(labelText: 'Folder'),
              ),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 12,
              runSpacing: 12,
              children: _prompts
                  .map((prompt) => _promptCard(context, prompt))
                  .toList(),
            ),
            const SizedBox(height: 12),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: TextField(
                  controller: _body,
                  minLines: 14,
                  maxLines: null,
                  decoration: const InputDecoration(
                    labelText: 'Free journal / brain dump',
                    alignLabelWithHint: true,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _promptCard(BuildContext context, Map<String, dynamic> prompt) {
    final id = prompt['id'].toString();
    final widthFactor = (prompt['width'] as num?)?.toDouble() ?? 0.5;
    final screen = MediaQuery.sizeOf(context).width - 48;
    final width = widthFactor >= 0.9
        ? screen
        : (screen / 2 - 18).clamp(280.0, 650.0).toDouble();
    return DragTarget<String>(
      onAcceptWithDetails: (details) {
        final oldIndex = _prompts.indexWhere(
          (item) => item['id'] == details.data,
        );
        final newIndex = _prompts.indexWhere((item) => item['id'] == id);
        if (oldIndex < 0 || newIndex < 0 || oldIndex == newIndex) {
          return;
        }
        setState(() {
          final moved = _prompts.removeAt(oldIndex);
          _prompts.insert(newIndex, moved);
        });
        _controller?.saveJournalPrompts(_prompts);
      },
      builder: (context, candidates, rejected) => SizedBox(
        width: width,
        child: Card(
          color: candidates.isNotEmpty
              ? Theme.of(context).colorScheme.primaryContainer
              : null,
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Draggable<String>(
                      data: id,
                      feedback: Material(
                        child: Chip(label: Text(prompt['question'].toString())),
                      ),
                      child: const Icon(Icons.drag_indicator),
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        prompt['question'].toString(),
                        style: const TextStyle(fontWeight: FontWeight.w800),
                      ),
                    ),
                    IconButton(
                      tooltip: 'Toggle full/half width',
                      onPressed: () {
                        setState(
                          () =>
                              prompt['width'] = widthFactor >= 0.9 ? 0.5 : 1.0,
                        );
                        _controller?.saveJournalPrompts(_prompts);
                      },
                      icon: const Icon(Icons.aspect_ratio, size: 18),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: _answers[id],
                  minLines: 4,
                  maxLines: null,
                  decoration: const InputDecoration(hintText: 'Write here…'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
