// import 'package:flutter/material.dart';
// import 'package:get/get.dart';
// import 'package:firebase_auth/firebase_auth.dart';
// import 'package:twin/core/theme.dart';
// import 'package:twin/views/shell_view.dart';

// import 'auth_widgets.dart';
// import 'register_page.dart';

// // =========================================================
// // LOGIN CONTROLLER  (logic only; text controllers live in the page)
// // =========================================================
// class LoginController extends GetxController {
//   final _auth = FirebaseAuth.instance;

//   final isLoading = false.obs;
//   final hidePassword = true.obs;

//   // ---------- Login ----------
//   Future<bool> login(String email, String password) async {
//     try {
//       await FirebaseAuth.instance.signInWithEmailAndPassword(
//         email: email,
//         password: password,
//       );

//       return true;
//     } on FirebaseAuthException catch (e) {
//       Get.snackbar('Login Failed', e.message ?? 'Invalid email or password');

//       return false;
//     } catch (e) {
//       Get.snackbar('Error', 'Something went wrong. Please try again.');

//       return false;
//     }
//   }
//   // Future<void> login(String email, String password) async {
//   //   email = email.trim();
//   //   password = password.trim();

//   //   if (email.isEmpty || password.isEmpty) {
//   //     return showAuthError('Please enter email and password');
//   //   }

//   //   try {
//   //     isLoading.value = true;
//   //     await _auth.signInWithEmailAndPassword(email: email, password: password);
//   //     Get.offAll(() => const ShellView());
//   //   } on FirebaseAuthException catch (e) {
//   //     showAuthError(authErrorMessage(e.code));
//   //   } catch (_) {
//   //     showAuthError('Something went wrong. Please try again.');
//   //   } finally {
//   //     isLoading.value = false;
//   //   }
//   // }

//   // ---------- Forgot password ----------
//   Future<void> resetPassword(String email) async {
//     if (email.trim().isEmpty) return showAuthError('Please enter your email');

//     try {
//       isLoading.value = true;
//       await _auth.sendPasswordResetEmail(email: email.trim());
//       Get.back(); // close dialog
//       Get.snackbar('Done', 'Password reset link sent to your email');
//     } on FirebaseAuthException catch (e) {
//       showAuthError(authErrorMessage(e.code));
//     } catch (_) {
//       showAuthError('Could not send reset email');
//     } finally {
//       isLoading.value = false;
//     }
//   }
// }

// // =========================================================
// // LOGIN PAGE
// // =========================================================
// class LoginView extends StatefulWidget {
//   const LoginView({super.key});

//   @override
//   State<LoginView> createState() => _LoginViewState();
// }

// class _LoginViewState extends State<LoginView> {
//   final c = Get.put(LoginController());

//   final _email = TextEditingController();
//   final _password = TextEditingController();

//   @override
//   void dispose() {
//     _email.dispose();
//     _password.dispose();
//     super.dispose();
//   }

//   Future<void> _submit() async {
//     final success = await c.login(_email.text.trim(), _password.text.trim());

//     if (success) {
//       Get.offAll(() => const ShellView());
//     }
//   }

//   @override
//   Widget build(BuildContext context) {
//     return AuthLayout(
//       title: 'Welcome back',
//       subtitle: 'Log in to your account',
//       child: Obx(
//         () => Column(
//           children: [
//             AuthField(
//               controller: _email,
//               label: 'Email',
//               icon: Icons.mail_outline,
//               keyboardType: TextInputType.emailAddress,
//             ),
//             const SizedBox(height: 14),

//             AuthField(
//               controller: _password,
//               label: 'Password',
//               icon: Icons.lock_outline,
//               obscure: c.hidePassword.value,
//               action: TextInputAction.done,
//               onSubmit: _submit,
//               suffix: IconButton(
//                 onPressed: c.hidePassword.toggle,
//                 icon: Icon(
//                   c.hidePassword.value
//                       ? Icons.visibility_off_outlined
//                       : Icons.visibility_outlined,
//                 ),
//               ),
//             ),

//             Align(
//               alignment: Alignment.centerRight,
//               child: TextButton(
//                 onPressed: c.isLoading.value ? null : _forgotDialog,
//                 child: const Text(
//                   'Forgot password?',
//                   style: TextStyle(color: C.soft),
//                 ),
//               ),
//             ),

//             AuthButton(
//               label: 'Log in',
//               loading: c.isLoading.value,
//               onPressed: _submit,
//             ),

//             const SizedBox(height: 18),

//             Wrap(
//               alignment: WrapAlignment.center,
//               crossAxisAlignment: WrapCrossAlignment.center,
//               children: [
//                 const Text(
//                   "Don't have an account?",
//                   style: TextStyle(color: Colors.black54),
//                 ),
//                 TextButton(
//                   onPressed: c.isLoading.value
//                       ? null
//                       : () => Get.to(() => const RegisterView()),
//                   child: const Text(
//                     'Sign up',
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

//   // Forgot password dialog
//   void _forgotDialog() {
//     final dialogEmail = TextEditingController(text: _email.text);

//     Get.defaultDialog(
//       title: 'Reset password',
//       content: Padding(
//         padding: const EdgeInsets.all(8),
//         child: AuthField(
//           controller: dialogEmail,
//           label: 'Email',
//           icon: Icons.mail_outline,
//           keyboardType: TextInputType.emailAddress,
//         ),
//       ),
//       textConfirm: 'Send link',
//       textCancel: 'Cancel',
//       confirmTextColor: C.ink,
//       buttonColor: C.orange,
//       onConfirm: () => c.resetPassword(dialogEmail.text),
//     );
//   }
// }

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:twin/core/theme.dart';
import 'package:twin/views/shell_view.dart';

