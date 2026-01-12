import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

/// Senior Emergency SOS
///
/// Creates an alert in /alerts and logs activity.
class SeniorEmergencyScreen extends StatefulWidget {
  final String seniorId;
  final String seniorName;

  const SeniorEmergencyScreen({
    super.key,
    required this.seniorId,
    required this.seniorName,
  });

  @override
  State<SeniorEmergencyScreen> createState() => _SeniorEmergencyScreenState();
}

class _SeniorEmergencyScreenState extends State<SeniorEmergencyScreen> {
  bool _sending = false;
  final _msgCtrl = TextEditingController();
  String? _error;

  @override
  void dispose() {
    _msgCtrl.dispose();
    super.dispose();
  }

  Future<void> _sendSOS() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;

    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Send SOS?'),
        content: const Text(
          'This will send an emergency alert to your guardian.\n\n'
          'Only press SOS if you really need help.',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          ElevatedButton(onPressed: () => Navigator.pop(context, true), child: const Text('Send')),
        ],
      ),
    );
    if (ok != true) return;

    setState(() {
      _sending = true;
      _error = null;
    });

    try {
      final db = FirebaseFirestore.instance;
      final text = _msgCtrl.text.trim();
      final message = text.isEmpty ? 'SOS triggered by ${widget.seniorName}' : text;

      final batch = db.batch();

      final alertRef = db.collection('alerts').doc();
      batch.set(alertRef, {
        'seniorId': widget.seniorId,
        'type': 'SOS',
        'message': message,
        'createdAt': FieldValue.serverTimestamp(),
        'createdBy': uid,
      });

      final actRef = db.collection('activity_logs_today').doc();
      batch.set(actRef, {
        'seniorId': widget.seniorId,
        'type': 'ALERT',
        'description': 'SOS sent',
        'time': FieldValue.serverTimestamp(),
        'createdBy': uid,
      });

      await batch.commit();

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('SOS sent ✅')),
      );
      Navigator.pop(context);
    } catch (e) {
      setState(() => _error = e.toString().replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF3FAF9),
      appBar: AppBar(
        title: const Text('Emergency SOS'),
        backgroundColor: Colors.teal,
        foregroundColor: Colors.white,
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Card(
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'If you need urgent help',
                        style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        'Press the SOS button to notify your guardian immediately.',
                        style: TextStyle(color: Colors.black54),
                      ),
                      const SizedBox(height: 14),
                      TextField(
                        controller: _msgCtrl,
                        minLines: 2,
                        maxLines: 4,
                        decoration: const InputDecoration(
                          labelText: 'Optional message',
                          hintText: 'Example: I fell down. Please come quickly.',
                          border: OutlineInputBorder(),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
              SizedBox(
                height: 58,
                child: ElevatedButton.icon(
                  onPressed: _sending ? null : _sendSOS,
                  icon: const Icon(Icons.sos),
                  label: _sending
                      ? const SizedBox(
                          height: 22,
                          width: 22,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text('SEND SOS', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.redAccent,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
                  ),
                ),
              ),
              if (_error != null) ...[
                const SizedBox(height: 12),
                Text(_error!, style: const TextStyle(color: Colors.red)),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
