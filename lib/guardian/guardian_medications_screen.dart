import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../services/medication_reminder_scheduler.dart';
import 'dialogs/medication_form_dialog.dart';
import 'models/medication.dart';

class GuardianMedicationsScreen extends StatelessWidget {
  final String seniorId;
  final String seniorName;

  const GuardianMedicationsScreen({
    super.key,
    required this.seniorId,
    required this.seniorName,
  });

  CollectionReference<Map<String, dynamic>> _medsRef() {
    return FirebaseFirestore.instance
        .collection('seniors')
        .doc(seniorId)
        .collection('medications');
  }

  Future<void> _add(BuildContext context) async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;

    final data = await showMedicationFormDialog(context);
    if (data == null) return;

    // 1) Add to Firestore and capture the created doc reference
    final docRef = await _medsRef().add({
      'name': data['name'],
      'dosage': data['dosage'],
      'route': data['route'],
      'times': data['times'],
      'instructions': data['instructions'],
      'startDate': data['startDate'] == null
          ? null
          : Timestamp.fromDate(data['startDate']),
      'endDate': data['endDate'] == null
          ? null
          : Timestamp.fromDate(data['endDate']),
      'isActive': data['isActive'] ?? true,
      'createdBy': uid,
      'updatedBy': uid,
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    });

    // 2) Build Medication model with new id
    final med = Medication(
      id: docRef.id,
      name: data['name'] as String,
      dosage: data['dosage'] as String?,
      route: data['route'] as String?,
      times: ((data['times'] ?? []) as List).map((e) => e.toString()).toList(),
      instructions: data['instructions'] as String?,
      startDate: data['startDate'] as DateTime?,
      endDate: data['endDate'] as DateTime?,
      isActive: (data['isActive'] ?? true) as bool,
      createdBy: uid,
      updatedBy: uid,
      createdAt: null,
      updatedAt: null,
    );

    // 3) Schedule local reminders (offline)
    await MedicationReminderScheduler.instance.scheduleForMedication(
      seniorId: seniorId,
      med: med,
    );
  }

  Future<void> _edit(BuildContext context, Medication med) async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;

    final data = await showMedicationFormDialog(context, initial: med);
    if (data == null) return;

    final updatedTimes =
    ((data['times'] ?? []) as List).map((e) => e.toString()).toList();

    await _medsRef().doc(med.id).update({
      'name': data['name'],
      'dosage': data['dosage'],
      'route': data['route'],
      'times': updatedTimes,
      'instructions': data['instructions'],
      'startDate': data['startDate'] == null
          ? null
          : Timestamp.fromDate(data['startDate']),
      'endDate': data['endDate'] == null
          ? null
          : Timestamp.fromDate(data['endDate']),
      'isActive': data['isActive'] ?? true,
      'updatedBy': uid,
      'updatedAt': FieldValue.serverTimestamp(),
    });

    final updated = Medication(
      id: med.id,
      name: data['name'] as String,
      dosage: data['dosage'] as String?,
      route: data['route'] as String?,
      times: updatedTimes,
      instructions: data['instructions'] as String?,
      startDate: data['startDate'] as DateTime?,
      endDate: data['endDate'] as DateTime?,
      isActive: (data['isActive'] ?? true) as bool,
      createdBy: med.createdBy,
      updatedBy: uid,
      createdAt: med.createdAt,
      updatedAt: med.updatedAt,
    );

    // Cancel old schedules then schedule new
    await MedicationReminderScheduler.instance.cancelForMedication(
      seniorId: seniorId,
      med: med,
    );

    if (updated.isActive) {
      await MedicationReminderScheduler.instance.scheduleForMedication(
        seniorId: seniorId,
        med: updated,
      );
    }
  }

  Future<void> _remove(BuildContext context, Medication med) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Remove medication'),
        content: Text('Remove "${med.name}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Remove'),
          ),
        ],
      ),
    );

    if (ok != true) return;

    // Cancel notifications first
    await MedicationReminderScheduler.instance.cancelForMedication(
      seniorId: seniorId,
      med: med,
    );

    await _medsRef().doc(med.id).delete();
  }

  @override
  Widget build(BuildContext context) {
    final query = _medsRef().orderBy('createdAt', descending: true);

    return Scaffold(
      appBar: AppBar(
        title: Text('Medications • $seniorName'),
        backgroundColor: Colors.teal,
        foregroundColor: Colors.white,
      ),
      backgroundColor: const Color(0xFFF3FAF9),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _add(context),
        backgroundColor: Colors.teal,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add),
        label: const Text('Add medication'),
      ),
      body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: query.snapshots(),
        builder: (context, snap) {
          if (!snap.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          final meds = snap.data!.docs.map((d) => Medication.fromDoc(d)).toList();

          if (meds.isEmpty) {
            return const Center(
              child: Text('No medications added yet. Tap "Add medication".'),
            );
          }

          return ListView.separated(
            padding: const EdgeInsets.fromLTRB(14, 14, 14, 80),
            itemCount: meds.length,
            separatorBuilder: (_, __) => const SizedBox(height: 10),
            itemBuilder: (context, i) {
              final m = meds[i];

              final subtitle = [
                if ((m.dosage ?? '').isNotEmpty) m.dosage!,
                if ((m.route ?? '').isNotEmpty) m.route!,
                if (m.times.isNotEmpty) 'Times: ${m.times.join(', ')}',
                if ((m.instructions ?? '').isNotEmpty) 'Note: ${m.instructions}',
              ].join(' • ');

              return Card(
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                child: ListTile(
                  title: Text(m.name, style: const TextStyle(fontWeight: FontWeight.bold)),
                  subtitle: Text(subtitle),
                  trailing: PopupMenuButton<String>(
                    onSelected: (v) {
                      if (v == 'edit') _edit(context, m);
                      if (v == 'remove') _remove(context, m);
                    },
                    itemBuilder: (_) => const [
                      PopupMenuItem(value: 'edit', child: Text('Edit')),
                      PopupMenuItem(value: 'remove', child: Text('Remove')),
                    ],
                  ),
                  onTap: () => _edit(context, m),
                ),
              );
            },
          );
        },
      ),
    );
  }
}
