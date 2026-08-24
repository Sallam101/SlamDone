import 'dart:js_interop';

@JS('slamDoneOpenPatreonSupport')
external bool _openPatreonSupport();

abstract final class SupportLinks {
  static Future<bool> openPatreon() async {
    try {
      return _openPatreonSupport();
    } catch (_) {
      return false;
    }
  }
}
