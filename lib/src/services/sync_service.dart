import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

import '../database/local_database.dart';
import '../firebase/firebase_config.dart';

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
  bool _busy = false;
  String _status = 'Browser local';
  Object? _lastError;
  DateTime? _lastSyncedAt;
  String _mode = 'local';

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
  String? get folderPath => null;
  bool get folderSyncEnabled => false;
  User? get currentUser =>
      firebaseAvailable ? FirebaseAuth.instance.currentUser : null;
  bool get isSignedIn => currentUser != null;

  Future<void> initialize() async {
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

  Future<void> _activateCurrentMode() async {
    await _cancelRealtime();
    if (_mode == 'firebase') {
      if (!firebaseAvailable) {
        _status = 'Firebase is not configured in this GitHub build';
      } else if (isSignedIn) {
        await startRealtime();
        _status = 'SlamDone Firestore sync ready';
        unawaited(syncNow(silent: true));
      } else {
        _status = 'Ready to connect Google for cross-device sync';
      }
    } else {
      _status = 'Browser local — automatic saving is active';
    }
    notifyListeners();
  }

  Future<void> useLocalOnly() async {
    _mode = 'local';
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
      await startRealtime();
      await syncNow();
      _lastError = null;
      return 'Google account connected. Browser and cloud data are merging.';
    } catch (error) {
      _lastError = error;
      return 'Google sign-in failed: $error';
    } finally {
      _setBusy(
        false,
        isSignedIn ? 'SlamDone Firestore synced' : 'Ready to connect Google',
      );
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

  Future<void> syncNow({bool silent = false, bool pullRemote = true}) async {
    if (_busy || _mode != 'firebase' || !firebaseAvailable || !isSignedIn) {
      return;
    }
    final user = currentUser!;
    _setBusy(true, silent ? _status : 'Syncing SlamDone…', notify: !silent);
    try {
      // Explicit/manual sync pulls before push so an older queued local row
      // cannot overwrite a newer Firestore row. Periodic sync relies on the
      // active realtime listeners and only drains the local dirty queue.
      if (pullRemote) {
        await _pullAllFromFirestore(user);
        await _pullSettings(user);
        await _pullTimerState(user);
      }
      await _pushQueueToFirestore(user);
      _lastSyncedAt = DateTime.now();
      _lastError = null;
      _status = 'SlamDone Firestore synced';
      await onRemoteChanged();
    } catch (error) {
      _lastError = error;
      _status = 'Sync waiting — browser changes are safe';
    } finally {
      _busy = false;
      notifyListeners();
    }
  }

  Future<void> _pushQueueToFirestore(User user) async {
    final root = _userRoot(user);
    final queue = await database.loadSyncQueue(limit: 500);
    for (final entry in queue) {
      try {
        final entityType = entry.entityType;
        if (entityType == 'app_settings') {
          if (!localOnlySettingKeys.contains(entry.entityId)) {
            await _pushSetting(user, entry.entityId);
          }
          await database.markQueueSuccess(entry.queueId);
          continue;
        }
        if (entityType == 'timer_state') {
          await _pushTimerState(user);
          await database.markQueueSuccess(entry.queueId);
          continue;
        }

        final payload = await database.cloudPayload(
          entityType,
          entry.entityId,
          user.uid,
        );
        if (payload == null) {
          await database.markQueueSuccess(entry.queueId);
          continue;
        }
        final cloudPayload = payload.cast<String, dynamic>();
        if (entityType == 'northstar_notes') {
          await _pushNorthStarNote(
            root,
            entry.entityId,
            cloudPayload,
          );
        } else {
          await root
              .collection(entityType)
              .doc(entry.entityId)
              .set(cloudPayload, SetOptions(merge: true));
        }
        await database.markQueueSuccess(entry.queueId);
      } catch (error) {
        await database.markQueueFailure(entry.queueId, error);
        rethrow;
      }
    }
  }

  Future<void> _pullAllFromFirestore(User user) async {
    final root = FirebaseFirestore.instance.collection('users').doc(user.uid);
    for (final entityType in cloudTables) {
      final snapshot = await root.collection(entityType).get();
      final rows = await _rowsFromSnapshot(user, entityType, snapshot);
      await database.mergeRemoteRows(
        entityType,
        rows,
        shouldDefer: entityType == 'journal_entries' ? isJournalEditing : null,
      );
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
    final root = _userRoot(user);

    for (final entityType in cloudTables) {
      final subscription = root.collection(entityType).snapshots().listen(
        (snapshot) async {
          try {
            final rows = await _rowsFromSnapshot(user, entityType, snapshot);
            await database.mergeRemoteRows(
              entityType,
              rows,
              shouldDefer:
                  entityType == 'journal_entries' ? isJournalEditing : null,
            );
            await onRemoteChanged();
            _lastSyncedAt = DateTime.now();
            _status = 'SlamDone Firestore synced';
            notifyListeners();
          } catch (error) {
            _lastError = error;
            _status = 'Realtime asset sync waiting — local work continues';
            notifyListeners();
          }
        },
        onError: (Object error) {
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
    unawaited(_authSubscription?.cancel());
    for (final subscription in _subscriptions) {
      unawaited(subscription.cancel());
    }
    super.dispose();
  }
}
