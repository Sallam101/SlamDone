class DesktopTimerBridge {
  DesktopTimerBridge({
    required this.onAction,
    required this.onClosed,
  });

  final void Function(String action) onAction;
  final void Function() onClosed;

  bool get supported => false;
  bool get isOpen => false;
  bool get nativeAvailable => false;
  bool get usingNative => false;

  void prepare() {}

  Future<bool> open(String snapshotJson) async => false;
  Future<bool> openBrowserFallback(String snapshotJson) async => false;
  void downloadCompanion() {}
  void update(String snapshotJson) {}
  void close() {}
  void primeChime() {}
  void dispose() {}
}
