import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

class RequestCareScreen extends StatefulWidget {
  final String caregiverId;
  final String caregiverName;
  final String? seniorId;

  const RequestCareScreen({
    super.key,
    required this.caregiverId,
    required this.caregiverName,
    this.seniorId,
  });

  @override
  State<RequestCareScreen> createState() => _RequestCareScreenState();
}

class _RequestCareScreenState extends State<RequestCareScreen> {
  final _formKey = GlobalKey<FormState>();

  final _patientName = TextEditingController();
  final _patientAge = TextEditingController();
  String? _patientGender;
  final _address = TextEditingController();
  final _city = TextEditingController();
  final _notes = TextEditingController();

  bool _loadingSenior = false;
  String? _seniorLoadError;
  Map<String, dynamic>? _seniorData;


  DateTime? _startDateTime;
  int _durationHours = 2;
  String _frequency = 'Once';

  bool _submitting = false;

  @override
  @override
  void initState() {
    super.initState();
    if (widget.seniorId != null && widget.seniorId!.trim().isNotEmpty) {
      _loadSeniorAndPrefill(widget.seniorId!.trim());
    }
  }

  Future<void> _loadSeniorAndPrefill(String seniorId) async {
    setState(() {
      _loadingSenior = true;
      _seniorLoadError = null;
    });

    try {
      final snap = await FirebaseFirestore.instance.collection('seniors').doc(seniorId).get();
      if (!snap.exists) {
        setState(() {
          _seniorLoadError = 'Selected senior profile not found.';
        });
        return;
      }

      final data = snap.data() ?? <String, dynamic>{};
      _seniorData = data;
      _prefillFromSenior(data);
    } catch (e) {
      setState(() {
        _seniorLoadError = 'Failed to load senior details.';
      });
    } finally {
      if (mounted) {
        setState(() => _loadingSenior = false);
      }
    }
  }

  void _prefillFromSenior(Map<String, dynamic> s) {
    final fullName = (s['fullName'] as String?)?.trim() ?? '';
    if (_patientName.text.trim().isEmpty && fullName.isNotEmpty) {
      _patientName.text = fullName;
    }

    // Age from DOB
    DateTime? dob;
    final dobVal = s['dob'];
    if (dobVal is Timestamp) {
      dob = dobVal.toDate();
    } else if (dobVal is DateTime) {
      dob = dobVal;
    }
    if (_patientAge.text.trim().isEmpty && dob != null) {
      _patientAge.text = _calcAge(dob).toString();
    }

    final gender = (s['gender'] as String?)?.trim();
    if ((_patientGender == null || _patientGender!.trim().isEmpty) && gender != null && gender.isNotEmpty) {
      _patientGender = gender;
    }

    final address = (s['address'] as String?)?.trim() ?? '';
    if (_address.text.trim().isEmpty && address.isNotEmpty) {
      _address.text = address;
    }

    if (_city.text.trim().isEmpty && address.isNotEmpty) {
      final guessedCity = _guessCityFromAddress(address);
      if (guessedCity.isNotEmpty) {
        _city.text = guessedCity;
      }
    }

    // Prefill notes with medical + emergency info (only if empty)
    if (_notes.text.trim().isEmpty) {
      final mc = (s['medicalConditions'] as String?)?.trim() ?? '';
      final al = (s['allergies'] as String?)?.trim() ?? '';
      final meds = (s['currentMedications'] as String?)?.trim() ?? '';
      final mob = (s['mobilityLevel'] as String?)?.trim() ?? '';
      final eName = (s['emergencyContactName'] as String?)?.trim() ?? '';
      final ePhone = (s['emergencyContactPhone'] as String?)?.trim() ?? '';
      final extra = (s['notes'] as String?)?.trim() ?? '';

      final parts = <String>[];
      if (mc.isNotEmpty) parts.add('Medical conditions: $mc');
      if (al.isNotEmpty) parts.add('Allergies: $al');
      if (meds.isNotEmpty) parts.add('Current medications: $meds');
      if (mob.isNotEmpty) parts.add('Mobility: $mob');
      if (eName.isNotEmpty || ePhone.isNotEmpty) {
        parts.add('Emergency contact: ${eName.isEmpty ? '-' : eName}${ePhone.isEmpty ? '' : ' ($ePhone)'}');
      }
      if (extra.isNotEmpty) parts.add('Notes: $extra');

      if (parts.isNotEmpty) {
        _notes.text = parts.join('');
      }
    }

    if (mounted) setState(() {});
  }

  int _calcAge(DateTime dob) {
    final now = DateTime.now();
    int age = now.year - dob.year;
    final hadBirthdayThisYear = (now.month > dob.month) || (now.month == dob.month && now.day >= dob.day);
    if (!hadBirthdayThisYear) age -= 1;
    if (age < 0) age = 0;
    return age;
  }

  String _guessCityFromAddress(String address) {
    // Simple heuristic: take last comma-separated token
    final parts = address.split(',').map((e) => e.trim()).where((e) => e.isNotEmpty).toList();
    if (parts.length >= 2) {
      return parts.last;
    }
    return '';
  }


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

  Future<Map<String, dynamic>> _loadGuardianProfile(String uid) async {
    final gSnap = await FirebaseFirestore.instance.collection('guardians').doc(uid).get();
    final uSnap = await FirebaseFirestore.instance.collection('users').doc(uid).get();

    final g = gSnap.data() ?? {};
    final u = uSnap.data() ?? {};

    final name = ((g['fullName'] as String?) ?? (u['fullName'] as String?) ?? '').trim();
    final phone = ((g['phone'] as String?) ?? '').trim();
    final nic = ((g['nicNumber'] as String?) ?? '').trim();

    return {
      'guardianName': name.isEmpty ? 'Guardian' : name,
      'guardianPhone': phone,
      'guardianNicNumber': nic,
    };
  }

