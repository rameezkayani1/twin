import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:twin/views/Authrization/login_page.dart';
// UserModel lives in your register file - adjust the file name if different.
import 'package:twin/views/Authrization/register_page.dart' show UserModel;
import 'chat_view.dart';
import 'extras_view.dart';
import 'invoices_view.dart';

// ── Palette: midnight + orange glow ─────────────────────────────────────────
const _orange = Color(0xFFFF7A00);
const _amber = Color(0xFFFFB347);
const _deep = Color(0xFF0B0830);
const _navy = Color(0xFF1B1464);
const _red = Color(0xFFFF5C62);

// =========================================================
// ACCOUNT VIEW  (live data from Firestore: users/{uid})
// =========================================================
class AccountView extends StatelessWidget {
  const AccountView({super.key});

  @override
  Widget build(BuildContext context) {
    final authUser = FirebaseAuth.instance.currentUser;

    return Scaffold(
      backgroundColor: _deep,
      body: _Backdrop(
        child: SafeArea(
          child: authUser == null
              ? const Center(
                  child: Text(
                    'You are not logged in',
                    style: TextStyle(color: Colors.white70),
                  ),
                )
              : StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
                  stream: FirebaseFirestore.instance
                      .collection('users')
                      .doc(authUser.uid)
                      .snapshots(),
                  builder: (context, snap) {
                    if (snap.hasError) {
                      return const Center(
                        child: Text(
                          'Could not load your profile',
                          style: TextStyle(color: Colors.white70),
                        ),
                      );
                    }
                    if (!snap.hasData) {
                      return const Center(
                        child: CircularProgressIndicator(color: _orange),
                      );
                    }
                    final data = snap.data!.data();
                    final user = data != null
                        ? UserModel.fromMap(data)
                        : UserModel(
                            uid: authUser.uid,
                            name: authUser.displayName ?? 'Customer',
                            email: authUser.email ?? '',
                            phone: authUser.phoneNumber ?? '',
                          );
                    return _Page(user: user);
                  },
                ),
        ),
      ),
    );
  }
}

// ── Gradient background with soft orange glows ──────────────────────────────
class _Backdrop extends StatelessWidget {
  const _Backdrop({required this.child});
  final Widget child;

  Widget _glow(double size, Color c) => Container(
    width: size,
    height: size,
    decoration: BoxDecoration(
      shape: BoxShape.circle,
      gradient: RadialGradient(colors: [c, c.withOpacity(0)]),
    ),
  );

  @override
  Widget build(BuildContext context) => Container(
    decoration: const BoxDecoration(
      gradient: LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [_navy, _deep],
      ),
    ),
    child: Stack(
      children: [
        Positioned(
          top: -120,
          right: -100,
          child: _glow(380, _orange.withOpacity(0.40)),
        ),
        Positioned(
          bottom: -140,
          left: -120,
          child: _glow(380, const Color(0xFF5B4BFF).withOpacity(0.30)),
        ),
        Positioned.fill(child: child),
      ],
    ),
  );
}

// ── Frosted glass container ─────────────────────────────────────────────────
class _Glass extends StatelessWidget {
  const _Glass({
    required this.child,
    this.radius = 24,
    this.padding = EdgeInsets.zero,
  });
  final Widget child;
  final double radius;
  final EdgeInsets padding;

  @override
  Widget build(BuildContext context) => ClipRRect(
    borderRadius: BorderRadius.circular(radius),
    child: BackdropFilter(
      filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
      child: Container(
        width: double.infinity,
        padding: padding,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(radius),
          color: Colors.white.withOpacity(0.07),
          border: Border.all(color: Colors.white.withOpacity(0.14)),
        ),
        child: child,
      ),
    ),
  );
}

