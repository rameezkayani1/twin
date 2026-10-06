import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:twin/core/theme.dart';

import 'auth_widgets.dart';
import 'login_page.dart';

// =========================================================
// USER MODEL  (Firestore document: users/{uid})
// =========================================================
class UserModel {
  final String uid;
  final String name;
  final String email;
  final String phone;
  final String role;
  final DateTime? createdAt;

  const UserModel({
    required this.uid,
    required this.name,
    required this.email,
    required this.phone,
    this.role = 'customer',
    this.createdAt,
  });

  /// Firestore -> App
  factory UserModel.fromMap(Map<String, dynamic> map) {
    return UserModel(
      uid: map['uid'] ?? '',
      name: map['name'] ?? '',
      email: map['email'] ?? '',
      phone: map['phone'] ?? '',
      role: map['role'] ?? 'customer',
      createdAt: (map['createdAt'] as Timestamp?)?.toDate(),
    );
  }

  /// App -> Firestore
  Map<String, dynamic> toMap() {
    return {
      'uid': uid,
      'name': name,
      'email': email,
      'phone': phone,
      'role': role,
      'createdAt': FieldValue.serverTimestamp(),
    };
  }
}

// =========================================================
// REGISTER CONTROLLER  (logic only; text controllers live in the page)
// =========================================================
class RegisterController extends GetxController {
  final _auth = FirebaseAuth.instance;
  final _db = FirebaseFirestore.instance;

  final isLoading = false.obs;
  final hidePassword = true.obs;

  // Saves profile in Firestore at users/{uid}, then opens the Login page
  Future<void> register({
    required String name,
    required String email,
    required String phone,
    required String password,
    required String confirm,
  }) async {
    name = name.trim();
    email = email.trim();
    phone = phone.trim();
    password = password.trim();

    // ---------- Validation ----------
    if (name.isEmpty || email.isEmpty || phone.isEmpty || password.isEmpty) {
      return showAuthError('Please fill all fields');
    }
    if (!GetUtils.isEmail(email)) {
      return showAuthError('Please enter a valid email address');
    }
    if (!GetUtils.isPhoneNumber(phone)) {
      return showAuthError('Please enter a valid phone number');
    }
    if (password.length < 6) {
      return showAuthError('Password must be at least 6 characters');
    }
    if (password != confirm.trim()) {
      return showAuthError('Passwords do not match');
    }

    User? user;
    try {
      isLoading.value = true;

      // 1) Create Firebase Auth account
      final credential = await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );
      user = credential.user!;
      await user.updateDisplayName(name);

      // 2) Save profile in Firestore using the UID
      final profile = UserModel(
        uid: user.uid,
        name: name,
        email: email.toLowerCase(),
        phone: phone,
      );
      await _db.collection('users').doc(user.uid).set(profile.toMap());

      // 3) Sign out, then go to Login page
      await _auth.signOut();
      isLoading.value = false;
      Get.offAll(() => const LoginView());
      Get.snackbar('Success', 'Account created! Please log in.');
    } on FirebaseAuthException catch (e) {
      showAuthError(authErrorMessage(e.code));
    } catch (_) {
      // Profile could not be saved -> remove the half-created account
      await user?.delete();
      showAuthError('Could not save your profile. Please try again.');
    } finally {
      isLoading.value = false;
    }
  }
}

// =========================================================
// REGISTER PAGE
// =========================================================
class RegisterView extends StatefulWidget {
  const RegisterView({super.key});

  @override
  State<RegisterView> createState() => _RegisterViewState();
}

class _RegisterViewState extends State<RegisterView> {
  final c = Get.put(RegisterController());

  // The page owns its text controllers and disposes them safely
  final _name = TextEditingController();
  final _email = TextEditingController();
  final _phone = TextEditingController();
  final _password = TextEditingController();
  final _confirm = TextEditingController();

  @override
  void dispose() {
    _name.dispose();
    _email.dispose();
    _phone.dispose();
    _password.dispose();
    _confirm.dispose();
    super.dispose();
  }

  void _submit() => c.register(
    name: _name.text,
    email: _email.text,
    phone: _phone.text,
    password: _password.text,
    confirm: _confirm.text,
  );

  @override
  Widget build(BuildContext context) {
    return AuthLayout(
      title: 'Create account',
      subtitle: 'It only takes a minute',
      child: Obx(
        () => Column(
          children: [
            AuthField(
              controller: _name,
              label: 'Full name',
              icon: Icons.person_outline,
            ),
            const SizedBox(height: 14),

            AuthField(
              controller: _email,
              label: 'Email',
              icon: Icons.mail_outline,
              keyboardType: TextInputType.emailAddress,
            ),
            const SizedBox(height: 14),

            AuthField(
              controller: _phone,
              label: 'Phone',
              icon: Icons.call_outlined,
              keyboardType: TextInputType.phone,
            ),
            const SizedBox(height: 14),

            AuthField(
              controller: _password,
              label: 'Password',
              icon: Icons.lock_outline,
              obscure: c.hidePassword.value,
              suffix: IconButton(
                onPressed: c.hidePassword.toggle,
                icon: Icon(
                  c.hidePassword.value
                      ? Icons.visibility_off_outlined
                      : Icons.visibility_outlined,
                ),
              ),
            ),
            const SizedBox(height: 14),

            AuthField(
              controller: _confirm,
              label: 'Confirm password',
              icon: Icons.lock_reset_outlined,
              obscure: c.hidePassword.value,
              action: TextInputAction.done,
              onSubmit: _submit,
            ),
            const SizedBox(height: 20),

            AuthButton(
              label: 'Create account',
              loading: c.isLoading.value,
              onPressed: _submit,
            ),
            const SizedBox(height: 14),

            Wrap(
              alignment: WrapAlignment.center,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                const Text(
                  'Already have an account?',
                  style: TextStyle(color: Colors.black54),
                ),
                TextButton(
                  onPressed: c.isLoading.value ? null : Get.back,
                  child: const Text(
                    'Log in',
                    style: TextStyle(
                      color: C.orange,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
