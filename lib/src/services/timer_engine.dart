import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';

import '../database/local_database.dart';
import '../models/models.dart';
import '../repositories/app_repository.dart';
import 'timer_completion_chime.dart';

class TimerEngine extends ChangeNotifier {
  TimerEngine({
    required this.database,
    required this.repository,
    required this.role,
    this.onTimerStarted,
    this.onSessionRecorded,
  });

  final LocalDatabase database;
  final AppRepository repository;
  final TimerOwner role;
  final void Function(TimerMode mode)? onTimerStarted;
  final void Function(TimeSession session)? onSessionRecorded;
  final Uuid _uuid = const Uuid();
  static const Duration suspensionGapThreshold = Duration(seconds: 5);

  TimerStateRecord _state = TimerStateRecord.idle();
  Timer? _ticker;
  bool _processing = false;
  int _lastPersistedSecond = -1;

  TimerStateRecord get state => _state;
  bool get ownsTimer => _state.owner == role;
  bool get isActive => _state.running || _state.paused;
  double get progress {
    if (_state.mode == TimerMode.stopwatch || _state.durationSeconds <= 0) {
      return 0;
    }
    return ((_state.durationSeconds - _state.remainingSeconds) /
            _state.durationSeconds)
        .clamp(0, 1)
        .toDouble();
  }

  Future<void> initialize() async {
    _state = await database.loadTimerState();
    if (_state.running && !_state.paused) {
      await _freezeForInterruption(
        DateTime.now().toUtc(),
        notify: false,
      );
    }
    if (role == TimerOwner.floating && isActive) {
      await takeOwnership();
    }
    _ticker = Timer.periodic(const Duration(milliseconds: 250), (_) {
      unawaited(_pulse());
    });
    notifyListeners();
  }

  Future<void> reloadFromDatabase() async {
    _state = await database.loadTimerState();
    _lastPersistedSecond = -1;
    notifyListeners();
  }

  /// Reconcile immediately against the persisted end timestamp. The desktop
  /// Picture-in-Picture surface calls this when its visible deadline reaches
  /// zero so completion is not delayed by hidden-page timer throttling.
  Future<void> reconcileNow() => _pulse();

  Future<void> _pulse() async {
    if (_processing) return;
    _processing = true;
    try {
      if (!ownsTimer) {
        final remote = await database.loadTimerState();
        if (remote.updatedAt != _state.updatedAt ||
            remote.running != _state.running ||
            remote.paused != _state.paused ||
            remote.owner != _state.owner ||
            remote.remainingSeconds != _state.remainingSeconds ||
            remote.elapsedSeconds != _state.elapsedSeconds) {
          _state = remote;
          notifyListeners();
        }
        return;
      }
      if (!_state.running || _state.paused) return;
      final now = DateTime.now().toUtc();
      final gap = now.difference(_state.updatedAt);
      if (gap > suspensionGapThreshold) {
        await _freezeForInterruption(now);
        return;
      }
      final next = _calculateCurrent(_state, now);
      final second = next.mode == TimerMode.stopwatch
          ? next.elapsedSeconds
          : next.remainingSeconds;
      _state = next;
      notifyListeners();
      if (second != _lastPersistedSecond) {
        _lastPersistedSecond = second;
        await database.saveTimerState(_state);
      }
      if (_state.mode != TimerMode.stopwatch && _state.remainingSeconds <= 0) {
        await _completeCurrentSession();
      }
    } finally {
      _processing = false;
    }
  }

  Future<void> _freezeForInterruption(
    DateTime now, {
    bool notify = true,
  }) async {
    _state = _state.copyWith(
      owner: role,
      running: false,
      paused: true,
      startedAt: null,
      endAt: null,
      updatedAt: now,
    );
    _lastPersistedSecond = -1;
    await database.saveTimerState(_state);
    if (notify) notifyListeners();
  }

  TimerStateRecord _calculateCurrent(TimerStateRecord current, DateTime now) {
    if (current.paused || !current.running || current.startedAt == null) {
      return current;
    }
    if (current.mode == TimerMode.stopwatch) {
      final added = now
          .difference(current.startedAt!)
          .inSeconds
          .clamp(0, 8640000)
          .toInt();
      return current.copyWith(
        elapsedSeconds: current.elapsedSeconds + added,
        startedAt: now,
        updatedAt: now,
      );
    }
    final endAt = current.endAt;
    if (endAt == null) return current;
    final remaining = endAt
        .difference(now)
        .inSeconds
        .clamp(0, current.durationSeconds)
        .toInt();
    return current.copyWith(
      remainingSeconds: remaining,
      elapsedSeconds: (current.durationSeconds - remaining)
          .clamp(0, current.durationSeconds)
          .toInt(),
      updatedAt: now,
    );
  }

  Future<void> start({
    required TimerMode mode,
    required String title,
    String? workItemId,
    int durationMinutes = 25,
    bool autoRepeat = false,
  }) async {
    primeTimerCompletionChime();
    final now = DateTime.now().toUtc();
    final durationSeconds = durationMinutes.clamp(1, 720).toInt() * 60;
    _state = TimerStateRecord(
      mode: mode,
      owner: role,
      workItemId: workItemId,
      title: title.trim().isEmpty
          ? (mode == TimerMode.stopwatch ? 'Study stopwatch' : 'General focus')
          : title.trim(),
      durationSeconds: durationSeconds,
      remainingSeconds: mode == TimerMode.stopwatch ? 0 : durationSeconds,
      elapsedSeconds: 0,
      running: true,
      paused: false,
      autoRepeat: autoRepeat,
      startedAt: now,
      endAt: mode == TimerMode.stopwatch
          ? null
          : now.add(Duration(seconds: durationSeconds)),
      updatedAt: now,
      completionToken: _uuid.v4(),
    );
    await database.saveTimerState(_state);
    onTimerStarted?.call(mode);
    notifyListeners();
  }