  Future<void> _submit() async {
    if (_loadingSenior) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Loading senior details… please wait.')),
      );
      return;
    }

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
      final guardianProfile = await _loadGuardianProfile(user.uid);

      final req = <String, dynamic>{
        'guardianId': user.uid,
        'caregiverId': widget.caregiverId,
        'caregiverName': widget.caregiverName,
        'seniorId': widget.seniorId,

        // ✅ store guardian info INSIDE the request
        'guardianName': guardianProfile['guardianName'],
        'guardianPhone': guardianProfile['guardianPhone'],
        'guardianNicNumber': guardianProfile['guardianNicNumber'],

        // Optional: snapshot some senior info for caregiver convenience
        if (_seniorData != null) ...{
          'seniorFullName': _seniorData!['fullName'],
          'seniorDob': _seniorData!['dob'],
          'seniorPhone': _seniorData!['phone'],
          'seniorAddress': _seniorData!['address'],
          'seniorEmergencyContactName': _seniorData!['emergencyContactName'],
          'seniorEmergencyContactPhone': _seniorData!['emergencyContactPhone'],
          'seniorMedicalConditions': _seniorData!['medicalConditions'],
          'seniorAllergies': _seniorData!['allergies'],
          'seniorCurrentMedications': _seniorData!['currentMedications'],
          'seniorMobilityLevel': _seniorData!['mobilityLevel'],
          'seniorNotes': _seniorData!['notes'],
        },

        'patientName': _patientName.text.trim(),
        'patientAge': int.tryParse(_patientAge.text.trim()),
        'patientGender': _patientGender,
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

          if (widget.seniorId != null) ...[
            Card(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.person, size: 18),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Selected Senior (auto-filled)',
                            style: Theme.of(context)
                                .textTheme
                                .titleSmall
                                ?.copyWith(fontWeight: FontWeight.bold),
                          ),
                        ),
                        if (_loadingSenior) const SizedBox(width: 16),
                        if (_loadingSenior)
                          const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    if (_seniorLoadError != null)
                      Text(
                        _seniorLoadError!,
                        style: const TextStyle(color: Colors.red),
                      )
                    else if (_seniorData != null) ...[
                      Text('Name: ${(_seniorData!['fullName'] as String?) ?? '-'}'),
                      const SizedBox(height: 2),
                      Text('Gender: ${(_seniorData!['gender'] as String?) ?? '-'}'),
                    ] else
                      const Text('Loading senior details…'),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),
          ],

          Form(
            key: _formKey,
            child: Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    TextFormField(
                      controller: _patientName,
                      readOnly: widget.seniorId != null,
                      enabled: !_submitting && !_loadingSenior,
                      decoration: const InputDecoration(
                        labelText: 'Patient name',
                        border: OutlineInputBorder(),
                      ),
                      validator: (v) => (v == null || v.trim().isEmpty) ? 'Required' : null,
                    ),
                    const SizedBox(height: 10),
                    TextFormField(
                      controller: _patientAge,
                      readOnly: widget.seniorId != null,
                      enabled: !_submitting && !_loadingSenior,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        labelText: 'Patient age *',
                        border: OutlineInputBorder(),
                      ),
                      validator: (v) {
                        final t = v?.trim() ?? '';
                        if (t.isEmpty) return 'Required';
                        final n = int.tryParse(t);
                        if (n == null || n <= 0 || n > 120) return 'Enter valid age';
                        return null;
                      },
                    ),
                    const SizedBox(height: 10),
                    DropdownButtonFormField<String>(
                      value: _patientGender,
                      decoration: const InputDecoration(
                        labelText: 'Patient gender *',
                        border: OutlineInputBorder(),
                      ),
                      items: const [
                        DropdownMenuItem(value: 'Male', child: Text('Male')),
                        DropdownMenuItem(value: 'Female', child: Text('Female')),
                        DropdownMenuItem(value: 'Other', child: Text('Other')),
                        DropdownMenuItem(value: 'Prefer not to say', child: Text('Prefer not to say')),
                      ],
                      onChanged: (_submitting || _loadingSenior) ? null : (v) => setState(() => _patientGender = v),
                      validator: (v) => (v == null || v.trim().isEmpty) ? 'Required' : null,
                    ),
                    const SizedBox(height: 10),
                    TextFormField(
                      controller: _city,
                      enabled: !_submitting && !_loadingSenior,
                      decoration: const InputDecoration(
                        labelText: 'City',
                        border: OutlineInputBorder(),
                      ),
                      validator: (v) => (v == null || v.trim().isEmpty) ? 'Required' : null,
                    ),
                    const SizedBox(height: 10),
                    TextFormField(
                      controller: _address,
                      readOnly: widget.seniorId != null,
                      enabled: !_submitting && !_loadingSenior,
                      maxLines: 2,
                      decoration: const InputDecoration(
                        labelText: 'Address',
                        border: OutlineInputBorder(),
                      ),
                      validator: (v) => (v == null || v.trim().isEmpty) ? 'Required' : null,
                    ),
                    const SizedBox(height: 14),

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
                      enabled: !_submitting && !_loadingSenior,
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
                  ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
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
