import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:twin/core/theme.dart';

// =========================================================
// AuthLayout: simple, clean page frame for Login & Register
//   - dark header band with logo
//   - white card overlapping the band
//   - centered, max width 440 -> works on phone, tablet, web
// =========================================================
class AuthLayout extends StatelessWidget {
  final String title;
  final String subtitle;
  final Widget child;

  const AuthLayout({
    super.key,
    required this.title,
    required this.subtitle,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    final cardPadding = width < 400 ? 20.0 : 28.0;

    return Scaffold(
      backgroundColor: const Color(0xFFF4F5F7),
      body: Stack(
        children: [
          // Dark header band
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            height: 280,
            child: Container(color: C.ink),
          ),

          SafeArea(
            child: Align(
              alignment: Alignment.topCenter,
              child: SingleChildScrollView(
                padding: EdgeInsets.fromLTRB(20, 28, 20, 32),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 440),
                  child: Column(
                    children: [
                      // Logo
                      Container(
                        width: 56,
                        height: 56,
                        decoration: BoxDecoration(
                          color: C.orange,
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: const Icon(
                          Icons.handyman,
                          color: C.ink,
                          size: 28,
                        ),
                      ),
                      const SizedBox(height: 12),
                      const Text(
                        'Twins Handyman llc',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 22,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 4),
                      const Text(
                        'North Jersey & Staten Island',
                        style: TextStyle(color: Color(0xFFB9BFC6)),
                      ),
                      const SizedBox(height: 28),

                      // Card
                      Container(
                        width: double.infinity,
                        padding: EdgeInsets.all(cardPadding),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: const Color(0xFFE5E7EB)),
                          boxShadow: const [
                            BoxShadow(
                              color: Color(0x14000000),
                              blurRadius: 24,
                              offset: Offset(0, 8),
                            ),
                          ],
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              title,
                              style: const TextStyle(
                                color: C.ink,
                                fontSize: 24,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              subtitle,
                              style: const TextStyle(color: Colors.black54),
                            ),
                            const SizedBox(height: 22),
                            child,
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// =========================================================
// Reusable text field
// =========================================================
class AuthField extends StatelessWidget {
  final TextEditingController controller;
  final String label;
  final IconData icon;
  final TextInputType? keyboardType;
  final bool obscure;
  final Widget? suffix;
  final TextInputAction? action;
  final VoidCallback? onSubmit;

  const AuthField({
    super.key,
    required this.controller,
    required this.label,
    required this.icon,
    this.keyboardType,
    this.obscure = false,
    this.suffix,
    this.action,
    this.onSubmit,
  });

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      keyboardType: keyboardType,
      obscureText: obscure,
      textInputAction: action ?? TextInputAction.next,
      onSubmitted: (_) => onSubmit?.call(),
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon, size: 20),
        suffixIcon: suffix,
        filled: true,
        fillColor: const Color(0xFFF6F7F9),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFFE5E7EB)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: C.orange, width: 1.6),
        ),
      ),
    );
  }
}

// =========================================================
// Reusable main button with loading spinner
// =========================================================
class AuthButton extends StatelessWidget {
  final String label;
  final bool loading;
  final VoidCallback onPressed;

  const AuthButton({
    super.key,
    required this.label,
    required this.loading,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: 52,
      child: ElevatedButton(
        onPressed: loading ? null : onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: C.orange,
          foregroundColor: C.ink,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
        child: loading
            ? const SizedBox(
                width: 22,
                height: 22,
                child: CircularProgressIndicator(strokeWidth: 2, color: C.ink),
              )
            : Text(
                label,
                style: const TextStyle(
                  fontWeight: FontWeight.w800,
                  fontSize: 16,
                ),
              ),
      ),
    );
  }
}

// =========================================================
// Shared helpers (used by both Login and Register files)
// =========================================================
String authErrorMessage(String code) {
  switch (code) {
    case 'invalid-email':
      return 'Please enter a valid email address';
    case 'user-not-found':
      return 'No account found with this email';
    case 'wrong-password':
    case 'invalid-credential':
      return 'Incorrect email or password';
    case 'email-already-in-use':
      return 'An account already exists with this email';
    case 'weak-password':
      return 'Password is too weak';
    case 'network-request-failed':
      return 'Please check your internet connection';
    case 'too-many-requests':
      return 'Too many attempts. Please try again later';
    case 'user-disabled':
      return 'This account has been disabled';
    default:
      return 'Authentication failed. Please try again';
  }
}

void showAuthError(String message) {
  Get.snackbar(
    'Error',
    message,
    snackPosition: SnackPosition.BOTTOM,
    backgroundColor: Colors.red.shade700,
    colorText: Colors.white,
    margin: const EdgeInsets.all(16),
  );
}
