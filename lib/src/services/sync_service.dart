import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

import '../database/local_database.dart';
import '../firebase/firebase_config.dart';
import '../models/models.dart';
import '../sync/conflict_resolver.dart';

class SyncService extends ChangeNotifier {
  SyncService({
    required this.database,
    required this.onRemoteChanged,
    required this.isJournalEditing,
  });

  final LocalDatabase database;
  final Future<void> Function() onRemoteChanged;
  final bool Function(String journalId) isJournalEditing;

  final List<StreamSubscription<dynamic>> _subscriptions = [];
  StreamSubscription<User?>? _authSubscription;
  Timer? _periodicTimer;
  Timer? _scheduledPushTimer;
  Timer? _verificationTimer;
  bool _busy = false;
  String _status = 'Browser local';
  Object? _lastError;
  DateTime? _lastSyncedAt;
  String _mode = 'local';
  bool _verified = false;
  Map<String, int> _localAuditCounts = const {};
  Map<String, int> _cloudAuditCounts = const {};
  Map<String, String> _auditErrors = const {};
  String _verificationStep = '';
  String _localDeviceId = '';
  String _primaryDeviceId = '';
  String _workItemDiagnostics = '';

  static const List<String> cloudTables = [
    'work_items',
    'canvas_layouts',
    'journal_entries',
    'journal_versions',
    'time_sessions',
    'habits',
    'habit_entries',
    'northstar_notes',
    'reward_ranks',
    'study_tables',
  ];

  static const Set<String> localOnlySettingKeys = {
    'device_id',
    'drive_sync_folder',
    'sync_mode',
    'floating_timer_command',
    'floating_timer_heartbeat',
  };

  static const int northStarImageChunkChars = 700000;

  bool get firebaseAvailable => FirebaseConfig.isConfigured;
  bool get isBusy => _busy;
  String get status => _status;
  Object? get lastError => _lastError;
  DateTime? get lastSyncedAt => _lastSyncedAt;
  String get mode => _mode;
  bool get verified => _verified;
  String get primaryDeviceId => _primaryDeviceId;
  String get localDeviceId => _localDeviceId;
  bool get isPrimaryDevice =>
      _primaryDeviceId.isNotEmpty && _primaryDeviceId == _localDeviceId;
  String get workItemDiagnostics => _workItemDiagnostics;
  Map<String, int> get localAuditCounts => Map.unmodifiable(_localAuditCounts);
  Map<String, int> get cloudAuditCounts => Map.unmodifiable(_cloudAuditCounts);
  Map<String, String> get auditErrors => Map.unmodifiable(_auditErrors);
  String get verificationDetail {
    if (_verificationStep.isNotEmpty) return _verificationStep;
    if (_auditErrors.isNotEmpty) {
      return _auditErrors.entries
          .map((entry) => '${entry.key}: ${entry.value}')
          .join(' • ');
    }
    if (!_verified && _localAuditCounts.isNotEmpty) {
      final keys = {..._localAuditCounts.keys, ..._cloudAuditCounts.keys}.toList()
        ..sort();
      final mismatches = keys.where(
        (key) =>
            (_localAuditCounts[key] ?? 0) != (_cloudAuditCounts[key] ?? 0),
      );
      if (mismatches.isNotEmpty) {
        final mismatchText = mismatches.map((key) {
          final local = _localAuditCounts[key] ?? 0;
          final cloud = _cloudAuditCounts[key] ?? 0;
          return '$key $local/$cloud';
        }).join(' • ');
        return 'Count mismatch • $mismatchText';
      }
    }
    return _verified
        ? 'Every planner table was reconciled and re-read from Firestore.'
        : '';
  }
  String get auditSummary {
    if (_localAuditCounts.isEmpty && _cloudAuditCounts.isEmpty) {
      return 'Not audited yet';
    }
    final prefix = _verified ? 'Verified local/cloud' : 'Local/cloud';
    String safePair(String key) {
      final local = _localAuditCounts[key] ?? 0;
      final cloud = _cloudAuditCounts[key] ?? 0;
      return cloud < 0 ? '$local/ERR' : '$local/$cloud';
    }
    return '$prefix • items ${safePair('work_items')} • habits ${safePair('habits')} • '
        'focus ${safePair('time_sessions')} • journals ${safePair('journal_entries')}';
  }
  String? get folderPath => null;
  bool get folderSyncEnabled => false;
  User? get currentUser =>
      firebaseAvailable ? FirebaseAuth.instance.currentUser : null;
  bool get isSignedIn => currentUser != null;