// =========================================================
// PAGE  (one scrolling column, centred on big screens)
// =========================================================
class _Page extends StatelessWidget {
  const _Page({required this.user});
  final UserModel user;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 600),
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 20, 16, 36),
          children: [
            _Header(user: user),

            _Group('Profile', [
              _Item(Icons.person_rounded, 'Name', user.name),
              _Item(Icons.mail_rounded, 'Email', user.email),
              _Item(Icons.call_rounded, 'Phone', user.phone),
            ]),

            _Group('Activity', [
              _Item(
                Icons.payments_rounded,
                'Invoices & payments',
                null,
                onTap: () => Get.to(() => const InvoicesView()),
              ),
              _Item(
                Icons.chat_bubble_rounded,
                'Messages',
                null,
                onTap: () => Get.to(() => const ChatPage()),
              ),
              _Item(
                Icons.notifications_rounded,
                'Notifications',
                null,
                onTap: () => Get.to(() => const NotificationsView()),
              ),
              _Item(
                Icons.star_rounded,
                'Reviews',
                null,
                onTap: () => Get.to(() => ReviewsView()),
              ),
            ]),

            _Group('Contact us', [
              _Item(
                Icons.call_rounded,
                'Phone',
                '908-803-8111',
                onTap: () => _open(
                  Uri(scheme: 'tel', path: '+19088038111'),
                  '908-803-8111',
                ),
              ),
              _Item(
                Icons.phone_forwarded_rounded,
                'Phone',
                '908-567-9897',
                onTap: () => _open(
                  Uri(scheme: 'tel', path: '+19085679897'),
                  '908-567-9897',
                ),
              ),
              _Item(
                Icons.mail_rounded,
                'Email',
                'mathew@twinshandymanllc.com',
                onTap: () => _open(
                  Uri(scheme: 'mailto', path: 'mathew@twinshandymanllc.com'),
                  'mathew@twinshandymanllc.com',
                ),
              ),
              _Item(
                Icons.location_on_rounded,
                'Address',
                '1156 Liberty Avenue, Hillside, NJ 07205',
                onTap: () => _open(
                  Uri.https('www.google.com', '/maps/search/', {
                    'api': '1',
                    'query': '1156 Liberty Avenue, Hillside, NJ 07205',
                  }),
                  '1156 Liberty Avenue, Hillside, NJ 07205',
                ),
              ),
              _Item(
                Icons.access_time_filled_rounded,
                'Hours',
                '9:00 AM – 9:00 PM',
              ),
            ]),

            _Group('Company', [
              _Item(
                Icons.account_balance_rounded,
                'Business & government documents',
                null,
                onTap: () => Get.to(() => const GovDocsView()),
              ),
              if (user.role == 'admin')
                _Item(
                  Icons.dashboard_rounded,
                  'Owner dashboard',
                  null,
                  onTap: () => Get.to(() => const AdminView()),
                ),
            ]),

            const SizedBox(height: 28),
            const _LogoutButton(),
          ],
        ),
      ),
    );
  }
}

// =========================================================
// HEADER  (glass card; row on wide, centred column on phones)
// =========================================================
class _Header extends StatelessWidget {
  const _Header({required this.user});
  final UserModel user;

  String get _initials {
    final parts = user.name.trim().split(RegExp(r'\s+'));
    if (parts.isEmpty || parts.first.isEmpty) return '?';
    final a = parts.first[0];
    final b = parts.length > 1 ? parts.last[0] : '';
    return (a + b).toUpperCase();
  }

