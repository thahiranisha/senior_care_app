import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import 'caregiver_public_profile_screen.dart';

class CaregiverSearchScreen extends StatefulWidget {
  const CaregiverSearchScreen({super.key});

  @override
  State<CaregiverSearchScreen> createState() => _CaregiverSearchScreenState();
}

class _CaregiverSearchScreenState extends State<CaregiverSearchScreen> {
  final _cities = const ['All', 'Colombo', 'Galle', 'Kandy', 'Jaffna', 'Matara', 'Kurunegala', 'Negombo'];

  String _selectedCity = 'All';
  String _queryText = '';

  bool _loading = true;
  String? _error;
  List<QueryDocumentSnapshot<Map<String, dynamic>>> _docs = [];

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
      final qs = await FirebaseFirestore.instance
          .collection('caregivers')
          .where('status', isEqualTo: 'VERIFIED')
          .where('isActive', isEqualTo: true)
          .limit(50)
          .get();

      setState(() {
        _docs = qs.docs;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
      });
    } finally {
      if (mounted) {
        setState(() {
          _loading = false;
        });
      }
    }
  }

  bool _matchesFilters(Map<String, dynamic> c) {
    final city = (c['city'] as String?)?.trim() ?? '';
    final name = (c['fullName'] as String?)?.trim() ?? '';
    final phone = (c['phone'] as String?)?.trim() ?? '';

    final cityOk = _selectedCity == 'All' || city.toLowerCase() == _selectedCity.toLowerCase();

    final q = _queryText.trim().toLowerCase();
    final queryOk = q.isEmpty ||
        name.toLowerCase().contains(q) ||
        phone.toLowerCase().contains(q) ||
        city.toLowerCase().contains(q);

    return cityOk && queryOk;
  }

  @override
  Widget build(BuildContext context) {
    final filtered = _docs.where((d) => _matchesFilters(d.data())).toList();

    return GestureDetector(
      onTap: () => FocusScope.of(context).unfocus(),
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Find Caregivers'),
          actions: [
            IconButton(
              icon: const Icon(Icons.refresh),
              onPressed: _load,
            ),
          ],
        ),
        body: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
              child: Column(
                children: [
                  TextField(
                    decoration: const InputDecoration(
                      prefixIcon: Icon(Icons.search),
                      hintText: 'Search by name / phone / city',
                      border: OutlineInputBorder(),
                    ),
                    onChanged: (v) => setState(() => _queryText = v),
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      const Text('City:  '),
                      const SizedBox(width: 8),
                      Expanded(
                        child: DropdownButtonFormField<String>(
                          value: _selectedCity,
                          items: _cities.map((c) => DropdownMenuItem(value: c, child: Text(c))).toList(),
                          onChanged: (v) => setState(() => _selectedCity = v ?? 'All'),
                          decoration: const InputDecoration(border: OutlineInputBorder()),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            Expanded(
              child: RefreshIndicator(
                onRefresh: _load,
                child: _loading
                    ? const Center(child: CircularProgressIndicator())
                    : _error != null
                    ? ListView(
                  children: [
                    const SizedBox(height: 80),
                    Center(child: Text('Failed to load caregivers.\n\n$_error')),
                    const SizedBox(height: 12),
                    Center(
                      child: ElevatedButton(
                        onPressed: _load,
                        child: const Text('Retry'),
                      ),
                    ),
                  ],
                )
                    : filtered.isEmpty
                    ? ListView(
                  children: [
                    const SizedBox(height: 120),
                    const Center(child: Text('No caregivers found.')),
                    const SizedBox(height: 10),
                    Center(
                      child: Text(
                        'Try changing city or search keywords.',
                        style: TextStyle(color: Colors.grey.shade700),
                      ),
                    ),
                  ],
                )
                    : ListView.separated(
                  padding: const EdgeInsets.all(16),
                  itemCount: filtered.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 10),
                  itemBuilder: (context, i) {
                    final doc = filtered[i];
                    final c = doc.data();

                    final name = (c['fullName'] as String?) ?? 'Unknown';
                    final city = (c['city'] as String?) ?? '';
                    final phone = (c['phone'] as String?) ?? '';
                    final exp = c['experienceYears'];
                    final rate = c['hourlyRate'];

                    return Card(
                      clipBehavior: Clip.antiAlias,
                      child: InkWell(
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => CaregiverPublicProfileScreen(caregiverId: doc.id),
                            ),
                          );
                        },
                        child: Padding(
                          padding: const EdgeInsets.all(14),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      name,
                                      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                                    ),
                                    const SizedBox(height: 6),
                                    if (city.isNotEmpty) Text('City: $city'),
                                    if (phone.isNotEmpty) Text('Phone: $phone'),
                                    Text('Experience: ${exp ?? '-'} years'),
                                    Text('Hourly rate: ${rate ?? '-'}'),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 8),
                              Icon(Icons.chevron_right, color: Colors.grey.shade700),
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
