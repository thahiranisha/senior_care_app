import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';

class CaregiverDocumentsScreen extends StatefulWidget {
  const CaregiverDocumentsScreen({super.key});

  @override
  State<CaregiverDocumentsScreen> createState() => _CaregiverDocumentsScreenState();
}

class _CaregiverDocumentsScreenState extends State<CaregiverDocumentsScreen> {
  bool _loading = true;
  bool _uploading = false;

  Map<String, dynamic> _docs = {};

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
    _docs = (data['documents'] as Map?)?.cast<String, dynamic>() ?? {};

    if (mounted) setState(() => _loading = false);
  }

  Future<void> _pickAndUpload({required String uid, required String docKey}) async {
    final result = await FilePicker.platform.pickFiles(
      withData: true, // gives bytes on web
      type: FileType.custom,
      allowedExtensions: const ['jpg', 'jpeg', 'png', 'pdf'],
    );

    if (result == null || result.files.isEmpty) return;
    final file = result.files.first;

    setState(() => _uploading = true);

    try {
      final ext = (file.extension ?? 'bin').toLowerCase();
      final fileName = '${docKey}_${DateTime.now().millisecondsSinceEpoch}.$ext';

      final ref = FirebaseStorage.instance
          .ref()
          .child('caregiver_docs')
          .child(uid)
          .child(fileName);

      UploadTask task;
      if (kIsWeb) {
        final bytes = file.bytes;
        if (bytes == null) throw Exception('No bytes found for selected file.');
        task = ref.putData(
          bytes,
          SettableMetadata(contentType: _guessContentType(ext)),
        );
      } else {
        final path = file.path;
        if (path == null) throw Exception('No file path found.');
        task = ref.putFile(
          File(path),
          SettableMetadata(contentType: _guessContentType(ext)),
        );
      }

      final snap = await task;
      final url = await snap.ref.getDownloadURL();

      // Save to Firestore
      await FirebaseFirestore.instance.collection('caregivers').doc(uid).set(
        {
          'documents': {
            docKey: url,
            '${docKey}Name': file.name,
            '${docKey}UpdatedAt': FieldValue.serverTimestamp(),
          },
          'updatedAt': FieldValue.serverTimestamp(),
        },
        SetOptions(merge: true),
      );

      // Update local state for immediate UI
      setState(() {
        _docs[docKey] = url;
        _docs['${docKey}Name'] = file.name;
      });

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Uploaded ${_labelFor(docKey)}')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Upload failed: $e')),
      );
    } finally {
      if (mounted) setState(() => _uploading = false);
    }
  }

  String _guessContentType(String ext) {
    switch (ext) {
      case 'jpg':
      case 'jpeg':
        return 'image/jpeg';
      case 'png':
        return 'image/png';
      case 'pdf':
        return 'application/pdf';
      default:
        return 'application/octet-stream';
    }
  }

  String _labelFor(String docKey) {
    switch (docKey) {
      case 'nicFrontUrl':
        return 'NIC (Front)';
      case 'nicBackUrl':
        return 'NIC (Back)';
      case 'policeClearanceUrl':
        return 'Police clearance';
      case 'certificatesUrl':
        return 'Certificates';
      default:
        return docKey;
    }
  }

  Widget _docTile({
    required String uid,
    required String docKey,
    required bool required,
    String? helper,
  }) {
    final url = (_docs[docKey] as String?)?.trim() ?? '';
    final name = (_docs['${docKey}Name'] as String?)?.trim();
    final isSet = url.isNotEmpty;

    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: ListTile(
        leading: Icon(isSet ? Icons.check_circle : Icons.upload_file, color: isSet ? Colors.green : null),
        title: Text(_labelFor(docKey)),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (helper != null) Text(helper),
            if (name != null && name.isNotEmpty) Text('File: $name'),
            if (!isSet && required) const Text('Required', style: TextStyle(color: Colors.orange)),
            if (isSet) Text(url, maxLines: 1, overflow: TextOverflow.ellipsis),
          ],
        ),
        trailing: ElevatedButton(
          onPressed: _uploading ? null : () => _pickAndUpload(uid: uid, docKey: docKey),
          child: Text(isSet ? 'Replace' : 'Upload'),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      return const Scaffold(body: Center(child: Text('Not logged in')));
    }

    if (_loading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    final uid = user.uid;

    final nicFront = (_docs['nicFrontUrl'] as String?)?.trim() ?? '';
    final nicBack = (_docs['nicBackUrl'] as String?)?.trim() ?? '';
    final docsOk = nicFront.isNotEmpty && nicBack.isNotEmpty;

    return Scaffold(
      appBar: AppBar(title: const Text('Verification Documents')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Row(
                children: [
                  Icon(docsOk ? Icons.verified : Icons.info_outline, color: docsOk ? Colors.green : Colors.orange),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      docsOk
                          ? 'Required documents are uploaded.'
                          : 'Upload NIC front & back to submit your profile for verification.',
                    ),
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 10),

          _docTile(
            uid: uid,
            docKey: 'nicFrontUrl',
            required: true,
            helper: 'Photo/scan of NIC (front).',
          ),
          _docTile(
            uid: uid,
            docKey: 'nicBackUrl',
            required: true,
            helper: 'Photo/scan of NIC (back).',
          ),
          _docTile(
            uid: uid,
            docKey: 'policeClearanceUrl',
            required: false,
            helper: 'Optional, but helps speed up verification.',
          ),
          _docTile(
            uid: uid,
            docKey: 'certificatesUrl',
            required: false,
            helper: 'Optional (nursing, first aid, etc.).',
          ),

          const SizedBox(height: 12),

          if (_uploading)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 8),
              child: Center(child: CircularProgressIndicator()),
            ),

          const SizedBox(height: 8),
          OutlinedButton.icon(
            onPressed: () {
              Navigator.pop(context);
            },
            icon: const Icon(Icons.arrow_back),
            label: const Text('Back'),
          ),
        ],
      ),
    );
  }
}
