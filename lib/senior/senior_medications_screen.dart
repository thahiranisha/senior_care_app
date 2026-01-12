import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../guardian/models/medication.dart';

/// Senior Medications (read-only)
///
/// Reads: seniors/{seniorId}/medications
class SeniorMedicationsScreen extends StatefulWidget {
  final String seniorId;
  final String seniorName;

  const SeniorMedicationsScreen({
    super.key,
    required this.seniorId,
    required this.seniorName,
  });

  @override
  State<SeniorMedicationsScreen> createState() => _SeniorMedicationsScreenState();
}

class _SeniorMedicationsScreenState extends State<SeniorMedicationsScreen> {
  Stream<QuerySnapshot<Map<String, dynamic>>>? _stream;
  bool _showInactive = false;

  CollectionReference<Map<String, dynamic>> _ref() {
    return FirebaseFirestore.instance
        .collection('seniors')
        .doc(widget.seniorId)
        .collection('medications');
  }

  @override
  void initState() {
    super.initState();
    _stream = _ref().orderBy('createdAt', descending: true).snapshots();
  }

  @override
  void didUpdateWidget(covariant SeniorMedicationsScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.seniorId != widget.seniorId) {
      _stream = _ref().orderBy('createdAt', descending: true).snapshots();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Medications • ${widget.seniorName}'),
        backgroundColor: Colors.teal,
        foregroundColor: Colors.white,
      ),
      backgroundColor: const Color(0xFFF3FAF9),
      body: Column(
        children: [
          SwitchListTile(
            value: _showInactive,
            onChanged: (v) => setState(() => _showInactive = v),
            title: const Text('Show inactive medications'),
          ),
          Expanded(
            child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
              stream: _stream,
              builder: (context, snap) {
                if (!snap.hasData) return const Center(child: CircularProgressIndicator());
                final docs = snap.data!.docs;
                if (docs.isEmpty) {
                  return const Center(child: Text('No medications added yet.'));
                }

                var meds = docs.map((d) => Medication.fromDoc(d)).toList();
                if (!_showInactive) {
                  meds = meds.where((m) => m.isActive).toList();
                }

                if (meds.isEmpty) {
                  return const Center(child: Text('No active medications.'));
                }

                return ListView.separated(
                  padding: const EdgeInsets.all(14),
                  itemCount: meds.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 10),
                  itemBuilder: (_, i) {
                    final m = meds[i];
                    final subtitle = [
                      if ((m.dosage ?? '').isNotEmpty) m.dosage!,
                      if ((m.route ?? '').isNotEmpty) m.route!,
                      if (m.times.isNotEmpty) 'Times: ${m.times.join(', ')}',
                      if ((m.instructions ?? '').isNotEmpty) 'Note: ${m.instructions}',
                      if (!m.isActive) 'Inactive',
                    ].join(' • ');

                    return Card(
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      child: ListTile(
                        leading: const Icon(Icons.medication_outlined),
                        title: Text(m.name, style: const TextStyle(fontWeight: FontWeight.bold)),
                        subtitle: Text(subtitle),
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
