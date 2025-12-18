import 'package:timezone/timezone.dart' as tz;

import '../guardian/models/medication.dart';
import 'notification_service.dart';
import 'stable_hash.dart';

class MedicationReminderScheduler {
  MedicationReminderScheduler._();
  static final MedicationReminderScheduler instance = MedicationReminderScheduler._();

  /// Schedule reminders for a medication.
  ///
  /// Strategy:
  /// - If `endDate` is null: schedule a daily repeating reminder per time.
  /// - If `endDate` is set: schedule individual reminders up to 30 days ahead
  ///   (extends next time the user edits/open app).
  Future<void> scheduleForMedication({
    required String seniorId,
    required Medication med,
  }) async {
    // Ensure notifications/timezone are initialized (safe to call multiple times).
    await NotificationService.instance.init();
    if (!med.isActive || med.times.isEmpty) return;

    final now = tz.TZDateTime.now(tz.local);
    final start = med.startDate ?? now;
    final end = med.endDate;

    for (final t in med.times) {
      final hm = _parseTime(t);
      if (hm == null) continue;

      if (end == null) {
        // Repeating daily.
        final first = _nextOccurrence(now, start, hm.$1, hm.$2);
        final id = _dailyId(seniorId, med.id, t);
        await NotificationService.instance.scheduleDaily(
          id: id,
          title: 'Medication: ${med.name}',
          body: _buildBody(med, t),
          firstOccurrence: first,
          payload: 'med|$seniorId|${med.id}|$t',
        );
      } else {
        // Schedule a window of reminders up to 30 days.
        final ids = <int>[];
        // Schedule only the *next* 30 days from "now" (not from startDate).
        // This avoids a common bug where long-running meds (started long ago) stop getting new reminders.
        final windowEnd = _minDate(end, now.add(const Duration(days: 30)));
        var day = _startOfDay(_maxDate(start, now));
        final endDay = _startOfDay(windowEnd);

        while (!day.isAfter(endDay)) {
          final when = tz.TZDateTime(tz.local, day.year, day.month, day.day, hm.$1, hm.$2);
          if (when.isAfter(now) || _sameMinute(when, now)) {
            final id = _datedId(seniorId, med.id, t, when);
            ids.add(id);
            await NotificationService.instance.scheduleOnce(
              id: id,
              title: 'Medication: ${med.name}',
              body: _buildBody(med, t),
              when: when,
              payload: 'med|$seniorId|${med.id}|$t|${when.year}${when.month.toString().padLeft(2, '0')}${when.day.toString().padLeft(2, '0')}',
            );
          }
          day = day.add(const Duration(days: 1));
        }
      }
    }
  }

  /// Cancel any reminders currently associated with a medication.
  Future<void> cancelForMedication({
    required String seniorId,
    required Medication med,
  }) async {
    // Ensure plugin is initialized before canceling.
    await NotificationService.instance.init();
    final now = tz.TZDateTime.now(tz.local);
    final start = med.startDate ?? now;
    final end = med.endDate;

    final ids = <int>[];
    for (final t in med.times) {
      if (end == null) {
        ids.add(_dailyId(seniorId, med.id, t));
      } else {
        final windowEnd = _minDate(end, now.add(const Duration(days: 30)));
        var day = _startOfDay(_maxDate(start, now.subtract(const Duration(days: 1))));
        final endDay = _startOfDay(windowEnd);
        while (!day.isAfter(endDay)) {
          final when = tz.TZDateTime(tz.local, day.year, day.month, day.day);
          ids.add(_datedId(seniorId, med.id, t, when));
          day = day.add(const Duration(days: 1));
        }
      }
    }

    await NotificationService.instance.cancelMany(ids);
  }

  // ---------------------------
  // Helpers
  // ---------------------------

  static (int, int)? _parseTime(String hhmm) {
    final parts = hhmm.split(':');
    if (parts.length != 2) return null;
    final h = int.tryParse(parts[0]);
    final m = int.tryParse(parts[1]);
    if (h == null || m == null) return null;
    if (h < 0 || h > 23 || m < 0 || m > 59) return null;
    return (h, m);
  }

  static tz.TZDateTime _nextOccurrence(
    tz.TZDateTime now,
    DateTime startDate,
    int hour,
    int minute,
  ) {
    final startTz = tz.TZDateTime.from(startDate, tz.local);
    final base = startTz.isAfter(now) ? startTz : now;
    var scheduled = tz.TZDateTime(tz.local, base.year, base.month, base.day, hour, minute);
    if (scheduled.isBefore(base)) {
      scheduled = scheduled.add(const Duration(days: 1));
    }
    return scheduled;
  }

  static bool _sameMinute(tz.TZDateTime a, tz.TZDateTime b) {
    return a.year == b.year &&
        a.month == b.month &&
        a.day == b.day &&
        a.hour == b.hour &&
        a.minute == b.minute;
  }

  static String _buildBody(Medication med, String time) {
    final parts = <String>['Time: $time'];
    if ((med.dosage ?? '').isNotEmpty) parts.add('Dose: ${med.dosage}');
    if ((med.route ?? '').isNotEmpty) parts.add('Route: ${med.route}');
    if ((med.instructions ?? '').isNotEmpty) parts.add(med.instructions!);
    return parts.join(' • ');
  }

  static int _dailyId(String seniorId, String medId, String hhmm) {
    return fnv1a32('med|daily|$seniorId|$medId|$hhmm');
  }

  static int _datedId(String seniorId, String medId, String hhmm, tz.TZDateTime when) {
    final ymd = '${when.year}${when.month.toString().padLeft(2, '0')}${when.day.toString().padLeft(2, '0')}';
    return fnv1a32('med|dated|$seniorId|$medId|$hhmm|$ymd');
  }

  static DateTime _maxDate(DateTime a, DateTime b) => a.isAfter(b) ? a : b;
  static DateTime _minDate(DateTime a, DateTime b) => a.isBefore(b) ? a : b;

  static DateTime _startOfDay(DateTime d) => DateTime(d.year, d.month, d.day);
}
