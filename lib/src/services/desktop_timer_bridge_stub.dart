class DesktopTimerBridge {
  DesktopTimerBridge({
    required this.onAction,
    required this.onClosed,
  });

  final void Function(String action) onAction;
  final void Function() onClosed;

  bool get supported => false;
  bool get isOpen => false;

  Future<bool> open(String snapshotJson) async => false;
  void update(String snapshotJson) {}
  void close() {}
  void primeChime() {}
  void dispose() {}
}
