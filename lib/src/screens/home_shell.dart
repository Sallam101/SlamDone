import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';

import '../controllers/app_controller.dart';
import '../controllers/app_scope.dart';
import '../models/models.dart';
import '../services/desktop_timer_bridge.dart';
import '../widgets/floating_timer_overlay.dart';
import '../widgets/slamdone_brand.dart';
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

class _HomeShellState extends State<HomeShell> with WidgetsBindingObserver {
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  AppController? _lifecycleController;
  AppController? _timerBridgeController;
  DesktopTimerBridge? _desktopTimerBridge;
  final ScrollController _tabScrollController = ScrollController();
  late final List<Widget> _screens;
  int _lastAutoArchiveSequence = 0;
  Offset _floatingTimerOffset = const Offset(18, 18);
  Size _floatingTimerSize = const Size(218, 214);
  bool _floatingTimerPinned = true;
  bool _desktopTimerOpen = false;
  double _floatingTimerOpacity = 1.0;
  int _floatingTimerColorIndex = 0;
  AppSection? _floatingTimerUnpinnedSection;
  final ValueNotifier<double> _floatingTimerPageScroll = ValueNotifier<double>(0);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
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
  void didChangeDependencies() {
    super.didChangeDependencies();
    final controller = AppScope.of(context);
    _lifecycleController = controller;
    if (!identical(_timerBridgeController, controller)) {
      _timerBridgeController?.timerEngine.removeListener(_pushDesktopTimerSnapshot);
      _desktopTimerBridge?.dispose();
      _timerBridgeController = controller;
      _desktopTimerBridge = DesktopTimerBridge(
        onAction: _handleDesktopTimerAction,
        onClosed: _handleDesktopTimerClosed,
      );
      controller.timerEngine.addListener(_pushDesktopTimerSnapshot);
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      final controller = _lifecycleController;
      if (controller != null) {
        unawaited(controller.syncService.handleAppResumed());
      }
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _timerBridgeController?.timerEngine.removeListener(_pushDesktopTimerSnapshot);
    _desktopTimerBridge?.dispose();
    _tabScrollController.dispose();
    _floatingTimerPageScroll.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final controller = AppScope.of(context);
    _showAutoArchiveNoticeIfNeeded(controller);
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
        final appBarBackground = Theme.of(context).appBarTheme.backgroundColor ??
            Theme.of(context).colorScheme.surface;
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
            leading: desktop
                ? null
                : IconButton(
                    tooltip: 'Open SlamDone navigation',
                    onPressed: () => _scaffoldKey.currentState?.openDrawer(),
                    icon: const Icon(Icons.menu_rounded),
                  ),
            title: Row(
              children: [
                Expanded(
                  child: SlamDoneBrand(
                    compact: !desktop,
                    showSlogan: desktop,
                    backgroundColor: appBarBackground,
                  ),
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
                        const Padding(
                          padding: EdgeInsets.fromLTRB(12, 12, 12, 10),
                          child: SlamDoneBrand(compact: false, showSlogan: true),
                        ),
                        const Padding(
                          padding: EdgeInsets.symmetric(horizontal: 12),
                          child: Text('All planner sections'),
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
          body: LayoutBuilder(
            builder: (context, bodyConstraints) {
              final minTimerWidth = desktop ? 156.0 : 148.0;
              final minTimerHeight = desktop ? 150.0 : 144.0;
              final maxTimerWidth = (bodyConstraints.maxWidth - 16)
                  .clamp(minTimerWidth, 760.0)
                  .toDouble();
              final maxTimerHeight = (bodyConstraints.maxHeight - 16)
                  .clamp(minTimerHeight, 840.0)
                  .toDouble();
              final timerSize = Size(
                _floatingTimerSize.width.clamp(minTimerWidth, maxTimerWidth).toDouble(),
                _floatingTimerSize.height.clamp(minTimerHeight, maxTimerHeight).toDouble(),
              );
              final maxLeft = (bodyConstraints.maxWidth - timerSize.width - 8)
                  .clamp(0.0, double.infinity)
                  .toDouble();
              final maxTop = (bodyConstraints.maxHeight - timerSize.height - 8)
                  .clamp(0.0, double.infinity)
                  .toDouble();
              final left = _floatingTimerOffset.dx.clamp(0.0, maxLeft).toDouble();
              final top = _floatingTimerOffset.dy.clamp(0.0, maxTop).toDouble();
              final timerBelongsToCurrentPage = _floatingTimerPinned ||
                  _floatingTimerUnpinnedSection == controller.selectedSection;
              return Stack(
                clipBehavior: Clip.hardEdge,
                children: [
                  Positioned.fill(
                    child: NotificationListener<ScrollUpdateNotification>(
                      onNotification: (notification) {
                        if (!_floatingTimerPinned &&
                            _floatingTimerUnpinnedSection == controller.selectedSection &&
                            notification.metrics.axis == Axis.vertical &&
                            notification.scrollDelta != null) {
                          _floatingTimerPageScroll.value += notification.scrollDelta!;
                        }
                        return false;
                      },
                      child: IndexedStack(index: bodyIndex, children: _screens),
                    ),
                  ),
                  if (controller.floatingTimerVisible &&
                      !_desktopTimerOpen &&
                      timerBelongsToCurrentPage)
                    Positioned(
                      left: left,
                      top: top,
                      child: ValueListenableBuilder<double>(
                        valueListenable: _floatingTimerPageScroll,
                        builder: (context, pageScroll, child) => Transform.translate(
                          offset: Offset(0, _floatingTimerPinned ? 0 : -pageScroll),
                          child: child,
                        ),
                        child: SlamDoneFloatingTimerOverlay(
                          controller: controller,
                          compact: !desktop,
                          size: timerSize,
                          pinned: _floatingTimerPinned,
                          opacity: _floatingTimerOpacity,
                          colorIndex: _floatingTimerColorIndex,
                          onOpacityChanged: (value) {
                            setState(() {
                              _floatingTimerOpacity = value.clamp(.25, 1).toDouble();
                            });
                            _pushDesktopTimerSnapshot();
                          },
                          onColorChanged: (value) {
                            setState(() => _floatingTimerColorIndex = value.clamp(0, 7).toInt());
                            _pushDesktopTimerSnapshot();
                          },
                          onPinnedChanged: (value) {
                            if (value) {
                              final bridge = _desktopTimerBridge;
                              if (bridge != null && bridge.supported) {
                                unawaited(
                                  _openDesktopPinnedTimer(
                                    controller,
                                    timerSize,
                                    left: left,
                                    top: top,
                                    maxTop: maxTop,
                                  ),
                                );
                                return;
                              }
                            } else if (_desktopTimerOpen) {
                              _returnDesktopTimerToApp();
                              return;
                            }
                            setState(() {
                              if (value) {
                                final visibleTop = (top - _floatingTimerPageScroll.value)
                                    .clamp(0.0, maxTop)
                                    .toDouble();
                                _floatingTimerOffset = Offset(left, visibleTop);
                                _floatingTimerPinned = true;
                                _floatingTimerUnpinnedSection = null;
                                _floatingTimerPageScroll.value = 0;
                              } else {
                                _floatingTimerPinned = false;
                                _floatingTimerUnpinnedSection = controller.selectedSection;
                                _floatingTimerPageScroll.value = 0;
                              }
                            });
                          },
                          onClose: controller.hideFloatingTimer,
                          onResizeDelta: (delta) {
                            setState(() {
                              _floatingTimerSize = Size(
                                (timerSize.width + delta.dx)
                                    .clamp(minTimerWidth, maxTimerWidth)
                                    .toDouble(),
                                (timerSize.height + delta.dy)
                                    .clamp(minTimerHeight, maxTimerHeight)
                                    .toDouble(),
                              );
                            });
                          },
                          onDragDelta: (delta) {
                            setState(() {
                              _floatingTimerOffset = Offset(
                                (_floatingTimerOffset.dx + delta.dx)
                                    .clamp(0.0, maxLeft)
                                    .toDouble(),
                                (_floatingTimerOffset.dy + delta.dy)
                                    .clamp(0.0, maxTop)
                                    .toDouble(),
                              );
                            });
                          },
                        ),
                      ),
                    ),
                ],
              );
            },
          ),
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

  String _desktopTimerSnapshotJson(AppController controller, [Size? windowSize]) {
    final state = controller.timerEngine.state;
    final size = windowSize ?? _floatingTimerSize;
    return jsonEncode({
      'mode': state.mode.name,
      'title': state.title.trim().isEmpty ? 'General focus' : state.title.trim(),
      'durationSeconds': state.durationSeconds,
      'remainingSeconds': state.remainingSeconds,
      'elapsedSeconds': state.elapsedSeconds,
      'running': state.running,
      'paused': state.paused,
      'autoRepeat': state.autoRepeat,
      'startedAtMs': state.startedAt?.millisecondsSinceEpoch,
      'endAtMs': state.endAt?.millisecondsSinceEpoch,
      'updatedAtMs': state.updatedAt.millisecondsSinceEpoch,
      'completionToken': state.completionToken,
      'colorIndex': _floatingTimerColorIndex,
      'opacity': _floatingTimerOpacity,
      'windowWidth': size.width.round(),
      'windowHeight': size.height.round(),
    });
  }

  void _pushDesktopTimerSnapshot() {
    final bridge = _desktopTimerBridge;
    final controller = _timerBridgeController;
    if (!_desktopTimerOpen || bridge == null || controller == null) return;
    bridge.update(_desktopTimerSnapshotJson(controller));
  }

  Future<void> _openDesktopPinnedTimer(
    AppController controller,
    Size timerSize, {
    required double left,
    required double top,
    required double maxTop,
  }) async {
    final bridge = _desktopTimerBridge;
    if (bridge == null || !bridge.supported) return;
    // open() invokes requestWindow synchronously before its first await so the
    // browser keeps the Pin click's transient user activation.
    final opened = await bridge.open(_desktopTimerSnapshotJson(controller, timerSize));
    if (!mounted) return;
    if (!opened) {
      setState(() {
        final visibleTop = (top - _floatingTimerPageScroll.value)
            .clamp(0.0, maxTop)
            .toDouble();
        _floatingTimerOffset = Offset(left, visibleTop);
        _floatingTimerPinned = true;
        _floatingTimerUnpinnedSection = null;
        _floatingTimerPageScroll.value = 0;
      });
      return;
    }
    setState(() {
      _desktopTimerOpen = true;
      _floatingTimerPinned = true;
      _floatingTimerUnpinnedSection = null;
      _floatingTimerPageScroll.value = 0;
    });
    _pushDesktopTimerSnapshot();
  }

  void _returnDesktopTimerToApp() {
    final controller = _timerBridgeController;
    _desktopTimerBridge?.close();
    if (!mounted) return;
    setState(() {
      _desktopTimerOpen = false;
      _floatingTimerPinned = false;
      _floatingTimerUnpinnedSection = controller?.selectedSection;
      _floatingTimerPageScroll.value = 0;
    });
  }

  void _handleDesktopTimerClosed() {
    if (!mounted) return;
    final controller = _timerBridgeController;
    setState(() {
      _desktopTimerOpen = false;
      _floatingTimerPinned = false;
      _floatingTimerUnpinnedSection = controller?.selectedSection;
      _floatingTimerPageScroll.value = 0;
    });
  }

  void _handleDesktopTimerAction(String rawAction) {
    final controller = _timerBridgeController;
    if (controller == null) return;
    final engine = controller.timerEngine;

    if (rawAction.startsWith('opacity:')) {
      final value = double.tryParse(rawAction.substring('opacity:'.length));
      if (value != null && mounted) {
        setState(() => _floatingTimerOpacity = value.clamp(.25, 1).toDouble());
        _pushDesktopTimerSnapshot();
      }
      return;
    }
    if (rawAction.startsWith('color:')) {
      final value = int.tryParse(rawAction.substring('color:'.length));
      if (value != null && mounted) {
        setState(() => _floatingTimerColorIndex = value.clamp(0, 7).toInt());
        _pushDesktopTimerSnapshot();
      }
      return;
    }

    switch (rawAction) {
      case 'toggle':
        if (!engine.isActive) {
          unawaited(engine.start(
            mode: TimerMode.general,
            title: 'General focus',
            durationMinutes: controller.defaultSessionMinutes,
          ));
        } else if (engine.state.paused) {
          unawaited(controller.timerEngine.resume());
        } else {
          unawaited(controller.timerEngine.pause());
        }
      case 'reset':
        unawaited(controller.timerEngine.reset());
      case 'stop':
        unawaited(controller.timerEngine.stop(saveSession: true));
      case 'stopwatch':
        unawaited(engine.start(
          mode: TimerMode.stopwatch,
          title: 'Study stopwatch',
        ));
      case 'deadline':
        unawaited(controller.timerEngine.reconcileNow());
      case 'unpin':
        _returnDesktopTimerToApp();
      case 'close':
        _desktopTimerBridge?.close();
        controller.hideFloatingTimer();
        if (mounted) {
          setState(() {
            _desktopTimerOpen = false;
            _floatingTimerPinned = false;
          });
        }
      default:
        return;
    }
  }

  void _showAutoArchiveNoticeIfNeeded(AppController controller) {
    final notice = controller.autoArchiveNotice;
    if (notice == null || notice.sequence == _lastAutoArchiveSequence) return;
    _lastAutoArchiveSequence = notice.sequence;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final messenger = ScaffoldMessenger.of(context);
      messenger.hideCurrentSnackBar();
      messenger.showSnackBar(
        SnackBar(
          duration: const Duration(seconds: 4),
          content: Text(
            'Completed & archived: ${notice.title}. It will disappear in 4 seconds.',
          ),
          action: SnackBarAction(
            label: 'UNDO',
            onPressed: () => controller.undoAutoArchive(notice.itemId),
          ),
        ),
      );
    });
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
