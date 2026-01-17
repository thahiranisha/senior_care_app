import 'package:cloud_firestore/cloud_firestore.dart';
import 'reminder_cache.dart';

bool _isMedicationEntry(Map<String, dynamic> v) {
  return v.containsKey('medId') && v.containsKey('time');
}

Future<void> syncMedicationRemindersForSeniors({
  required List<String> seniorIds,
  required ReminderCache cache,
}) async {
  final ids = seniorIds
      .map((e) => e.trim())
      .where((e) => e.isNotEmpty)
      .toSet()
      .toList()
    ..sort();

  final db = FirebaseFirestore.instance;
  final now = DateTime.now();

  bool validNow(Map<String, dynamic> d) {
    final sd = d['startDate'];
    final ed = d['endDate'];
    final start = (sd is Timestamp) ? sd.toDate() : null;
    final end = (ed is Timestamp) ? ed.toDate() : null;
    if (start != null && now.isBefore(start)) return false;
    if (end != null && now.isAfter(end)) return false;
    return true;
  }

  // Start from existing cache, but remove medication entries that don't belong to current ids
  final existing = Map<String, Map<String, dynamic>>.from(cache.all);

  // If no ids => remove ALL medication reminders (but keep other reminder types)
  if (ids.isEmpty) {
    existing.removeWhere((k, v) => _isMedicationEntry(v));
    cache.setAll(existing);
    await cache.save();
    return;
  }

  // Remove medication reminders for seniors not in ids
  existing.removeWhere((k, v) {
    if (!_isMedicationEntry(v)) return false;
    final sid = (v['seniorId'] as String?)?.trim() ?? '';
    return sid.isNotEmpty && !ids.contains(sid);
  });

  existing.removeWhere((k, v) {
    if (!_isMedicationEntry(v)) return false;
    final sid = (v['seniorId'] as String?)?.trim() ?? '';
    return sid.isNotEmpty && ids.contains(sid);
  });

  // Fetch senior names (best effort)
  final seniorNameById = <String, String>{};
  try {
    final seniorSnaps = await Future.wait(
      ids.map((id) => db.collection('seniors').doc(id).get()),
    );
    for (final s in seniorSnaps) {
      if (!s.exists) continue;
      final data = s.data() as Map<String, dynamic>?;
      final name = (data?['fullName'] as String?)?.trim();
      if (name != null && name.isNotEmpty) {
        seniorNameById[s.id] = name;
      }
    }
  } catch (_) {
  }

  // Build new medication entries
  for (final seniorId in ids) {
    try {
      final meds = await db
          .collection('seniors')
          .doc(seniorId)
          .collection('medications')
          .where('isActive', isEqualTo: true)
          .get();

      for (final doc in meds.docs) {
        final d = doc.data();
        if (!validNow(d)) continue;

        final medName = (d['name'] as String?)?.trim();
        final times = ((d['times'] ?? []) as List).map((e) => e.toString()).toList();

        for (final t in times) {
          final time = t.trim();
          if (time.isEmpty) continue;

          final key = '$seniorId|${doc.id}|$time';
          existing[key] = {
            'seniorId': seniorId,
            'seniorName': seniorNameById[seniorId] ?? '',
            'medId': doc.id,
            'name': (medName == null || medName.isEmpty) ? 'Medication' : medName,
            'time': time,
            'enabled': true,
          };
        }
      }
    } catch (e) {

    }
  }

  cache.setAll(existing);
  await cache.save();
}
