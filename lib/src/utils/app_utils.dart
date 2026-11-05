import 'package:flutter/material.dart';

import '../models/models.dart';

Color? parseHexColor(String? value) {
  if (value == null || value.trim().isEmpty) return null;
  var hex = value.trim().replaceFirst('#', '');
  if (hex.length == 6) hex = 'FF$hex';
  final parsed = int.tryParse(hex, radix: 16);
  return parsed == null ? null : Color(parsed);
}

String toHexColor(Color color) =>
    '#${color.toARGB32().toRadixString(16).padLeft(8, '0').substring(2).toUpperCase()}';

Color readableTextColor(Color background) =>
    ThemeData.estimateBrightnessForColor(background) == Brightness.dark
        ? Colors.white
        : const Color(0xFF171717);

DateTime startOfDay(DateTime value) =>
    DateTime(value.year, value.month, value.day);

/// Advances by local calendar dates, preserving midnight across DST changes.
DateTime addCalendarDays(DateTime value, int days) =>
    DateTime(value.year, value.month, value.day + days);

/// Parses a YYYY-MM-DD key as a calendar date, not a UTC timestamp.
DateTime? parseDateKey(String? value) {
  if (value == null) return null;
  final match = RegExp(r'^(\d{4})-(\d{2})-(\d{2})$').firstMatch(value);
  if (match == null) return null;
  final year = int.parse(match.group(1)!);
  final month = int.parse(match.group(2)!);
  final day = int.parse(match.group(3)!);
  final parsed = DateTime(year, month, day);
  if (parsed.year != year || parsed.month != month || parsed.day != day) {
    return null;
  }
  return parsed;
}

/// Counts consecutive local dates with completed sessions in permanent focus history.
int calculateFocusDayStreak(Iterable<TimeSession> sessions, DateTime now) {
  final completedDays = sessions
      .where(
        (session) =>
            session.completed &&
            session.mode != TimerMode.stopwatch,
      )
      .map((session) => startOfDay(session.startedAt.toLocal()))
      .toSet();
  var cursor = startOfDay(now);
  if (!completedDays.contains(cursor)) {
    cursor = addCalendarDays(cursor, -1);
  }
  var streak = 0;
  while (completedDays.contains(cursor)) {
    streak++;
    cursor = addCalendarDays(cursor, -1);
  }
  return streak;
}

bool sameDay(DateTime a, DateTime b) =>
    a.year == b.year && a.month == b.month && a.day == b.day;

String dateKey(DateTime value) =>
    '${value.year.toString().padLeft(4, '0')}-${value.month.toString().padLeft(2, '0')}-${value.day.toString().padLeft(2, '0')}';

DateTime startOfIsoWeek(DateTime value) {
  final local = startOfDay(value);
  return addCalendarDays(local, -(local.weekday - DateTime.monday));
}

DateTime endOfIsoWeek(DateTime value) =>
    addCalendarDays(startOfIsoWeek(value), 6);

int isoWeekNumber(DateTime date) {
  final day = startOfDay(date);
  final thursday = addCalendarDays(day, 4 - day.weekday);
  final firstThursday = DateTime(thursday.year, 1, 4);
  final firstWeekStart =
      addCalendarDays(firstThursday, -(firstThursday.weekday - 1));
  return 1 +
      DateTime.utc(thursday.year, thursday.month, thursday.day)
              .difference(
                DateTime.utc(
                  firstWeekStart.year,
                  firstWeekStart.month,
                  firstWeekStart.day,
                ),
              )
              .inDays ~/
          7;
}

int isoWeekYear(DateTime date) {
  final day = startOfDay(date);
  return addCalendarDays(day, 4 - day.weekday).year;
}

int weeksInIsoYear(int year) {
  final dec28 = DateTime(year, 12, 28);
  return isoWeekNumber(dec28);
}

DateTime isoWeekStart(int year, int week) {
  final jan4 = DateTime(year, 1, 4);
  final firstMonday = addCalendarDays(jan4, -(jan4.weekday - 1));
  return addCalendarDays(firstMonday, (week - 1) * 7);
}

bool itemIsOverdue(WorkItem item, DateTime now) {
  final due = item.dueDate?.toLocal();
  return due != null &&
      startOfDay(due).isBefore(startOfDay(now)) &&
      !item.isCompleted;
}

bool itemDueThisWeek(WorkItem item, DateTime now) {
  final due = item.dueDate?.toLocal();
  if (due == null) return false;
  final start = startOfIsoWeek(now);
  final end = addCalendarDays(endOfIsoWeek(now), 1);
  return !due.isBefore(start) && due.isBefore(end);
}

int dueSortScore(WorkItem item, DateTime now) {
  var score = 0;
  if (itemIsOverdue(item, now)) score -= 1000000;
  if (item.urgent || item.priority == PriorityLevel.urgent) score -= 100000;
  if (item.priority == PriorityLevel.important) score -= 50000;
  score += item.dueDate?.millisecondsSinceEpoch ?? 9000000000000000;
  return score;
}

String formatHoursFromMinutes(int minutes) {
  final hours = minutes / 60;
  return hours >= 10 ? hours.toStringAsFixed(0) : hours.toStringAsFixed(1);
}