  Future<void> initialize() async {
    await _refreshDeviceIdentity();
    _mode = await database.getSetting('sync_mode') ?? 'local';
    if (_mode == 'folder' || _mode == 'supabase') {
      _mode = 'local';
      await database.setSetting('sync_mode', _mode);
    }

    if (firebaseAvailable) {
      _authSubscription = FirebaseAuth.instance.authStateChanges().listen(
        (user) async {
          if (_mode != 'firebase') return;
          if (user == null) {
            await _cancelRealtime();
            _status = 'Cloud signed out — browser data remains safe';
            notifyListeners();
          } else {
            await startRealtime();
            unawaited(syncNow());
          }
        },
      );
    }

    await _activateCurrentMode();
    _periodicTimer = Timer.periodic(
      const Duration(seconds: 15),
      (_) => unawaited(syncNow(silent: true, pullRemote: false)),
    );
  }


  void schedulePush({
    Duration delay = const Duration(milliseconds: 450),
  }) {
    if (_mode != 'firebase' || !firebaseAvailable || !isSignedIn) return;
    _scheduledPushTimer?.cancel();
    _verificationTimer?.cancel();
    if (_verified) {
      _verified = false;
      _status = 'Change queued — syncing to cloud…';
      notifyListeners();
    }
    _scheduledPushTimer = Timer(delay, () {
      unawaited(_flushScheduledPush());
    });
  }

  void _scheduleVerificationAudit({
    Duration delay = const Duration(milliseconds: 900),
  }) {
    if (_mode != 'firebase' || !firebaseAvailable || !isSignedIn) return;
    _verified = false;
    if (_auditErrors.isEmpty) {
      _status = 'Realtime connected — verifying planner data…';
    }
    _verificationTimer?.cancel();
    _verificationTimer = Timer(delay, () {
      if (_busy) {
        _scheduleVerificationAudit(delay: const Duration(milliseconds: 900));
        return;
      }
      unawaited(syncNow(silent: true));
    });
  }

  Future<void> _flushScheduledPush() async {
    if (_mode != 'firebase' || !firebaseAvailable || !isSignedIn) return;
    if (_busy) {
      schedulePush(delay: const Duration(milliseconds: 700));
      return;
    }
    await syncNow(silent: true, pullRemote: false);
    if (_auditErrors.isEmpty) {
      _scheduleVerificationAudit(delay: const Duration(milliseconds: 1400));
    }
  }

  Future<void> handleAppResumed() async {
    if (_mode != 'firebase' || !firebaseAvailable || !isSignedIn) return;
    await startRealtime();
    await syncNow(silent: true);
  }

  Future<void> _activateCurrentMode() async {
    await _cancelRealtime();
    if (_mode == 'firebase') {
      if (!firebaseAvailable) {
        _status = 'Firebase is not configured in this GitHub build';
      } else if (isSignedIn) {
        await startRealtime();
        _verified = false;
        _status = 'Realtime connected — verifying planner data…';
        unawaited(syncNow(silent: true));
      } else {
        _status = 'Ready to connect Google for cross-device sync';
      }
    } else {
      _verified = false;
      _status = 'Browser local — automatic saving is active';
    }
    notifyListeners();
  }

  Future<void> _refreshDeviceIdentity() async {
    _localDeviceId = await database.getSetting('device_id') ?? '';
    _primaryDeviceId = await database.getSetting('primary_device_id') ?? '';
  }

  Future<void> makeThisPrimaryDevice() async {
    await _refreshDeviceIdentity();
    if (_localDeviceId.isEmpty) {
      throw StateError('This browser does not have a stable device id yet.');
    }
    await database.claimPrimaryStructuralAuthority(_localDeviceId);
    await database.setSetting('primary_device_id', _localDeviceId);
    _primaryDeviceId = _localDeviceId;
    _verified = false;
    _status = 'Primary PC saved — reconciling planner structure…';
    notifyListeners();
    if (_mode == 'firebase' && firebaseAvailable && isSignedIn) {
      await _pushSetting(currentUser!, 'primary_device_id');
      await verifyAndRepair();
    }
  }

  Future<void> useLocalOnly() async {
    _mode = 'local';
    _verified = false;
    await database.setSetting('sync_mode', _mode);
    await _activateCurrentMode();
  }

  Future<void> useFirebase() async {
    _mode = 'firebase';
    await database.setSetting('sync_mode', _mode);
    await _activateCurrentMode();
  }

