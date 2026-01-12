import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';

/// Senior Link Code Screen
///
/// Flow:
/// 1) Senior signs in (email/password).
/// 2) Senior enters 6-digit link code received from guardian.
/// 3) We atomically link:
///    - seniors/{seniorId} -> linkedAuthUid, linked=true
///    - link_codes/{code} -> used=true, usedByUid
///    - users/{uid} -> role=senior, seniorId
class SeniorLinkCodeScreen extends StatefulWidget {
  const SeniorLinkCodeScreen({super.key});

  @override
  State<SeniorLinkCodeScreen> createState() => _SeniorLinkCodeScreenState();
}

class _SeniorLinkCodeScreenState extends State<SeniorLinkCodeScreen> {
  final _codeCtrl = TextEditingController();
  bool _loading = false;
  String? _error;

  @override
  void dispose() {
    _codeCtrl.dispose();
    super.dispose();
  }

  Future<void> _logout() async {
    await FirebaseAuth.instance.signOut();
    if (!mounted) return;
    Navigator.pushNamedAndRemoveUntil(context, '/login', (_) => false);
  }
  Future<void> _recoverIfAlreadyLinked() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    final db = FirebaseFirestore.instance;

    final q = await db
        .collection('seniors')
        .where('linkedAuthUid', isEqualTo: user.uid)
        .limit(1)
        .get();

    if (q.docs.isEmpty) return;

    final sid = q.docs.first.id;

    await db.collection('users').doc(user.uid).set({
      'role': 'senior',
      'seniorId': sid,
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));

    if (!mounted) return;
    Navigator.pushNamedAndRemoveUntil(context, '/seniorDashboard', (_) => false);
  }

  Future<void> _linkNow() async {
    final code = _codeCtrl.text.trim();
    if (code.isEmpty) {
      setState(() => _error = 'Please enter the 6-digit code');
      return;
    }

    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      setState(() => _error = 'Not logged in. Please login again.');
      return;
    }

    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final db = FirebaseFirestore.instance;
      final uid = user.uid;

      // Optional: if the user profile already exists with a non-senior role, block linking.
      final existingUserSnap = await db.collection('users').doc(uid).get();
      if (existingUserSnap.exists) {
        final role = (existingUserSnap.data()?['role'] as String?)?.toLowerCase().trim();
        if (role == 'guardian' || role == 'caregiver' || role == 'admin') {
          throw Exception('This account is already a $role account. Please use a senior account.');
        }
      }

      final codeRef = db.collection('link_codes').doc(code);
      final codeSnap = await codeRef.get();

      if (!codeSnap.exists) throw Exception('Invalid code');
      final c = codeSnap.data()!;
      if (c['used'] == true) throw Exception('Code already used');

      final seniorId = (c['seniorId'] as String?)?.trim();
      if (seniorId == null || seniorId.isEmpty) throw Exception('Invalid code data');

      final seniorRef = db.collection('seniors').doc(seniorId);

      await db.runTransaction((tx) async {
        // IMPORTANT:
        // Do NOT tx.get(seniorRef) here. Seniors are not allowed to read senior docs before linking.
        // Security rules will still validate the update against existing resource.data.

        tx.update(seniorRef, {
          'linkedAuthUid': uid,
          'linked': true,
          'linkedAt': FieldValue.serverTimestamp(),
        });

        // Mark link code as used
        tx.update(codeRef, {
          'used': true,
          'usedByUid': uid,
          'usedAt': FieldValue.serverTimestamp(),
        });

        // Create/update users profile as senior
        tx.set(
          db.collection('users').doc(uid),
          {
            'role': 'senior',
            'seniorId': seniorId,
            'updatedAt': FieldValue.serverTimestamp(),
            'createdAt': FieldValue.serverTimestamp(),
          },
          SetOptions(merge: true),
        );
      });

      if (!mounted) return;
      Navigator.pushNamedAndRemoveUntil(context, '/seniorDashboard', (_) => false);
    } catch (e, st) {
      debugPrint('Senior link failed: $e');
      debugPrint(st.toString());

      String msg;

      if (e is FirebaseException) {
        msg = '${e.code}: ${e.message ?? ''}'.trim();
      } else {
        msg = e.toString().replaceFirst('Exception: ', '');
      }
      if (msg.toLowerCase().contains('already used')) {
        await _recoverIfAlreadyLinked();
      }

      setState(() => _error = msg);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Link Code'),
        actions: [
          IconButton(
            tooltip: 'Logout',
            onPressed: _loading ? null : _logout,
            icon: const Icon(Icons.logout),
          ),
        ],
      ),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.key, size: 90, color: Colors.teal),
                  const SizedBox(height: 12),
                  const Text(
                    'Enter your 6-digit code',
                    style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Ask your guardian for the link code.',
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 24),
                  TextField(
                    controller: _codeCtrl,
                    keyboardType: TextInputType.number,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 30,
                      letterSpacing: 4,
                      fontWeight: FontWeight.bold,
                    ),
                    decoration: const InputDecoration(
                      labelText: 'Code',
                      border: OutlineInputBorder(),
                      hintText: '123456',
                    ),
                  ),
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    height: 52,
                    child: ElevatedButton(
                      onPressed: _loading ? null : _linkNow,
                      child: _loading
                          ? const SizedBox(
                              height: 22,
                              width: 22,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Text('Link & Continue', style: TextStyle(fontSize: 20)),
                    ),
                  ),
                  if (_error != null) ...[
                    const SizedBox(height: 14),
                    Text(
                      _error!,
                      style: const TextStyle(color: Colors.red),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
