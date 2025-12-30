import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

class GuardianProfileEditScreen extends StatefulWidget {
  const GuardianProfileEditScreen({super.key});

  @override
  State<GuardianProfileEditScreen> createState() => _GuardianProfileEditScreenState();
}

class _GuardianProfileEditScreenState extends State<GuardianProfileEditScreen> {
  final _formKey = GlobalKey<FormState>();

  final _fullName = TextEditingController();
  final _phone = TextEditingController();
  final _nic = TextEditingController();

  bool _saving = false;

  @override
  void dispose() {
    _fullName.dispose();
    _phone.dispose();
    _nic.dispose();
    super.dispose();
  }

  String _digitsOnly(String v) => v.replaceAll(RegExp(r'[^0-9+]'), '');

  Future<void> _save(String uid) async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _saving = true);
    try {
      await FirebaseFirestore.instance.collection('guardians').doc(uid).set({
        'fullName': _fullName.text.trim(),
        'phone': _digitsOnly(_phone.text.trim()),
        'nicNumber': _nic.text.trim(),
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      if (!mounted) return;
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Guardian profile updated')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed: $e')),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      return const Scaffold(body: Center(child: Text('Not logged in')));
    }
    final uid = user.uid;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Update Guardian Profile'),
        backgroundColor: Colors.teal,
        foregroundColor: Colors.white,
      ),
      body: StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
        stream: FirebaseFirestore.instance.collection('guardians').doc(uid).snapshots(),
        builder: (context, snap) {
          if (snap.hasError) return Center(child: Text('Error: ${snap.error}'));
          if (!snap.hasData) return const Center(child: CircularProgressIndicator());

          final data = snap.data!.data() ?? {};

          // prefill only once
          if (_fullName.text.isEmpty) _fullName.text = (data['fullName'] ?? '').toString();
          if (_phone.text.isEmpty) _phone.text = (data['phone'] ?? '').toString();
          if (_nic.text.isEmpty) _nic.text = (data['nicNumber'] ?? '').toString();

          return Padding(
            padding: const EdgeInsets.all(16),
            child: Form(
              key: _formKey,
              child: ListView(
                children: [
                  TextFormField(
                    controller: _fullName,
                    decoration: const InputDecoration(
                      labelText: 'Full name',
                      border: OutlineInputBorder(),
                    ),
                    validator: (v) => (v == null || v.trim().isEmpty) ? 'Required' : null,
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _phone,
                    keyboardType: TextInputType.phone,
                    decoration: const InputDecoration(
                      labelText: 'Contact number',
                      hintText: '07XXXXXXXX',
                      border: OutlineInputBorder(),
                    ),
                    validator: (v) {
                      final t = (v ?? '').trim();
                      if (t.isEmpty) return 'Contact number is required';
                      if (t.length < 9) return 'Invalid contact number';
                      return null;
                    },
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _nic,
                    decoration: const InputDecoration(
                      labelText: 'NIC (optional)',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: _saving ? null : () => _save(uid),
                      icon: _saving
                          ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                          : const Icon(Icons.save),
                      label: Text(_saving ? 'Saving...' : 'Save'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.teal,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}
