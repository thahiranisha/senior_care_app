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
    final snap = await FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .get();

    final role = (snap.data()?['role'] as String?) ?? '';
    final route = role == 'guardian'
        ? '/guardianDashboard'
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
        // WEB: use Firebase popup (do NOT use google_sign_in on web)
        final provider = GoogleAuthProvider();
        provider.setCustomParameters({'prompt': 'select_account'});
        userCred = await FirebaseAuth.instance.signInWithPopup(provider);
      } else {
        // MOBILE: google_sign_in -> Firebase credential
        final googleUser = await GoogleSignIn().signIn();
        if (googleUser == null) return; // user cancelled

        final googleAuth = await googleUser.authentication;

        final credential = GoogleAuthProvider.credential(
          accessToken: googleAuth.accessToken,
          idToken: googleAuth.idToken,
        );

        userCred = await FirebaseAuth.instance.signInWithCredential(credential);
      }

      final user = userCred.user;
      if (user == null) throw Exception('Google sign-in failed (user is null)');

      // Ensure Firestore user docs exist (first time sign-in)
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

  // returns false if user cancels role selection
  Future<bool> _ensureUserProfile(User user) async {
    final db = FirebaseFirestore.instance;
    final uid = user.uid;

    final userRef = db.collection('users').doc(uid);
    final userSnap = await userRef.get();

    Future<void> signOutFully() async {
      await FirebaseAuth.instance.signOut();
      if (!kIsWeb) {
        await GoogleSignIn().signOut();
      }
    }

    bool isValidRole(String? r) => r == 'guardian' || r == 'caregiver';

    // Helper: create/repair role-specific doc and migrate caregiver status
    Future<void> ensureRoleDoc(String role) async {
      final roleCollection = role == 'guardian' ? 'guardians' : 'caregivers';
      final roleRef = db.collection(roleCollection).doc(uid);
      final roleSnap = await roleRef.get();

      if (!roleSnap.exists) {
        // create minimal role doc
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

            'isVerified': false,
          }, SetOptions(merge: true));
        }
        return;
      }

      // If exists, patch missing basics + migrate caregiver statuses
      final data = roleSnap.data() ?? <String, dynamic>{};
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

      if (role == 'caregiver') {
        final rawStatus = (data['status'] as String?)?.toUpperCase().trim() ?? '';
        final oldVerified = (data['isVerified'] as bool?) ?? false;

        String newStatus;
        if (rawStatus == 'BLOCKED') {
          newStatus = 'BLOCKED';
        } else if (rawStatus == 'VERIFIED' || rawStatus == 'APPROVED' || oldVerified) {
          newStatus = 'VERIFIED';
        } else {
          // includes rawStatus == 'PENDING' or unknown/empty
          newStatus = 'PENDING_VERIFICATION';
        }

        patch['status'] = newStatus;

        patch['isVerified'] = (newStatus == 'VERIFIED');

        // If blocked, force not active
        if (newStatus == 'BLOCKED') {
          patch['isActive'] = false;
        } else {
          // ensure field exists (don’t override if already set)
          if (!data.containsKey('isActive')) patch['isActive'] = false;
        }

        // ensure field exists
        if (!data.containsKey('statusReason')) patch['statusReason'] = '';
      }

      await roleRef.set(patch, SetOptions(merge: true));
    }

    // ------------------------------------------------------------
    // CASE 1: users/{uid} already exists
    // ------------------------------------------------------------
    if (userSnap.exists) {
      final userData = userSnap.data() ?? <String, dynamic>{};
      String? role = (userData['role'] as String?)?.toLowerCase().trim();

      // If role missing/invalid, ask now (rare but possible)
      if (!isValidRole(role)) {
        role = await _askRoleDialog();
        if (role == null) {
          await signOutFully();
          return false;
        }

        // patch role into users/{uid} without overwriting existing fields
        await userRef.set({
          'role': role,
          'updatedAt': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));
      }

      // Ensure role-specific doc exists and is migrated/patched
      await ensureRoleDoc(role!);
      return true;
    }

    // ------------------------------------------------------------
    // CASE 2: First time user -> ask role and create docs
    // ------------------------------------------------------------
    final role = await _askRoleDialog();
    if (role == null) {
      await signOutFully();
      return false;
    }

    final batch = db.batch();

    // users/{uid}
    batch.set(userRef, {
      'fullName': user.displayName ?? 'User',
      'email': user.email ?? '',
      'role': role, // guardian / caregiver
      'isAdmin': false,
      'linkedSeniorIds': [],
      'createdAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));

    final roleCollection = role == 'guardian' ? 'guardians' : 'caregivers';
    final roleRef = db.collection(roleCollection).doc(uid);

    if (role == 'guardian') {
      batch.set(roleRef, {
        'userId': uid,
        'fullName': user.displayName ?? 'User',
        'email': user.email ?? '',
        'createdAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    } else {
      batch.set(roleRef, {
        'userId': uid,
        'fullName': user.displayName ?? 'User',
        'email': user.email ?? '',
        'createdAt': FieldValue.serverTimestamp(),

        'status': 'PENDING_VERIFICATION',
        'statusReason': '',
        'isActive': false,

        // keep for backward compatibility
        'isVerified': false,
      }, SetOptions(merge: true));
    }

    await batch.commit();
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
