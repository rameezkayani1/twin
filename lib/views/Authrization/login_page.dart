import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:twin/views/shell_view.dart';

import 'register_page.dart';

// ── Design tokens ───────────────────────────────────────────────────────────
const _orange = Color(0xFFFF7A00);
const _navy = Color(0xFF1B1464);
const _peach = Color(0xFFFFE3C7);
const _cream = Color(0xFFFFF7EE);
const _logoAsset = 'assets/logo.jpeg';

// =========================================================
// LOGIN CONTROLLER
// =========================================================
class LoginController extends GetxController {
  final _auth = FirebaseAuth.instance;

  final isLoading = false.obs;
  final hidePassword = true.obs;

  // ---------- Login ----------
  Future<bool> login(String email, String password) async {
    if (email.isEmpty || password.isEmpty) {
      Get.snackbar('Login Failed', 'Please enter your email and password');
      return false;
    }

    try {
      isLoading.value = true;
      await _auth.signInWithEmailAndPassword(email: email, password: password);
      return true;
    } on FirebaseAuthException catch (e) {
      Get.snackbar('Login Failed', e.message ?? 'Invalid email or password');
      return false;
    } catch (_) {
      Get.snackbar('Error', 'Something went wrong. Please try again.');
      return false;
    } finally {
      isLoading.value = false;
    }
  }

  // ---------- Forgot password ----------
  /// Returns null on success, or an error message on failure.
  Future<String?> sendResetEmail(String email) async {
    final e = email.trim();
    if (e.isEmpty) return 'Please enter your email';
    if (!GetUtils.isEmail(e)) return 'Enter a valid email address';

    try {
      await _auth.sendPasswordResetEmail(email: e);
      return null;
    } on FirebaseAuthException catch (ex) {
      switch (ex.code) {
        case 'invalid-email':
          return 'That email address is not valid';
        case 'user-not-found':
          return 'No account found with this email';
        case 'too-many-requests':
          return 'Too many attempts. Try again later';
        case 'network-request-failed':
          return 'No internet connection';
        default:
          return ex.message ?? 'Could not send reset email';
      }
    } catch (_) {
      return 'Could not send reset email';
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
    if (c.isLoading.value) return;
    FocusScope.of(context).unfocus();
    final success = await c.login(_email.text.trim(), _password.text.trim());
    if (success) {
      Get.offAll(() => const ShellView());
    }
  }

  Future<void> _forgotDialog() async {
    final sent = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (_) => _ForgotPasswordDialog(initialEmail: _email.text.trim()),
    );

    if (sent == true) {
      Get.snackbar(
        'Email sent',
        'Check your inbox (and spam folder) for the reset link',
      );
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

            // Log in button (navy pill that morphs into a spinner)
            _AnimatedLoginButton(
              label: 'Log in',
              isLoading: c.isLoading.value,
              onPressed: _submit,
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
}

// =========================================================
// Animated login button
// Press: slight scale-down. Loading: shrinks into a circle with a spinner.
// =========================================================
class _AnimatedLoginButton extends StatefulWidget {
  const _AnimatedLoginButton({
    required this.label,
    required this.isLoading,
    required this.onPressed,
  });

  final String label;
  final bool isLoading;
  final VoidCallback onPressed;

  @override
  State<_AnimatedLoginButton> createState() => _AnimatedLoginButtonState();
}

class _AnimatedLoginButtonState extends State<_AnimatedLoginButton> {
  static const _height = 54.0;
  bool _pressed = false;

  void _setPressed(bool v) {
    if (widget.isLoading) return;
    setState(() => _pressed = v);
  }

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, box) {
      final loading = widget.isLoading;
      return Center(
        child: AnimatedScale(
          scale: _pressed ? 0.96 : 1.0,
          duration: const Duration(milliseconds: 110),
          curve: Curves.easeOut,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 350),
            curve: Curves.easeInOutCubic,
            width: loading ? _height : box.maxWidth,
            height: _height,
            decoration: BoxDecoration(
              color: loading ? _navy.withOpacity(0.92) : _navy,
              borderRadius: BorderRadius.circular(_height / 2),
              boxShadow: [
                BoxShadow(
                  color: _navy.withOpacity(loading ? 0.10 : 0.30),
                  blurRadius: loading ? 8 : 16,
                  offset: Offset(0, loading ? 2 : 6),
                ),
              ],
            ),
            child: Material(
              color: Colors.transparent,
              clipBehavior: Clip.antiAlias,
              shape: const StadiumBorder(),
              child: InkWell(
                customBorder: const StadiumBorder(),
                splashColor: Colors.white24,
                highlightColor: Colors.white10,
                onTap: loading ? null : widget.onPressed,
                onTapDown: (_) => _setPressed(true),
                onTapUp: (_) => _setPressed(false),
                onTapCancel: () => _setPressed(false),
                child: Center(
                  child: AnimatedSwitcher(
                    duration: const Duration(milliseconds: 220),
                    switchInCurve: Curves.easeOut,
                    switchOutCurve: Curves.easeIn,
                    transitionBuilder: (child, anim) => FadeTransition(
                      opacity: anim,
                      child: ScaleTransition(scale: anim, child: child),
                    ),
                    child: loading
                        ? const SizedBox(
                            key: ValueKey('spinner'),
                            width: 24,
                            height: 24,
                            child: CircularProgressIndicator(
                              strokeWidth: 2.6,
                              strokeCap: StrokeCap.round,
                              color: Colors.white,
                            ),
                          )
                        : Text(
                            widget.label,
                            key: const ValueKey('label'),
                            maxLines: 1,
                            overflow: TextOverflow.clip,
                            softWrap: false,
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w700,
                              fontSize: 16,
                              letterSpacing: 0.3,
                            ),
                          ),
                  ),
                ),
              ),
            ),
          ),
        ),
      );
    },
  );
}

