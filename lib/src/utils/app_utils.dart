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

bool sameDay(DateTime a, DateTime b) =>
    a.year == b.year && a.month == b.month && a.day == b.day;

String dateKey(DateTime value) =>
    '${value.year.toString().padLeft(4, '0')}-${value.month.toString().padLeft(2, '0')}-${value.day.toString().padLeft(2, '0')}';

DateTime startOfIsoWeek(DateTime value) {
  final local = startOfDay(value);
  return local.subtract(Duration(days: local.weekday - DateTime.monday));
}

DateTime endOfIsoWeek(DateTime value) =>
    startOfIsoWeek(value).add(const Duration(days: 6));

int isoWeekNumber(DateTime date) {
  final day = startOfDay(date);
  final thursday = day.add(Duration(days: 4 - day.weekday));
  final firstThursday = DateTime(thursday.year, 1, 4);
  final firstWeekStart =
      firstThursday.subtract(Duration(days: firstThursday.weekday - 1));
  return 1 + thursday.difference(firstWeekStart).inDays ~/ 7;
}

int isoWeekYear(DateTime date) {
  final day = startOfDay(date);
  return day.add(Duration(days: 4 - day.weekday)).year;
}

int weeksInIsoYear(int year) {
  final dec28 = DateTime(year, 12, 28);
  return isoWeekNumber(dec28);
}

DateTime isoWeekStart(int year, int week) {
  final jan4 = DateTime(year, 1, 4);
  final firstMonday = jan4.subtract(Duration(days: jan4.weekday - 1));
  return firstMonday.add(Duration(days: (week - 1) * 7));
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
  final end = endOfIsoWeek(now).add(const Duration(days: 1));
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
