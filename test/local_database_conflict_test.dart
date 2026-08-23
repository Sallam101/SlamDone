import 'package:flutter_test/flutter_test.dart';
import 'package:supeslam/src/sync/conflict_resolver.dart';

void main() {
  Map<String, Object?> row({
    required int revision,
    required String updatedAt,
    required String deviceId,
  }) => {
        'revision': revision,
        'client_updated_at': updatedAt,
        'device_id': deviceId,
      };

  test('higher revision wins before timestamp', () {
    expect(
      incomingRecordIsNewer(
        row(revision: 3, updatedAt: '2026-01-01T00:00:00Z', deviceId: 'a'),
        row(revision: 2, updatedAt: '2026-12-01T00:00:00Z', deviceId: 'z'),
      ),
      isTrue,
    );
  });

  test('newer timestamp wins when revisions tie', () {
    expect(
      incomingRecordIsNewer(
        row(revision: 3, updatedAt: '2026-08-23T07:00:01Z', deviceId: 'a'),
        row(revision: 3, updatedAt: '2026-08-23T07:00:00Z', deviceId: 'z'),
      ),
      isTrue,
    );
  });

  test('device id breaks exact revision and timestamp ties', () {
    expect(
      incomingRecordIsNewer(
        row(revision: 3, updatedAt: '2026-08-23T07:00:00Z', deviceId: 'z'),
        row(revision: 3, updatedAt: '2026-08-23T07:00:00Z', deviceId: 'a'),
      ),
      isTrue,
    );
  });
}
