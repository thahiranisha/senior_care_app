import 'package:flutter/material.dart';
import '../models/senior_registration_data.dart';

Future<SeniorRegistrationData?> showRegisterSeniorDialog(BuildContext context) async {
  final nameCtrl = TextEditingController();
  final phoneCtrl = TextEditingController();
  final addressCtrl = TextEditingController();

  final ecNameCtrl = TextEditingController();
  final ecPhoneCtrl = TextEditingController();

  final conditionsCtrl = TextEditingController();
  final allergiesCtrl = TextEditingController();
  final medsCtrl = TextEditingController();
  final notesCtrl = TextEditingController();

  DateTime? dob;
  String? gender;
  String mobility = 'Independent';

  SeniorRegistrationData? result;

  await showDialog(
    context: context,
    barrierDismissible: false,
    builder: (_) {
      return StatefulBuilder(
        builder: (context, setState) {
          return AlertDialog(
            title: const Text('Register Senior'),
            content: SingleChildScrollView(
              child: Column(
                children: [
                  TextField(
                    controller: nameCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Full Name',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 12),

                  // DOB picker
                  InkWell(
                    onTap: () async {
                      final now = DateTime.now();
                      final picked = await showDatePicker(
                        context: context,
                        firstDate: DateTime(1900),
                        lastDate: now,
                        initialDate: DateTime(now.year - 60),
                      );
                      if (picked != null) setState(() => dob = picked);
                    },
                    child: InputDecorator(
                      decoration: const InputDecoration(
                        labelText: 'Date of Birth *',
                        border: OutlineInputBorder(),
                      ),
                      child: Text(
                        dob == null ? 'Select DOB' : '${dob!.day}/${dob!.month}/${dob!.year}',
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),

                  DropdownButtonFormField<String>(
                    value: gender,
                    decoration: const InputDecoration(
                      labelText: 'Gender (optional)',
                      border: OutlineInputBorder(),
                    ),
                    items: const [
                      DropdownMenuItem(value: 'Male', child: Text('Male')),
                      DropdownMenuItem(value: 'Female', child: Text('Female')),
                      DropdownMenuItem(value: 'Other', child: Text('Other')),
                    ],
                    onChanged: (v) => setState(() => gender = v),
                  ),
                  const SizedBox(height: 12),

                  TextField(
                    controller: phoneCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Phone (optional)',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 12),

                  TextField(
                    controller: addressCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Address (optional)',
                      border: OutlineInputBorder(),
                    ),
                  ),

                  const SizedBox(height: 16),
                  const Align(
                    alignment: Alignment.centerLeft,
                    child: Text('Emergency Contact', style: TextStyle(fontWeight: FontWeight.bold)),
                  ),
                  const SizedBox(height: 8),

                  TextField(
                    controller: ecNameCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Name (optional)',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 12),

                  TextField(
                    controller: ecPhoneCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Phone (optional)',
                      border: OutlineInputBorder(),
                    ),
                  ),

                  const SizedBox(height: 16),
                  const Align(
                    alignment: Alignment.centerLeft,
                    child: Text('Medical Info', style: TextStyle(fontWeight: FontWeight.bold)),
                  ),
                  const SizedBox(height: 8),

                  TextField(
                    controller: conditionsCtrl,
                    maxLines: 2,
                    decoration: const InputDecoration(
                      labelText: 'Medical conditions (e.g., diabetes, dementia)',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 12),

                  TextField(
                    controller: allergiesCtrl,
                    maxLines: 2,
                    decoration: const InputDecoration(
                      labelText: 'Allergies',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 12),

                  TextField(
                    controller: medsCtrl,
                    maxLines: 3,
                    decoration: const InputDecoration(
                      labelText: 'Current medications (name + dose + schedule)',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 12),

                  DropdownButtonFormField<String>(
                    value: mobility,
                    decoration: const InputDecoration(
                      labelText: 'Mobility level',
                      border: OutlineInputBorder(),
                    ),
                    items: const [
                      DropdownMenuItem(value: 'Independent', child: Text('Independent')),
                      DropdownMenuItem(value: 'Needs walker', child: Text('Needs walker')),
                      DropdownMenuItem(value: 'Wheelchair', child: Text('Wheelchair')),
                      DropdownMenuItem(value: 'Bed-bound', child: Text('Bed-bound')),
                    ],
                    onChanged: (v) => setState(() => mobility = v ?? 'Independent'),
                  ),
                  const SizedBox(height: 12),

                  TextField(
                    controller: notesCtrl,
                    maxLines: 2,
                    decoration: const InputDecoration(
                      labelText: 'Notes (optional)',
                      border: OutlineInputBorder(),
                    ),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Cancel'),
              ),
              ElevatedButton(
                onPressed: () {
                  final name = nameCtrl.text.trim();

                  if (name.isEmpty) return;
                  if (dob == null) return;

                  result = SeniorRegistrationData(
                    fullName: name,
                    dob: dob!,
                    gender: gender,
                    phone: phoneCtrl.text.trim().isEmpty ? null : phoneCtrl.text.trim(),
                    address: addressCtrl.text.trim().isEmpty ? null : addressCtrl.text.trim(),
                    emergencyContactName: ecNameCtrl.text.trim().isEmpty ? null : ecNameCtrl.text.trim(),
                    emergencyContactPhone: ecPhoneCtrl.text.trim().isEmpty ? null : ecPhoneCtrl.text.trim(),
                    medicalConditions: conditionsCtrl.text.trim().isEmpty ? null : conditionsCtrl.text.trim(),
                    allergies: allergiesCtrl.text.trim().isEmpty ? null : allergiesCtrl.text.trim(),
                    currentMedications: medsCtrl.text.trim().isEmpty ? null : medsCtrl.text.trim(),
                    mobilityLevel: mobility,
                    notes: notesCtrl.text.trim().isEmpty ? null : notesCtrl.text.trim(),
                  );

                  Navigator.pop(context);
                },
                child: const Text('Save'),
              ),
            ],
          );
        },
      );
    },
  );

  nameCtrl.dispose();
  phoneCtrl.dispose();
  addressCtrl.dispose();
  ecNameCtrl.dispose();
  ecPhoneCtrl.dispose();
  conditionsCtrl.dispose();
  allergiesCtrl.dispose();
  medsCtrl.dispose();
  notesCtrl.dispose();

  return result;
}
