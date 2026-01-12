import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

/// Senior Profile (read-only)
class SeniorProfileScreen extends StatelessWidget {
  final String seniorId;

  const SeniorProfileScreen({super.key, required this.seniorId});

  String _v(dynamic value) {
    if (value == null) return '-';
    final s = value.toString().trim();
    return s.isEmpty ? '-' : s;
  }

  Widget _row(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(label, style: const TextStyle(fontWeight: FontWeight.bold)),
          ),
          Expanded(child: Text(value)),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF3FAF9),
      appBar: AppBar(
        title: const Text('My Profile'),
        backgroundColor: Colors.teal,
        foregroundColor: Colors.white,
      ),
      body: StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
        stream: FirebaseFirestore.instance.collection('seniors').doc(seniorId).snapshots(),
        builder: (context, snap) {
          if (snap.hasError) return Center(child: Text('Error: ${snap.error}'));
          if (!snap.hasData) return const Center(child: CircularProgressIndicator());

          final s = snap.data!.data() ?? <String, dynamic>{};

          final name = (s['fullName'] as String?)?.trim().isNotEmpty == true
              ? (s['fullName'] as String)
              : ((s['name'] as String?)?.trim().isNotEmpty == true ? (s['name'] as String) : 'Senior');

          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Card(
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const CircleAvatar(
                            radius: 24,
                            backgroundColor: Colors.teal,
                            child: Icon(Icons.elderly, color: Colors.white),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              name,
                              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 14),
                      _row('Age', _v(s['age'])),
                      _row('Gender', _v(s['gender'])),
                      _row('Phone', _v(s['phone'])),
                      _row('City', _v(s['city'])),
                      _row('Address', _v(s['address'])),
                      _row('Guardian ID', _v(s['guardianId'] ?? s['createdByGuardianId'])),
                      if (_v(s['medicalNotes']) != '-') _row('Medical notes', _v(s['medicalNotes'])),
                    ],
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
