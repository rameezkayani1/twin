import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../core/theme.dart';
import '../core/widgets.dart';
import 'shell_view.dart';

class LoginView extends StatelessWidget {
  LoginView({super.key});
  final signUp = false.obs;
  void _go() => Get.offAll(() => const ShellView());

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: C.ink,
    body: SafeArea(
      child: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 440),
            child: Obx(
              () => Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 48,
                        height: 48,
                        decoration: BoxDecoration(
                          color: C.orange,
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: const Icon(Icons.handyman, color: C.ink),
                      ),
                      const SizedBox(width: 12),
                      const Text(
                        'Twins Handyman llc',
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w800,
                          fontSize: 22,
                        ),
                      ),
                    ],
                  ),
                  gap(32),
                  Text(
                    signUp.value ? 'Create your account' : 'Welcome back',
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w800,
                      fontSize: 28,
                    ),
                  ),
                  gap(6),
                  const Text(
                    'North Jersey & Staten Island',
                    style: TextStyle(color: Color(0xFFB9BFC6)),
                  ),
                  gap(24),
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(18),
                    ),
                    child: Column(
                      children: [
                        if (signUp.value) ...[
                          _f('Full name', Icons.person_outline),
                          gap(),
                        ],
                        _f('Email', Icons.mail_outline),
                        gap(),
                        if (signUp.value) ...[
                          _f('Phone', Icons.call_outlined),
                          gap(),
                        ],
                        _f('Password', Icons.lock_outline, obscure: true),
                        gap(16),
                        cta(signUp.value ? 'Create account' : 'Log in', _go),
                        gap(10),
                        Row(
                          children: [
                            Expanded(
                              child: OutlinedButton.icon(
                                onPressed: _go,
                                icon: const Icon(Icons.apple),
                                label: const Text('Apple'),
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: OutlinedButton.icon(
                                onPressed: _go,
                                icon: const Icon(Icons.g_mobiledata, size: 28),
                                label: const Text('Google'),
                              ),
                            ),
                          ],
                        ),
                        if (!signUp.value)
                          TextButton(
                            onPressed: _recover,
                            child: const Text(
                              'Forgot password?',
                              style: TextStyle(color: C.soft),
                            ),
                          ),
                      ],
                    ),
                  ),
                  gap(8),
                  Center(
                    child: TextButton(
                      onPressed: () => signUp.toggle(),
                      child: Text(
                        signUp.value
                            ? 'Have an account? Log in'
                            : 'New here? Sign up',
                        style: const TextStyle(
                          color: C.orange,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    ),
  );

  Widget _f(String l, IconData i, {bool obscure = false}) => TextField(
    obscureText: obscure,
    decoration: InputDecoration(labelText: l, prefixIcon: Icon(i, size: 20)),
  );

  void _recover() => Get.defaultDialog(
    title: 'Reset password',
    content: const Padding(
      padding: EdgeInsets.all(8),
      child: TextField(decoration: InputDecoration(labelText: 'Email')),
    ),
    textConfirm: 'Send link',
    confirmTextColor: Colors.white,
    buttonColor: C.orange,
    textCancel: 'Cancel',
    onConfirm: () {
      Get.back();
      toast('Reset link sent (demo)');
    },
  );
}
