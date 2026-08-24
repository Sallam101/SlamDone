import 'dart:js_interop';

@JS('slamDoneDesktopTimerSupported')
external bool _desktopTimerSupported();

@JS('slamDoneDesktopTimerIsOpen')
external bool _desktopTimerIsOpen();

@JS('slamDoneDesktopTimerNativeAvailable')
external bool _desktopTimerNativeAvailable();

@JS('slamDoneDesktopTimerUsingNative')
external bool _desktopTimerUsingNative();

@JS('slamDoneDesktopTimerPrepare')
external void _desktopTimerPrepare();

@JS('slamDoneDesktopTimerOpen')
external JSPromise<JSBoolean> _desktopTimerOpen(String snapshotJson);

@JS('slamDoneDesktopTimerOpenBrowserFallback')
external JSPromise<JSBoolean> _desktopTimerOpenBrowserFallback(String snapshotJson);

@JS('slamDoneDesktopTimerDownloadCompanion')
external void _desktopTimerDownloadCompanion();

@JS('slamDoneDesktopTimerUpdate')
external void _desktopTimerUpdate(String snapshotJson);

@JS('slamDoneDesktopTimerClose')
external void _desktopTimerClose();

@JS('slamDoneDesktopTimerPrimeChime')
external void _desktopTimerPrimeChime();

@JS('slamDoneTimerPipAction')
external set _timerPipAction(JSFunction callback);

@JS('slamDoneTimerPipClosed')
external set _timerPipClosed(JSFunction callback);

class DesktopTimerBridge {
  DesktopTimerBridge({
    required this.onAction,
    required this.onClosed,
  }) {
    _timerPipAction = _dispatchAction.toJS;
    _timerPipClosed = _dispatchClosed.toJS;
  }

  final void Function(String action) onAction;
  final void Function() onClosed;

  bool get supported {
    try {
      return _desktopTimerSupported();
    } catch (_) {
      return false;
    }
  }

  bool get isOpen {
    try {
      return _desktopTimerIsOpen();
    } catch (_) {
      return false;
    }
  }

  bool get nativeAvailable {
    try {
      return _desktopTimerNativeAvailable();
    } catch (_) {
      return false;
    }
  }

  bool get usingNative {
    try {
      return _desktopTimerUsingNative();
    } catch (_) {
      return false;
    }
  }

  void prepare() {
    try {
      _desktopTimerPrepare();
    } catch (_) {}
  }

  Future<bool> open(String snapshotJson) async {
    try {
      final promise = _desktopTimerOpen(snapshotJson);
      return (await promise.toDart).toDart;
    } catch (_) {
      return false;
    }
  }

  Future<bool> openBrowserFallback(String snapshotJson) async {
    try {
      final promise = _desktopTimerOpenBrowserFallback(snapshotJson);
      return (await promise.toDart).toDart;
    } catch (_) {
      return false;
    }
  }

  void downloadCompanion() {
    try {
      _desktopTimerDownloadCompanion();
    } catch (_) {}
  }

  void update(String snapshotJson) {
    try {
      _desktopTimerUpdate(snapshotJson);
    } catch (_) {}
  }

  void close() {
    try {
      _desktopTimerClose();
    } catch (_) {}
  }

  void primeChime() {
    try {
      _desktopTimerPrimeChime();
    } catch (_) {}
  }

  void _dispatchAction(String action) => onAction(action);
  void _dispatchClosed() => onClosed();

  void dispose() {
    close();
    _timerPipAction = ((String _) {}).toJS;
    _timerPipClosed = (() {}).toJS;
  }
}