import 'auth_widgets.dart';
import 'register_page.dart';

// ── Design tokens (same as SplashLogin) ─────────────────────────────────────
const _orange = Color(0xFFFF7A00);
const _navy = Color(0xFF1B1464);
const _peach = Color(0xFFFFE3C7);
const _cream = Color(0xFFFFF7EE);

// =========================================================
// LOGIN CONTROLLER  (logic unchanged)
// =========================================================
class LoginController extends GetxController {
  final _auth = FirebaseAuth.instance;

  final isLoading = false.obs;
  final hidePassword = true.obs;

  // ---------- Login ----------
  Future<bool> login(String email, String password) async {
    try {
      await FirebaseAuth.instance.signInWithEmailAndPassword(
        email: email,
        password: password,
      );

      return true;
    } on FirebaseAuthException catch (e) {
      Get.snackbar('Login Failed', e.message ?? 'Invalid email or password');

      return false;
    } catch (e) {
      Get.snackbar('Error', 'Something went wrong. Please try again.');

      return false;
    }
  }

  // ---------- Forgot password ----------
  Future<void> resetPassword(String email) async {
    if (email.trim().isEmpty) return showAuthError('Please enter your email');

    try {
      isLoading.value = true;
      await _auth.sendPasswordResetEmail(email: email.trim());
      Get.back(); // close dialog
      Get.snackbar('Done', 'Password reset link sent to your email');
    } on FirebaseAuthException catch (e) {
      showAuthError(authErrorMessage(e.code));
    } catch (_) {
      showAuthError('Could not send reset email');
    } finally {
      isLoading.value = false;
    }
  }
}

// =========================================================
// LOGIN PAGE
// =========================================================
class LoginView extends StatefulWidget {
  const LoginView({super.key});

  @override
  State<LoginView> createState() => _LoginViewState();
}

class _LoginViewState extends State<LoginView> {
  final c = Get.put(LoginController());

  final _email = TextEditingController();
  final _password = TextEditingController();

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final success = await c.login(_email.text.trim(), _password.text.trim());

    if (success) {
      Get.offAll(() => const ShellView());
    }
  }

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
    final h = (box.maxHeight - 48).clamp(480.0, 720.0);
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
              child: const Icon(Icons.handyman, color: Colors.white, size: 22),
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
              'Welcome back',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w800,
                fontSize: 24,
              ),
            ),
            const SizedBox(height: 4),
            const Text(
              'Log in to your account',
              style: TextStyle(color: Color(0xE6FFFFFF), fontSize: 13),
            ),
            const SizedBox(height: 22),

            _PillField(
              controller: _email,
              hint: 'Email',
              icon: Icons.mail_outline,
              keyboardType: TextInputType.emailAddress,
              action: TextInputAction.next,
            ),
            const SizedBox(height: 12),

            _PillField(
              controller: _password,
              hint: 'Password',
              icon: Icons.lock_outline,
              obscure: c.hidePassword.value,
              action: TextInputAction.done,
              onSubmit: _submit,
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

            Align(
              alignment: Alignment.centerRight,
              child: TextButton(
                onPressed: c.isLoading.value ? null : _forgotDialog,
                child: const Text(
                  'Forgot password?',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w600,
                    fontSize: 13,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 4),

            // Log in button (navy pill)
            SizedBox(
              width: double.infinity,
              height: 54,
              child: ElevatedButton(
                onPressed: c.isLoading.value ? null : _submit,
                style: ElevatedButton.styleFrom(
                  backgroundColor: _navy,
                  foregroundColor: Colors.white,
                  disabledBackgroundColor: _navy.withOpacity(0.6),
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
                    : const Text('Log in'),
              ),
            ),

            const SizedBox(height: 14),
            GestureDetector(
              onTap: c.isLoading.value
                  ? null
                  : () => Get.to(() => const RegisterView()),
              behavior: HitTestBehavior.opaque,
              child: const Padding(
                padding: EdgeInsets.symmetric(vertical: 8),
                child: Text.rich(
                  TextSpan(
                    style: TextStyle(color: Color(0xE6FFFFFF), fontSize: 13),
                    children: [
                      TextSpan(text: "Don't have an account? "),
                      TextSpan(
                        text: 'SIGN UP',
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

  // ── Forgot password dialog (logic unchanged) ──────────────────────────────
  void _forgotDialog() {
    final dialogEmail = TextEditingController(text: _email.text);

    Get.defaultDialog(
      title: 'Reset password',
      content: Padding(
        padding: const EdgeInsets.all(8),
        child: AuthField(
          controller: dialogEmail,
          label: 'Email',
          icon: Icons.mail_outline,
          keyboardType: TextInputType.emailAddress,
        ),
      ),
      textConfirm: 'Send link',
      textCancel: 'Cancel',
      confirmTextColor: C.ink,
      buttonColor: C.orange,
      onConfirm: () => c.resetPassword(dialogEmail.text),
    );
  }
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
      if (s < 90) return const SizedBox.shrink(); // keyboard open: hide hero
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
                    Icons.engineering,
                    size: s * 0.46,
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
