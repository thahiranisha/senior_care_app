import 'dart:async';
import 'package:flutter/material.dart';
import 'reminder_cache.dart';

class ReminderRunner {
  final List<Timer> _timers = [];
  final Set<String> _firedToday = {}; // prevent duplicates per day

  void stop() {
    for (final t in _timers) {
      t.cancel();
    }
    _timers.clear();
  }

  DateTime _nextOccurrence(DateTime now, String hhmm) {
    final parts = hhmm.split(':');
    final h = int.tryParse(parts[0]) ?? 0;
    final m = int.tryParse(parts[1]) ?? 0;

    var dt = DateTime(now.year, now.month, now.day, h, m);
    if (!dt.isAfter(now)) dt = dt.add(const Duration(days: 1));
    return dt;
  }

  void start({required ReminderCache cache, required BuildContext context}) {
    stop();

    final now = DateTime.now();
    final entries = cache.all.entries.toList();

    debugPrint('ReminderRunner.start() reminders=${entries.length}');

    for (final e in entries) {
      final data = e.value;
      if (data['enabled'] != true) continue;

      final time = (data['time'] as String?) ?? '';
      if (!RegExp(r'^\d{2}:\d{2}$').hasMatch(time)) continue;

      final name = (data['name'] as String?) ?? 'Medication';

      final next = _nextOccurrence(now, time);
      final delay = next.difference(now);

      _timers.add(Timer(delay, () {
        final todayKey = '${DateTime.now().year}-${DateTime.now().month}-${DateTime.now().day}';
        final uniq = '$todayKey|${e.key}';
        if (_firedToday.contains(uniq)) return;
        _firedToday.add(uniq);

        // In-app notification (SnackBar)
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Reminder: Take $name ($time)'),
            duration: const Duration(seconds: 6),
          ),
        );

        // Reschedule again for next day
        start(cache: cache, context: context);
      }));
    }
  }
}
