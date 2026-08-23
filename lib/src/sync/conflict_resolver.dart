DateTime _parseSyncTime(Object? value) {
  if (value is DateTime) return value.toUtc();
  if (value == null) {
    return DateTime.fromMillisecondsSinceEpoch(0, isUtc: true);
  }
  return DateTime.tryParse(value.toString())?.toUtc() ??
      DateTime.fromMillisecondsSinceEpoch(0, isUtc: true);
}

bool incomingRecordIsNewer(
  Map<String, Object?> incoming,
  Map<String, Object?> local,
) {
  final incomingRevision = (incoming['revision'] as num?)?.toInt() ?? 0;
  final localRevision = (local['revision'] as num?)?.toInt() ?? 0;
  if (incomingRevision != localRevision) {
    return incomingRevision > localRevision;
  }

  final timeComparison = _parseSyncTime(
    incoming['client_updated_at'],
  ).compareTo(_parseSyncTime(local['client_updated_at']));
  if (timeComparison != 0) return timeComparison > 0;

  return (incoming['device_id'] as String? ?? '').compareTo(
        local['device_id'] as String? ?? '',
      ) >
      0;
}
