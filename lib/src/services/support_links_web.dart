import 'dart:js_interop';

@JS('slamDoneOpenPatreonSupport')
external JSBoolean _openPatreonSupport();

abstract final class SupportLinks {
  static Future<bool> openPatreon() async {
    try {
      return _openPatreonSupport().toDart;
    } catch (_) {
      return false;
    }
  }
}