// =========================================================
// Forgot password dialog
// =========================================================
class _ForgotPasswordDialog extends StatefulWidget {
  const _ForgotPasswordDialog({required this.initialEmail});
  final String initialEmail;

  @override
  State<_ForgotPasswordDialog> createState() => _ForgotPasswordDialogState();
}

class _ForgotPasswordDialogState extends State<_ForgotPasswordDialog> {
  late final TextEditingController _emailCtrl;
  bool _loading = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _emailCtrl = TextEditingController(text: widget.initialEmail);
  }

  @override
  void dispose() {
    _emailCtrl.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    final err = await Get.find<LoginController>().sendResetEmail(
      _emailCtrl.text,
    );

    if (!mounted) return;

    if (err == null) {
      Navigator.of(context).pop(true);
    } else {
      setState(() {
        _loading = false;
        _error = err;
      });
    }
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    backgroundColor: Colors.white,
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
    title: const Text(
      'Reset password',
      style: TextStyle(color: _navy, fontWeight: FontWeight.w800),
    ),
    content: Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          "Enter your email and we'll send you a reset link.",
          style: TextStyle(fontSize: 13, color: Colors.black54),
        ),
        const SizedBox(height: 14),
        TextField(
          controller: _emailCtrl,
          enabled: !_loading,
          autofocus: true,
          keyboardType: TextInputType.emailAddress,
          textInputAction: TextInputAction.done,
          onSubmitted: (_) => _send(),
          cursorColor: _orange,
          decoration: InputDecoration(
            hintText: 'Email',
            prefixIcon: const Icon(Icons.mail_outline, color: _navy),
            errorText: _error,
            filled: true,
            fillColor: _cream,
            contentPadding: const EdgeInsets.symmetric(horizontal: 16),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(30),
              borderSide: BorderSide.none,
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(30),
              borderSide: const BorderSide(color: _orange, width: 2),
            ),
          ),
        ),
      ],
    ),
    actions: [
      TextButton(
        onPressed: _loading ? null : () => Navigator.of(context).pop(false),
        child: const Text('Cancel', style: TextStyle(color: Colors.black54)),
      ),
      ElevatedButton(
        onPressed: _loading ? null : _send,
        style: ElevatedButton.styleFrom(
          backgroundColor: _orange,
          foregroundColor: Colors.white,
          elevation: 0,
          shape: const StadiumBorder(),
        ),
        child: _loading
            ? const SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(
                  strokeWidth: 2.2,
                  color: Colors.white,
                ),
              )
            : const Text('Send link'),
      ),
    ],
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
                    color: Colors.black,
                  ),
                  child: Padding(
                    padding: EdgeInsets.all(s * 0.12),
                    child: Image.asset(
                      _logoAsset,
                      fit: BoxFit.contain,
                      errorBuilder: (c, e, st) => Icon(
                        Icons.engineering,
                        size: s * 0.46,
                        color: Colors.white,
                      ),
                    ),
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
// import 'package:twin/core/theme.dart';
// import 'package:twin/views/shell_view.dart';

// import 'auth_widgets.dart';
// import 'register_page.dart';

// // ── Design tokens (same as SplashLogin) ─────────────────────────────────────
// const _orange = Color(0xFFFF7A00);
// const _navy = Color(0xFF1B1464);
// const _peach = Color(0xFFFFE3C7);
// const _cream = Color(0xFFFFF7EE);
// const _logoAsset = 'assets/logo.jpeg';

// // =========================================================
// // LOGIN CONTROLLER  (logic unchanged)
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

//   // ── Build ─────────────────────────────────────────────────────────────────
//   @override
//   Widget build(BuildContext context) => Scaffold(
//     backgroundColor: _peach,
//     resizeToAvoidBottomInset: true,
//     body: Container(
//       decoration: const BoxDecoration(
//         gradient: LinearGradient(
//           begin: Alignment.topCenter,
//           end: Alignment.bottomCenter,
//           colors: [_cream, _peach],
//         ),
//       ),
//       child: SafeArea(
//         child: LayoutBuilder(
//           builder: (context, box) =>
//               box.maxWidth >= 720 ? _wide(box) : _narrow(box),
//         ),
//       ),
//     ),
//   );

//   /// Phones: hero on top, orange sheet at the bottom.
//   Widget _narrow(BoxConstraints box) => Column(
//     children: [
//       Expanded(child: _hero()),
//       Align(
//         alignment: Alignment.bottomCenter,
//         child: ConstrainedBox(
//           constraints: BoxConstraints(
//             maxWidth: 520,
//             maxHeight: box.maxHeight * 0.85,
//           ),
//           child: Padding(
//             padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
//             child: _panel(),
//           ),
//         ),
//       ),
//     ],
//   );

//   /// Tablets / web: framed card, hero left, panel right.
//   Widget _wide(BoxConstraints box) {
//     final h = (box.maxHeight - 48).clamp(480.0, 720.0);
//     return Center(
//       child: SingleChildScrollView(
//         padding: const EdgeInsets.all(24),
//         child: Container(
//           width: box.maxWidth.clamp(0.0, 1040.0) - 48,
//           height: h,
//           clipBehavior: Clip.antiAlias,
//           decoration: BoxDecoration(
//             color: Colors.white,
//             borderRadius: BorderRadius.circular(40),
//             boxShadow: const [
//               BoxShadow(
//                 color: Color(0x33FF7A00),
//                 blurRadius: 40,
//                 offset: Offset(0, 20),
//               ),
//             ],
//           ),
//           child: Row(
//             children: [
//               Expanded(child: _hero()),
//               SizedBox(
//                 width: 440,
//                 child: Padding(
//                   padding: const EdgeInsets.all(16),
//                   child: Align(alignment: Alignment.center, child: _panel()),
//                 ),
//               ),
//             ],
//           ),
//         ),
//       ),
//     );
//   }

//   // ── Hero (brand + back + illustration) ────────────────────────────────────
//   Widget _hero() => Stack(
//     children: [
//       const Positioned.fill(child: CustomPaint(painter: _DotsPainter())),
//       const Positioned.fill(top: 64, child: _FallbackHero()),
//       Positioned(
//         left: 12,
//         top: 16,
//         child: Row(
//           children: [
//             if (Navigator.of(context).canPop())
//               IconButton(
//                 onPressed: Get.back,
//                 icon: const Icon(Icons.arrow_back_ios_new_rounded),
//                 color: _navy,
//                 iconSize: 20,
//               )
//             else
//               const SizedBox(width: 8),
//             Container(
//               width: 40,
//               height: 40,
//               decoration: BoxDecoration(
//                 color: _orange,
//                 borderRadius: BorderRadius.circular(12),
//               ),
//               child: Image.asset(
//                 _logoAsset,
//                 fit: BoxFit.contain,
//                 errorBuilder: (c, e, s) =>
//                     const Icon(Icons.handyman, color: Colors.black, size: 24),
//               ),
//             ),
//             const SizedBox(width: 10),
//             const Text(
//               'Twins Handyman llc',
//               style: TextStyle(
//                 color: _navy,
//                 fontWeight: FontWeight.w800,
//                 fontSize: 17,
//               ),
//             ),
//           ],
//         ),
//       ),
//     ],
//   );

//   // ── Orange form panel ─────────────────────────────────────────────────────
//   Widget _panel() => Container(
//     width: double.infinity,
//     decoration: BoxDecoration(
//       color: _orange,
//       borderRadius: BorderRadius.circular(40),
//       boxShadow: const [
//         BoxShadow(
//           color: Color(0x40FF7A00),
//           blurRadius: 24,
//           offset: Offset(0, 10),
//         ),
//       ],
//     ),
//     child: SingleChildScrollView(
//       padding: const EdgeInsets.fromLTRB(24, 28, 24, 20),
//       child: Obx(
//         () => Column(
//           mainAxisSize: MainAxisSize.min,
//           children: [
//             const Text(
//               'Welcome back',
//               textAlign: TextAlign.center,
//               style: TextStyle(
//                 color: Colors.white,
//                 fontWeight: FontWeight.w800,
//                 fontSize: 24,
//               ),
//             ),
//             const SizedBox(height: 4),
//             const Text(
//               'Log in to your account',
//               style: TextStyle(color: Color(0xE6FFFFFF), fontSize: 13),
//             ),
//             const SizedBox(height: 22),

//             _PillField(
//               controller: _email,
//               hint: 'Email',
//               icon: Icons.mail_outline,
//               keyboardType: TextInputType.emailAddress,
//               action: TextInputAction.next,
//             ),
//             const SizedBox(height: 12),

//             _PillField(
//               controller: _password,
//               hint: 'Password',
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
//                   color: Colors.black45,
//                 ),
//               ),
//             ),

//             Align(
//               alignment: Alignment.centerRight,
//               child: TextButton(
//                 onPressed: c.isLoading.value ? null : _forgotDialog,
//                 child: const Text(
//                   'Forgot password?',
//                   style: TextStyle(
//                     color: Colors.white,
//                     fontWeight: FontWeight.w600,
//                     fontSize: 13,
//                   ),
//                 ),
//               ),
//             ),
//             const SizedBox(height: 4),

//             // Log in button (navy pill)
//             SizedBox(
//               width: double.infinity,
//               height: 54,
//               child: ElevatedButton(
//                 onPressed: c.isLoading.value ? null : _submit,
//                 style: ElevatedButton.styleFrom(
//                   backgroundColor: _navy,
//                   foregroundColor: Colors.white,
//                   disabledBackgroundColor: _navy.withOpacity(0.6),
//                   elevation: 0,
//                   shape: const StadiumBorder(),
//                   textStyle: const TextStyle(
//                     fontWeight: FontWeight.w700,
//                     fontSize: 16,
//                   ),
//                 ),
//                 child: c.isLoading.value
//                     ? const SizedBox(
//                         width: 22,
//                         height: 22,
//                         child: CircularProgressIndicator(
//                           strokeWidth: 2.5,
//                           color: Colors.white,
//                         ),
//                       )
//                     : const Text('Log in'),
//               ),
//             ),

//             const SizedBox(height: 14),
//             GestureDetector(
//               onTap: c.isLoading.value
//                   ? null
//                   : () => Get.to(() => const RegisterView()),
//               behavior: HitTestBehavior.opaque,
//               child: const Padding(
//                 padding: EdgeInsets.symmetric(vertical: 8),
//                 child: Text.rich(
//                   TextSpan(
//                     style: TextStyle(color: Color(0xE6FFFFFF), fontSize: 13),
//                     children: [
//                       TextSpan(text: "Don't have an account? "),
//                       TextSpan(
//                         text: 'SIGN UP',
//                         style: TextStyle(
//                           color: Colors.white,
//                           fontWeight: FontWeight.w800,
//                         ),
//                       ),
//                     ],
//                   ),
//                 ),
//               ),
//             ),
//           ],
//         ),
//       ),
//     ),
//   );

//   // ── Forgot password dialog (logic unchanged) ──────────────────────────────
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

// // =========================================================
// // White pill text field (sits on the orange panel)
// // =========================================================
// class _PillField extends StatelessWidget {
//   const _PillField({
//     required this.controller,
//     required this.hint,
//     required this.icon,
//     this.obscure = false,
//     this.suffix,
//     this.keyboardType,
//     this.action,
//     this.onSubmit,
//   });

//   final TextEditingController controller;
//   final String hint;
//   final IconData icon;
//   final bool obscure;
//   final Widget? suffix;
//   final TextInputType? keyboardType;
//   final TextInputAction? action;
//   final VoidCallback? onSubmit;

//   @override
//   Widget build(BuildContext context) => SizedBox(
//     height: 54,
//     child: TextField(
//       controller: controller,
//       obscureText: obscure,
//       keyboardType: keyboardType,
//       textInputAction: action,
//       onSubmitted: onSubmit == null ? null : (_) => onSubmit!(),
//       style: const TextStyle(
//         color: _navy,
//         fontWeight: FontWeight.w600,
//         fontSize: 16,
//       ),
//       cursorColor: _orange,
//       decoration: InputDecoration(
//         hintText: hint,
//         hintStyle: const TextStyle(color: Colors.black38),
//         prefixIcon: Icon(icon, color: _navy),
//         suffixIcon: suffix,
//         filled: true,
//         fillColor: Colors.white,
//         contentPadding: const EdgeInsets.symmetric(horizontal: 20),
//         border: OutlineInputBorder(
//           borderRadius: BorderRadius.circular(40),
//           borderSide: BorderSide.none,
//         ),
//         enabledBorder: OutlineInputBorder(
//           borderRadius: BorderRadius.circular(40),
//           borderSide: BorderSide.none,
//         ),
//         focusedBorder: OutlineInputBorder(
//           borderRadius: BorderRadius.circular(40),
//           borderSide: const BorderSide(color: _navy, width: 2),
//         ),
//       ),
//     ),
//   );
// }

// // ── Decorative dot grid ─────────────────────────────────────────────────────
// class _DotsPainter extends CustomPainter {
//   const _DotsPainter();
//   @override
//   void paint(Canvas canvas, Size size) {
//     final p = Paint()..color = const Color(0x40FF7A00);
//     const gap = 9.0;
//     final left = size.width * 0.12;
//     final top = size.height * 0.28;
//     for (var r = 0; r < 9; r++) {
//       for (var c = 0; c < 9; c++) {
//         canvas.drawCircle(Offset(left + c * gap, top + r * gap), 1.2, p);
//       }
//     }
//   }

//   @override
//   bool shouldRepaint(covariant CustomPainter old) => false;
// }

// // ── Hero illustration ───────────────────────────────────────────────────────
// class _FallbackHero extends StatelessWidget {
//   const _FallbackHero();

//   @override
//   Widget build(BuildContext context) => LayoutBuilder(
//     builder: (context, box) {
//       final s = (box.biggest.shortestSide * 0.8).clamp(0.0, 420.0);
//       if (s < 90) return const SizedBox.shrink(); // keyboard open: hide hero
//       Widget chip(IconData i, Alignment a, Color bg) => Align(
//         alignment: a,
//         child: Container(
//           width: s * 0.2,
//           height: s * 0.2,
//           decoration: BoxDecoration(
//             color: bg,
//             shape: BoxShape.circle,
//             boxShadow: const [
//               BoxShadow(
//                 color: Color(0x22000000),
//                 blurRadius: 10,
//                 offset: Offset(0, 4),
//               ),
//             ],
//           ),
//           child: Icon(i, color: Colors.white, size: s * 0.1),
//         ),
//       );
//       return Center(
//         child: SizedBox(
//           width: s,
//           height: s,
//           child: Stack(
//             children: [
//               Center(
//                 child: Container(
//                   width: s * 0.78,
//                   height: s * 0.78,
//                   decoration: const BoxDecoration(
//                     shape: BoxShape.circle,
//                     gradient: LinearGradient(
//                       begin: Alignment.topLeft,
//                       end: Alignment.bottomRight,
//                       colors: [Colors.black, Colors.black],
//                     ),
//                   ),
//                   child: Padding(
//                     padding: EdgeInsets.all(s * 0.12),
//                     child: Image.asset(
//                       _logoAsset,
//                       fit: BoxFit.contain,
//                       errorBuilder: (c, e, st) => Icon(
//                         Icons.engineering,
//                         size: s * 0.46,
//                         color: Colors.white,
//                       ),
//                     ),
//                   ),
//                 ),
//               ),
//               chip(Icons.hardware, Alignment.topLeft, _navy),
//               chip(Icons.plumbing, Alignment.topRight, _orange),
//               chip(Icons.format_paint, Alignment.bottomLeft, _orange),
//               chip(Icons.electrical_services, Alignment.bottomRight, _navy),
//             ],
//           ),
//         ),
//       );
//     },
//   );
// }
