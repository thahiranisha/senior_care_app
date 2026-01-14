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

  final _addressCtrl = TextEditingController();

  final _mobilityLevel = TextEditingController();
  final _medicalConditions = TextEditingController();
  final _currentMedications = TextEditingController();
  final _allergies = TextEditingController();

  final _notes = TextEditingController();

  DateTime? _startDateTime;
  int _durationHours = 2;
  String _frequency = 'Once';

  bool _submitting = false;
  bool _loadingSenior = false;

  String _cityValue = '';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _prefillFromSenior());
  }

  @override
  void dispose() {
    _patientName.dispose();
    _patientAge.dispose();
    _addressCtrl.dispose();

    _mobilityLevel.dispose();
    _medicalConditions.dispose();
    _currentMedications.dispose();
    _allergies.dispose();

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
    final d =
        '${dt.year}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')}';
    final h = dt.hour.toString().padLeft(2, '0');
    final m = dt.minute.toString().padLeft(2, '0');
    return '$d  $h:$m';
  }

  Future<Map<String, dynamic>> _loadGuardianProfile(String uid) async {
    final gSnap =
    await FirebaseFirestore.instance.collection('guardians').doc(uid).get();
    final uSnap =
    await FirebaseFirestore.instance.collection('users').doc(uid).get();

    final g = gSnap.data() ?? {};
    final u = uSnap.data() ?? {};

    final name =
    ((g['fullName'] as String?) ?? (u['fullName'] as String?) ?? '').trim();
    final phone = ((g['phone'] as String?) ?? '').trim();
    final nic = ((g['nicNumber'] as String?) ?? '').trim();

    return {
      'guardianName': name.isEmpty ? 'Guardian' : name,
      'guardianPhone': phone,
      'guardianNicNumber': nic,
    };
  }

  int _calcAge(DateTime dob) {
    final now = DateTime.now();
    int age = now.year - dob.year;
    if (now.month < dob.month ||
        (now.month == dob.month && now.day < dob.day)) {
      age--;
    }
    return age;
  }

  String? _normalizeGender(String raw) {
    final g = raw.trim().toLowerCase();
    if (g.isEmpty) return null;
    if (g == 'm' || g == 'male') return 'Male';
    if (g == 'f' || g == 'female') return 'Female';
    if (g == 'other') return 'Other';
    if (g.contains('prefer')) return 'Prefer not to say';
    if (raw == 'Male' ||
        raw == 'Female' ||
        raw == 'Other' ||
        raw == 'Prefer not to say') return raw;
    return null;
  }

  String _deriveCityFromAddress(String address) {
    final a = address.trim();
    if (a.isEmpty) return '';
    final parts = a.split(',');
    if (parts.isEmpty) return '';
    final last = parts.last.trim();
    return last;
  }

  Future<void> _prefillFromSenior() async {
    final id = widget.seniorId;
    if (id == null || id.trim().isEmpty) return;

    setState(() => _loadingSenior = true);
    try {
      final snap =
      await FirebaseFirestore.instance.collection('seniors').doc(id).get();
      final s = snap.data();
      if (s == null || !mounted) return;

      final fullName =
      (s['fullName'] ?? s['patientName'] ?? s['name'] ?? '').toString();
      if (_patientName.text.trim().isEmpty && fullName.trim().isNotEmpty) {
        _patientName.text = fullName.trim();
      }

      int? age;
      final ageVal = s['age'];
      if (ageVal is num) {
        age = ageVal.toInt();
      } else {
        final dobVal = s['dob'];
        if (dobVal is Timestamp) {
          age = _calcAge(dobVal.toDate());
        }
      }
      if (_patientAge.text.trim().isEmpty && age != null && age > 0) {
        _patientAge.text = age.toString();
      }

      final genderRaw = (s['gender'] ?? '').toString();
      final normGender = _normalizeGender(genderRaw);
      if ((_patientGender == null || _patientGender!.trim().isEmpty) &&
          normGender != null) {
        setState(() => _patientGender = normGender);
      }

      final address = (s['address'] ?? '').toString().trim();
      if (_addressCtrl.text.trim().isEmpty && address.isNotEmpty) {
        _addressCtrl.text = address;
      }

      final city = (s['city'] ?? '').toString().trim();
      if (_cityValue.isEmpty && city.isNotEmpty) {
        _cityValue = city;
      }

      final mobility = (s['mobilityLevel'] ?? '').toString();
      if (_mobilityLevel.text.trim().isEmpty && mobility.trim().isNotEmpty) {
        _mobilityLevel.text = mobility.trim();
      }

      final cond = (s['medicalConditions'] ?? '').toString();
      if (_medicalConditions.text.trim().isEmpty && cond.trim().isNotEmpty) {
        _medicalConditions.text = cond.trim();
      }

      final meds = (s['currentMedications'] ?? '').toString();
      if (_currentMedications.text.trim().isEmpty && meds.trim().isNotEmpty) {
        _currentMedications.text = meds.trim();
      }

      final allergies = (s['allergies'] ?? '').toString();
      if (_allergies.text.trim().isEmpty && allergies.trim().isNotEmpty) {
        _allergies.text = allergies.trim();
      }
    } catch (_) {
    } finally {
      if (mounted) setState(() => _loadingSenior = false);
    }
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

    final addressValue = _addressCtrl.text.trim();
    if (addressValue.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Senior address missing.')),
      );
      return;
    }

    var cityValue = _cityValue.trim();
    if (cityValue.isEmpty) {
      cityValue = _deriveCityFromAddress(addressValue);
    }
    if (cityValue.isEmpty) {
      cityValue = 'N/A';
    }

    setState(() => _submitting = true);

    try {
      final guardianProfile = await _loadGuardianProfile(user.uid);

      final req = <String, dynamic>{
        'guardianId': user.uid,
        'caregiverId': widget.caregiverId,
        'caregiverName': widget.caregiverName,
        'seniorId': widget.seniorId,
        'guardianName': guardianProfile['guardianName'],
        'guardianPhone': guardianProfile['guardianPhone'],
        'guardianNicNumber': guardianProfile['guardianNicNumber'],
        'patientName': _patientName.text.trim(),
        'patientAge': int.tryParse(_patientAge.text.trim()),
        'patientGender': _patientGender,
        'city': cityValue,
        'address': addressValue,
        'mobilityLevel': _mobilityLevel.text.trim(),
        'medicalConditions': _medicalConditions.text.trim(),
        'currentMedications': _currentMedications.text.trim(),
        'allergies': _allergies.text.trim(),
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
        const SnackBar(content: Text('Request submitted.')),
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
                  const Text('Caregiver',
                      style: TextStyle(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 6),
                  Text(widget.caregiverName),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          if (_loadingSenior) const LinearProgressIndicator(),
          Form(
            key: _formKey,
            child: Column(
              children: [
                TextFormField(
                  controller: _patientName,
                  decoration: const InputDecoration(labelText: 'Patient name'),
                  validator: (v) =>
                  (v == null || v.trim().isEmpty) ? 'Required' : null,
                ),
                const SizedBox(height: 10),
                TextFormField(
                  controller: _patientAge,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(labelText: 'Patient age *'),
                  validator: (v) {
                    final n = int.tryParse((v ?? '').trim());
                    if (n == null || n <= 0) return 'Enter a valid age';
                    return null;
                  },
                ),
                const SizedBox(height: 10),
                DropdownButtonFormField<String>(
                  value: _patientGender,
                  items: const [
                    DropdownMenuItem(value: 'Male', child: Text('Male')),
                    DropdownMenuItem(value: 'Female', child: Text('Female')),
                    DropdownMenuItem(value: 'Other', child: Text('Other')),
                    DropdownMenuItem(
                      value: 'Prefer not to say',
                      child: Text('Prefer not to say'),
                    ),
                  ],
                  onChanged: (v) => setState(() => _patientGender = v),
                  decoration:
                  const InputDecoration(labelText: 'Patient gender *'),
                  validator: (v) =>
                  (v == null || v.trim().isEmpty) ? 'Required' : null,
                ),
                const SizedBox(height: 10),
                TextFormField(
                  controller: _addressCtrl,
                  decoration: const InputDecoration(labelText: 'Address *'),
                  maxLines: 2,
                  validator: (v) =>
                  (v == null || v.trim().isEmpty) ? 'Required' : null,
                ),
                const SizedBox(height: 10),
                TextFormField(
                  controller: _mobilityLevel,
                  decoration: const InputDecoration(labelText: 'Mobility level'),
                ),
                const SizedBox(height: 10),
                TextFormField(
                  controller: _medicalConditions,
                  decoration:
                  const InputDecoration(labelText: 'Medical conditions'),
                  maxLines: 2,
                ),
                const SizedBox(height: 10),
                TextFormField(
                  controller: _currentMedications,
                  decoration:
                  const InputDecoration(labelText: 'Current medications'),
                  maxLines: 2,
                ),
                const SizedBox(height: 10),
                TextFormField(
                  controller: _allergies,
                  decoration: const InputDecoration(labelText: 'Allergies'),
                  maxLines: 2,
                ),
                const SizedBox(height: 10),
                TextFormField(
                  controller: _notes,
                  decoration: const InputDecoration(labelText: 'Notes'),
                  maxLines: 3,
                ),
                const SizedBox(height: 16),
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Schedule',
                            style: TextStyle(fontWeight: FontWeight.bold)),
                        const SizedBox(height: 10),
                        SizedBox(
                          width: double.infinity,
                          child: OutlinedButton.icon(
                            icon: const Icon(Icons.calendar_month),
                            onPressed: _pickDateTime,
                            label: Text(
                              _startDateTime == null
                                  ? 'Pick start date & time'
                                  : _prettyDateTime(_startDateTime!),
                            ),
                          ),
                        ),
                        const SizedBox(height: 10),
                        DropdownButtonFormField<int>(
                          value: _durationHours,
                          items: const [
                            DropdownMenuItem(value: 1, child: Text('1 hour')),
                            DropdownMenuItem(value: 2, child: Text('2 hours')),
                            DropdownMenuItem(value: 3, child: Text('3 hours')),
                            DropdownMenuItem(value: 4, child: Text('4 hours')),
                            DropdownMenuItem(value: 6, child: Text('6 hours')),
                            DropdownMenuItem(value: 8, child: Text('8 hours')),
                          ],
                          onChanged: (v) =>
                              setState(() => _durationHours = v ?? 2),
                          decoration: const InputDecoration(
                              labelText: 'Duration (hours)'),
                        ),
                        const SizedBox(height: 10),
                        DropdownButtonFormField<String>(
                          value: _frequency,
                          items: const [
                            DropdownMenuItem(value: 'Once', child: Text('Once')),
                            DropdownMenuItem(value: 'Daily', child: Text('Daily')),
                            DropdownMenuItem(value: 'Weekly', child: Text('Weekly')),
                          ],
                          onChanged: (v) =>
                              setState(() => _frequency = v ?? 'Once'),
                          decoration:
                          const InputDecoration(labelText: 'Frequency'),
                        ),
                        if (end != null) ...[
                          const SizedBox(height: 8),
                          Text('Ends: ${_prettyDateTime(end)}'),
                        ],
                      ],
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
          ),
        ],
      ),
    );
  }
}
