import 'dart:js_interop';

@JS('slamDoneDesktopTimerPrimeChime')
external void slamDoneDesktopTimerPrimeChime();

@JS('slamDoneDesktopTimerPlayChime')
external void slamDoneDesktopTimerPlayChime(String completionToken);

void primeTimerCompletionChime() {
  try {
    slamDoneDesktopTimerPrimeChime();
  } catch (_) {}
}

Future<void> playTimerCompletionChime(String completionToken) async {
  try {
    slamDoneDesktopTimerPlayChime(completionToken);
  } catch (_) {}
}