  String? get _since {
    final d = user.createdAt;
    if (d == null) return null;
    const m = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];
    return 'Since ${m[d.month - 1]} ${d.year}';
  }

  Widget _chip(IconData icon, String text, {bool filled = false}) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 6),
    decoration: BoxDecoration(
      color: filled ? _orange : Colors.white.withOpacity(0.10),
      borderRadius: BorderRadius.circular(20),
      border: Border.all(
        color: filled ? _orange : Colors.white.withOpacity(0.18),
      ),
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 14, color: Colors.white),
        const SizedBox(width: 5),
        Text(
          text,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 12,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    ),
  );

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, box) {
        final wide = box.maxWidth >= 480;
        final r = wide ? 46.0 : 42.0;

        final avatar = Container(
          padding: const EdgeInsets.all(3.5),
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [_amber, _orange],
            ),
            boxShadow: [
              BoxShadow(
                color: _orange.withOpacity(0.55),
                blurRadius: 28,
                spreadRadius: 1,
              ),
            ],
          ),
          child: CircleAvatar(
            radius: r,
            backgroundColor: _deep,
            child: Text(
              _initials,
              style: TextStyle(
                color: Colors.white,
                fontSize: wide ? 32 : 28,
                fontWeight: FontWeight.w800,
                letterSpacing: 1,
              ),
            ),
          ),
        );

        final info = Column(
          crossAxisAlignment: wide
              ? CrossAxisAlignment.start
              : CrossAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              user.name,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              textAlign: wide ? TextAlign.start : TextAlign.center,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 25,
                height: 1.15,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              user.email,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(color: Colors.white60, fontSize: 13.5),
            ),
            const SizedBox(height: 14),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              alignment: wide ? WrapAlignment.start : WrapAlignment.center,
              children: [
                _chip(
                  Icons.verified_rounded,
                  user.role.toUpperCase(),
                  filled: true,
                ),
                if (user.phone.isNotEmpty)
                  _chip(Icons.call_rounded, user.phone),
                if (_since != null) _chip(Icons.cake_rounded, _since!),
              ],
            ),
          ],
        );

        return _Glass(
          radius: 30,
          child: Stack(
            children: [
              Positioned(
                right: -14,
                bottom: -18,
                child: Icon(
                  Icons.handyman_rounded,
                  size: 120,
                  color: Colors.white.withOpacity(0.05),
                ),
              ),
              Padding(
                padding: EdgeInsets.fromLTRB(
                  wide ? 26 : 18,
                  wide ? 26 : 38,
                  wide ? 26 : 18,
                  24,
                ),
                child: wide
                    ? Row(
                        children: [
                          avatar,
                          const SizedBox(width: 22),
                          Expanded(child: info),
                        ],
                      )
                    : Column(
                        children: [avatar, const SizedBox(height: 16), info],
                      ),
              ),
              Positioned(
                top: 12,
                right: 12,
                child: GestureDetector(
                  onTap: () => _editProfile(context, user),
                  child: Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: Colors.white.withOpacity(0.12),
                      border: Border.all(color: Colors.white.withOpacity(0.2)),
                    ),
                    child: const Icon(
                      Icons.edit_rounded,
                      size: 17,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

// =========================================================
// SECTION BLOCKS
// =========================================================
class _Group extends StatelessWidget {
  const _Group(this.title, this.items);
  final String title;
  final List<Widget> items;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      const SizedBox(height: 26),
      Padding(
        padding: const EdgeInsets.only(left: 6, bottom: 10),
        child: Row(
          children: [
            Container(
              width: 4,
              height: 16,
              decoration: BoxDecoration(
                color: _orange,
                borderRadius: BorderRadius.circular(4),
              ),
            ),
            const SizedBox(width: 8),
            Text(
              title.toUpperCase(),
              style: const TextStyle(
                color: Colors.white70,
                fontWeight: FontWeight.w800,
                fontSize: 12,
                letterSpacing: 1.6,
              ),
            ),
          ],
        ),
      ),
      _Glass(
        radius: 24,
        child: Column(
          children: [
            for (var i = 0; i < items.length; i++) ...[
              items[i],
              if (i != items.length - 1)
                Divider(
                  height: 1,
                  indent: 68,
                  endIndent: 16,
                  color: Colors.white.withOpacity(0.09),
                ),
            ],
          ],
        ),
      ),
    ],
  );
}

class _Item extends StatelessWidget {
  const _Item(this.icon, this.label, this.value, {this.onTap});
  final IconData icon;
  final String label;
  final String? value; // null = simple navigation row
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) => InkWell(
    onTap: onTap,
    onLongPress: value == null || value!.isEmpty
        ? null
        : () {
            Clipboard.setData(ClipboardData(text: value!));
            Get.snackbar('Copied', value!);
          },
    child: Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: _orange.withOpacity(0.16),
            ),
            child: Icon(icon, size: 20, color: _amber),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: value == null
                ? Text(
                    label,
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                      fontSize: 15,
                    ),
                  )
                : Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        label,
                        style: const TextStyle(
                          color: Colors.white54,
                          fontSize: 12,
                        ),
                      ),
                      const SizedBox(height: 1),
                      Text(
                        value!.isEmpty ? '—' : value!,
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w700,
                          fontSize: 15,
                        ),
                      ),
                    ],
                  ),
          ),
          if (onTap != null)
            const Icon(
              Icons.chevron_right_rounded,
              size: 22,
              color: Colors.white38,
            ),
        ],
      ),
    ),
  );
}

