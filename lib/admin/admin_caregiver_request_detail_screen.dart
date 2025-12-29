import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

class AdminCaregiverRequestDetailScreen extends StatelessWidget {
  final String caregiverId;
  const AdminCaregiverRequestDetailScreen({super.key, required this.caregiverId});

  Future<String?> _askReason(BuildContext context, String title) async {
    final c = TextEditingController();
    final res = await showDialog<String?>(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(title),
        content: TextField(
          controller: c,
          maxLines: 3,
          decoration: const InputDecoration(hintText: 'Reason (required)'),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, null), child: const Text('Cancel')),
          ElevatedButton(onPressed: () => Navigator.pop(context, c.text.trim()), child: const Text('Submit')),
        ],
      ),
    );
    c.dispose();
    return res;
  }

  bool _looksLikePdf(String url) {
    final u = url.toLowerCase();
    return u.contains('.pdf') || u.contains('application/pdf');
  }

  // Firebase download URLs may not end with .jpg/.png, so keep this lenient.
  bool _looksLikeImage(String url) {
    final u = url.toLowerCase();
    return u.contains('.png') || u.contains('.jpg') || u.contains('.jpeg') || u.contains('.webp') || u.contains('image/');
  }

  Future<void> _openExternal(String url) async {
    final uri = Uri.tryParse(url);
    if (uri == null) return;
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  void _openImageViewer(BuildContext context, {required String title, required String url}) {
    showDialog(
      context: context,
      builder: (_) => Dialog(
        insetPadding: const EdgeInsets.all(12),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            AppBar(
              title: Text(title),
              automaticallyImplyLeading: false,
              actions: [
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
            Flexible(
              child: InteractiveViewer(
                minScale: 1,
                maxScale: 5,
                child: Image.network(
                  url,
                  fit: BoxFit.contain,
                  errorBuilder: (_, __, ___) => Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.broken_image_outlined, size: 40),
                        const SizedBox(height: 8),
                        const Text('Could not load preview.'),
                        const SizedBox(height: 10),
                        OutlinedButton.icon(
                          icon: const Icon(Icons.open_in_new),
                          label: const Text('Open link'),
                          onPressed: () => _openExternal(url),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _docCard(
      BuildContext context, {
        required String title,
        required String? url,
      }) {
    final u = (url ?? '').trim();

    if (u.isEmpty) {
      return Card(
        child: ListTile(
          leading: const Icon(Icons.warning_amber_rounded),
          title: Text(title),
          subtitle: const Text('Missing'),
        ),
      );
    }

    final isPdf = _looksLikePdf(u);
    final isImg = _looksLikeImage(u);

    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () {
          if (isPdf) {
            _openExternal(u);
          } else {
            _openImageViewer(context, title: title, url: u);
          }
        },
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 12, 12, 8),
              child: Row(
                children: [
                  Icon(isPdf ? Icons.picture_as_pdf_outlined : Icons.image_outlined),
                  const SizedBox(width: 8),
                  Expanded(child: Text(title, style: const TextStyle(fontWeight: FontWeight.bold))),
                  const Icon(Icons.open_in_full, size: 18),
                ],
              ),
            ),
            if (!isPdf)
              AspectRatio(
                aspectRatio: 16 / 9,
                child: isImg
                    ? Image.network(
                  u,
                  fit: BoxFit.cover,
                  loadingBuilder: (c, w, p) {
                    if (p == null) return w;
                    return const Center(child: CircularProgressIndicator());
                  },
                  errorBuilder: (_, __, ___) => const Padding(
                    padding: EdgeInsets.all(12),
                    child: Text('Preview not available. Tap to open.'),
                  ),
                )
                    : const Padding(
                  padding: EdgeInsets.all(12),
                  child: Text('Tap to open document'),
                ),
              )
            else
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
                child: Text('Tap to open PDF', style: TextStyle(color: Colors.grey.shade700)),
              ),
          ],
        ),
      ),
    );
  }

  String _prettyKey(String key) {
    // converts "policeClearanceUrl" -> "Police Clearance"
    final s = key.replaceAll('Url', '').replaceAllMapped(
      RegExp(r'([a-z])([A-Z])'),
          (m) => '${m.group(1)} ${m.group(2)}',
    );
    return s[0].toUpperCase() + s.substring(1);
  }

  bool _shouldIgnoreDocKey(String key) {
    final k = key.toLowerCase();
    if (k.contains('urlname')) return true; // remove nicFrontUrlName etc.
    return false;
  }

  @override
  Widget build(BuildContext context) {
    final ref = FirebaseFirestore.instance.collection('caregivers').doc(caregiverId);

    return Scaffold(
      appBar: AppBar(title: const Text('Request Details')),
      body: StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
        stream: ref.snapshots(),
        builder: (context, snap) {
          if (snap.hasError) return Center(child: Text('Error: ${snap.error}'));
          if (!snap.hasData) return const Center(child: CircularProgressIndicator());

          final data = snap.data!.data();
          if (data == null) return const Center(child: Text('Not found'));

          final name = (data['fullName'] as String?) ?? 'Unknown';
          final email = (data['email'] as String?) ?? '';
          final phone = (data['phone'] as String?) ?? '';
          final city = (data['city'] as String?) ?? '';
          final exp = data['experienceYears'];
          final rate = data['hourlyRate'];
          final bio = (data['bio'] as String?) ?? '';
          final status = (data['status'] as String?) ?? '';
          final reason = (data['statusReason'] as String?) ?? '';

          final langs = (data['languages'] as List?)?.cast<dynamic>() ?? const [];
          final specs = (data['specialties'] as List?)?.cast<dynamic>() ?? const [];

          final docs = (data['documents'] as Map?)?.cast<String, dynamic>() ?? {};

          // Known docs
          final nicFront = docs['nicFrontUrl'] as String?;
          final nicBack = docs['nicBackUrl'] as String?;
          final police = docs['policeClearanceUrl'] as String?;

          // Extra docs (any other URL fields except urlName junk + except known keys)
          final knownKeys = {'nicFrontUrl', 'nicBackUrl', 'policeClearanceUrl'};
          final extraDocs = docs.entries
              .where((e) => e.value is String && (e.value as String).trim().isNotEmpty)
              .where((e) => !knownKeys.contains(e.key))
              .where((e) => !_shouldIgnoreDocKey(e.key))
              .where((e) => e.key.toLowerCase().contains('url')) // show only URL-like items
              .toList();

          Future<void> verify() async {
            final adminId = FirebaseAuth.instance.currentUser?.uid;
            if (adminId == null) return;

            await ref.set({
              'status': 'VERIFIED',
              'isVerified': true,
              'isActive': true,
              'statusReason': '',
              'verifiedAt': FieldValue.serverTimestamp(),
              'verifiedBy': adminId,
              'updatedAt': FieldValue.serverTimestamp(),
            }, SetOptions(merge: true));

            if (context.mounted) Navigator.pop(context);
          }

          Future<void> reject() async {
            final adminId = FirebaseAuth.instance.currentUser?.uid;
            if (adminId == null) return;

            final r = await _askReason(context, 'Reject caregiver');
            if (r == null || r.isEmpty) return;

            await ref.set({
              'status': 'REJECTED',
              'isVerified': false,
              'isActive': false,
              'statusReason': r,
              'rejectedAt': FieldValue.serverTimestamp(),
              'rejectedBy': adminId,
              'updatedAt': FieldValue.serverTimestamp(),
            }, SetOptions(merge: true));
          }

          Future<void> block() async {
            final adminId = FirebaseAuth.instance.currentUser?.uid;
            if (adminId == null) return;

            final r = await _askReason(context, 'Block caregiver');
            if (r == null || r.isEmpty) return;

            await ref.set({
              'status': 'BLOCKED',
              'isVerified': false,
              'isActive': false,
              'statusReason': r,
              'blockedAt': FieldValue.serverTimestamp(),
              'blockedBy': adminId,
              'updatedAt': FieldValue.serverTimestamp(),
            }, SetOptions(merge: true));
          }

          Future<void> unblock() async {
            final adminId = FirebaseAuth.instance.currentUser?.uid;
            if (adminId == null) return;

            await ref.set({
              'status': 'PENDING_VERIFICATION',
              'isVerified': false,
              'isActive': false,
              'statusReason': '',
              'unblockedAt': FieldValue.serverTimestamp(),
              'unblockedBy': adminId,
              'updatedAt': FieldValue.serverTimestamp(),
            }, SetOptions(merge: true));
          }

          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(name, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 8),
                      if (email.isNotEmpty) Text('Email: $email'),
                      if (phone.isNotEmpty) Text('Phone: $phone'),
                      if (city.isNotEmpty) Text('City: $city'),
                      Text('Experience: ${exp ?? '-'}'),
                      Text('Hourly rate: ${rate ?? '-'}'),
                      const SizedBox(height: 10),
                      Text('Status: $status', style: const TextStyle(fontWeight: FontWeight.bold)),
                      if (reason.trim().isNotEmpty)
                        Text('Reason: $reason', style: const TextStyle(color: Colors.red)),
                      if (bio.trim().isNotEmpty) ...[
                        const SizedBox(height: 10),
                        const Text('Bio', style: TextStyle(fontWeight: FontWeight.bold)),
                        Text(bio),
                      ],
                      if (langs.isNotEmpty) ...[
                        const SizedBox(height: 10),
                        const Text('Languages', style: TextStyle(fontWeight: FontWeight.bold)),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: [
                            for (final l in langs) Chip(label: Text('$l')),
                          ],
                        ),
                      ],
                      if (specs.isNotEmpty) ...[
                        const SizedBox(height: 10),
                        const Text('Specialties', style: TextStyle(fontWeight: FontWeight.bold)),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: [
                            for (final s in specs) Chip(label: Text('$s')),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 12),
              const Text('Documents', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),

              GridView.count(
                crossAxisCount: 2,
                crossAxisSpacing: 12,
                mainAxisSpacing: 12,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                childAspectRatio: 0.95,
                children: [
                  _docCard(context, title: 'NIC Front', url: nicFront),
                  _docCard(context, title: 'NIC Back', url: nicBack),
                  _docCard(context, title: 'Police Clearance', url: police),
                ],
              ),

              if (extraDocs.isNotEmpty) ...[
                const SizedBox(height: 12),
                const Text('Other Documents', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                for (final e in extraDocs)
                  _docCard(context, title: _prettyKey(e.key), url: e.value as String),
              ],

              const SizedBox(height: 12),
              const Text('Admin Actions', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),

              if (status == 'BLOCKED') ...[
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: unblock,
                    child: const Text('Unblock (move to pending)'),
                  ),
                ),
              ] else ...[
                Row(
                  children: [
                    Expanded(child: ElevatedButton(onPressed: verify, child: const Text('Verify'))),
                    const SizedBox(width: 10),
                    Expanded(child: OutlinedButton(onPressed: reject, child: const Text('Reject'))),
                  ],
                ),
                const SizedBox(height: 10),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    icon: const Icon(Icons.block),
                    onPressed: block,
                    label: const Text('Block'),
                  ),
                ),
              ],
            ],
          );
        },
      ),
    );
  }
}
