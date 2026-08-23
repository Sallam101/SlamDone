import '../models/models.dart';
import '../utils/app_utils.dart';
import 'spreadsheet_export_service.dart';

class FocusHistoryExportService {
  const FocusHistoryExportService._();

  static Future<String?> exportRange({
    required String title,
    required DateTime start,
    required DateTime endExclusive,
    required List<TimeSession> sessions,
  }) {
    final rows = <List<String>>[];
    for (
      var day = DateTime(start.year, start.month, start.day);
      day.isBefore(endExclusive);
      day = day.add(const Duration(days: 1))
    ) {
      final next = day.add(const Duration(days: 1));
      final seconds = _secondsBetween(sessions, day, next);
      rows.add([
        dateKey(day),
        _weekday(day.weekday),
        '${(seconds / 60).round()}',
        (seconds / 3600).toStringAsFixed(2),
      ]);
    }
    return SpreadsheetExportService.exportTable(
      title: title,
      columns: const ['Date', 'Day', 'Focused minutes', 'Focused hours'],
      rows: rows,
      columnWidths: const [130, 100, 150, 140],
      fontSize: 12,
      wrapText: true,
    );
  }

  static Future<String?> exportCombined({
    required int year,
    required List<TimeSession> sessions,
  }) {
    final rows = <List<String>>[];
    final weekCount = weeksInIsoYear(year);
    for (var week = 1; week <= weekCount; week++) {
      final start = isoWeekStart(year, week);
      final end = start.add(const Duration(days: 7));
      final seconds = _secondsBetween(sessions, start, end);
      rows.add([
        'Week',
        'Week $week',
        dateKey(start),
        dateKey(end.subtract(const Duration(days: 1))),
        '${(seconds / 60).round()}',
        (seconds / 3600).toStringAsFixed(2),
      ]);
    }
    for (var month = 1; month <= 12; month++) {
      final start = DateTime(year, month, 1);
      final end = DateTime(year, month + 1, 1);
      final seconds = _secondsBetween(sessions, start, end);
      rows.add([
        'Month',
        '${_monthName(month)} ($month)',
        dateKey(start),
        dateKey(end.subtract(const Duration(days: 1))),
        '${(seconds / 60).round()}',
        (seconds / 3600).toStringAsFixed(2),
      ]);
    }
    final yearStart = DateTime(year, 1, 1);
    final yearEnd = DateTime(year + 1, 1, 1);
    final seconds = _secondsBetween(sessions, yearStart, yearEnd);
    rows.add([
      'Year',
      '$year total',
      dateKey(yearStart),
      dateKey(yearEnd.subtract(const Duration(days: 1))),
      '${(seconds / 60).round()}',
      (seconds / 3600).toStringAsFixed(2),
    ]);
    return SpreadsheetExportService.exportTable(
      title: 'SlamDone_Focus_History_$year',
      columns: const [
        'Scope',
        'Period',
        'Start',
        'End',
        'Focused minutes',
        'Focused hours',
      ],
      rows: rows,
      columnWidths: const [100, 180, 120, 120, 150, 140],
      fontSize: 12,
      wrapText: true,
    );
  }

  static int _secondsBetween(
    List<TimeSession> sessions,
    DateTime start,
    DateTime endExclusive,
  ) => sessions
      .where((session) {
        final local = session.startedAt.toLocal();
        return session.completed &&
            session.mode != TimerMode.stopwatch &&
            !local.isBefore(start) &&
            local.isBefore(endExclusive);
      })
      .fold<int>(0, (sum, session) => sum + session.elapsedSeconds);

  static String _weekday(int day) =>
      const ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'][day - 1];

  static String _monthName(int month) => const [
    'January',
    'February',
    'March',
    'April',
    'May',
    'June',
    'July',
    'August',
    'September',
    'October',
    'November',
    'December',
  ][month - 1];
}