  Future<String> signInWithGoogle() async {
    if (!firebaseAvailable) {
      return 'Firebase is not configured in this GitHub build.';
    }
    await useFirebase();
    _setBusy(true, 'Connecting Google account…');
    try {
      final provider = GoogleAuthProvider();
      provider.setCustomParameters({'prompt': 'select_account'});
      try {
        await FirebaseAuth.instance.signInWithPopup(provider);
      } catch (popupError) {
        _lastError = popupError;
        await FirebaseAuth.instance.signInWithRedirect(provider);
        return 'Google sign-in is continuing in this browser. Return to SlamDone after Google completes.';
      }
      // Release the sign-in busy gate before invoking syncNow(); otherwise
      // syncNow() exits immediately and the newly authenticated device can
      // appear connected without ever reconciling its planner records.
      _busy = false;
      notifyListeners();
      await startRealtime();
      await syncNow();
      _lastError = null;
      return _verified
          ? 'Google account connected. ${_verifiedStatus()}'
          : 'Google account connected. Planner verification is still running.';
    } catch (error) {
      _lastError = error;
      return 'Google sign-in failed: $error';
    } finally {
      _busy = false;
      _status = !isSignedIn
          ? 'Ready to connect Google'
          : (_verified
              ? _verifiedStatus()
              : (_auditErrors.isNotEmpty
                  ? 'Sync incomplete • ${_auditErrors.length} repair issue(s)'
                  : 'Realtime connected — verifying planner data…'));
      notifyListeners();
    }
  }

  Future<void> signOut() async {
    if (!firebaseAvailable) return;
    await _cancelRealtime();
    await FirebaseAuth.instance.signOut();
    _status = 'Signed out — browser data remains safe';
    notifyListeners();
  }

  DocumentReference<Map<String, dynamic>> _userRoot(User user) =>
      FirebaseFirestore.instance.collection('users').doc(user.uid);

  Future<void> verifyAndRepair() async {
    if (_busy || _mode != 'firebase' || !firebaseAvailable || !isSignedIn) {
      return;
    }
    _verificationTimer?.cancel();
    _scheduledPushTimer?.cancel();
    _verified = false;
    _auditErrors = const {};
    _localAuditCounts = const {};
    _cloudAuditCounts = const {};
    _verificationStep = 'Starting full planner verification…';
    _status = 'Verifying every planner table…';
    notifyListeners();

    // Keep realtime listeners from racing the deterministic repair pass. They
    // are restarted after the audit so normal live updates continue.
    await _cancelRealtime();
    try {
      await syncNow(pullRemote: true, forceFullRepair: true);
    } finally {
      await startRealtime();
      notifyListeners();
    }
  }

  Future<void> syncNow({
    bool silent = false,
    bool pullRemote = true,
    bool forceFullRepair = false,
  }) async {
    if (_busy || _mode != 'firebase' || !firebaseAvailable || !isSignedIn) {
      return;
    }
    final user = currentUser!;
    _setBusy(true, silent ? _status : 'Syncing SlamDone…', notify: !silent);
    if (pullRemote) {
      _verified = false;
      if (!forceFullRepair) {
        _auditErrors = const {};
      }
    }
    try {
      if (pullRemote) {
        // Settings contains the Primary-PC device designation. Load it before
        // planner entities so structural conflict policy is correct even on a
        // stale phone during the very first repair pass.
        await _reconcileSettings(user);
        await _reconcileAllEntities(user);
        await _reconcileTimerState(user);
      }
      await _pushQueueToFirestore(user);
      _lastSyncedAt = DateTime.now();
      _lastError = null;

      if (pullRemote) {
        _verified = _auditErrors.isEmpty && _auditCountsMatch();
        _verificationStep = '';
        if (_verified) {
          _status = _verifiedStatus();
        } else if (_auditErrors.isNotEmpty) {
          _status = 'Sync incomplete • ${_auditErrors.length} repair issue(s)';
        } else {
          _status = 'Cloud connected — planner counts still differ';
        }
        await onRemoteChanged();
      } else if (_verified) {
        _status = _verifiedStatus();
      } else if (_auditErrors.isNotEmpty) {
        // Do not let a successful background queue drain erase the useful
        // failure produced by the last full verification attempt.
        _status = 'Sync incomplete • ${_auditErrors.length} repair issue(s)';
      }
    } catch (error) {
      _verified = false;
      _lastError = error;
      _verificationStep = '';
      _auditErrors = {..._auditErrors, 'sync': _shortError(error)};
      _status = 'Sync incomplete • ${_auditErrors.length} repair issue(s)';
    } finally {
      _busy = false;
      notifyListeners();
    }
  }

  String _shortError(Object error) {
    final text = error.toString().replaceAll(RegExp(r'\s+'), ' ').trim();
    return text.length <= 180 ? text : '${text.substring(0, 177)}…';
  }

  String _verifiedStatus() {
    final items = _localAuditCounts['work_items'] ?? 0;
    final habits = _localAuditCounts['habits'] ?? 0;
    final sessions = _localAuditCounts['time_sessions'] ?? 0;
    return 'Verified sync • $items items • $habits habits • $sessions sessions';
  }

