import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import 'caregiver_public_profile_screen.dart';

class CaregiverSearchScreen extends StatefulWidget {
  final String? seniorId;
  const CaregiverSearchScreen({super.key, this.seniorId});

  @override
  State<CaregiverSearchScreen> createState() => _CaregiverSearchScreenState();
}

class _CaregiverSearchScreenState extends State<CaregiverSearchScreen> {
  final _cities = const [
    'All',
    'Colombo',
    'Galle',
    'Kandy',
    'Jaffna',
    'Matara',
    'Kurunegala',
    'Negombo',
  ];

  String _selectedCity = 'All';
  String _queryText = '';

  final TextEditingController _searchController = TextEditingController();
  Timer? _debounce;

  bool _loading = true;
  String? _error;
  List<QueryDocumentSnapshot<Map<String, dynamic>>> _docs = [];

  // Prevent concurrent loads (web / firestore sdk can crash when hammered)
  Future<void>? _loadFuture;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _load() {
    return _loadFuture ??= _doLoad().whenComplete(() => _loadFuture = null);
  }

  Future<void> _doLoad() async {
    if (!mounted) return;

    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      Query<Map<String, dynamic>> q = FirebaseFirestore.instance
          .collection('caregivers')
          .where('status', isEqualTo: 'VERIFIED')
          .where('isActive', isEqualTo: true);

      // Server-side city filter (reduces downloads)
      if (_selectedCity != 'All') {
        q = q.where('city', isEqualTo: _selectedCity);
      }

      final qs = await q.limit(50).get();

      if (!mounted) return;
      setState(() => _docs = qs.docs);
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = e.toString());
    } finally {
      if (!mounted) return;
      setState(() => _loading = false);
    }
  }

  void _onSearchChanged(String v) {
    // Debounce text search (client-side filter only)
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 250), () {
      if (!mounted) return;
      setState(() => _queryText = v);
    });
  }

  bool _matchesFilters(Map<String, dynamic> c) {
    final city = (c['city'] as String?)?.trim() ?? '';
    final name = (c['fullName'] as String?)?.trim() ?? '';
    final phone = (c['phone'] as String?)?.trim() ?? '';

    // City is already filtered server-side when not All,
    // but keep this as a safe fallback.
    final cityOk = _selectedCity == 'All' ||
        city.toLowerCase() == _selectedCity.toLowerCase();

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
              onPressed: _loading ? null : _load,
              tooltip: 'Refresh',
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
                    controller: _searchController,
                    decoration: const InputDecoration(
                      prefixIcon: Icon(Icons.search),
                      hintText: 'Search by name / phone / city',
                      border: OutlineInputBorder(),
                    ),
                    onChanged: _onSearchChanged,
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      const Text('City:  '),
                      const SizedBox(width: 8),
                      Expanded(
                        child: DropdownButtonFormField<String>(
                          value: _selectedCity,
                          items: _cities
                              .map((c) =>
                              DropdownMenuItem(value: c, child: Text(c)))
                              .toList(),
                          onChanged: (v) {
                            final next = v ?? 'All';
                            if (next == _selectedCity) return;
                            setState(() => _selectedCity = next);
                            _load(); // reload from Firestore with server-side city filter
                          },
                          decoration:
                          const InputDecoration(border: OutlineInputBorder()),
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
                    Center(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        child: Text(
                          'Failed to load caregivers.\n\n$_error',
                          textAlign: TextAlign.center,
                        ),
                      ),
                    ),
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
                  separatorBuilder: (_, __) =>
                  const SizedBox(height: 10),
                  itemBuilder: (context, i) {
                    final doc = filtered[i];
                    final c = doc.data();

                    final name =
                        (c['fullName'] as String?) ?? 'Unknown';
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
                              builder: (_) => CaregiverPublicProfileScreen(
                                caregiverId: doc.id,
                                seniorId: widget.seniorId,
                              ),
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
                                  crossAxisAlignment:
                                  CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      name,
                                      style: const TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.bold,
                                      ),
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
                              Icon(Icons.chevron_right,
                                  color: Colors.grey.shade700),
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
