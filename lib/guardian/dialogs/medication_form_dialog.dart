import 'package:flutter/material.dart';
import '../models/medication.dart';

Future<Map<String, dynamic>?> showMedicationFormDialog(
    BuildContext context, {
      Medication? initial,
    }) async {
  final nameCtrl = TextEditingController(text: initial?.name ?? '');
  final dosageCtrl = TextEditingController(text: initial?.dosage ?? '');
  final routeCtrl = TextEditingController(text: initial?.route ?? '');
  final instructionsCtrl = TextEditingController(text: initial?.instructions ?? '');

  DateTime? startDate = initial?.startDate;
  DateTime? endDate = initial?.endDate;
  bool isActive = initial?.isActive ?? true;

  final times = <String>[...(initial?.times ?? [])];
  times.sort();

  Map<String, dynamic>? result;

  String fmtDate(DateTime d) => '${d.day}/${d.month}/${d.year}';

  String two(int n) => n.toString().padLeft(2, '0');
  String fmtTime(TimeOfDay t) => '${two(t.hour)}:${two(t.minute)}';

  bool isValidTime(String s) => RegExp(r'^\d{2}:\d{2}$').hasMatch(s);

  await showDialog(
    context: context,
    barrierDismissible: false,
    builder: (_) {
      return StatefulBuilder(
        builder: (context, setState) {
          Future<void> pickTime() async {
            final picked = await showTimePicker(
              context: context,
              initialTime: const TimeOfDay(hour: 8, minute: 0),
            );
            if (picked == null) return;
            final v = fmtTime(picked);
            if (!times.contains(v)) {
              setState(() {
                times.add(v);
                times.sort();
              });
            }
          }

          Future<void> pickStart() async {
            final now = DateTime.now();
            final picked = await showDatePicker(
              context: context,
              firstDate: DateTime(1900),
              lastDate: DateTime(now.year + 5),
              initialDate: startDate ?? now,
            );
            if (picked != null) setState(() => startDate = picked);
          }

          Future<void> pickEnd() async {
            final now = DateTime.now();
            final picked = await showDatePicker(
              context: context,
              firstDate: DateTime(1900),
              lastDate: DateTime(now.year + 5),
              initialDate: endDate ?? (startDate ?? now),
            );
            if (picked != null) setState(() => endDate = picked);
          }

          return AlertDialog(
            title: Text(initial == null ? 'Add Medication' : 'Edit Medication'),
            content: SingleChildScrollView(
              child: Column(
                children: [
                  TextField(
                    controller: nameCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Medication name *',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: dosageCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Dosage (e.g., 500mg)',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: routeCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Route (e.g., Oral)',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 12),

                  // Times
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Row(
                      children: [
                        const Text('Times *', style: TextStyle(fontWeight: FontWeight.bold)),
                        const Spacer(),
                        TextButton.icon(
                          onPressed: pickTime,
                          icon: const Icon(Icons.add_alarm),
                          label: const Text('Add time'),
                        ),
                      ],
                    ),
                  ),
                  if (times.isEmpty)
                    const Align(
                      alignment: Alignment.centerLeft,
                      child: Text('Add at least one time (e.g., 08:00).'),
                    )
                  else
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        for (final t in times)
                          Chip(
                            label: Text(t),
                            onDeleted: () => setState(() => times.remove(t)),
                          )
                      ],
                    ),

                  const SizedBox(height: 12),

                  // Dates
                  Row(
                    children: [
                      Expanded(
                        child: InkWell(
                          onTap: pickStart,
                          child: InputDecorator(
                            decoration: const InputDecoration(
                              labelText: 'Start date (optional)',
                              border: OutlineInputBorder(),
                            ),
                            child: Text(startDate == null ? '-' : fmtDate(startDate!)),
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: InkWell(
                          onTap: pickEnd,
                          child: InputDecorator(
                            decoration: const InputDecoration(
                              labelText: 'End date (optional)',
                              border: OutlineInputBorder(),
                            ),
                            child: Text(endDate == null ? '-' : fmtDate(endDate!)),
                          ),
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 12),

                  TextField(
                    controller: instructionsCtrl,
                    maxLines: 2,
                    decoration: const InputDecoration(
                      labelText: 'Instructions (e.g., after meals)',
                      border: OutlineInputBorder(),
                    ),
                  ),

                  const SizedBox(height: 12),

                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Active'),
                    value: isActive,
                    onChanged: (v) => setState(() => isActive = v),
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
                  if (times.isEmpty) return;
                  if (times.any((t) => !isValidTime(t))) return;
                  if (startDate != null && endDate != null && endDate!.isBefore(startDate!)) return;

                  result = {
                    'name': name,
                    'dosage': dosageCtrl.text.trim().isEmpty ? null : dosageCtrl.text.trim(),
                    'route': routeCtrl.text.trim().isEmpty ? null : routeCtrl.text.trim(),
                    'times': times,
                    'instructions': instructionsCtrl.text.trim().isEmpty ? null : instructionsCtrl.text.trim(),
                    'startDate': startDate,
                    'endDate': endDate,
                    'isActive': isActive,
                  };

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
  dosageCtrl.dispose();
  routeCtrl.dispose();
  instructionsCtrl.dispose();

  return result;
}
