import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../controllers/app_scope.dart';
import '../services/word_export_service.dart';
import 'journal_editor_screen.dart';

class JournalScreen extends StatefulWidget {
  const JournalScreen({super.key});
  @override
  State<JournalScreen> createState() => _JournalScreenState();
}

class _JournalScreenState extends State<JournalScreen> {
  bool _showArchived = false;
  String _folder = 'All';

  @override
  Widget build(BuildContext context) {
    final controller = AppScope.of(context);
    final folders = {
      'All',
      ...controller.journals
          .map((entry) => entry.folder)
          .where((value) => value.isNotEmpty),
    }.toList();
    final entries = controller.journals.where((entry) {
      if (!_showArchived && entry.archived) return false;
      if (_folder != 'All' && entry.folder != _folder) return false;
      return true;
    }).toList();
    return Padding(
      padding: const EdgeInsets.all(14),
      child: Column(
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Wrap(
                spacing: 8,
                runSpacing: 8,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  const Icon(Icons.menu_book_outlined),
                  SizedBox(
                    width: (MediaQuery.sizeOf(context).width - 74)
                        .clamp(220, 620)
                        .toDouble(),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Journal',
                          style: Theme.of(context).textTheme.titleLarge,
                        ),
                        const Text(
                          'One protected page per day. Local drafts save before synchronization.',
                        ),
                      ],
                    ),
                  ),
                  SizedBox(
                    width: 150,
                    child: DropdownButtonFormField<String>(
                      initialValue: _folder,
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
                    label: const Text('Archived'),
                    selected: _showArchived,
                    onSelected: (value) =>
                        setState(() => _showArchived = value),
                  ),
                  OutlinedButton.icon(
                    onPressed: controller.journals.isEmpty
                        ? null
                        : () => _exportAll(context),
                    icon: const Icon(Icons.library_books_outlined),
                    label: const Text('Export Word files'),
                  ),
                  OutlinedButton.icon(
                    onPressed: () => _openDate(context, DateTime.now()),
                    icon: const Icon(Icons.today),
                    label: const Text('Today'),
                  ),
                  FilledButton.icon(
                    onPressed: () async {
                      final picked = await showDatePicker(
                        context: context,
                        firstDate: DateTime(2020),
                        lastDate: DateTime(2100),
                        initialDate: DateTime.now(),
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
            ),
          ),
          const SizedBox(height: 10),
          Expanded(
            child: entries.isEmpty
                ? Center(
                    child: FilledButton.icon(
                      onPressed: () => _openDate(context, DateTime.now()),
                      icon: const Icon(Icons.edit_note),
                      label: const Text('Write today’s page'),
                    ),
                  )
                : ListView.separated(
                    itemCount: entries.length,
                    separatorBuilder: (context, index) =>
                        const SizedBox(height: 8),
                    itemBuilder: (context, index) {
                      final entry = entries[index];
                      final date =
                          DateTime.tryParse(entry.entryDate) ?? DateTime.now();
                      final preview =
                          [
                            entry.winBig,
                            entry.feel,
                            entry.grateful,
                            entry.body,
                          ].firstWhere(
                            (value) => value.trim().isNotEmpty,
                            orElse: () => 'Empty journal page',
                          );
                      return Card(
                        child: ListTile(
                          leading: CircleAvatar(
                            child: Text(DateFormat('d').format(date)),
                          ),
                          title: Text(
                            DateFormat('EEEE, MMMM d, yyyy').format(date),
                          ),
                          subtitle: Text(
                            '${entry.folder.isEmpty ? 'Journal' : entry.folder} • $preview',
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                          trailing: PopupMenuButton<String>(
                            onSelected: (value) async {
                              if (value == 'archive') {
                                await controller.saveJournal(
                                  entry.copyWith(archived: !entry.archived),
                                );
                              }
                              if (value == 'open' && context.mounted) {
                                await Navigator.of(context).push(
                                  MaterialPageRoute(
                                    builder: (_) =>
                                        JournalEditorScreen(entryId: entry.id),
                                  ),
                                );
                              }
                            },
                            itemBuilder: (context) => [
                              const PopupMenuItem(
                                value: 'open',
                                child: Text('Open'),
                              ),
                              PopupMenuItem(
                                value: 'archive',
                                child: Text(
                                  entry.archived ? 'Restore' : 'Archive',
                                ),
                              ),
                            ],
                          ),
                          onTap: () => Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) =>
                                  JournalEditorScreen(entryId: entry.id),
                            ),
                          ),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
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
