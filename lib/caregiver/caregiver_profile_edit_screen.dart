import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

class CaregiverProfileEditScreen extends StatefulWidget {
  const CaregiverProfileEditScreen({super.key});

  @override
  State<CaregiverProfileEditScreen> createState() => _CaregiverProfileEditScreenState();
}

class _CaregiverProfileEditScreenState extends State<CaregiverProfileEditScreen> {
  final _formKey = GlobalKey<FormState>();

  final _phone = TextEditingController();
  final _city = TextEditingController();
  final _experience = TextEditingController();
  final _hourlyRate = TextEditingController();
  final _bio = TextEditingController();
  final _languages = TextEditingController();
  final _specialties = TextEditingController();

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

    _phone.text = (data['phone'] as String?) ?? '';
    _city.text = (data['city'] as String?) ?? '';
    _experience.text = '${data['experienceYears'] ?? ''}'.trim();
    _hourlyRate.text = '${data['hourlyRate'] ?? ''}'.trim();
    _bio.text = (data['bio'] as String?) ?? '';

    final langs = (data['languages'] as List?)?.map((e) => e.toString()).toList() ?? [];
    final specs = (data['specialties'] as List?)?.map((e) => e.toString()).toList() ?? [];

    _languages.text = langs.join(', ');
    _specialties.text = specs.join(', ');

    if (mounted) setState(() => _loading = false);
  }

  List<String> _splitList(String raw) {
    return raw
        .split(',')
        .map((s) => s.trim())
        .where((s) => s.isNotEmpty)
        .toList();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    setState(() => _saving = true);

    final exp = int.tryParse(_experience.text.trim());
    final rate = num.tryParse(_hourlyRate.text.trim());

    await FirebaseFirestore.instance.collection('caregivers').doc(user.uid).set(
      {
        'phone': _phone.text.trim(),
        'city': _city.text.trim(),
        'experienceYears': exp,
        'hourlyRate': rate,
        'bio': _bio.text.trim(),
        'languages': _splitList(_languages.text),
        'specialties': _splitList(_specialties.text),
        'updatedAt': FieldValue.serverTimestamp(),
      },
      SetOptions(merge: true),
    );

    if (!mounted) return;
    setState(() => _saving = false);
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Profile updated')));
    Navigator.pop(context);
  }

  @override
  void dispose() {
    _phone.dispose();
    _city.dispose();
    _experience.dispose();
    _hourlyRate.dispose();
    _bio.dispose();
    _languages.dispose();
    _specialties.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Edit Caregiver Profile')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: ListView(
            children: [
              TextFormField(
                controller: _phone,
                decoration: const InputDecoration(labelText: 'Phone', border: OutlineInputBorder()),
                validator: (v) => (v == null || v.trim().isEmpty) ? 'Phone is required' : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _city,
                decoration: const InputDecoration(labelText: 'City', border: OutlineInputBorder()),
                validator: (v) => (v == null || v.trim().isEmpty) ? 'City is required' : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _experience,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: 'Experience years', border: OutlineInputBorder()),
                validator: (v) => (v == null || v.trim().isEmpty) ? 'Experience is required' : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _hourlyRate,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: 'Hourly rate', border: OutlineInputBorder()),
                validator: (v) => (v == null || v.trim().isEmpty) ? 'Hourly rate is required' : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _languages,
                decoration: const InputDecoration(
                  labelText: 'Languages (comma separated)',
                  border: OutlineInputBorder(),
                ),
                validator: (v) => (v == null || v.trim().isEmpty) ? 'Languages required' : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _specialties,
                decoration: const InputDecoration(
                  labelText: 'Specialties (comma separated)',
                  border: OutlineInputBorder(),
                ),
                validator: (v) => (v == null || v.trim().isEmpty) ? 'Specialties required' : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _bio,
                maxLines: 4,
                decoration: const InputDecoration(labelText: 'Bio', border: OutlineInputBorder()),
                validator: (v) => (v == null || v.trim().isEmpty) ? 'Bio is required' : null,
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