class _LogoutButton extends StatelessWidget {
  const _LogoutButton();

  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: () async {
      await FirebaseAuth.instance.signOut();
      Get.offAll(() => const LoginView());
    },
    child: Container(
      height: 54,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(40),
        color: _red.withOpacity(0.12),
        border: Border.all(color: _red.withOpacity(0.7), width: 1.4),
      ),
      child: const Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.logout_rounded, color: _red, size: 20),
          SizedBox(width: 8),
          Text(
            'Log out',
            style: TextStyle(
              color: _red,
              fontWeight: FontWeight.w800,
              fontSize: 16,
            ),
          ),
        ],
      ),
    ),
  );
}

Future<void> _open(Uri uri, String copyText) async {
  try {
    if (await launchUrl(uri, mode: LaunchMode.externalApplication)) return;
  } catch (_) {}
  await Clipboard.setData(ClipboardData(text: copyText));
  Get.snackbar('Copied', copyText);
}

// =========================================================
// EDIT PROFILE (writes to Firestore, screen updates live)
// =========================================================
InputDecoration _fieldDeco(String label, IconData icon) => InputDecoration(
  labelText: label,
  labelStyle: const TextStyle(color: Colors.white60),
  floatingLabelStyle: const TextStyle(color: _amber),
  prefixIcon: Icon(icon, color: _amber),
  filled: true,
  fillColor: Colors.white.withOpacity(0.08),
  enabledBorder: OutlineInputBorder(
    borderRadius: BorderRadius.circular(18),
    borderSide: BorderSide(color: Colors.white.withOpacity(0.18)),
  ),
  focusedBorder: OutlineInputBorder(
    borderRadius: BorderRadius.circular(18),
    borderSide: const BorderSide(color: _orange, width: 2),
  ),
);

Future<void> _editProfile(BuildContext context, UserModel user) async {
  final name = TextEditingController(text: user.name);
  final phone = TextEditingController(text: user.phone);
  final saving = false.obs;

  await showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: const Color(0xFF14104A),
    shape: RoundedRectangleBorder(
      borderRadius: const BorderRadius.vertical(top: Radius.circular(30)),
      side: BorderSide(color: Colors.white.withOpacity(0.14)),
    ),
    builder: (ctx) => Padding(
      padding: EdgeInsets.fromLTRB(
        22,
        14,
        22,
        MediaQuery.of(ctx).viewInsets.bottom + 24,
      ),
      child: Center(
        heightFactor: 1,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 500),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 44,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.white24,
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
              ),
              const SizedBox(height: 18),
              const Text(
                'Edit profile',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 18),
              TextField(
                controller: name,
                cursorColor: _orange,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w600,
                ),
                decoration: _fieldDeco('Full name', Icons.person_rounded),
              ),
              const SizedBox(height: 14),
              TextField(
                controller: phone,
                keyboardType: TextInputType.phone,
                cursorColor: _orange,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w600,
                ),
                decoration: _fieldDeco('Phone', Icons.call_rounded),
              ),
              const SizedBox(height: 22),
              Obx(
                () => GestureDetector(
                  onTap: saving.value
                      ? null
                      : () async {
                          final n = name.text.trim();
                          final p = phone.text.trim();
                          if (n.isEmpty || p.isEmpty) {
                            Get.snackbar(
                              'Missing info',
                              'Name and phone cannot be empty',
                            );
                            return;
                          }
                          saving.value = true;
                          try {
                            await FirebaseFirestore.instance
                                .collection('users')
                                .doc(user.uid)
                                .update({'name': n, 'phone': p});
                            await FirebaseAuth.instance.currentUser
                                ?.updateDisplayName(n);
                            if (ctx.mounted) Navigator.of(ctx).pop();
                          } catch (_) {
                            Get.snackbar(
                              'Error',
                              'Could not update your profile',
                            );
                          } finally {
                            saving.value = false;
                          }
                        },
                  child: Container(
                    height: 54,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(40),
                      gradient: const LinearGradient(colors: [_amber, _orange]),
                      boxShadow: [
                        BoxShadow(
                          color: _orange.withOpacity(0.45),
                          blurRadius: 20,
                          offset: const Offset(0, 8),
                        ),
                      ],
                    ),
                    child: saving.value
                        ? const SizedBox(
                            width: 22,
                            height: 22,
                            child: CircularProgressIndicator(
                              strokeWidth: 2.5,
                              color: Colors.white,
                            ),
                          )
                        : const Text(
                            'Save changes',
                            style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w800,
                              fontSize: 16,
                            ),
                          ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    ),
  );

  name.dispose();
  phone.dispose();
}

