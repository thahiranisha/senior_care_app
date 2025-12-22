import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:google_sign_in/google_sign_in.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
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

  // -------------------------------
  // ROUTE AFTER LOGIN (role-based)
  // -------------------------------
  Future<void> _goAfterLogin(User user) async {
    await user.getIdToken(true);

    final snap = await FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .get();

    final data = snap.data() ?? {};
    final role = (data['role'] as String?)?.toLowerCase().trim() ?? '';
    final isAdmin = data['isAdmin'] == true;

    // NOTE: Ensure these routes exist in MaterialApp routes
    final route = isAdmin
        ? '/adminDashboard'
        : role == 'guardian'
        ? '/guardianDashboard'
    // If you don't have this route yet, change to '/home'
        : role == 'caregiver'
        ? '/caregiverDashboard'
        : '/home';

    if (!mounted) return;
    Navigator.pushNamedAndRemoveUntil(context, route, (_) => false);
  }

  // -------------------------------
  // EMAIL/PASSWORD LOGIN
  // -------------------------------
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

      final ok = await _ensureUserProfile(user);
      if (!ok) return;

      await _goAfterLogin(user);
    } on FirebaseAuthException catch (e) {
      setState(() {
        _errorText = e.message ?? 'Login failed. Please try again.';
      });
    } catch (e) {
      setState(() {
        _errorText = e.toString();
      });
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // -------------------------------
  // GOOGLE SIGN-IN (Web + Mobile)
  // -------------------------------
  Future<void> _loginWithGoogle() async {
    setState(() {
      _isLoading = true;
      _errorText = null;
    });

    try {
      UserCredential userCred;

      if (kIsWeb) {
        final provider = GoogleAuthProvider();
        provider.setCustomParameters({'prompt': 'select_account'});
        userCred = await FirebaseAuth.instance.signInWithPopup(provider);
      } else {
        final googleUser = await GoogleSignIn().signIn();
        if (googleUser == null) {
          // user cancelled
          return;
        }

        final googleAuth = await googleUser.authentication;

        final credential = GoogleAuthProvider.credential(
          accessToken: googleAuth.accessToken,
          idToken: googleAuth.idToken,
        );

        userCred = await FirebaseAuth.instance.signInWithCredential(credential);
      }

      final user = userCred.user;
      if (user == null) throw Exception('Google sign-in failed (user is null)');

      final ok = await _ensureUserProfile(user);
      if (!ok) return;

      await _goAfterLogin(user);
    } on FirebaseAuthException catch (e) {
      setState(() {
        _errorText = e.message ?? 'Google sign-in failed.';
      });
    } catch (e) {
      setState(() {
        _errorText = e.toString();
      });
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // -------------------------------
  // Ensure Firestore profile exists + role is set
  // Returns false if user cancels role selection.
  // IMPORTANT: For existing caregiver docs, do NOT update status/isActive/etc (rules block it).
  // -------------------------------
  Future<bool> _ensureUserProfile(User user) async {
    final db = FirebaseFirestore.instance;
    final uid = user.uid;

    final userRef = db.collection('users').doc(uid);

    Future<void> signOutFully() async {
      await FirebaseAuth.instance.signOut();
      if (!kIsWeb) {
        await GoogleSignIn().signOut();
      }
    }

    bool isValidRole(String? r) => r == 'guardian' || r == 'caregiver';

    Future<void> ensureAdminDocIfNeeded({required bool isAdmin}) async {
      if (!isAdmin) return;
      final adminRef = db.collection('admins').doc(uid);
      await adminRef.set({
        'userId': uid,
        'fullName': user.displayName ?? 'Admin',
        'email': user.email ?? '',
        'updatedAt': FieldValue.serverTimestamp(),
        'createdAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    }

    /// Creates role doc if missing.
    /// If role doc exists -> updates ONLY safe fields to avoid permission errors.
    Future<void> ensureRoleDoc(String role) async {
      final roleCollection = role == 'guardian' ? 'guardians' : 'caregivers';
      final roleRef = db.collection(roleCollection).doc(uid);

      final roleSnap = await roleRef.get();
      final data = roleSnap.data() ?? <String, dynamic>{};

      if (!roleSnap.exists) {
        // Create is allowed by your rules
        if (role == 'guardian') {
          await roleRef.set({
            'userId': uid,
            'fullName': user.displayName ?? 'User',
            'email': user.email ?? '',
            'createdAt': FieldValue.serverTimestamp(),
          }, SetOptions(merge: true));
        } else {
          await roleRef.set({
            'userId': uid,
            'fullName': user.displayName ?? 'User',
            'email': user.email ?? '',
            'createdAt': FieldValue.serverTimestamp(),
            'status': 'PENDING_VERIFICATION',
            'statusReason': '',
            'isActive': false,
            'isVerified': false, // compatibility
          }, SetOptions(merge: true));
        }
        return;
      }

      // Existing doc: ONLY safe patch (do NOT touch status/isActive/isVerified/statusReason)
      final patch = <String, dynamic>{
        'userId': uid,
        'fullName': (data['fullName'] as String?)?.trim().isNotEmpty == true
            ? data['fullName']
            : (user.displayName ?? 'User'),
        'email': (data['email'] as String?)?.trim().isNotEmpty == true
            ? data['email']
            : (user.email ?? ''),
        'updatedAt': FieldValue.serverTimestamp(),
      };

      await roleRef.set(patch, SetOptions(merge: true));
    }

    // ------------------------------------------------------------
    // users/{uid} exists -> ensure role + admin doc
    // ------------------------------------------------------------
    final userSnap = await userRef.get();

    if (userSnap.exists) {
      final userData = userSnap.data() ?? <String, dynamic>{};

      final isAdmin = userData['isAdmin'] == true;
      await ensureAdminDocIfNeeded(isAdmin: isAdmin);

      String? role = (userData['role'] as String?)?.toLowerCase().trim();

      // If role missing/invalid, ask now
      if (!isValidRole(role)) {
        role = await _askRoleDialog();
        if (role == null) {
          await signOutFully();
          return false;
        }

        // Update users/{uid} role only (allowed by your rules as owner)
        await userRef.set({
          'role': role,
          'updatedAt': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));
      }

      await ensureRoleDoc(role!);
      return true;
    }

    // ------------------------------------------------------------
    // First-time user -> ask role and create docs
    // ------------------------------------------------------------
    final role = await _askRoleDialog();
    if (role == null) {
      await signOutFully();
      return false;
    }

    // 1) create users/{uid}
    await userRef.set({
      'fullName': user.displayName ?? 'User',
      'email': user.email ?? '',
      'role': role,
      'isAdmin': false,
      'linkedSeniorIds': [],
      'createdAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));

    // 2) create role doc
    await ensureRoleDoc(role);

    return true;
  }

  Future<String?> _askRoleDialog() {
    return showDialog<String>(
      context: context,
      barrierDismissible: false,
      builder: (_) => AlertDialog(
        title: const Text('Select role'),
        content: const Text('Register as:'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, 'guardian'),
            child: const Text('Guardian'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, 'caregiver'),
            child: const Text('Caregiver'),
          ),
        ],
      ),
    );
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
                  const Icon(Icons.elderly, size: 80, color: Colors.teal),
                  const SizedBox(height: 16),
                  const Text(
                    'Senior Care',
                    style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Welcome back! Please sign in.',
                    style: TextStyle(fontSize: 16),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 24),

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
                      if (!value.contains('@')) return 'Enter a valid email';
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),

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
                          : const Text('Login', style: TextStyle(fontSize: 18)),
                    ),
                  ),

                  const SizedBox(height: 12),

                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: _isLoading ? null : _loginWithGoogle,
                      icon: const Icon(Icons.account_circle),
                      label: const Text('Sign in with Google'),
                    ),
                  ),

                  const SizedBox(height: 12),

                  TextButton(
                    onPressed: () =>
                        Navigator.pushReplacementNamed(context, '/register'),
                    child: const Text(
                      "Don't have an account? Register",
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
