import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:twin/core/theme.dart';
import 'package:twin/views/shell_view.dart';

import 'auth_widgets.dart';
import 'register_page.dart';

// =========================================================
// LOGIN CONTROLLER  (logic only; text controllers live in the page)
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
  // Future<void> login(String email, String password) async {
  //   email = email.trim();
  //   password = password.trim();

  //   if (email.isEmpty || password.isEmpty) {
  //     return showAuthError('Please enter email and password');
  //   }

  //   try {
  //     isLoading.value = true;
  //     await _auth.signInWithEmailAndPassword(email: email, password: password);
  //     Get.offAll(() => const ShellView());
  //   } on FirebaseAuthException catch (e) {
  //     showAuthError(authErrorMessage(e.code));
  //   } catch (_) {
  //     showAuthError('Something went wrong. Please try again.');
  //   } finally {
  //     isLoading.value = false;
  //   }
  // }

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

  @override
  Widget build(BuildContext context) {
    return AuthLayout(
      title: 'Welcome back',
      subtitle: 'Log in to your account',
      child: Obx(
        () => Column(
          children: [
            AuthField(
              controller: _email,
              label: 'Email',
              icon: Icons.mail_outline,
              keyboardType: TextInputType.emailAddress,
            ),
            const SizedBox(height: 14),

            AuthField(
              controller: _password,
              label: 'Password',
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
                ),
              ),
            ),

            Align(
              alignment: Alignment.centerRight,
              child: TextButton(
                onPressed: c.isLoading.value ? null : _forgotDialog,
                child: const Text(
                  'Forgot password?',
                  style: TextStyle(color: C.soft),
                ),
              ),
            ),

            AuthButton(
              label: 'Log in',
              loading: c.isLoading.value,
              onPressed: _submit,
            ),

            const SizedBox(height: 18),

            Wrap(
              alignment: WrapAlignment.center,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                const Text(
                  "Don't have an account?",
                  style: TextStyle(color: Colors.black54),
                ),
                TextButton(
                  onPressed: c.isLoading.value
                      ? null
                      : () => Get.to(() => const RegisterView()),
                  child: const Text(
                    'Sign up',
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

  // Forgot password dialog
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
