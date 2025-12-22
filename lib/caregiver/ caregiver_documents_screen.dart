import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

class CaregiverDocumentsScreen extends StatefulWidget {
  const CaregiverDocumentsScreen({super.key});

  @override
  State<CaregiverDocumentsScreen> createState() => _CaregiverDocumentsScreenState();
}

class _CaregiverDocumentsScreenState extends State<CaregiverDocumentsScreen> {
  final _formKey = GlobalKey<FormState>();

  final _nicFront = TextEditingController();
  final _nicBack = TextEditingController();
  final _police = TextEditingController();

  bool _loading = true;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    final snap = await FirebaseFirestore.instance.collection('caregivers').doc(user.uid).get();
    final data = snap.data() ?? {};
    final docs = (data['documents'] as Map?)?.cast<String, dynamic>() ?? {};

    _nicFront.text = (docs['nicFrontUrl'] as String?) ?? '';
    _nicBack.text = (docs['nicBackUrl'] as String?) ?? '';
    _police.text = (docs['policeClearanceUrl'] as String?) ?? '';

    if (mounted) setState(() => _loading = false);
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    setState(() => _saving = true);

    await FirebaseFirestore.instance.collection('caregivers').doc(user.uid).set(
      {
        'documents': {
          'nicFrontUrl': _nicFront.text.trim(),
          'nicBackUrl': _nicBack.text.trim(),
          'policeClearanceUrl': _police.text.trim(),
        },
        'updatedAt': FieldValue.serverTimestamp(),
      },
      SetOptions(merge: true),
    );

    if (!mounted) return;
    setState(() => _saving = false);
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Documents updated')));
    Navigator.pop(context);
  }

  @override
  void dispose() {
    _nicFront.dispose();
    _nicBack.dispose();
    _police.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Scaffold(body: Center(child: CircularProgressIndicator()));

    return Scaffold(
      appBar: AppBar(title: const Text('Verification Documents')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: ListView(
            children: [
              const Text(
                'For now paste URLs here. Next we will add real upload buttons (Firebase Storage).',
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _nicFront,
                decoration: const InputDecoration(labelText: 'NIC Front URL', border: OutlineInputBorder()),
                validator: (v) => (v == null || v.trim().isEmpty) ? 'NIC Front required' : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _nicBack,
                decoration: const InputDecoration(labelText: 'NIC Back URL', border: OutlineInputBorder()),
                validator: (v) => (v == null || v.trim().isEmpty) ? 'NIC Back required' : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _police,
                decoration: const InputDecoration(
                  labelText: 'Police Clearance URL (optional)',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: _saving ? null : _save,
                child: Text(_saving ? 'Saving...' : 'Save'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
