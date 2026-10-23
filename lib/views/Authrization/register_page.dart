import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:twin/core/theme.dart';

import 'auth_widgets.dart';
import 'login_page.dart';

// ── Design tokens (same as SplashLogin / LoginView) ─────────────────────────
const _orange = Color(0xFFFF7A00);
const _navy = Color(0xFF1B1464);
const _peach = Color(0xFFFFE3C7);
const _cream = Color(0xFFFFF7EE);
const _logoAsset = 'assets/logo.jpeg';

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
// REGISTER CONTROLLER  (logic unchanged)
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

  // ── Build ─────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: _peach,
    resizeToAvoidBottomInset: true,
    body: Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [_cream, _peach],
        ),
      ),
      child: SafeArea(
        child: LayoutBuilder(
          builder: (context, box) =>
              box.maxWidth >= 720 ? _wide(box) : _narrow(box),
        ),
      ),
    ),
  );

  /// Phones: hero on top, orange sheet at the bottom.
  Widget _narrow(BoxConstraints box) => Column(
    children: [
      Expanded(child: _hero()),
      Align(
        alignment: Alignment.bottomCenter,
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxWidth: 520,
            maxHeight: box.maxHeight * 0.85,
          ),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
            child: _panel(),
          ),
        ),
      ),
    ],
  );

  /// Tablets / web: framed card, hero left, panel right.
  Widget _wide(BoxConstraints box) {
    final h = (box.maxHeight - 48).clamp(560.0, 760.0);
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Container(
          width: box.maxWidth.clamp(0.0, 1040.0) - 48,
          height: h,
          clipBehavior: Clip.antiAlias,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(40),
            boxShadow: const [
              BoxShadow(
                color: Color(0x33FF7A00),
                blurRadius: 40,
                offset: Offset(0, 20),
              ),
            ],
          ),
          child: Row(
            children: [
              Expanded(child: _hero()),
              SizedBox(
                width: 440,
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Align(alignment: Alignment.center, child: _panel()),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ── Hero (brand + back + illustration) ────────────────────────────────────
  Widget _hero() => Stack(
    children: [
      const Positioned.fill(child: CustomPaint(painter: _DotsPainter())),
      const Positioned.fill(top: 64, child: _FallbackHero()),
      Positioned(
        left: 12,
        top: 16,
        child: Row(
          children: [
            if (Navigator.of(context).canPop())
              IconButton(
                onPressed: Get.back,
                icon: const Icon(Icons.arrow_back_ios_new_rounded),
                color: _navy,
                iconSize: 20,
              )
            else
              const SizedBox(width: 8),
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: _orange,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Image.asset(
                _logoAsset,
                fit: BoxFit.contain,
                errorBuilder: (c, e, s) =>
                    const Icon(Icons.handyman, color: Colors.black, size: 24),
              ),
            ),
            const SizedBox(width: 10),
            const Text(
              'Twins Handyman llc',
              style: TextStyle(
                color: _navy,
                fontWeight: FontWeight.w800,
                fontSize: 17,
              ),
            ),
          ],
        ),
      ),
    ],
  );

  // ── Orange form panel ─────────────────────────────────────────────────────
  Widget _panel() => Container(
    width: double.infinity,
    decoration: BoxDecoration(
      color: _orange,
      borderRadius: BorderRadius.circular(40),
      boxShadow: const [
        BoxShadow(
          color: Color(0x40FF7A00),
          blurRadius: 24,
          offset: Offset(0, 10),
        ),
      ],
    ),
    child: SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(24, 28, 24, 20),
      child: Obx(
        () => Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Create account',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w800,
                fontSize: 24,
              ),
            ),
            const SizedBox(height: 4),
            const Text(
              'It only takes a minute',
              style: TextStyle(color: Color(0xE6FFFFFF), fontSize: 13),
            ),
            const SizedBox(height: 22),

            _PillField(
              controller: _name,
              hint: 'Full name',
              icon: Icons.person_outline,
              keyboardType: TextInputType.name,
              action: TextInputAction.next,
            ),
            const SizedBox(height: 12),

            _PillField(
              controller: _email,
              hint: 'Email',
              icon: Icons.mail_outline,
              keyboardType: TextInputType.emailAddress,
              action: TextInputAction.next,
            ),
            const SizedBox(height: 12),

            _PillField(
              controller: _phone,
              hint: 'Phone',
              icon: Icons.call_outlined,
              keyboardType: TextInputType.phone,
              action: TextInputAction.next,
            ),
            const SizedBox(height: 12),

            _PillField(
              controller: _password,
              hint: 'Password',
              icon: Icons.lock_outline,
              obscure: c.hidePassword.value,
              action: TextInputAction.next,
              suffix: IconButton(
                onPressed: c.hidePassword.toggle,
                icon: Icon(
                  c.hidePassword.value
                      ? Icons.visibility_off_outlined
                      : Icons.visibility_outlined,
                  color: Colors.black45,
                ),
              ),
            ),
            const SizedBox(height: 12),

            _PillField(
              controller: _confirm,
              hint: 'Confirm password',
              icon: Icons.lock_reset_outlined,
              obscure: c.hidePassword.value,
              action: TextInputAction.done,
              onSubmit: _submit,
            ),
            const SizedBox(height: 20),

            // Create account button (navy pill)
            SizedBox(
              width: double.infinity,
              height: 54,
              child: ElevatedButton(
                onPressed: c.isLoading.value ? null : _submit,
                style: ElevatedButton.styleFrom(
                  backgroundColor: _navy,
                  foregroundColor: Colors.white,
                  disabledBackgroundColor: const Color(0x991B1464),
                  elevation: 0,
                  shape: const StadiumBorder(),
                  textStyle: const TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 16,
                  ),
                ),
                child: c.isLoading.value
                    ? const SizedBox(
                        width: 22,
                        height: 22,
                        child: CircularProgressIndicator(
                          strokeWidth: 2.5,
                          color: Colors.white,
                        ),
                      )
                    : const Text('Create account'),
              ),
            ),

            const SizedBox(height: 14),
            GestureDetector(
              onTap: c.isLoading.value ? null : Get.back,
              behavior: HitTestBehavior.opaque,
              child: const Padding(
                padding: EdgeInsets.symmetric(vertical: 8),
                child: Text.rich(
                  TextSpan(
                    style: TextStyle(color: Color(0xE6FFFFFF), fontSize: 13),
                    children: [
                      TextSpan(text: 'Already have an account? '),
                      TextSpan(
                        text: 'LOG IN',
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

// =========================================================
// White pill text field (sits on the orange panel)
// =========================================================
class _PillField extends StatelessWidget {
  const _PillField({
    required this.controller,
    required this.hint,
    required this.icon,
    this.obscure = false,
    this.suffix,
    this.keyboardType,
    this.action,
    this.onSubmit,
  });

  final TextEditingController controller;
  final String hint;
  final IconData icon;
  final bool obscure;
  final Widget? suffix;
  final TextInputType? keyboardType;
  final TextInputAction? action;
  final VoidCallback? onSubmit;

  @override
  Widget build(BuildContext context) => SizedBox(
    height: 54,
    child: TextField(
      controller: controller,
      obscureText: obscure,
      keyboardType: keyboardType,
      textInputAction: action,
      onSubmitted: onSubmit == null ? null : (_) => onSubmit!(),
      style: const TextStyle(
        color: _navy,
        fontWeight: FontWeight.w600,
        fontSize: 16,
      ),
      cursorColor: _orange,
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: const TextStyle(color: Colors.black38),
        prefixIcon: Icon(icon, color: _navy),
        suffixIcon: suffix,
        filled: true,
        fillColor: Colors.white,
        contentPadding: const EdgeInsets.symmetric(horizontal: 20),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(40),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(40),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(40),
          borderSide: const BorderSide(color: _navy, width: 2),
        ),
      ),
    ),
  );
}

// ── Decorative dot grid ─────────────────────────────────────────────────────
class _DotsPainter extends CustomPainter {
  const _DotsPainter();
  @override
  void paint(Canvas canvas, Size size) {
    final p = Paint()..color = const Color(0x40FF7A00);
    const gap = 9.0;
    final left = size.width * 0.12;
    final top = size.height * 0.28;
    for (var r = 0; r < 9; r++) {
      for (var c = 0; c < 9; c++) {
        canvas.drawCircle(Offset(left + c * gap, top + r * gap), 1.2, p);
      }
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter old) => false;
}

// ── Hero illustration ───────────────────────────────────────────────────────
class _FallbackHero extends StatelessWidget {
  const _FallbackHero();

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, box) {
      final s = (box.biggest.shortestSide * 0.8).clamp(0.0, 420.0);
      if (s < 90) return const SizedBox.shrink(); // small space: hide hero
      Widget chip(IconData i, Alignment a, Color bg) => Align(
        alignment: a,
        child: Container(
          width: s * 0.2,
          height: s * 0.2,
          decoration: BoxDecoration(
            color: bg,
            shape: BoxShape.circle,
            boxShadow: const [
              BoxShadow(
                color: Color(0x22000000),
                blurRadius: 10,
                offset: Offset(0, 4),
              ),
            ],
          ),
          child: Icon(i, color: Colors.white, size: s * 0.1),
        ),
      );
      return Center(
        child: SizedBox(
          width: s,
          height: s,
          child: Stack(
            children: [
              Center(
                child: Container(
                  width: s * 0.78,
                  height: s * 0.78,
                  decoration: const BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [Color(0xFFFFC27A), _orange],
                    ),
                  ),
                  child: Icon(
                    Icons.person_add_alt_1,
                    size: s * 0.42,
                    color: Colors.white,
                  ),
                ),
              ),
              chip(Icons.hardware, Alignment.topLeft, _navy),
              chip(Icons.plumbing, Alignment.topRight, _orange),
              chip(Icons.format_paint, Alignment.bottomLeft, _orange),
              chip(Icons.electrical_services, Alignment.bottomRight, _navy),
            ],
          ),
        ),
      );
    },
  );
}

// import 'package:flutter/material.dart';
// import 'package:get/get.dart';
// import 'package:firebase_auth/firebase_auth.dart';
// import 'package:cloud_firestore/cloud_firestore.dart';
// import 'package:twin/core/theme.dart';

// import 'auth_widgets.dart';
// import 'login_page.dart';

// // =========================================================
// // USER MODEL  (Firestore document: users/{uid})
// // =========================================================
// class UserModel {
//   final String uid;
//   final String name;
//   final String email;
//   final String phone;
//   final String role;
//   final DateTime? createdAt;

//   const UserModel({
//     required this.uid,
//     required this.name,
//     required this.email,
//     required this.phone,
//     this.role = 'customer',
//     this.createdAt,
//   });

//   /// Firestore -> App
//   factory UserModel.fromMap(Map<String, dynamic> map) {
//     return UserModel(
//       uid: map['uid'] ?? '',
//       name: map['name'] ?? '',
//       email: map['email'] ?? '',
//       phone: map['phone'] ?? '',
//       role: map['role'] ?? 'customer',
//       createdAt: (map['createdAt'] as Timestamp?)?.toDate(),
//     );
//   }

//   /// App -> Firestore
//   Map<String, dynamic> toMap() {
//     return {
//       'uid': uid,
//       'name': name,
//       'email': email,
//       'phone': phone,
//       'role': role,
//       'createdAt': FieldValue.serverTimestamp(),
//     };
//   }
// }

// // =========================================================
// // REGISTER CONTROLLER  (logic only; text controllers live in the page)
// // =========================================================
// class RegisterController extends GetxController {
//   final _auth = FirebaseAuth.instance;
//   final _db = FirebaseFirestore.instance;

//   final isLoading = false.obs;
//   final hidePassword = true.obs;

//   // Saves profile in Firestore at users/{uid}, then opens the Login page
//   Future<void> register({
//     required String name,
//     required String email,
//     required String phone,
//     required String password,
//     required String confirm,
//   }) async {
//     name = name.trim();
//     email = email.trim();
//     phone = phone.trim();
//     password = password.trim();

//     // ---------- Validation ----------
//     if (name.isEmpty || email.isEmpty || phone.isEmpty || password.isEmpty) {
//       return showAuthError('Please fill all fields');
//     }
//     if (!GetUtils.isEmail(email)) {
//       return showAuthError('Please enter a valid email address');
//     }
//     if (!GetUtils.isPhoneNumber(phone)) {
//       return showAuthError('Please enter a valid phone number');
//     }
//     if (password.length < 6) {
//       return showAuthError('Password must be at least 6 characters');
//     }
//     if (password != confirm.trim()) {
//       return showAuthError('Passwords do not match');
//     }

//     User? user;
//     try {
//       isLoading.value = true;

//       // 1) Create Firebase Auth account
//       final credential = await _auth.createUserWithEmailAndPassword(
//         email: email,
//         password: password,
//       );
//       user = credential.user!;
//       await user.updateDisplayName(name);

//       // 2) Save profile in Firestore using the UID
//       final profile = UserModel(
//         uid: user.uid,
//         name: name,
//         email: email.toLowerCase(),
//         phone: phone,
//       );
//       await _db.collection('users').doc(user.uid).set(profile.toMap());

//       // 3) Sign out, then go to Login page
//       await _auth.signOut();
//       isLoading.value = false;
//       Get.offAll(() => const LoginView());
//       Get.snackbar('Success', 'Account created! Please log in.');
//     } on FirebaseAuthException catch (e) {
//       showAuthError(authErrorMessage(e.code));
//     } catch (_) {
//       // Profile could not be saved -> remove the half-created account
//       await user?.delete();
//       showAuthError('Could not save your profile. Please try again.');
//     } finally {
//       isLoading.value = false;
//     }
//   }
// }

// // =========================================================
// // REGISTER PAGE
// // =========================================================
// class RegisterView extends StatefulWidget {
//   const RegisterView({super.key});

//   @override
//   State<RegisterView> createState() => _RegisterViewState();
// }

// class _RegisterViewState extends State<RegisterView> {
//   final c = Get.put(RegisterController());

//   // The page owns its text controllers and disposes them safely
//   final _name = TextEditingController();
//   final _email = TextEditingController();
//   final _phone = TextEditingController();
//   final _password = TextEditingController();
//   final _confirm = TextEditingController();

//   @override
//   void dispose() {
//     _name.dispose();
//     _email.dispose();
//     _phone.dispose();
//     _password.dispose();
//     _confirm.dispose();
//     super.dispose();
//   }

//   void _submit() => c.register(
//     name: _name.text,
//     email: _email.text,
//     phone: _phone.text,
//     password: _password.text,
//     confirm: _confirm.text,
//   );

//   @override
//   Widget build(BuildContext context) {
//     return AuthLayout(
//       title: 'Create account',
//       subtitle: 'It only takes a minute',
//       child: Obx(
//         () => Column(
//           children: [
//             AuthField(
//               controller: _name,
//               label: 'Full name',
//               icon: Icons.person_outline,
//             ),
//             const SizedBox(height: 14),

//             AuthField(
//               controller: _email,
//               label: 'Email',
//               icon: Icons.mail_outline,
//               keyboardType: TextInputType.emailAddress,
//             ),
//             const SizedBox(height: 14),

//             AuthField(
//               controller: _phone,
//               label: 'Phone',
//               icon: Icons.call_outlined,
//               keyboardType: TextInputType.phone,
//             ),
//             const SizedBox(height: 14),

//             AuthField(
//               controller: _password,
//               label: 'Password',
//               icon: Icons.lock_outline,
//               obscure: c.hidePassword.value,
//               suffix: IconButton(
//                 onPressed: c.hidePassword.toggle,
//                 icon: Icon(
//                   c.hidePassword.value
//                       ? Icons.visibility_off_outlined
//                       : Icons.visibility_outlined,
//                 ),
//               ),
//             ),
//             const SizedBox(height: 14),

//             AuthField(
//               controller: _confirm,
//               label: 'Confirm password',
//               icon: Icons.lock_reset_outlined,
//               obscure: c.hidePassword.value,
//               action: TextInputAction.done,
//               onSubmit: _submit,
//             ),
//             const SizedBox(height: 20),

//             AuthButton(
//               label: 'Create account',
//               loading: c.isLoading.value,
//               onPressed: _submit,
//             ),
//             const SizedBox(height: 14),

//             Wrap(
//               alignment: WrapAlignment.center,
//               crossAxisAlignment: WrapCrossAlignment.center,
//               children: [
//                 const Text(
//                   'Already have an account?',
//                   style: TextStyle(color: Colors.black54),
//                 ),
//                 TextButton(
//                   onPressed: c.isLoading.value ? null : Get.back,
//                   child: const Text(
//                     'Log in',
//                     style: TextStyle(
//                       color: C.orange,
//                       fontWeight: FontWeight.w800,
//                     ),
//                   ),
//                 ),
//               ],
//             ),
//           ],
//         ),
//       ),
//     );
//   }
// }
