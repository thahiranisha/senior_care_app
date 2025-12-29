import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

class RequestCareScreen extends StatefulWidget {
  final String caregiverId;
  final String caregiverName;

  const RequestCareScreen({
    super.key,
    required this.caregiverId,
    required this.caregiverName,
  });

  @override
  State<RequestCareScreen> createState() => _RequestCareScreenState();
}

class _RequestCareScreenState extends State<RequestCareScreen> {
  final _formKey = GlobalKey<FormState>();

  final _patientName = TextEditingController();
  final _patientAge = TextEditingController();
  final _address = TextEditingController();
  final _city = TextEditingController();
  final _notes = TextEditingController();

  DateTime? _startDateTime;
  int _durationHours = 2;
  String _frequency = 'Once';

  bool _submitting = false;

  @override
  void dispose() {
    _patientName.dispose();
    _patientAge.dispose();
    _address.dispose();
    _city.dispose();
    _notes.dispose();
    super.dispose();
  }

  Future<void> _pickDateTime() async {
    final now = DateTime.now();

    final pickedDate = await showDatePicker(
      context: context,
      initialDate: _startDateTime ?? now.add(const Duration(days: 1)),
      firstDate: now,
      lastDate: now.add(const Duration(days: 365)),
    );
    if (pickedDate == null) return;

    final pickedTime = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(_startDateTime ?? now),
    );
    if (pickedTime == null) return;

    final dt = DateTime(
      pickedDate.year,
      pickedDate.month,
      pickedDate.day,
      pickedTime.hour,
      pickedTime.minute,
    );

    setState(() => _startDateTime = dt);
  }

  String _prettyDateTime(DateTime dt) {
    final d = '${dt.year}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')}';
    final h = dt.hour.toString().padLeft(2, '0');
    final m = dt.minute.toString().padLeft(2, '0');
    return '$d  $h:$m';
  }

  Future<void> _submit() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please login as Guardian first.')),
      );
      return;
    }

    if (!_formKey.currentState!.validate()) return;

    if (_startDateTime == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please pick a start date & time.')),
      );
      return;
    }

    setState(() => _submitting = true);

    try {
      final req = <String, dynamic>{
        'guardianId': user.uid,
        'caregiverId': widget.caregiverId,
        'caregiverName': widget.caregiverName,

        'patientName': _patientName.text.trim(),
        'patientAge': int.tryParse(_patientAge.text.trim()) ?? null,
        'city': _city.text.trim(),
        'address': _address.text.trim(),
        'notes': _notes.text.trim(),

        'startDate': Timestamp.fromDate(_startDateTime!),
        'durationHours': _durationHours,
        'frequency': _frequency,

        'status': 'PENDING',
        'statusReason': '',
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      };

      await FirebaseFirestore.instance.collection('care_requests').add(req);

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Request submitted ✅')),
      );
      Navigator.pop(context);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed: $e')),
      );
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final end = (_startDateTime == null)
        ? null
        : _startDateTime!.add(Duration(hours: _durationHours));

    return Scaffold(
      appBar: AppBar(title: const Text('Request Care')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Caregiver', style: TextStyle(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 6),
                  Text(widget.caregiverName),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),

          Form(
            key: _formKey,
            child: Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    TextFormField(
                      controller: _patientName,
                      decoration: const InputDecoration(
                        labelText: 'Patient name',
                        border: OutlineInputBorder(),
                      ),
                      validator: (v) => (v == null || v.trim().isEmpty) ? 'Required' : null,
                    ),
                    const SizedBox(height: 10),
                    TextFormField(
                      controller: _patientAge,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        labelText: 'Patient age',
                        border: OutlineInputBorder(),
                      ),
                      validator: (v) {
                        final t = v?.trim() ?? '';
                        if (t.isEmpty) return null; // optional
                        final n = int.tryParse(t);
                        if (n == null || n <= 0 || n > 120) return 'Enter valid age';
                        return null;
                      },
                    ),
                    const SizedBox(height: 10),
                    TextFormField(
                      controller: _city,
                      decoration: const InputDecoration(
                        labelText: 'City',
                        border: OutlineInputBorder(),
                      ),
                      validator: (v) => (v == null || v.trim().isEmpty) ? 'Required' : null,
                    ),
                    const SizedBox(height: 10),
                    TextFormField(
                      controller: _address,
                      maxLines: 2,
                      decoration: const InputDecoration(
                        labelText: 'Address',
                        border: OutlineInputBorder(),
                      ),
                      validator: (v) => (v == null || v.trim().isEmpty) ? 'Required' : null,
                    ),
                    const SizedBox(height: 14),

                    // Scheduling
                    Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        'Schedule',
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                      ),
                    ),
                    const SizedBox(height: 10),

                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton.icon(
                        icon: const Icon(Icons.event),
                        onPressed: _submitting ? null : _pickDateTime,
                        label: Text(
                          _startDateTime == null
                              ? 'Pick start date & time'
                              : 'Start: ${_prettyDateTime(_startDateTime!)}',
                        ),
                      ),
                    ),
                    if (end != null) ...[
                      const SizedBox(height: 8),
                      Align(
                        alignment: Alignment.centerLeft,
                        child: Text('Ends: ${_prettyDateTime(end)}'),
                      ),
                    ],
                    const SizedBox(height: 10),

                    DropdownButtonFormField<int>(
                      value: _durationHours,
                      decoration: const InputDecoration(
                        labelText: 'Duration (hours)',
                        border: OutlineInputBorder(),
                      ),
                      items: const [1, 2, 3, 4, 6, 8, 12]
                          .map((h) => DropdownMenuItem(value: h, child: Text('$h hours')))
                          .toList(),
                      onChanged: _submitting ? null : (v) => setState(() => _durationHours = v ?? 2),
                    ),
                    const SizedBox(height: 10),

                    DropdownButtonFormField<String>(
                      value: _frequency,
                      decoration: const InputDecoration(
                        labelText: 'Frequency',
                        border: OutlineInputBorder(),
                      ),
                      items: const ['Once', 'Daily', 'Weekly']
                          .map((f) => DropdownMenuItem(value: f, child: Text(f)))
                          .toList(),
                      onChanged: _submitting ? null : (v) => setState(() => _frequency = v ?? 'Once'),
                    ),

                    const SizedBox(height: 14),
                    TextFormField(
                      controller: _notes,
                      maxLines: 3,
                      decoration: const InputDecoration(
                        labelText: 'Notes (optional)',
                        border: OutlineInputBorder(),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),

          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              icon: _submitting
                  ? const SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
                  : const Icon(Icons.send),
              onPressed: _submitting ? null : _submit,
              label: Text(_submitting ? 'Submitting...' : 'Submit Request'),
            ),
          ),
        ],
      ),
    );
  }
}