  bool _auditCountsMatch() {
    if (_localAuditCounts.isEmpty || _cloudAuditCounts.isEmpty) return false;
    for (final key in {..._localAuditCounts.keys, ..._cloudAuditCounts.keys}) {
      if ((_localAuditCounts[key] ?? 0) != (_cloudAuditCounts[key] ?? 0)) {
        return false;
      }
    }
    return true;
  }

  Future<void> _pushEntityPayload(
    User user,
    DocumentReference<Map<String, dynamic>> root,
    String entityType,
    String entityId,
  ) async {
    final payload = await database.cloudPayload(entityType, entityId, user.uid);
    if (payload == null) return;
    final cloudPayload = payload.cast<String, dynamic>();
    if (entityType == 'northstar_notes') {
      await _pushNorthStarNote(root, entityId, cloudPayload);
    } else {
      await root
          .collection(entityType)
          .doc(entityId)
          .set(cloudPayload, SetOptions(merge: true));
    }
  }

  Future<void> _pushEntityIds(
    User user,
    DocumentReference<Map<String, dynamic>> root,
    String entityType,
    List<String> entityIds,
  ) async {
    if (entityIds.isEmpty) return;
    if (entityType == 'northstar_notes') {
      for (final id in entityIds) {
        await _pushEntityPayload(user, root, entityType, id);
      }
      return;
    }

    // Firestore batches cut the first full PC repair from hundreds of network
    // round-trips to a handful while staying below the 500-operation limit.
    const maxBatchWrites = 350;
    for (var start = 0; start < entityIds.length; start += maxBatchWrites) {
      final end = (start + maxBatchWrites).clamp(0, entityIds.length).toInt();
      final batch = FirebaseFirestore.instance.batch();
      var writes = 0;
      for (final id in entityIds.sublist(start, end)) {
        final payload = await database.cloudPayload(entityType, id, user.uid);
        if (payload == null) continue;
        batch.set(
          root.collection(entityType).doc(id),
          payload.cast<String, dynamic>(),
          SetOptions(merge: true),
        );
        writes++;
      }
      if (writes > 0) await batch.commit();
    }
  }

  bool _localShouldUpload(
    String entityType,
    Map<String, Object?> localRow,
    Map<String, Object?>? remoteRow,
  ) {
    if (remoteRow == null) return true;
    if (_primaryDeviceId.isNotEmpty &&
        const {'work_items', 'canvas_layouts', 'northstar_notes'}
            .contains(entityType)) {
      final localPrimary =
          localRow['device_id']?.toString() == _primaryDeviceId;
      final remotePrimary =
          remoteRow['device_id']?.toString() == _primaryDeviceId;
      if (localPrimary && !remotePrimary) return true;
      if (!localPrimary && remotePrimary && entityType != 'work_items') {
        return false;
      }
    }
    return incomingRecordIsNewer(localRow, remoteRow);
  }

