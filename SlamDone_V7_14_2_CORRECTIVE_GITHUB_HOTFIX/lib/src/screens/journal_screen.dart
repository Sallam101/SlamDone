import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../controllers/app_scope.dart';
import '../models/models.dart';
import '../services/word_export_service.dart';
import 'journal_editor_screen.dart';

enum JournalPeriodFilter { week, month, year, all }
enum JournalViewMode { large, medium, small, list }

class JournalScreen extends StatefulWidget {
  const JournalScreen({super.key});

  @override
  State<JournalScreen> createState() => _JournalScreenState();
}

class _JournalScreenState extends State<JournalScreen> {
  bool _showArchived = false;
  bool _mobileControlsVisible = false;
  String _folder = 'All';
  JournalPeriodFilter _period = JournalPeriodFilter.month;
  JournalViewMode _viewMode = JournalViewMode.medium;
  DateTime _anchorDate = DateTime.now();

  @override
  Widget build(BuildContext context) {
    final controller = AppScope.of(context);
    final mobile = MediaQuery.sizeOf(context).width < 700;
    final folders = {
      'All',
      ...controller.journals
          .map((entry) => entry.folder)
          .where((value) => value.isNotEmpty),
    }.toList()..sort();

    final entries = controller.journals.where((entry) {
      if (entry.deletedAt != null) return false;
      if (!_showArchived && entry.archived) return false;
      if (_folder != 'All' && entry.folder != _folder) return false;
      final date = DateTime.tryParse(entry.entryDate);
      if (date == null) return _period == JournalPeriodFilter.all;
      return _matchesPeriod(date);
    }).toList()
      ..sort((a, b) => b.entryDate.compareTo(a.entryDate));

    return Padding(
      padding: const EdgeInsets.all(12),
      child: Column(
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.menu_book_outlined),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Journal',
                              style: Theme.of(context).textTheme.titleLarge,
                            ),
                            if (!mobile)
                              const Text(
                                'Filter your Brain Dumping by time, then choose the card size that keeps review fast.',
                              ),
                          ],
                        ),
                      ),
                      if (mobile)
                        IconButton.filledTonal(
                          tooltip: 'Journal controls',
                          onPressed: () => setState(
                            () => _mobileControlsVisible = !_mobileControlsVisible,
                          ),
                          icon: Icon(
                            _mobileControlsVisible
                                ? Icons.tune
                                : Icons.tune_outlined,
                          ),
                        ),
                      const SizedBox(width: 6),
                      mobile
                          ? IconButton.filled(
                              tooltip: 'Today',
                              onPressed: () => _openDate(context, DateTime.now()),
                              icon: const Icon(Icons.today),
                            )
                          : FilledButton.icon(
                              onPressed: () => _openDate(context, DateTime.now()),
                              icon: const Icon(Icons.today),
                              label: const Text('Today'),
                            ),
                    ],
                  ),
                  if (!mobile || _mobileControlsVisible) ...[
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      SegmentedButton<JournalPeriodFilter>(
                        showSelectedIcon: false,
                        segments: const [
                          ButtonSegment(
                            value: JournalPeriodFilter.week,
                            label: Text('Week'),
                          ),
                          ButtonSegment(
                            value: JournalPeriodFilter.month,
                            label: Text('Month'),
                          ),
                          ButtonSegment(
                            value: JournalPeriodFilter.year,
                            label: Text('Year'),
                          ),
                          ButtonSegment(
                            value: JournalPeriodFilter.all,
                            label: Text('All'),
                          ),
                        ],
                        selected: {_period},
                        onSelectionChanged: (selection) =>
                            setState(() => _period = selection.first),
                      ),
                      IconButton.filledTonal(
                        tooltip: 'Previous period',
                        onPressed: _period == JournalPeriodFilter.all
                            ? null
                            : () => _movePeriod(-1),
                        icon: const Icon(Icons.chevron_left),
                      ),
                      ConstrainedBox(
                        constraints: const BoxConstraints(minWidth: 150),
                        child: Text(
                          _periodLabel(),
                          textAlign: TextAlign.center,
                          style: const TextStyle(fontWeight: FontWeight.w800),
                        ),
                      ),
                      IconButton.filledTonal(
                        tooltip: 'Next period',
                        onPressed: _period == JournalPeriodFilter.all
                            ? null
                            : () => _movePeriod(1),
                        icon: const Icon(Icons.chevron_right),
                      ),
                      SizedBox(
                        width: 150,
                        child: DropdownButtonFormField<String>(
                          initialValue: _folder,
                          isDense: true,
                          decoration: const InputDecoration(labelText: 'Folder'),
                          items: folders
                              .map(
                                (value) => DropdownMenuItem(
                                  value: value,
                                  child: Text(value),
                                ),
                              )
                              .toList(),
                          onChanged: (value) =>
                              setState(() => _folder = value ?? 'All'),
                        ),
                      ),
                      FilterChip(
                        avatar: const Icon(Icons.archive_outlined, size: 17),
                        label: const Text('Archived'),
                        selected: _showArchived,
                        onSelected: (value) =>
                            setState(() => _showArchived = value),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      SegmentedButton<JournalViewMode>(
                        showSelectedIcon: false,
                        segments: const [
                          ButtonSegment(
                            value: JournalViewMode.large,
                            icon: Icon(Icons.crop_square),
                            tooltip: 'Large cards',
                          ),
                          ButtonSegment(
                            value: JournalViewMode.medium,
                            icon: Icon(Icons.grid_view),
                            tooltip: 'Medium cards',
                          ),
                          ButtonSegment(
                            value: JournalViewMode.small,
                            icon: Icon(Icons.apps),
                            tooltip: 'Small cards',
                          ),
                          ButtonSegment(
                            value: JournalViewMode.list,
                            icon: Icon(Icons.view_list),
                            tooltip: 'List view',
                          ),
                        ],
                        selected: {_viewMode},
                        onSelectionChanged: (selection) =>
                            setState(() => _viewMode = selection.first),
                      ),
                      Text(
                        '${entries.length} page${entries.length == 1 ? '' : 's'}',
                        style: Theme.of(context).textTheme.labelLarge,
                      ),
                      OutlinedButton.icon(
                        onPressed: controller.journals.isEmpty
                            ? null
                            : () => _exportAll(context),
                        icon: const Icon(Icons.library_books_outlined),
                        label: const Text('Export Word files'),
                      ),
                      FilledButton.tonalIcon(
                        onPressed: () async {
                          final picked = await showDatePicker(
                            context: context,
                            firstDate: DateTime(2020),
                            lastDate: DateTime(2100),
                            initialDate: _anchorDate,
                          );
                          if (picked != null && context.mounted) {
                            await _openDate(context, picked);
                          }
                        },
                        icon: const Icon(Icons.note_add_outlined),
                        label: const Text('New page'),
                      ),
                    ],
                  ),
                  ],
                ],
              ),
            ),
          ),
          const SizedBox(height: 10),
          Expanded(
            child: entries.isEmpty
                ? Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.auto_stories_outlined, size: 42),
                        const SizedBox(height: 8),
                        Text('No journal pages in ${_periodLabel()}.'),
                        const SizedBox(height: 10),
                        FilledButton.icon(
                          onPressed: () => _openDate(context, DateTime.now()),
                          icon: const Icon(Icons.edit_note),
                          label: const Text('Write today’s page'),
                        ),
                      ],
                    ),
                  )
                : _viewMode == JournalViewMode.list
                    ? _buildList(entries)
                    : _buildGrid(entries),
          ),
        ],
      ),
    );
  }

  Widget _buildList(List<JournalEntry> entries) {
    return ListView.separated(
      itemCount: entries.length,
      separatorBuilder: (_, __) => const SizedBox(height: 7),
      itemBuilder: (context, index) => _journalCard(entries[index], list: true),
    );
  }

  Widget _buildGrid(List<JournalEntry> entries) {
    final maxExtent = switch (_viewMode) {
      JournalViewMode.large => 680.0,
      JournalViewMode.medium => 440.0,
      JournalViewMode.small => 300.0,
      JournalViewMode.list => 680.0,
    };
    final height = switch (_viewMode) {
      JournalViewMode.large => 238.0,
      JournalViewMode.medium => 196.0,
      JournalViewMode.small => 154.0,
      JournalViewMode.list => 120.0,
    };
    return GridView.builder(
      gridDelegate: SliverGridDelegateWithMaxCrossAxisExtent(
        maxCrossAxisExtent: maxExtent,
        mainAxisExtent: height,
        crossAxisSpacing: 9,
        mainAxisSpacing: 9,
      ),
      itemCount: entries.length,
      itemBuilder: (context, index) => _journalCard(entries[index]),
    );
  }

  Widget _journalCard(JournalEntry entry, {bool list = false}) {
    final date = DateTime.tryParse(entry.entryDate) ?? DateTime.now();
    final preview = [
      entry.winBig,
      entry.feel,
      entry.grateful,
      entry.body,
      entry.regret,
    ].firstWhere(
      (value) => value.trim().isNotEmpty,
      orElse: () => 'Empty journal page',
    );
    final compact = _viewMode == JournalViewMode.small;
    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => _openEntry(entry),
        child: Padding(
          padding: EdgeInsets.all(compact ? 10 : 14),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (list || !compact) ...[
                CircleAvatar(
                  radius: compact ? 18 : 22,
                  child: Text(DateFormat('d').format(date)),
                ),
                const SizedBox(width: 11),
              ],
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            compact
                                ? DateFormat('MMM d, yyyy').format(date)
                                : DateFormat('EEEE, MMMM d, yyyy').format(date),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontWeight: FontWeight.w900,
                              fontSize: compact ? 13 : 15,
                            ),
                          ),
                        ),
                        _entryMenu(entry),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Wrap(
                      spacing: 6,
                      runSpacing: 4,
                      children: [
                        _metaChip(entry.folder.isEmpty ? 'Journal' : entry.folder),
                        if (entry.archived) _metaChip('Archived'),
                      ],
                    ),
                    const SizedBox(height: 7),
                    Expanded(
                      child: Text(
                        preview,
                        maxLines: list ? 2 : (compact ? 4 : 7),
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          height: 1.28,
                          fontSize: compact ? 12 : 13.5,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _metaChip(String label) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surfaceContainerHigh,
          borderRadius: BorderRadius.circular(999),
        ),
        child: Text(label, style: const TextStyle(fontSize: 10.5)),
      );

  Widget _entryMenu(JournalEntry entry) => PopupMenuButton<String>(
        padding: EdgeInsets.zero,
        onSelected: (value) async {
          if (value == 'archive') {
            await AppScope.read(context).saveJournal(
              entry.copyWith(archived: !entry.archived),
            );
          } else if (value == 'delete') {
            final confirmed = await showDialog<bool>(
              context: context,
              builder: (dialogContext) => AlertDialog(
                title: const Text('Delete journal page?'),
                content: Text(
                  'Delete the journal page for ${entry.entryDate}? This removes it from your journal views.',
                ),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(dialogContext, false),
                    child: const Text('Cancel'),
                  ),
                  FilledButton(
                    onPressed: () => Navigator.pop(dialogContext, true),
                    child: const Text('Delete'),
                  ),
                ],
              ),
            );
            if (confirmed == true && context.mounted) {
              await AppScope.read(context).deleteJournal(entry);
            }
          } else if (value == 'open') {
            await _openEntry(entry);
          }
        },
        itemBuilder: (context) => [
          const PopupMenuItem(value: 'open', child: Text('Open')),
          PopupMenuItem(
            value: 'archive',
            child: Text(entry.archived ? 'Restore' : 'Archive'),
          ),
          const PopupMenuDivider(),
          const PopupMenuItem(value: 'delete', child: Text('Delete')),
        ],
      );

  bool _matchesPeriod(DateTime date) {
    final anchor = DateTime(_anchorDate.year, _anchorDate.month, _anchorDate.day);
    final target = DateTime(date.year, date.month, date.day);
    return switch (_period) {
      JournalPeriodFilter.week => () {
          final start = anchor.subtract(Duration(days: anchor.weekday - 1));
          final end = start.add(const Duration(days: 7));
          return !target.isBefore(start) && target.isBefore(end);
        }(),
      JournalPeriodFilter.month =>
        target.year == anchor.year && target.month == anchor.month,
      JournalPeriodFilter.year => target.year == anchor.year,
      JournalPeriodFilter.all => true,
    };
  }

  String _periodLabel() => switch (_period) {
        JournalPeriodFilter.week => () {
            final start = _anchorDate.subtract(
              Duration(days: _anchorDate.weekday - 1),
            );
            final end = start.add(const Duration(days: 6));
            return '${DateFormat('MMM d').format(start)} – ${DateFormat('MMM d, yyyy').format(end)}';
          }(),
        JournalPeriodFilter.month => DateFormat('MMMM yyyy').format(_anchorDate),
        JournalPeriodFilter.year => DateFormat('yyyy').format(_anchorDate),
        JournalPeriodFilter.all => 'All journal history',
      };

  void _movePeriod(int direction) {
    setState(() {
      _anchorDate = switch (_period) {
        JournalPeriodFilter.week =>
          _anchorDate.add(Duration(days: 7 * direction)),
        JournalPeriodFilter.month =>
          DateTime(_anchorDate.year, _anchorDate.month + direction, 1),
        JournalPeriodFilter.year =>
          DateTime(_anchorDate.year + direction, _anchorDate.month, 1),
        JournalPeriodFilter.all => _anchorDate,
      };
    });
  }

  Future<void> _openEntry(JournalEntry entry) async {
    await Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => JournalEditorScreen(entryId: entry.id)),
    );
    if (mounted) await AppScope.read(context).refreshJournals();
  }

  Future<void> _exportAll(BuildContext context) async {
    final controller = AppScope.read(context);
    final path = await WordExportService.exportJournalBulkZip(
      entries: controller.journals,
      prompts: controller.journalPrompts,
    );
    if (context.mounted && path != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Journal Word files saved to $path')),
      );
    }
  }

  Future<void> _openDate(BuildContext context, DateTime date) async {
    final controller = AppScope.read(context);
    final key = DateFormat('yyyy-MM-dd').format(date);
    final entry = await controller.getOrCreateJournal(key);
    if (!context.mounted) return;
    await Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => JournalEditorScreen(entryId: entry.id)),
    );
    await controller.refreshJournals();
  }
}