// import 'package:flutter/material.dart';
// import 'package:get/get.dart';
// import 'package:twin/views/Authrization/login_page.dart';
// import '../core/theme.dart';
// import '../core/widgets.dart';
// import '../data/models.dart';
// import 'chat_view.dart';
// import 'extras_view.dart';
// import 'invoices_view.dart';
// import 'login_view.dart';

// class AccountView extends StatelessWidget {
//   const AccountView({super.key});
//   @override
//   Widget build(BuildContext context) {
//     Widget tile(IconData i, String t, VoidCallback f) => InkWell(
//       onTap: f,
//       child: Padding(
//         padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
//         child: Row(
//           children: [
//             Icon(i, size: 19, color: C.blue),
//             const SizedBox(width: 12),
//             Expanded(
//               child: Text(
//                 t,
//                 style: const TextStyle(fontWeight: FontWeight.w600),
//               ),
//             ),
//             const Icon(Icons.chevron_right, size: 18),
//           ],
//         ),
//       ),
//     );
//     Widget group(String t, List<Widget> l) => Column(
//       crossAxisAlignment: CrossAxisAlignment.start,
//       children: [
//         gap(18),
//         Text(
//           t,
//           style: const TextStyle(
//             fontWeight: FontWeight.w700,
//             color: C.soft,
//             fontSize: 13,
//           ),
//         ),
//         gap(8),
//         Container(
//           decoration: BoxDecoration(
//             color: Colors.white,
//             borderRadius: BorderRadius.circular(14),
//           ),
//           child: Column(children: l),
//         ),
//       ],
//     );
//     return Body(
//       ListView(
//         padding: const EdgeInsets.all(20),
//         children: [
//           const Row(
//             children: [
//               CircleAvatar(
//                 radius: 30,
//                 backgroundColor: C.ink,
//                 child: Text(
//                   'S',
//                   style: TextStyle(
//                     color: Colors.white,
//                     fontSize: 22,
//                     fontWeight: FontWeight.w800,
//                   ),
//                 ),
//               ),
//               SizedBox(width: 14),
//               Column(
//                 crossAxisAlignment: CrossAxisAlignment.start,
//                 children: [
//                   Text(
//                     'Sarah Malik',
//                     style: TextStyle(fontWeight: FontWeight.w800, fontSize: 18),
//                   ),
//                   Text('sarah.malik@email.com'),
//                   Text('(201) 555-0148'),
//                 ],
//               ),
//             ],
//           ),
//           group('Saved addresses', [
//             for (final a in kAddresses)
//               tile(Icons.location_on_outlined, a, () {}),
//             tile(Icons.add, 'Add new address', () => toast('Add address form')),
//           ]),
//           group('Payment methods', [
//             tile(Icons.credit_card, 'Visa •••• 4242', () {}),
//             tile(
//               Icons.add,
//               'Add payment method',
//               () => toast('Handled by payment processor'),
//             ),
//           ]),
//           group('Activity', [
//             tile(
//               Icons.payments_outlined,
//               'Invoices & payments',
//               () => Get.to(() => const InvoicesView()),
//             ),
//             tile(
//               Icons.chat_bubble_outline,
//               'Messages',
//               () => Get.to(() => const ChatPage()),
//             ),
//             tile(
//               Icons.notifications_outlined,
//               'Notifications',
//               () => Get.to(() => const NotificationsView()),
//             ),
//             tile(
//               Icons.star_outline,
//               'Reviews',
//               () => Get.to(() => ReviewsView()),
//             ),
//           ]),
//           group('Company', [
//             tile(
//               Icons.account_balance_outlined,
//               'Business & government documents',
//               () => Get.to(() => const GovDocsView()),
//             ),
//             tile(
//               Icons.call_outlined,
//               'Call Twins Handyman',
//               () => toast('Calling… (demo)'),
//             ),
//             tile(
//               Icons.dashboard_outlined,
//               'Owner dashboard (preview)',
//               () => Get.to(() => const AdminView()),
//             ),
//           ]),
//           gap(18),
//           OutlinedButton(
//             onPressed: () => Get.offAll(() => LoginView()),
//             style: OutlinedButton.styleFrom(
//               foregroundColor: C.red,
//               minimumSize: const Size.fromHeight(48),
//             ),
//             child: const Text('Log out'),
//           ),
//         ],
//       ),
//     );
//   }
// }