  Future<void> _reconcileAllEntities(User user) async {
    await _refreshDeviceIdentity();
    final root = _userRoot(user);
    final localCounts = <String, int>{};
    final cloudCounts = <String, int>{};
    final errors = <String, String>{..._auditErrors};

    for (var index = 0; index < cloudTables.length; index++) {
      final entityType = cloudTables[index];
      _verificationStep =
          'Checking ${index + 1}/${cloudTables.length}: ${_tableLabel(entityType)}…';
      _status = _verificationStep;
      notifyListeners();
      try {
        final snapshot = await root.collection(entityType).get();
        final remoteRows = await _rowsFromSnapshot(user, entityType, snapshot);
        final remoteById = <String, Map<String, Object?>>{
          for (final raw in remoteRows)
            if (raw['id']?.toString().isNotEmpty == true)
              raw['id'].toString():
                  Map<String, Object?>.from(raw)..remove('owner_id'),
        };

        final forcedUploadIds = <String>{};
        if (entityType == 'work_items') {
          final report = await database.mergeRemoteWorkItemsParentFirst(
            remoteRows,
            primaryDeviceId: _primaryDeviceId,
          );
          forcedUploadIds.addAll(report.authoritativeUploadIds);
          _workItemDiagnostics =
              'Work items • inserted ${report.inserted} • updated ${report.updated} • '
              'skipped ${report.skipped} • deferred ${report.deferred}';
          if (report.orphanIds.isNotEmpty) {
            errors['work_items'] =
                'Unresolved parent links: ${report.orphanIds.join(', ')}';
          }
        } else {
          await database.mergeRemoteRows(
            entityType,
            remoteRows,
            shouldDefer:
                entityType == 'journal_entries' ? isJournalEditing : null,
            primaryDeviceId: _primaryDeviceId,
          );
        }

        final localRows = await database.loadRowsForSync(entityType);
        final uploadIds = <String>[];
        for (final rawLocal in localRows) {
          final id = rawLocal['id']?.toString() ?? '';
          if (id.isEmpty) continue;
          final localRow = Map<String, Object?>.from(rawLocal);
          final remoteRow = remoteById[id];
          if (forcedUploadIds.contains(id) ||
              _localShouldUpload(entityType, localRow, remoteRow)) {
            uploadIds.add(id);
          }
        }
        await _pushEntityIds(user, root, entityType, uploadIds);

        final verifySnapshot = await root.collection(entityType).get();
        if (entityType != 'northstar_notes') {
          final verifyRows = await _rowsFromSnapshot(
            user,
            entityType,
            verifySnapshot,
          );
          if (entityType == 'work_items') {
            final verifyReport = await database.mergeRemoteWorkItemsParentFirst(
              verifyRows,
              primaryDeviceId: _primaryDeviceId,
            );
            if (verifyReport.orphanIds.isNotEmpty) {
              errors['work_items'] =
                  'Unresolved parent links: ${verifyReport.orphanIds.join(', ')}';
            } else if (errors['work_items']?.startsWith('Unresolved parent') ==
                true) {
              errors.remove('work_items');
            }
          } else {
            await database.mergeRemoteRows(
              entityType,
              verifyRows,
              shouldDefer:
                  entityType == 'journal_entries' ? isJournalEditing : null,
              primaryDeviceId: _primaryDeviceId,
            );
          }
        }
        final finalLocalRows = await database.loadRowsForSync(entityType);
        localCounts[entityType] = finalLocalRows
            .map((row) => row['id']?.toString() ?? '')
            .where((id) => id.isNotEmpty)
            .toSet()
            .length;
        cloudCounts[entityType] = verifySnapshot.docs.length;
        if (entityType != 'work_items' || !errors.containsKey('work_items')) {
          errors.remove(entityType);
        }
        if (const {
          'work_items',
          'journal_entries',
          'time_sessions',
          'habit_entries',
        }.contains(entityType)) {
          await onRemoteChanged();
        }
      } catch (error) {
        errors[entityType] = _shortError(error);
        localCounts[entityType] =
            (await database.loadRowsForSync(entityType)).length;
        cloudCounts[entityType] = -1;
      }
      _localAuditCounts = {..._localAuditCounts, ...localCounts};
      _cloudAuditCounts = {..._cloudAuditCounts, ...cloudCounts};
      _auditErrors = Map.unmodifiable(errors);
      notifyListeners();
    }
  }

  String _tableLabel(String entityType) => switch (entityType) {
        'work_items' => 'tasks and Big Picture',
        'canvas_layouts' => 'card layouts',
        'journal_entries' => 'journals',
        'journal_versions' => 'journal history',
        'time_sessions' => 'focus sessions',
        'habits' => 'habits',
        'habit_entries' => 'habit check-ins',
        'northstar_notes' => 'NorthStar',
        'reward_ranks' => 'rewards',
        'study_tables' => 'tables',
        _ => entityType,
      };

  bool _settingLocalIsNewer(
    Map<String, Object?> localRow,
    Map<String, Object?> remoteRow,
  ) {
    final localTime = DateTime.tryParse(localRow['updated_at']?.toString() ?? '')
            ?.toUtc() ??
        DateTime.fromMillisecondsSinceEpoch(0, isUtc: true);
    final remoteTime = DateTime.tryParse(remoteRow['updated_at']?.toString() ?? '')
            ?.toUtc() ??
        DateTime.fromMillisecondsSinceEpoch(0, isUtc: true);
    return localTime.isAfter(remoteTime);
  }

  Future<void> _reconcileSettings(User user) async {
    _verificationStep = 'Checking settings…';
    _status = _verificationStep;
    notifyListeners();
    final errors = <String, String>{..._auditErrors};
    try {
      final root = _userRoot(user);
      final snapshot = await root.collection('settings').get();
      await _mergeSettingsSnapshot(user, snapshot);
      final remoteByKey = <String, Map<String, Object?>>{
        for (final doc in snapshot.docs)
          if (!localOnlySettingKeys.contains(doc.id))
            doc.id: Map<String, Object?>.from(doc.data()),
      };
      final localRows = (await database.loadAllSettingRows())
          .where(
            (row) => !localOnlySettingKeys.contains(
              row['setting_key']?.toString(),
            ),
          )
          .toList(growable: false);
      for (final row in localRows) {
        final key = row['setting_key']?.toString() ?? '';
        if (key.isEmpty) continue;
        final remote = remoteByKey[key];
        if (remote == null || _settingLocalIsNewer(row, remote)) {
          await _pushSetting(user, key);
        }
      }

      final verifySnapshot = await root.collection('settings').get();
      await _mergeSettingsSnapshot(user, verifySnapshot);
      final finalLocalKeys = (await database.loadAllSettingRows())
          .where(
            (row) => !localOnlySettingKeys.contains(
              row['setting_key']?.toString(),
            ),
          )
          .map((row) => row['setting_key']?.toString() ?? '')
          .where((key) => key.isNotEmpty)
          .toSet();
      final finalCloudKeys = verifySnapshot.docs
          .where((doc) => !localOnlySettingKeys.contains(doc.id))
          .map((doc) => doc.id)
          .toSet();
      _localAuditCounts = {
        ..._localAuditCounts,
        'app_settings': finalLocalKeys.length,
      };
      _cloudAuditCounts = {
        ..._cloudAuditCounts,
        'app_settings': finalCloudKeys.length,
      };
      await _refreshDeviceIdentity();
      errors.remove('app_settings');
    } catch (error) {
      errors['app_settings'] = _shortError(error);
      _cloudAuditCounts = {..._cloudAuditCounts, 'app_settings': -1};
    }
    _auditErrors = Map.unmodifiable(errors);
    notifyListeners();
  }

