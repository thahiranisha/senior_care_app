import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

/// Senior Login (Email + Password)
///
/// Minimal MVP flow:
/// - Senior authenticates (login or create account).
/// - If users/{uid}.role == 'senior' -> go to /seniorDashboard.
/// - Otherwise -> go to /seniorLinkCode to link using the 6-digit code.
class SeniorLoginScreen extends StatefulWidget {
  const SeniorLoginScreen({super.key});

  @override
  State<SeniorLoginScreen> createState() => _SeniorLoginScreenState();
}

class _SeniorLoginScreenState extends State<SeniorLoginScreen> {
  final _emailController = TextEditingController();
  final _passController = TextEditingController();
  final _formKey = GlobalKey<FormState>();

  bool _isLoading = false;
  String? _errorText;

  @override
  void dispose() {
    _emailController.dispose();
    _passController.dispose();
    super.dispose();
  }

  Future<void> _goAfterSeniorAuth(User user) async {
    final db = FirebaseFirestore.instance;

    final snap = await db.collection('users').doc(user.uid).get();
    final data = snap.data() ?? <String, dynamic>{};
    final role = (data['role'] as String?)?.toLowerCase().trim();
    final seniorId = (data['seniorId'] as String?)?.trim();

    if (role == 'senior' && seniorId != null && seniorId.isNotEmpty) {
      if (!mounted) return;
      Navigator.pushNamedAndRemoveUntil(context, '/seniorDashboard', (_) => false);
      return;
    }

    final q = await db
        .collection('seniors')
        .where('linkedAuthUid', isEqualTo: user.uid)
        .limit(1)
        .get();

    if (q.docs.isNotEmpty) {
      final sid = q.docs.first.id;

      await db.collection('users').doc(user.uid).set({
        'role': 'senior',
        'seniorId': sid,
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      if (!mounted) return;
      Navigator.pushNamedAndRemoveUntil(context, '/seniorDashboard', (_) => false);
      return;
    }

    // Not linked yet
    if (!mounted) return;
    Navigator.pushNamedAndRemoveUntil(context, '/seniorLinkCode', (_) => false);
  }


  Future<void> _login() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isLoading = true;
      _errorText = null;
    });

    try {
      final cred = await FirebaseAuth.instance.signInWithEmailAndPassword(
        email: _emailController.text.trim(),
        password: _passController.text.trim(),
      );

      final user = cred.user;
      if (user == null) throw Exception('Login failed (user is null)');
      await _goAfterSeniorAuth(user);
    } on FirebaseAuthException catch (e) {
      setState(() => _errorText = e.message ?? 'Login failed.');
    } catch (e) {
      setState(() => _errorText = e.toString());
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _createAccount() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isLoading = true;
      _errorText = null;
    });

    try {
      final cred = await FirebaseAuth.instance.createUserWithEmailAndPassword(
        email: _emailController.text.trim(),
        password: _passController.text.trim(),
      );

      final user = cred.user;
      if (user == null) throw Exception('Registration failed (user is null)');

      // Do NOT create users/{uid} here.
      // The user doc is created during link-code step, so we can set role=senior.
      await _goAfterSeniorAuth(user);
    } on FirebaseAuthException catch (e) {
      setState(() => _errorText = e.message ?? 'Registration failed.');
    } catch (e) {
      setState(() => _errorText = e.toString());
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Senior Login'),
      ),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Form(
                key: _formKey,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.elderly, size: 90, color: Colors.teal),
                    const SizedBox(height: 12),
                    const Text(
                      'Sign in as Senior',
                      style: TextStyle(fontSize: 26, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'After signing in, enter your 6-digit code from your guardian.',
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 24),

                    TextFormField(
                      controller: _emailController,
                      keyboardType: TextInputType.emailAddress,
                      style: const TextStyle(fontSize: 20),
                      decoration: const InputDecoration(
                        labelText: 'Email',
                        border: OutlineInputBorder(),
                      ),
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) return 'Email is required';
                        if (!value.contains('@')) return 'Enter a valid email';
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),

                    TextFormField(
                      controller: _passController,
                      obscureText: true,
                      style: const TextStyle(fontSize: 20),
                      decoration: const InputDecoration(
                        labelText: 'Password',
                        border: OutlineInputBorder(),
                      ),
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) return 'Password is required';
                        if (value.length < 6) return 'At least 6 characters';
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),

                    if (_errorText != null) ...[
                      Text(
                        _errorText!,
                        style: const TextStyle(color: Colors.red),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 8),
                    ],

                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: _isLoading ? null : _login,
                        child: _isLoading
                            ? const SizedBox(
                                height: 20,
                                width: 20,
                                child: CircularProgressIndicator(strokeWidth: 2),
                              )
                            : const Text('Login', style: TextStyle(fontSize: 20)),
                      ),
                    ),
                    const SizedBox(height: 10),

                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton(
                        onPressed: _isLoading ? null : _createAccount,
                        child: const Text('Create senior account', style: TextStyle(fontSize: 18)),
                      ),
                    ),

                    const SizedBox(height: 10),
                    TextButton(
                      onPressed: _isLoading ? null : () => Navigator.pop(context),
                      child: const Text('Back'),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
