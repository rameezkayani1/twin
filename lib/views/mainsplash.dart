import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:twin/views/Authrization/login_page.dart';
import 'login_view.dart'; // your original LoginView (email / password form)

// ── Design tokens ───────────────────────────────────────────────────────────
const _orange = Color(0xFFFF7A00);
const _navy = Color(0xFF1B1464);
const _peach = Color(0xFFFFE3C7);
const _cream = Color(0xFFFFF7EE);

/// Replace with your own cut-out PNG (transparent background) for best result.
/// Or use: Image.asset('assets/images/handyman.png', ...)
const _heroUrl = '';

class SplashLogin extends StatelessWidget {
  const SplashLogin({super.key});

  /// Email, Google, Apple and Sign Up all open the LoginView page.
  void _openLogin() => Get.to(() => LoginView());

  // ── Build ─────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: _peach,
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

  /// Phones & small tablets: hero on top, orange sheet at the bottom.
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

  /// Tablets / desktop / web: framed card, hero left, panel right.
  Widget _wide(BoxConstraints box) {
    final h = (box.maxHeight - 48).clamp(420.0, 700.0);
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

  // ── Hero (image + brand) ──────────────────────────────────────────────────
  Widget _hero() => Stack(
    children: [
      const Positioned.fill(child: CustomPaint(painter: _DotsPainter())),
      Positioned.fill(
        top: 64,
        child: Image.network(
          _heroUrl,
          fit: BoxFit.contain,
          alignment: Alignment.bottomCenter,
          loadingBuilder: (c, child, p) =>
              p == null ? child : const _FallbackHero(),
          errorBuilder: (c, e, s) => const _FallbackHero(),
        ),
      ),
      Positioned(
        left: 20,
        top: 16,
        child: Row(
          children: [
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

  // ── Orange bottom panel ───────────────────────────────────────────────────
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
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text(
            'Welcome to handyman',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w800,
              fontSize: 24,
            ),
          ),
          const SizedBox(height: 4),
          const Text(
            'North Jersey & Staten Island',
            style: TextStyle(color: Color(0xE6FFFFFF), fontSize: 13),
          ),
          const SizedBox(height: 22),
          _pill(
            'Sign in with Email',
            const Icon(Icons.mail_outline, size: 22),
            _navy,
            Colors.white,
            _openLogin,
          ),
          const SizedBox(height: 12),
          _pill(
            'Sign in with Google',
            const Icon(Icons.g_mobiledata, size: 34),
            Colors.white,
            Colors.black87,
            _openLogin,
          ),
          const SizedBox(height: 12),
          _pill(
            'Sign in with Apple',
            const Icon(Icons.apple, size: 24),
            Colors.white,
            Colors.black87,
            _openLogin,
          ),
          const SizedBox(height: 14),
          GestureDetector(
            onTap: _openLogin,
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
  );

  Widget _pill(String t, Widget icon, Color bg, Color fg, VoidCallback onTap) =>
      SizedBox(
        width: double.infinity,
        height: 54,
        child: ElevatedButton(
          onPressed: onTap,
          style: ElevatedButton.styleFrom(
            backgroundColor: bg,
            foregroundColor: fg,
            elevation: 0,
            shape: const StadiumBorder(),
            textStyle: const TextStyle(
              fontWeight: FontWeight.w600,
              fontSize: 16,
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              icon,
              const SizedBox(width: 12),
              Flexible(child: Text(t, overflow: TextOverflow.ellipsis)),
            ],
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

// ── Illustration shown while the photo loads or if offline ──────────────────
class _FallbackHero extends StatelessWidget {
  const _FallbackHero();

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, box) {
      final s = (box.biggest.shortestSide * 0.8).clamp(120.0, 420.0);
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