  Future<void> _reconcileTimerState(User user) async {
    _verificationStep = 'Checking timer state…';
    _status = _verificationStep;
    notifyListeners();
    final errors = <String, String>{..._auditErrors};
    try {
      await _pullTimerState(user);
      await _pushTimerState(user);
      final verify = await _userRoot(user)
          .collection('meta')
          .doc('timer_state')
          .get();
      await _mergeTimerSnapshot(user, verify);
      _localAuditCounts = {..._localAuditCounts, 'timer_state': 1};
      _cloudAuditCounts = {
        ..._cloudAuditCounts,
        'timer_state': verify.exists ? 1 : 0,
      };
      errors.remove('timer_state');
    } catch (error) {
      errors['timer_state'] = _shortError(error);
      _localAuditCounts = {..._localAuditCounts, 'timer_state': 1};
      _cloudAuditCounts = {..._cloudAuditCounts, 'timer_state': -1};
    }
    _auditErrors = Map.unmodifiable(errors);
    notifyListeners();
  }

  Future<void> _pushQueueToFirestore(User user) async {
    final root = _userRoot(user);
    final queue = await database.loadSyncQueue(limit: 500);
    final batchedGroups = <String, List<SyncQueueEntry>>{};
    final directEntries = <SyncQueueEntry>[];

    for (final entry in queue) {
      if (entry.entityType == 'app_settings' ||
          entry.entityType == 'timer_state' ||
          entry.entityType == 'northstar_notes') {
        directEntries.add(entry);
      } else {
        batchedGroups.putIfAbsent(entry.entityType, () => []).add(entry);
      }
    }

    for (final group in batchedGroups.entries) {
      try {
        await _pushEntityIds(
          user,
          root,
          group.key,
          group.value.map((entry) => entry.entityId).toList(growable: false),
        );
        for (final entry in group.value) {
          await database.markQueueSuccess(entry.queueId);
        }
      } catch (error) {
        for (final entry in group.value) {
          await database.markQueueFailure(entry.queueId, error);
        }
        _auditErrors = {
          ..._auditErrors,
          'queue:${group.key}': _shortError(error),
        };
        _lastError = error;
      }
    }

    for (final entry in directEntries) {
      try {
        final entityType = entry.entityType;
        if (entityType == 'app_settings') {
          if (!localOnlySettingKeys.contains(entry.entityId)) {
            await _pushSetting(user, entry.entityId);
          }
        } else if (entityType == 'timer_state') {
          await _pushTimerState(user);
        } else {
          await _pushEntityPayload(user, root, entityType, entry.entityId);
        }
        await database.markQueueSuccess(entry.queueId);
      } catch (error) {
        await database.markQueueFailure(entry.queueId, error);
        _auditErrors = {
          ..._auditErrors,
          'queue:${entry.entityType}': _shortError(error),
        };
        _lastError = error;
      }
    }
  }

  Future<void> _pullAllFromFirestore(User user) async {
    await _refreshDeviceIdentity();
    final root = FirebaseFirestore.instance.collection('users').doc(user.uid);
    for (final entityType in cloudTables) {
      final snapshot = await root.collection(entityType).get();
      final rows = await _rowsFromSnapshot(user, entityType, snapshot);
      if (entityType == 'work_items') {
        await database.mergeRemoteWorkItemsParentFirst(
          rows,
          primaryDeviceId: _primaryDeviceId,
        );
      } else {
        await database.mergeRemoteRows(
          entityType,
          rows,
          shouldDefer:
              entityType == 'journal_entries' ? isJournalEditing : null,
          primaryDeviceId: _primaryDeviceId,
        );
      }
    }
  }

