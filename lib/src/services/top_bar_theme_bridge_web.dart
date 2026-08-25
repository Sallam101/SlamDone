import 'dart:html' as html;

const int _defaultInstalledTopBarColor = 0xFF78D12F;

void applyTopBarThemeColor(int value) {
  final resolved = value == 0 ? _defaultInstalledTopBarColor : value;
  final rgb = resolved & 0x00FFFFFF;
  final hex = '#${rgb.toRadixString(16).padLeft(6, '0').toUpperCase()}';
  final document = html.document;
  var meta = document.querySelector('meta[name="theme-color"]');
  if (meta == null) {
    final created = html.MetaElement()
      ..name = 'theme-color'
      ..content = hex;
    document.head?.append(created);
  } else {
    meta.setAttribute('content', hex);
  }
}
