import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

class RegisterPage extends StatefulWidget {
  const RegisterPage({super.key});

  @override
  State<RegisterPage> createState() => _RegisterPageState();
}

class _RegisterPageState extends State<RegisterPage> {
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passController = TextEditingController();
  final _confirmController = TextEditingController();
  final _formKey = GlobalKey<FormState>();

  bool _isLoading = false;
  String? _errorText;

  // Only two roles are user-facing at registration
  final List<String> _roles = ['guardian', 'caregiver'];
  String? _selectedRole;

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _passController.dispose();
    _confirmController.dispose();
    super.dispose();
  }

  Future<void> _register() async {
    if (!_formKey.currentState!.validate()) return;

    if (_selectedRole == null) {
      setState(() => _errorText = 'Please select your role.');
      return;
    }

    setState(() {
      _isLoading = true;
      _errorText = null;
    });

    try {
      // 1) Create Firebase Auth user
      final userCred = await FirebaseAuth.instance.createUserWithEmailAndPassword(
        email: _emailController.text.trim(),
        password: _passController.text.trim(),
      );

      final user = userCred.user;
      if (user == null) throw Exception('User is null after registration');

      final uid = user.uid;
      final role = _selectedRole!; // guardian / caregiver
      final db = FirebaseFirestore.instance;

      // 2) References
      final userRef = db.collection('users').doc(uid);
      final roleRef = db.collection(role == 'guardian' ? 'guardians' : 'caregivers').doc(uid);

      // 3) Batch write (atomic)
      final batch = db.batch();

      // users/{uid} (master user profile)
      batch.set(userRef, {
        'fullName': _nameController.text.trim(),
        'email': _emailController.text.trim(),
        'role': role,
        'isAdmin': false,
        'createdAt': FieldValue.serverTimestamp(),

        // guardian-only field (safe to keep for all users too)
        'linkedSeniorIds': role == 'guardian' ? [] : [],
      });

      // role doc
      if (role == 'guardian') {
        batch.set(roleRef, {
          'userId': uid,
          'fullName': _nameController.text.trim(),
          'email': _emailController.text.trim(),
          'createdAt': FieldValue.serverTimestamp(),
          // optional guardian fields later: phone, address, etc.
        });
      }

      if (role == 'caregiver') {
        batch.set(roleRef, {
          'userId': uid,
          'fullName': _nameController.text.trim(),
          'email': _emailController.text.trim(),
          'createdAt': FieldValue.serverTimestamp(),

          // Verification workflow fields
          'status': 'PENDING',      // PENDING / SUBMITTED / APPROVED / REJECTED
          'isVerified': false,
          'isActive': false,
        });
      }

      await batch.commit();

      // 4) Go to home
      if (mounted) {
        Navigator.pushNamedAndRemoveUntil(context, '/home', (route) => false);
      }
    } on FirebaseAuthException catch (e) {
      setState(() {
        _errorText = e.message ?? 'Registration failed. Please try again.';
      });
    } catch (e, st) {
      debugPrint('REGISTER ERROR: $e');
      debugPrintStack(stackTrace: st);

      setState(() {
        _errorText = e.toString(); // temporarily show the exact error
      });
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }


  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Form(
              key: _formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.health_and_safety,
                      size: 80, color: Colors.teal),
                  const SizedBox(height: 16),
                  const Text(
                    'Create Account',
                    style: TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Sign up as a Guardian or Caregiver.',
                    style: TextStyle(fontSize: 16),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 24),

                  // Full name
                  TextFormField(
                    controller: _nameController,
                    style: const TextStyle(fontSize: 18),
                    decoration: const InputDecoration(
                      labelText: 'Full name',
                      border: OutlineInputBorder(),
                    ),
                    validator: (value) {
                      if (value == null || value.trim().isEmpty) {
                        return 'Name is required';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),

                  // Email
                  TextFormField(
                    controller: _emailController,
                    keyboardType: TextInputType.emailAddress,
                    style: const TextStyle(fontSize: 18),
                    decoration: const InputDecoration(
                      labelText: 'Email',
                      border: OutlineInputBorder(),
                    ),
                    validator: (value) {
                      if (value == null || value.trim().isEmpty) {
                        return 'Email is required';
                      }
                      if (!value.contains('@')) {
                        return 'Enter a valid email';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),

                  // Role selection (guardian / caregiver)
                  DropdownButtonFormField<String>(
                    value: _selectedRole,
                    decoration: const InputDecoration(
                      labelText: 'Register as',
                      border: OutlineInputBorder(),
                    ),
                    items: _roles
                        .map(
                          (r) => DropdownMenuItem(
                        value: r,
                        child: Text(
                          r[0].toUpperCase() + r.substring(1),
                          style: const TextStyle(fontSize: 18),
                        ),
                      ),
                    )
                        .toList(),
                    onChanged: (value) {
                      setState(() {
                        _selectedRole = value;
                      });
                    },
                    validator: (value) {
                      if (value == null) {
                        return 'Please choose a role';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),

                  // Password
                  TextFormField(
                    controller: _passController,
                    obscureText: true,
                    style: const TextStyle(fontSize: 18),
                    decoration: const InputDecoration(
                      labelText: 'Password',
                      border: OutlineInputBorder(),
                    ),
                    validator: (value) {
                      if (value == null || value.trim().isEmpty) {
                        return 'Password is required';
                      }
                      if (value.length < 6) {
                        return 'At least 6 characters';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),

                  // Confirm password
                  TextFormField(
                    controller: _confirmController,
                    obscureText: true,
                    style: const TextStyle(fontSize: 18),
                    decoration: const InputDecoration(
                      labelText: 'Confirm Password',
                      border: OutlineInputBorder(),
                    ),
                    validator: (value) {
                      if (value == null || value.trim().isEmpty) {
                        return 'Confirm your password';
                      }
                      if (value != _passController.text) {
                        return 'Passwords do not match';
                      }
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
                      onPressed: _isLoading ? null : _register,
                      child: _isLoading
                          ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                          : const Text(
                        'Register',
                        style: TextStyle(fontSize: 18),
                      ),
                    ),
                  ),

                  const SizedBox(height: 12),

                  TextButton(
                    onPressed: () {
                      Navigator.pushReplacementNamed(context, '/login');
                    },
                    child: const Text(
                      "Already have an account? Login",
                      style: TextStyle(fontSize: 16),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