  Future<List<Map<String, dynamic>>> _rowsFromSnapshot(
    User user,
    String entityType,
    QuerySnapshot<Map<String, dynamic>> snapshot,
  ) async {
    final rows = <Map<String, dynamic>>[];
    for (final doc in snapshot.docs) {
      var row = Map<String, dynamic>.from(doc.data());
      row['id'] ??= doc.id;
      if (entityType == 'northstar_notes') {
        row = await _hydrateNorthStarImage(user, row);
      }
      rows.add(row);
    }
    return rows;
  }

  CollectionReference<Map<String, dynamic>> _northStarChunks(
    DocumentReference<Map<String, dynamic>> root,
    String noteId,
  ) => root
      .collection('northstar_assets')
      .doc(noteId)
      .collection('chunks');

  List<String> _splitNorthStarImage(String imageBase64) {
    final chunks = <String>[];
    for (var start = 0;
        start < imageBase64.length;
        start += northStarImageChunkChars) {
      final candidate = start + northStarImageChunkChars;
      final end = candidate < imageBase64.length ? candidate : imageBase64.length;
      chunks.add(imageBase64.substring(start, end));
    }
    return chunks;
  }

  Future<void> _replaceNorthStarImageChunks(
    DocumentReference<Map<String, dynamic>> root,
    String noteId,
    List<String> chunks,
  ) async {
    final collection = _northStarChunks(root, noteId);
    for (var index = 0; index < chunks.length; index++) {
      await collection.doc(index.toString().padLeft(6, '0')).set({
        'data': chunks[index],
      });
    }

    final existing = await collection.get();
    for (final doc in existing.docs) {
      final index = int.tryParse(doc.id);
      if (index == null || index >= chunks.length) {
        await doc.reference.delete();
      }
    }
  }

  Future<void> _pushNorthStarNote(
    DocumentReference<Map<String, dynamic>> root,
    String noteId,
    Map<String, dynamic> payload,
  ) async {
    final imageBase64 = payload.remove('image_base64')?.toString() ?? '';
    final deleted = payload['deleted_at'] != null;
    final chunks = deleted || imageBase64.isEmpty
        ? const <String>[]
        : _splitNorthStarImage(imageBase64);

    if (chunks.isNotEmpty) {
      // Upload chunks before publishing the new chunk count so readers never
      // observe a note that points at not-yet-written image pieces.
      await _replaceNorthStarImageChunks(root, noteId, chunks);
    }

    payload['image_chunk_count'] = chunks.length;
    await root
        .collection('northstar_notes')
        .doc(noteId)
        .set(payload, SetOptions(merge: true));

    if (chunks.isEmpty) {
      // Publish count=0 first, then remove any obsolete prior chunks.
      await _replaceNorthStarImageChunks(root, noteId, chunks);
    }
  }

  Future<Map<String, dynamic>> _hydrateNorthStarImage(
    User user,
    Map<String, dynamic> row,
  ) async {
    final rawCount = row.remove('image_chunk_count');
    if (rawCount == null) return row; // Compatibility with an older cloud row.
    final count = (rawCount as num?)?.toInt() ?? 0;
    if (count <= 0) {
      row['image_base64'] = '';
      return row;
    }

    final noteId = row['id']?.toString() ?? '';
    if (noteId.isEmpty) return row;
    final root = _userRoot(user);
    final collection = _northStarChunks(root, noteId);
    final buffer = StringBuffer();
    for (var index = 0; index < count; index++) {
      final chunk = await collection.doc(index.toString().padLeft(6, '0')).get();
      final data = chunk.data()?['data']?.toString();
      if (data == null) {
        throw StateError('NorthStar image chunk $index is missing for $noteId.');
      }
      buffer.write(data);
    }
    row['image_base64'] = buffer.toString();
    return row;
  }

  Future<void> _pullSettings(User user) async {
    final snapshot = await _userRoot(user).collection('settings').get();
    await _mergeSettingsSnapshot(user, snapshot);
  }

  Future<void> _mergeSettingsSnapshot(
    User user,
    QuerySnapshot<Map<String, dynamic>> snapshot,
  ) async {
    final rows = snapshot.docs
        .where((doc) => !localOnlySettingKeys.contains(doc.id))
        .map((doc) {
          final row = Map<String, dynamic>.from(doc.data());
          row['setting_key'] ??= doc.id;
          return row;
        })
        .toList(growable: false);
    final deviceId = await database.getSetting('device_id') ?? '';
    await database.mergeRemoteSettingRows(rows, localDeviceId: deviceId);
  }

  Future<void> _pushSetting(User user, String key) async {
    if (localOnlySettingKeys.contains(key)) return;
    final raw = await database.loadSettingRow(key);
    if (raw == null) return;
    final row = Map<String, dynamic>.from(raw);
    row['device_id'] = await database.getSetting('device_id') ?? '';
    row['owner_id'] = user.uid;
    await _userRoot(user)
        .collection('settings')
        .doc(key)
        .set(row, SetOptions(merge: true));
  }