  Future<void> pause() async {
    if (!isActive) return;
    final now = DateTime.now().toUtc();
    _state = _calculateCurrent(_state, now).copyWith(
      running: false,
      paused: true,
      startedAt: null,
      endAt: null,
      updatedAt: now,
      owner: role,
    );
    await database.saveTimerState(_state);
    notifyListeners();
  }

  Future<void> resume() async {
    if (!_state.paused) return;
    primeTimerCompletionChime();
    final now = DateTime.now().toUtc();
    _state = _state.copyWith(
      owner: role,
      running: true,
      paused: false,
      startedAt: now,
      endAt: _state.mode == TimerMode.stopwatch
          ? null
          : now.add(Duration(seconds: _state.remainingSeconds)),
      updatedAt: now,
    );
    await database.saveTimerState(_state);
    notifyListeners();
  }

  Future<void> reset() async {
    final now = DateTime.now().toUtc();
    _state = _state.copyWith(
      owner: role,
      running: false,
      paused: false,
      remainingSeconds: _state.mode == TimerMode.stopwatch
          ? 0
          : _state.durationSeconds,
      elapsedSeconds: 0,
      startedAt: null,
      endAt: null,
      updatedAt: now,
      completionToken: _uuid.v4(),
    );
    await database.saveTimerState(_state);
    notifyListeners();
  }

  Future<void> stop({bool saveSession = true}) async {
    final now = DateTime.now().toUtc();
    final calculated = _calculateCurrent(_state, now);
    if (saveSession && calculated.elapsedSeconds > 0) {
      await _recordSession(calculated, completed: false, endedAt: now);
    }
    _state = calculated.copyWith(
      owner: role,
      running: false,
      paused: false,
      startedAt: null,
      endAt: null,
      updatedAt: now,
      completionToken: _uuid.v4(),
    );
    await database.saveTimerState(_state);
    notifyListeners();
  }

  Future<void> setAutoRepeat(bool value) async {
    _state = _state.copyWith(
      autoRepeat: value,
      owner: role,
      updatedAt: DateTime.now().toUtc(),
    );
    await database.saveTimerState(_state);
    notifyListeners();
  }

  Future<void> takeOwnership() async {
    final fresh = await database.loadTimerState();
    _state = fresh.copyWith(owner: role, updatedAt: DateTime.now().toUtc());
    await database.saveTimerState(_state);
    notifyListeners();
  }

  Future<void> giveOwnership(TimerOwner owner) async {
    _state = _state.copyWith(owner: owner, updatedAt: DateTime.now().toUtc());
    await database.saveTimerState(_state);
    notifyListeners();
  }

  Future<void> _completeCurrentSession() async {
    final now = DateTime.now().toUtc();
    final completedState = _state.copyWith(
      remainingSeconds: 0,
      elapsedSeconds: _state.durationSeconds,
      updatedAt: now,
    );
    await _recordSession(completedState, completed: true, endedAt: now);
    if (completedState.workItemId != null) {
      await repository.advanceChecklist(completedState.workItemId!);
    }
    unawaited(playTimerCompletionChime(completedState.completionToken));
    if (_state.autoRepeat) {
      final duration = _state.durationSeconds;
      _state = _state.copyWith(
        remainingSeconds: duration,
        elapsedSeconds: 0,
        running: true,
        paused: false,
        startedAt: now,
        endAt: now.add(Duration(seconds: duration)),
        updatedAt: now,
        completionToken: _uuid.v4(),
      );
    } else {
      _state = _state.copyWith(
        remainingSeconds: 0,
        elapsedSeconds: _state.durationSeconds,
        running: false,
        paused: false,
        startedAt: null,
        endAt: null,
        updatedAt: now,
      );
    }
    await database.saveTimerState(_state);
    notifyListeners();
  }

  Future<void> _recordSession(
    TimerStateRecord source, {
    required bool completed,
    required DateTime endedAt,
  }) async {
    final startedAt = endedAt.subtract(
      Duration(seconds: source.elapsedSeconds),
    );
    final session = TimeSession(
      id: source.completionToken.isEmpty ? _uuid.v4() : source.completionToken,
      mode: source.mode,
      workItemId: source.workItemId,
      title: source.title,
      plannedSeconds: source.mode == TimerMode.stopwatch
          ? 0
          : source.durationSeconds,
      elapsedSeconds: source.elapsedSeconds,
      startedAt: startedAt,
      endedAt: endedAt,
      completed: completed,
      createdAt: endedAt,
      updatedAt: endedAt,
      revision: 1,
      deviceId: repository.deviceId,
    );
    await repository.saveTimeSession(session);
    onSessionRecorded?.call(session);
  }

  String formatSeconds(int totalSeconds) {
    final seconds = totalSeconds.abs();
    final hours = seconds ~/ 3600;
    final minutes = (seconds % 3600) ~/ 60;
    final remainder = seconds % 60;
    if (hours > 0) {
      return '${hours.toString().padLeft(2, '0')}:${minutes.toString().padLeft(2, '0')}:${remainder.toString().padLeft(2, '0')}';
    }
    return '${minutes.toString().padLeft(2, '0')}:${remainder.toString().padLeft(2, '0')}';
  }

  @override
  void dispose() {
    _ticker?.cancel();
    super.dispose();
  }
}
