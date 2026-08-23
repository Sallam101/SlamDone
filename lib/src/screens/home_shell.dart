import 'package:flutter/material.dart';

import '../controllers/app_controller.dart';
import '../controllers/app_scope.dart';
import '../models/models.dart';
import 'big_picture_screen.dart';
import 'calendar_screen.dart';
import 'do_first_screen.dart';
import 'focus_screen.dart';
import 'gtd_para_screen.dart';
import 'habits_screen.dart';
import 'journal_screen.dart';
import 'mind_map_screen.dart';
import 'northstar_screen.dart';
import 'overview_screen.dart';
import 'rewards_screen.dart';
import 'settings_screen.dart';
import 'study_tables_screen.dart';
import 'tasks_screen.dart';

class HomeShell extends StatefulWidget {
  const HomeShell({super.key});

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  final ScrollController _tabScrollController = ScrollController();
  late final List<Widget> _screens;

  @override
  void initState() {
    super.initState();
    _screens = AppSection.values
        .map(
          (section) => KeyedSubtree(
            key: ValueKey<String>('section-${section.name}'),
            child: _screen(section),
          ),
        )
        .toList(growable: false);
  }

  @override
  void dispose() {
    _tabScrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final controller = AppScope.of(context);
    final tabs = controller.tabPreferences.isEmpty
        ? AppController.defaultTabPreferences()
        : controller.tabPreferences;
    final selectedIndex = tabs.indexWhere(
      (item) => item.section == controller.selectedSection,
    );
    final index = selectedIndex < 0 ? 0 : selectedIndex;
    // Keep the body in a fixed, keyed order. Reordering the visible tab bar
    // must not move the active Settings element while a drag operation is in
    // progress; doing so can trigger Flutter's _InactiveElements assertion.
    final bodySections = AppSection.values;
    final bodyIndex = bodySections.indexOf(controller.selectedSection);
    return LayoutBuilder(
      builder: (context, constraints) {
        final desktop = constraints.maxWidth >= 780;
        final mobileSections = <AppSection>[
          AppSection.doFirst,
          AppSection.focus,
          AppSection.tasks,
          AppSection.calendar,
        ];
        final mobileIndex = mobileSections.indexOf(controller.selectedSection);
        return Scaffold(
          key: _scaffoldKey,
          appBar: AppBar(
            toolbarHeight: desktop ? 48 : 56,
            title: Row(
              children: [
                const Icon(Icons.auto_awesome_mosaic),
                const SizedBox(width: 8),
                const Expanded(
                  child: Text('SupeSlam', overflow: TextOverflow.ellipsis),
                ),
                if (desktop && controller.message != null) ...[
                  const SizedBox(width: 12),
                  Flexible(
                    child: Text(
                      controller.message!,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ),
                ],
              ],
            ),
            actions: [
              if (desktop)
                Padding(
                  padding: const EdgeInsets.only(right: 12),
                  child: Center(
                    child: Chip(
                      avatar: Icon(
                        controller.syncService.isBusy
                            ? Icons.sync
                            : controller.syncService.mode != 'local'
                            ? Icons.cloud_done_outlined
                            : Icons.cloud_off_outlined,
                        size: 18,
                      ),
                      label: Text(controller.syncService.status),
                    ),
                  ),
                )
              else
                IconButton(
                  tooltip: controller.syncService.status,
                  onPressed: controller.syncService.isBusy ||
                          controller.syncService.mode == 'local'
                      ? null
                      : controller.syncService.syncNow,
                  icon: Icon(
                    controller.syncService.isBusy
                        ? Icons.sync
                        : controller.syncService.mode != 'local'
                        ? Icons.cloud_done_outlined
                        : Icons.cloud_off_outlined,
                  ),
                ),
            ],
            bottom: desktop
                ? PreferredSize(
                    preferredSize: const Size.fromHeight(62),
                    child: Scrollbar(
                      controller: _tabScrollController,
                      thumbVisibility: true,
                      scrollbarOrientation: ScrollbarOrientation.bottom,
                      child: SingleChildScrollView(
                        controller: _tabScrollController,
                        scrollDirection: Axis.horizontal,
                        padding: const EdgeInsets.fromLTRB(12, 4, 12, 14),
                        child: Row(
                          children: List.generate(tabs.length, (tabIndex) {
                            final tab = tabs[tabIndex];
                            final selected = tabIndex == index;
                            final color = Color(tab.colorValue);
                            return Padding(
                              padding: const EdgeInsets.only(right: 7),
                              child: selected
                                  ? FilledButton.tonalIcon(
                                      style: FilledButton.styleFrom(
                                        backgroundColor: color.withValues(
                                          alpha: 0.22,
                                        ),
                                        foregroundColor: color,
                                      ),
                                      onPressed: () =>
                                          controller.selectSection(tab.section),
                                      icon: Icon(_icon(tab.iconKey), size: 19),
                                      label: Text(tab.label),
                                    )
                                  : TextButton.icon(
                                      style: TextButton.styleFrom(
                                        foregroundColor: color,
                                      ),
                                      onPressed: () =>
                                          controller.selectSection(tab.section),
                                      icon: Icon(_icon(tab.iconKey), size: 19),
                                      label: Text(tab.label),
                                    ),
                            );
                          }),
                        ),
                      ),
                    ),
                  )
                : null,
          ),
          drawer: desktop
              ? null
              : Drawer(
                  child: SafeArea(
                    child: ListView(
                      padding: const EdgeInsets.all(8),
                      children: [
                        const ListTile(
                          leading: Icon(Icons.auto_awesome_mosaic),
                          title: Text('SupeSlam'),
                          subtitle: Text('All planner sections'),
                        ),
                        ListTile(
                          dense: true,
                          leading: Icon(
                            controller.syncService.mode == 'local'
                                ? Icons.phone_android
                                : Icons.cloud_done_outlined,
                          ),
                          title: Text(controller.syncService.status),
                          subtitle: const Text(
                            'Changes are saved locally automatically',
                          ),
                        ),
                        const Divider(),
                        ...List.generate(tabs.length, (tabIndex) {
                          final tab = tabs[tabIndex];
                          return ListTile(
                            key: ValueKey<String>('drawer-${tab.section.name}'),
                            selected: tabIndex == index,
                            leading: Icon(
                              _icon(tab.iconKey),
                              color: Color(tab.colorValue),
                            ),
                            title: Text(tab.label),
                            onTap: () {
                              Navigator.pop(context);
                              controller.selectSection(tab.section);
                            },
                          );
                        }),
                      ],
                    ),
                  ),
                ),
          body: IndexedStack(index: bodyIndex, children: _screens),
          bottomNavigationBar: desktop
              ? null
              : NavigationBar(
                  selectedIndex: mobileIndex < 0 ? 4 : mobileIndex,
                  onDestinationSelected: (destination) {
                    if (destination == 4) {
                      _scaffoldKey.currentState?.openDrawer();
                      return;
                    }
                    controller.selectSection(mobileSections[destination]);
                  },
                  destinations: const [
                    NavigationDestination(
                      icon: Icon(Icons.bolt_outlined),
                      selectedIcon: Icon(Icons.bolt),
                      label: 'Do First',
                    ),
                    NavigationDestination(
                      icon: Icon(Icons.timer_outlined),
                      selectedIcon: Icon(Icons.timer),
                      label: 'Focus',
                    ),
                    NavigationDestination(
                      icon: Icon(Icons.checklist_outlined),
                      selectedIcon: Icon(Icons.checklist),
                      label: 'Tasks',
                    ),
                    NavigationDestination(
                      icon: Icon(Icons.calendar_month_outlined),
                      selectedIcon: Icon(Icons.calendar_month),
                      label: 'Calendar',
                    ),
                    NavigationDestination(
                      icon: Icon(Icons.menu),
                      label: 'More',
                    ),
                  ],
                ),
        );
      },
    );
  }

  Widget _screen(AppSection section) => switch (section) {
    AppSection.overview => const OverviewScreen(),
    AppSection.doFirst => const DoFirstScreen(),
    AppSection.bigPicture => const BigPictureScreen(),
    AppSection.mindMap => const MindMapScreen(),
    AppSection.focus => const FocusScreen(),
    AppSection.tasks => const TasksScreen(),
    AppSection.calendar => const CalendarScreen(),
    AppSection.habits => const HabitsScreen(),
    AppSection.journal => const JournalScreen(),
    AppSection.northStar => const NorthStarScreen(),
    AppSection.rewards => const RewardsScreen(),
    AppSection.gtdPara => const GtdParaScreen(),
    AppSection.studyTables => const StudyTablesScreen(),
    AppSection.settings => const SettingsScreen(),
  };

  IconData _icon(String key) => switch (key) {
    'overview' => Icons.insights_outlined,
    'bolt' => Icons.bolt_outlined,
    'dashboard' => Icons.account_tree_outlined,
    'hub' => Icons.hub_outlined,
    'timer' => Icons.timer_outlined,
    'tasks' => Icons.checklist_outlined,
    'calendar' => Icons.calendar_month_outlined,
    'habit' => Icons.track_changes_outlined,
    'journal' => Icons.menu_book_outlined,
    'northstar' => Icons.explore_outlined,
    'rewards' => Icons.military_tech_outlined,
    'kanban' => Icons.view_kanban_outlined,
    'table' => Icons.table_chart_outlined,
    'settings' => Icons.settings_outlined,
    _ => Icons.circle_outlined,
  };
}