  Future<void> _pullTimerState(User user) async {
    final doc = await _userRoot(user).collection('meta').doc('timer_state').get();
    await _mergeTimerSnapshot(user, doc);
  }

  Future<void> _mergeTimerSnapshot(
    User user,
    DocumentSnapshot<Map<String, dynamic>> doc,
  ) async {
    final data = doc.data();
    if (data == null) return;
    final deviceId = await database.getSetting('device_id') ?? '';
    await database.mergeRemoteTimerState(
      Map<String, dynamic>.from(data),
      localDeviceId: deviceId,
    );
  }

  Future<void> _pushTimerState(User user) async {
    final row = Map<String, dynamic>.from(await database.loadTimerStateMap());
    row['device_id'] = await database.getSetting('device_id') ?? '';
    row['owner_id'] = user.uid;
    await _userRoot(user)
        .collection('meta')
        .doc('timer_state')
        .set(row, SetOptions(merge: true));
  }

  Future<void> startRealtime() async {
    await _cancelRealtime();
    if (_mode != 'firebase') return;
    final user = currentUser;
    if (user == null) return;
    await _refreshDeviceIdentity();
    final root = _userRoot(user);
    if (!_verified && _auditErrors.isEmpty) {
      _status = 'Realtime connected — verifying planner data…';
      notifyListeners();
    }

    for (final entityType in cloudTables) {
      final subscription = root.collection(entityType).snapshots().listen(
        (snapshot) async {
          try {
            final rows = await _rowsFromSnapshot(user, entityType, snapshot);
            if (entityType == 'work_items') {
              await database.mergeRemoteWorkItemsParentFirst(
                rows,
                primaryDeviceId: _primaryDeviceId,
              );
            } else {
              await database.mergeRemoteRows(
                entityType,
                rows,
                shouldDefer:
                    entityType == 'journal_entries' ? isJournalEditing : null,
                primaryDeviceId: _primaryDeviceId,
              );
            }
            await onRemoteChanged();
            _lastSyncedAt = DateTime.now();
            if (_localAuditCounts.containsKey(entityType)) {
              final localCount =
                  (await database.loadRowsForSync(entityType)).length;
              _localAuditCounts = {
                ..._localAuditCounts,
                entityType: localCount,
              };
              _cloudAuditCounts = {
                ..._cloudAuditCounts,
                entityType: snapshot.docs.length,
              };
              if (_auditErrors.isEmpty && _auditCountsMatch()) {
                _verified = true;
                _status = _verifiedStatus();
              }
            }
            notifyListeners();
          } catch (error) {
            _verified = false;
            _lastError = error;
            _status = 'Realtime asset sync waiting — local work continues';
            notifyListeners();
          }
        },
        onError: (Object error) {
          _verified = false;
          _lastError = error;
          _status = 'Realtime paused — local work continues';
          notifyListeners();
        },
      );
      _subscriptions.add(subscription);
    }

    final settingsSubscription = root.collection('settings').snapshots().listen(
      (snapshot) async {
        try {
          await _mergeSettingsSnapshot(user, snapshot);
          await onRemoteChanged();
        } catch (error) {
          _lastError = error;
          _status = 'Settings sync waiting — local work continues';
          notifyListeners();
        }
      },
      onError: (Object error) {
        _lastError = error;
        _status = 'Settings realtime paused — local work continues';
        notifyListeners();
      },
    );
    _subscriptions.add(settingsSubscription);

    final timerSubscription = root
        .collection('meta').doc('timer_state').snapshots().listen(
      (snapshot) async {
        try {
          await _mergeTimerSnapshot(user, snapshot);
          await onRemoteChanged();
        } catch (error) {
          _lastError = error;
          _status = 'Timer sync waiting — local timer remains safe';
          notifyListeners();
        }
      },
      onError: (Object error) {
        _lastError = error;
        _status = 'Timer realtime paused — local timer remains safe';
        notifyListeners();
      },
    );
    _subscriptions.add(timerSubscription);
  }

  Future<void> _cancelRealtime() async {
    for (final subscription in _subscriptions) {
      await subscription.cancel();
    }
    _subscriptions.clear();
  }

  void _setBusy(bool value, String nextStatus, {bool notify = true}) {
    _busy = value;
    _status = nextStatus;
    if (notify) notifyListeners();
  }

  @override
  void dispose() {
    _periodicTimer?.cancel();
    _scheduledPushTimer?.cancel();
    _verificationTimer?.cancel();
    unawaited(_authSubscription?.cancel());
    for (final subscription in _subscriptions) {
      unawaited(subscription.cancel());
    }
    super.dispose();
  }
}
