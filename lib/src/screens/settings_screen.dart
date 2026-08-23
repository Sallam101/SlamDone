import 'dart:async';
import 'package:flutter/material.dart';

import '../controllers/app_scope.dart';
import '../models/models.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  String? _result;
  List<TabPreference> _draftTabs = const [];
  Timer? _tabSaveTimer;
  bool _tabsInitialized = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final incoming = AppScope.of(context).tabPreferences;
    if (!_tabsInitialized) {
      _draftTabs = List<TabPreference>.of(incoming);
      _tabsInitialized = true;
      return;
    }

    if (_tabSaveTimer?.isActive != true && !_sameTabs(_draftTabs, incoming)) {
      _draftTabs = List<TabPreference>.of(incoming);
    }
  }

  @override
  void dispose() {
    _tabSaveTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final controller = AppScope.of(context);
    final sync = controller.syncService;
    final mobile = MediaQuery.sizeOf(context).width < 700;
    return ListView(
      padding: const EdgeInsets.all(14),
      children: [
        _section(context, 'Appearance', [
          SegmentedButton<ThemeMode>(
            segments: const [
              ButtonSegment(
                value: ThemeMode.system,
                label: Text('System'),
                icon: Icon(Icons.brightness_auto),
              ),
              ButtonSegment(
                value: ThemeMode.light,
                label: Text('Light'),
                icon: Icon(Icons.light_mode),
              ),
              ButtonSegment(
                value: ThemeMode.dark,
                label: Text('Dark'),
                icon: Icon(Icons.dark_mode),
              ),
            ],
            selected: {controller.themeMode},
            onSelectionChanged: (value) => controller.setThemeMode(value.first),
          ),
          const SizedBox(height: 12),
          _colorRow(
            context,
            'Accent',
            controller.accentColorValue,
            controller.setAccentColor,
          ),
          _colorRow(
            context,
            'Background',
            controller.backgroundColorValue,
            controller.setBackgroundColor,
            allowDefault: true,
          ),
          _colorRow(
            context,
            'Default cards',
            controller.cardColorValue,
            controller.setCardColor,
            allowDefault: true,
          ),
          _colorRow(
            context,
            'Text',
            controller.textColorValue,
            controller.setTextColor,
            allowDefault: true,
          ),
          const SizedBox(height: 12),
          LayoutBuilder(
            builder: (context, constraints) {
              final fontPicker = DropdownButtonFormField<String>(
                initialValue: controller.fontFamily,
                decoration: const InputDecoration(labelText: 'Font family'),
                items:
                    const [
                          'Roboto',
                          'Segoe UI',
                          'Arial',
                          'Calibri',
                          'Georgia',
                          'Verdana',
                          'Tahoma',
                          'Trebuchet MS',
                          'Courier New',
                        ]
                        .map(
                          (value) => DropdownMenuItem(
                            value: value,
                            child: Text(value),
                          ),
                        )
                        .toList(),
                onChanged: (value) {
                  if (value != null) controller.setFontFamily(value);
                },
              );
              final sizeSlider = Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'App font size ${(controller.fontScale * 100).round()}%',
                  ),
                  Slider(
                    value: controller.fontScale,
                    min: .8,
                    max: 1.6,
                    divisions: 16,
                    onChanged: controller.setFontScale,
                  ),
                ],
              );
              if (constraints.maxWidth < 560) {
                return Column(
                  children: [
                    fontPicker,
                    const SizedBox(height: 12),
                    sizeSlider,
                  ],
                );
              }
              return Row(
                children: [
                  Expanded(child: fontPicker),
                  const SizedBox(width: 12),
                  Expanded(child: sizeSlider),
                ],
              );
            },
          ),
          Align(
            alignment: Alignment.centerLeft,
            child: OutlinedButton.icon(
              onPressed: controller.resetAppearance,
              icon: const Icon(Icons.restart_alt),
              label: const Text('Reset appearance'),
            ),
          ),
        ]),
        const SizedBox(height: 12),
        _section(context, 'Tabs and section bar', [
          const Text(
            'Drag the handle to arrange tabs. Use the pencil to rename a tab and the color button to change its icon color.',
          ),
          const SizedBox(height: 8),
          SizedBox(
            height: 420,
            child: ReorderableListView.builder(
              buildDefaultDragHandles: false,
              itemCount: _draftTabs.length,
              onReorderItem: _reorderTab,
              proxyDecorator: (child, index, animation) => Material(
                elevation: 8,
                color: Colors.transparent,
                borderRadius: BorderRadius.circular(16),
                child: child,
              ),
              itemBuilder: (context, index) {
                final tab = _draftTabs[index];
                return Card(
                  key: ValueKey<String>('tab-${tab.section.name}'),
                  margin: const EdgeInsets.symmetric(vertical: 4),
                  child: ListTile(
                    leading: CircleAvatar(
                      backgroundColor: Color(tab.colorValue),
                      child: const Icon(
                        Icons.view_quilt_outlined,
                        color: Colors.white,
                      ),
                    ),
                    title: Text(
                      tab.label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    subtitle: Text(tab.section.name),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        PopupMenuButton<int>(
                          tooltip: 'Tab color',
                          icon: const Icon(Icons.palette_outlined),
                          onSelected: (color) => _changeTabColor(index, color),
                          itemBuilder: (context) => _palette
                              .map(
                                (color) => PopupMenuItem<int>(
                                  value: color,
                                  child: Row(
                                    children: [
                                      CircleAvatar(
                                        backgroundColor: Color(color),
                                        radius: 11,
                                      ),
                                      const SizedBox(width: 10),
                                      Text(
                                        color == tab.colorValue
                                            ? 'Selected'
                                            : 'Use this color',
                                      ),
                                    ],
                                  ),
                                ),
                              )
                              .toList(),
                        ),
                        IconButton(
                          tooltip: 'Rename tab',
                          onPressed: () => _renameTab(index),
                          icon: const Icon(Icons.edit_outlined),
                        ),
                        ReorderableDragStartListener(
                          index: index,
                          child: const Padding(
                            padding: EdgeInsets.all(12),
                            child: Icon(Icons.drag_handle),
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        ]),
        const SizedBox(height: 12),
        _section(context, 'Journal recurring questions', [
          ...List.generate(controller.journalPrompts.length, (index) {
            final prompt = controller.journalPrompts[index];
            final id = prompt['id']?.toString() ?? 'prompt-$index';
            return ListTile(
              key: ValueKey<String>('journal-prompt-$id'),
              leading: const Icon(Icons.drag_indicator),
              title: TextFormField(
                key: ValueKey<String>('journal-prompt-field-$id'),
                initialValue: prompt['question']?.toString() ?? '',
                onFieldSubmitted: (value) {
                  final next = controller.journalPrompts
                      .map((item) => Map<String, dynamic>.from(item))
                      .toList();
                  next[index]['question'] = value;
                  controller.saveJournalPrompts(next);
                },
              ),
              trailing: IconButton(
                icon: const Icon(Icons.delete_outline),
                onPressed: () {
                  final next =
                      controller.journalPrompts
                          .map((item) => Map<String, dynamic>.from(item))
                          .toList()
                        ..removeAt(index);
                  controller.saveJournalPrompts(next);
                },
              ),
            );
          }),
          Align(
            alignment: Alignment.centerLeft,
            child: OutlinedButton.icon(
              onPressed: () {
                final next =
                    controller.journalPrompts
                        .map((item) => Map<String, dynamic>.from(item))
                        .toList()
                      ..add({
                        'id': 'custom_${DateTime.now().microsecondsSinceEpoch}',
                        'question': 'New recurring question',
                        'width': .5,
                      });
                controller.saveJournalPrompts(next);
              },
              icon: const Icon(Icons.add),
              label: const Text('Question'),
            ),
          ),
        ]),
        const SizedBox(height: 12),
        _section(context, 'Migration, saving and backup', [
          Text(sync.status),
          const SizedBox(height: 8),
          if (!mobile)
            const Text(
              'SlamDone saves automatically in this browser. Use the private full migration file once to bring over goals, Big Picture/Mind Map layouts, focus history, habits, journals + journal history, NorthStar, rewards, study tables, settings and timer state. Stable IDs prevent duplicates.',
            ),
          if (mobile)
            const Text('Backups, migration, and repair tools.'),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              FilledButton.icon(
                onPressed: () => _importMigration(controller, sync),
                icon: const Icon(Icons.move_to_inbox_outlined),
                label: const Text('Import Existing Autivra4 Progress'),
              ),
              OutlinedButton.icon(
                onPressed: controller.exportBackup,
                icon: const Icon(Icons.save_alt),
                label: const Text('Download backup'),
              ),
              OutlinedButton.icon(
                onPressed: controller.exportForAutivra4,
                icon: const Icon(Icons.swap_horiz),
                label: const Text('Export for Autivra4'),
              ),
              OutlinedButton.icon(
                onPressed: sync.isBusy ? null : () => sync.syncNow(),
                icon: const Icon(Icons.sync),
                label: const Text('Verify & repair sync'),
              ),
              OutlinedButton.icon(
                onPressed: sync.useLocalOnly,
                icon: const Icon(Icons.cloud_off_outlined),
                label: const Text('Browser only'),
              ),
            ],
          ),
          if (!mobile) ...[
            const SizedBox(height: 8),
            const Text(
              'Autivra4 export uses the native V6 backup shape and keeps native device/Drive sync settings out of the file. Autivra4 V6.4.1 itself only imports missing record IDs; use the file as a full/fresh restore unless that native importer is upgraded to merge newer existing IDs.',
            ),
          ],
          if (_result != null)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(_result!),
            ),
        ]),
        if (sync.firebaseAvailable) ...[
          const SizedBox(height: 12),
          _section(context, 'Cross-device cloud sync', [
            Text(sync.status),
            const SizedBox(height: 6),
            Text(
              'Sync audit: ${sync.auditSummary}',
              style: Theme.of(context).textTheme.bodySmall,
            ),
            if (sync.isSignedIn && !sync.verified)
              const Padding(
                padding: EdgeInsets.only(top: 6),
                child: Text(
                  'Connected is not the same as verified. Use Verify & repair sync on the PC and phone to reconcile every planner table.',
                ),
              ),
            const SizedBox(height: 8),
            if (sync.isSignedIn && sync.currentUser?.email != null)
              Text('Signed in as ${sync.currentUser!.email}'),
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                if (!sync.isSignedIn)
                  FilledButton.icon(
                    onPressed: sync.isBusy ? null : () => _googleSignIn(sync),
                    icon: const Icon(Icons.account_circle_outlined),
                    label: const Text('Continue with Google'),
                  ),
                if (sync.isSignedIn)
                  FilledButton.tonalIcon(
                    onPressed: sync.isBusy ? null : () => sync.syncNow(),
                    icon: const Icon(Icons.sync),
                    label: const Text('Verify & repair sync'),
                  ),
                if (sync.isSignedIn)
                  OutlinedButton.icon(
                    onPressed: sync.isBusy ? null : sync.signOut,
                    icon: const Icon(Icons.logout),
                    label: const Text('Sign out'),
                  ),
                OutlinedButton.icon(
                  onPressed: sync.useLocalOnly,
                  icon: const Icon(Icons.cloud_off_outlined),
                  label: const Text('Browser only'),
                ),
              ],
            ),
          ]),
        ],
        const SizedBox(height: 12),
        _section(context, 'Local data', [
          const Text('SlamDone browser database'),
          const Text(
            'Your browser storage keeps the legacy internal database key for migration compatibility. Visible SlamDone branding and cloud sync are unaffected; app updates do not intentionally clear this data.',
          ),
        ]),
      ],
    );
  }

  Future<void> _importMigration(dynamic controller, dynamic sync) async {
    if (sync.firebaseAvailable && !sync.isSignedIn) {
      setState(() => _result =
          'Connect your Google account first, then import the Autivra migration file.');
      return;
    }
    try {
      final result = await controller.importMigration();
      if (!mounted) return;
      final entities = result.sourceCounts.entries
          .where((entry) => entry.key != 'app_settings' && entry.key != 'timer_state')
          .map((entry) => '${entry.key}: ${entry.value}')
          .join(' · ');
      setState(() => _result =
          'Migration complete. ${result.totalChanged} local rows changed. Source: $entities');
    } catch (error) {
      if (mounted) setState(() => _result = 'Migration failed: $error');
    }
  }

  Future<void> _googleSignIn(dynamic sync) async {
    final result = await sync.signInWithGoogle();
    if (mounted) setState(() => _result = result);
  }

  void _reorderTab(int oldIndex, int newIndex) {
    if (oldIndex < 0 || oldIndex >= _draftTabs.length) return;
    final next = List<TabPreference>.of(_draftTabs);
    final moved = next.removeAt(oldIndex);
    final target = newIndex.clamp(0, next.length).toInt();
    next.insert(target, moved);
    setState(() => _draftTabs = next);
    _queueTabSave();
  }

  Future<void> _renameTab(int index) async {
    if (index < 0 || index >= _draftTabs.length) return;
    final tab = _draftTabs[index];
    final editor = TextEditingController(text: tab.label);
    final value = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Rename tab'),
        content: TextField(
          controller: editor,
          autofocus: true,
          maxLength: 40,
          decoration: const InputDecoration(labelText: 'Tab name'),
          onSubmitted: (text) => Navigator.pop(context, text),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, editor.text),
            child: const Text('Save'),
          ),
        ],
      ),
    );
    editor.dispose();
    if (!mounted || value == null) return;
    final trimmed = value.trim();
    if (trimmed.isEmpty || trimmed == tab.label) return;
    final next = List<TabPreference>.of(_draftTabs);
    next[index] = TabPreference(
      section: tab.section,
      label: trimmed,
      colorValue: tab.colorValue,
      iconKey: tab.iconKey,
    );
    setState(() => _draftTabs = next);
    _queueTabSave();
  }

  void _changeTabColor(int index, int color) {
    if (index < 0 || index >= _draftTabs.length) return;
    final tab = _draftTabs[index];
    final next = List<TabPreference>.of(_draftTabs);
    next[index] = TabPreference(
      section: tab.section,
      label: tab.label,
      colorValue: color,
      iconKey: tab.iconKey,
    );
    setState(() => _draftTabs = next);
    _queueTabSave();
  }

  void _queueTabSave() {
    _tabSaveTimer?.cancel();
    final snapshot = List<TabPreference>.unmodifiable(_draftTabs);
    _tabSaveTimer = Timer(const Duration(milliseconds: 300), () async {
      if (!mounted) return;
      await AppScope.read(context).saveTabPreferences(snapshot);
    });
  }

  bool _sameTabs(List<TabPreference> left, List<TabPreference> right) {
    if (left.length != right.length) return false;
    for (var index = 0; index < left.length; index++) {
      final a = left[index];
      final b = right[index];
      if (a.section != b.section ||
          a.label != b.label ||
          a.colorValue != b.colorValue ||
          a.iconKey != b.iconKey) {
        return false;
      }
    }
    return true;
  }

  Widget _section(BuildContext context, String title, List<Widget> children) =>
      Card(
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(title, style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: 12),
              ...children,
            ],
          ),
        ),
      );

  Widget _colorRow(
    BuildContext context,
    String label,
    int selected,
    Future<void> Function(int) onSelected, {
    bool allowDefault = false,
  }) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 5),
    child: Row(
      children: [
        SizedBox(width: 115, child: Text(label)),
        if (allowDefault)
          Padding(
            padding: const EdgeInsets.only(right: 7),
            child: ChoiceChip(
              label: const Text('Auto'),
              selected: selected == 0,
              onSelected: (_) => onSelected(0),
            ),
          ),
        ..._palette.map(
          (value) => Padding(
            padding: const EdgeInsets.only(right: 7),
            child: InkWell(
              onTap: () => onSelected(value),
              child: Container(
                width: 31,
                height: 31,
                decoration: BoxDecoration(
                  color: Color(value),
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: selected == value
                        ? Theme.of(context).colorScheme.onSurface
                        : Colors.transparent,
                    width: 3,
                  ),
                ),
                child: selected == value
                    ? const Icon(Icons.check, color: Colors.white, size: 17)
                    : null,
              ),
            ),
          ),
        ),
      ],
    ),
  );

  static const _palette = [
    0xFF4CAF7A,
    0xFF1565C0,
    0xFF00ACC1,
    0xFF2E7D32,
    0xFFFF9800,
    0xFFE53935,
    0xFF8E24AA,
    0xFF5E35B1,
    0xFF6D4C41,
    0xFF455A64,
    0xFFF5F5F5,
    0xFF161616,
  ];
}
