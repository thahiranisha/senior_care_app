// lib/guardian/caregiver_public_profile_screen.dart

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

class CaregiverPublicProfileScreen extends StatefulWidget {
  final String caregiverId;
  const CaregiverPublicProfileScreen({super.key, required this.caregiverId});

  @override
  State<CaregiverPublicProfileScreen> createState() => _CaregiverPublicProfileScreenState();
}

class _CaregiverPublicProfileScreenState extends State<CaregiverPublicProfileScreen> {
  bool _loading = true;
  String? _error;
  Map<String, dynamic>? _data;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final snap = await FirebaseFirestore.instance
          .collection('caregivers')
          .doc(widget.caregiverId)
          .get();

      setState(() {
        _data = snap.data();
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
      });
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Caregiver Profile')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
          ? Center(child: Text('Error: $_error'))
          : _data == null
          ? const Center(child: Text('Caregiver not found'))
          : ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    (_data!['fullName'] as String?) ?? 'Unknown',
                    style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  if (((_data!['city'] as String?) ?? '').isNotEmpty)
                    Text('City: ${_data!['city']}'),
                  if (((_data!['phone'] as String?) ?? '').isNotEmpty)
                    Text('Phone: ${_data!['phone']}'),
                  Text('Experience: ${_data!['experienceYears'] ?? '-'} years'),
                  Text('Hourly rate: ${_data!['hourlyRate'] ?? '-'}'),
                  const SizedBox(height: 10),
                  if (((_data!['bio'] as String?) ?? '').trim().isNotEmpty) ...[
                    const Text('Bio', style: TextStyle(fontWeight: FontWeight.bold)),
                    Text((_data!['bio'] as String?) ?? ''),
                  ],
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: () {
                final caregiverName = (_data?['fullName'] as String?) ?? 'Caregiver';

                Navigator.pushNamed(
                  context,
                  '/requestCare',
                  arguments: {
                    'caregiverId': widget.caregiverId,
                    'caregiverName': caregiverName,
                  },
                );
              },
              icon: const Icon(Icons.assignment_outlined),
              label: const Text('Request Care'),
            ),
          ),
        ],
      ),
    );
  }
}
