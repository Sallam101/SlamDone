import 'package:firebase_analytics/firebase_analytics.dart';

import '../firebase/firebase_config.dart';

/// Privacy-safe product analytics for SlamDone.
///
/// Only aggregate event names and generic enum/status values are accepted here.
/// Planner content (task titles, journal text, NorthStar text, habit names,
/// table contents, emails, IDs, and other user-authored text) must never be
/// passed to this service.
class AppAnalytics {
  FirebaseAnalytics? _client;
  bool _available = false;
  bool _enabled = false;

  bool get isAvailable => _available;
  bool get isEnabled => _enabled;

  Future<void> initialize({required bool enabled}) async {
    _available = FirebaseConfig.isConfigured &&
        FirebaseConfig.measurementId.trim().isNotEmpty;
    if (!_available) {
      _enabled = false;
      return;
    }

    try {
      _client ??= FirebaseAnalytics.instance;
      await _client!.setAnalyticsCollectionEnabled(enabled);
      _enabled = enabled;
    } catch (_) {
      // Analytics must never prevent SlamDone from opening or saving data.
      _enabled = false;
    }
  }

  Future<void> setEnabled(bool enabled) async {
    if (!_available || _client == null) {
      _enabled = false;
      return;
    }

    // Stop custom events immediately when the user opts out, even if the SDK
    // call itself is delayed or rejected by the browser.
    _enabled = enabled;
    try {
      await _client!.setAnalyticsCollectionEnabled(enabled);
    } catch (_) {
      if (enabled) _enabled = false;
    }
  }

  Future<void> logAppOpened({
    required String syncMode,
    required bool signedIn,
  }) =>
      _log('slamdone_opened', {
        'sync_mode': _safeEnum(syncMode),
        'signed_in': signedIn ? 1 : 0,
      });

  Future<void> logSectionOpened(String section) =>
      _log('section_opened', {'section': _safeEnum(section)});

  Future<void> logWorkItemCreated(String itemType) =>
      _log('work_item_created', {'item_type': _safeEnum(itemType)});

  Future<void> logWorkItemCompleted(String itemType) =>
      _log('work_item_completed', {'item_type': _safeEnum(itemType)});

  Future<void> logHabitCheckIn(String habitKind) =>
      _log('habit_checkin', {'habit_kind': _safeEnum(habitKind)});

  Future<void> logFocusStarted(String timerMode) =>
      _log('focus_started', {'timer_mode': _safeEnum(timerMode)});

  Future<void> logFocusCompleted(String timerMode) =>
      _log('focus_completed', {'timer_mode': _safeEnum(timerMode)});

  Future<void> logCloudSyncEnabled(bool signedIn) =>
      _log('cloud_sync_enabled', {'signed_in': signedIn ? 1 : 0});

  Future<void> _log(String name, Map<String, Object> parameters) async {
    final client = _client;
    if (!_enabled || !_available || client == null) return;
    try {
      await client.logEvent(name: name, parameters: parameters);
    } catch (_) {
      // Tracking failures are intentionally non-fatal and silent.
    }
  }

  String _safeEnum(String value) {
    final normalized = value
        .trim()
        .toLowerCase()
        .replaceAll(RegExp(r'[^a-z0-9_]+'), '_')
        .replaceAll(RegExp(r'_+'), '_');
    if (normalized.isEmpty) return 'unknown';
    return normalized.length <= 40 ? normalized : normalized.substring(0, 40);
  }
}
