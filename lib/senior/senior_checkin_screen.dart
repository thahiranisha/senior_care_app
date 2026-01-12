import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

/// Senior Check-in
///
/// Writes:
/// - senior_status/{seniorId}: lastCheckIn, lastMood
/// - activity_logs_today: {seniorId, type, description, time}
class SeniorCheckinScreen extends StatefulWidget {
  final String seniorId;
  const SeniorCheckinScreen({super.key, required this.seniorId});

  @override
  State<SeniorCheckinScreen> createState() => _SeniorCheckinScreenState();
}

class _SeniorCheckinScreenState extends State<SeniorCheckinScreen> {
  bool _saving = false;
  String? _error;

  Future<void> _save(String mood) async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;

    setState(() {
      _saving = true;
      _error = null;
    });

    try {
      final db = FirebaseFirestore.instance;

      final batch = db.batch();

      final statusRef = db.collection('senior_status').doc(widget.seniorId);
      batch.set(
        statusRef,
        {
          'lastCheckIn': FieldValue.serverTimestamp(),
          'lastMood': mood,
          'updatedAt': FieldValue.serverTimestamp(),
          'updatedBy': uid,
        },
        SetOptions(merge: true),
      );

      final actRef = db.collection('activity_logs_today').doc();
      batch.set(actRef, {
        'seniorId': widget.seniorId,
        'type': 'CHECKIN',
        'description': 'Checked in • Mood: $mood',
        'time': FieldValue.serverTimestamp(),
        'createdBy': uid,
      });

      await batch.commit();

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Check-in saved ✅')),
      );
      Navigator.pop(context);
    } catch (e) {
      setState(() => _error = e.toString().replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Widget _moodButton({required String mood, required IconData icon, required Color color}) {
    return SizedBox(
      width: double.infinity,
      height: 54,
      child: ElevatedButton.icon(
        onPressed: _saving ? null : () => _save(mood),
        icon: Icon(icon),
        label: Text(mood, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
        style: ElevatedButton.styleFrom(
          backgroundColor: color,
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF3FAF9),
      appBar: AppBar(
        title: const Text('Check-in'),
        backgroundColor: Colors.teal,
        foregroundColor: Colors.white,
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text(
                'How are you feeling right now?',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 12),
              _moodButton(mood: 'Good', icon: Icons.sentiment_satisfied_alt, color: Colors.teal),
              const SizedBox(height: 10),
              _moodButton(mood: 'Okay', icon: Icons.sentiment_neutral, color: Colors.blueGrey),
              const SizedBox(height: 10),
              _moodButton(mood: 'Not well', icon: Icons.sentiment_dissatisfied, color: Colors.deepOrange),
              if (_error != null) ...[
                const SizedBox(height: 12),
                Text(_error!, style: const TextStyle(color: Colors.red)),
              ],
              const Spacer(),
              const Text(
                'Tip: Checking in helps your guardian monitor your wellbeing.',
                style: TextStyle(color: Colors.black54),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
