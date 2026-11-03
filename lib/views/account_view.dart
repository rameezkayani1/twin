import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:twin/views/mainsplash.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:twin/views/Authrization/login_page.dart';
// UserModel lives in your register file - adjust the file name if different.
import 'package:twin/views/Authrization/register_page.dart' show UserModel;
import 'chat_view.dart';
import 'extras_view.dart';
import 'invoices_view.dart';

// ── Palette: clean light UI + orange accent ─────────────────────────────────
const _orange = Color(0xFFFF7A00);
const _orangeSoft = Color(0xFFFFF1E3);
const _bg = Color(0xFFF5F6FA);
const _card = Colors.white;
const _border = Color(0xFFE8EAF0);
const _ink = Color(0xFF14142B);
const _muted = Color(0xFF6B7280);
const _red = Color(0xFFE5484D);

// =========================================================
// ACCOUNT VIEW  (live data from Firestore: users/{uid})
// =========================================================
class AccountView extends StatelessWidget {
  const AccountView({super.key});

  @override
  Widget build(BuildContext context) {
    final authUser = FirebaseAuth.instance.currentUser;

    return Scaffold(
      backgroundColor: _bg,
      body: SafeArea(
        child: authUser == null
            ? const Center(
                child: Text(
                  'You are not logged in',
                  style: TextStyle(color: _muted),
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
                        style: TextStyle(color: _muted),
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
    );
  }
}

// ── Simple white card ───────────────────────────────────────────────────────
class _Card extends StatelessWidget {
  const _Card({required this.child, this.padding = EdgeInsets.zero});
  final Widget child;
  final EdgeInsets padding;

  @override
  Widget build(BuildContext context) => Container(
    width: double.infinity,
    padding: padding,
    decoration: BoxDecoration(
      color: _card,
      borderRadius: BorderRadius.circular(16),
      border: Border.all(color: _border),
    ),
    child: ClipRRect(borderRadius: BorderRadius.circular(16), child: child),
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
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
          children: [
            const Padding(
              padding: EdgeInsets.fromLTRB(4, 4, 4, 16),
              child: Text(
                'Account',
                style: TextStyle(
                  color: _ink,
                  fontSize: 28,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),

            _Header(user: user),

            _Group('Profile', [
              _Item(Icons.person_outline_rounded, 'Name', user.name),
              _Item(Icons.mail_outline_rounded, 'Email', user.email),
              _Item(Icons.call_outlined, 'Phone', user.phone),
            ]),

            _Group('Activity', [
              _Item(
                Icons.receipt_long_outlined,
                'Invoices & payments',
                null,
                onTap: () => Get.to(() => const InvoicesView()),
              ),
              _Item(
                Icons.chat_bubble_outline_rounded,
                'Messages',
                null,
                onTap: () => Get.to(() => const ChatPage()),
              ),
              _Item(
                Icons.notifications_none_rounded,
                'Notifications',
                null,
                onTap: () => Get.to(() => const NotificationsView()),
              ),
              _Item(
                Icons.star_border_rounded,
                'Reviews',
                null,
                onTap: () => Get.to(() => ReviewsView()),
              ),
            ]),

            _Group('Contact us', [
              _Item(
                Icons.call_outlined,
                'Phone',
                '908-803-8111',
                onTap: () => _open(
                  Uri(scheme: 'tel', path: '+19088038111'),
                  '908-803-8111',
                ),
              ),
              _Item(
                Icons.phone_forwarded_outlined,
                'Phone',
                '908-567-9897',
                onTap: () => _open(
                  Uri(scheme: 'tel', path: '+19085679897'),
                  '908-567-9897',
                ),
              ),
              _Item(
                Icons.mail_outline_rounded,
                'Email',
                'mathew@twinshandymanllc.com',
                onTap: () => _open(
                  Uri(scheme: 'mailto', path: 'mathew@twinshandymanllc.com'),
                  'mathew@twinshandymanllc.com',
                ),
              ),
              _Item(
                Icons.location_on_outlined,
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
              _Item(Icons.access_time_rounded, 'Hours', '9:00 AM – 9:00 PM'),
            ]),

            _Group('Company', [
              _Item(
                Icons.account_balance_outlined,
                'Business & government documents',
                null,
                onTap: () => Get.to(() => const GovDocsView()),
              ),
              if (user.role == 'admin')
                _Item(
                  Icons.dashboard_outlined,
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
// HEADER  (avatar + name + email + role)
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
    return 'Member since ${m[d.month - 1]} ${d.year}';
  }

  @override
  Widget build(BuildContext context) {
    return _Card(
      padding: const EdgeInsets.all(18),
      child: Row(
        children: [
          CircleAvatar(
            radius: 30,
            backgroundColor: _orangeSoft,
            child: Text(
              _initials,
              style: const TextStyle(
                color: _orange,
                fontSize: 20,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  user.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: _ink,
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  user.email,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(color: _muted, fontSize: 13.5),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 9,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        color: _orangeSoft,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        user.role.toUpperCase(),
                        style: const TextStyle(
                          color: _orange,
                          fontSize: 11,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 0.6,
                        ),
                      ),
                    ),
                    if (_since != null) ...[
                      const SizedBox(width: 8),
                      Flexible(
                        child: Text(
                          _since!,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(color: _muted, fontSize: 12),
                        ),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),
          IconButton(
            tooltip: 'Edit profile',
            onPressed: () => showProfileSheet(
              context,
              uid: user.uid,
              name: user.name == 'Customer' ? '' : user.name,
              phone: user.phone,
            ),
            icon: const Icon(Icons.edit_outlined, color: _ink, size: 20),
          ),
        ],
      ),
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
      Padding(
        padding: const EdgeInsets.fromLTRB(6, 24, 0, 8),
        child: Text(
          title.toUpperCase(),
          style: const TextStyle(
            color: _muted,
            fontWeight: FontWeight.w700,
            fontSize: 12,
            letterSpacing: 1.2,
          ),
        ),
      ),
      _Card(
        child: Column(
          children: [
            for (var i = 0; i < items.length; i++) ...[
              items[i],
              if (i != items.length - 1)
                const Divider(
                  height: 1,
                  thickness: 1,
                  indent: 62,
                  color: _border,
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
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(10),
              color: _orangeSoft,
            ),
            child: Icon(icon, size: 19, color: _orange),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: value == null
                ? Text(
                    label,
                    style: const TextStyle(
                      color: _ink,
                      fontWeight: FontWeight.w600,
                      fontSize: 15,
                    ),
                  )
                : Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        label,
                        style: const TextStyle(color: _muted, fontSize: 12),
                      ),
                      const SizedBox(height: 1),
                      Text(
                        value!.isEmpty ? '—' : value!,
                        style: const TextStyle(
                          color: _ink,
                          fontWeight: FontWeight.w600,
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
              color: Color(0xFFB4B8C5),
            ),
        ],
      ),
    ),
  );
}

class _LogoutButton extends StatelessWidget {
  const _LogoutButton();

  @override
  Widget build(BuildContext context) => SizedBox(
    height: 52,
    child: OutlinedButton.icon(
      onPressed: () async {
        await FirebaseAuth.instance.signOut();
        Get.offAll(() => const SplashLogin());
      },
      icon: const Icon(Icons.logout_rounded, size: 20),
      label: const Text(
        'Log out',
        style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15.5),
      ),
      style: OutlinedButton.styleFrom(
        foregroundColor: _red,
        backgroundColor: _card,
        side: const BorderSide(color: _border),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
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
// PROFILE EDITOR
// Used by the Account page (optional sheet) and by ShellView
// (mandatory dialog when name / phone is empty).
// =========================================================

/// Optional edit from the Account page (bottom sheet, can be dismissed).
Future<bool?> showProfileSheet(
  BuildContext context, {
  required String uid,
  String name = '',
  String phone = '',
}) {
  return showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.white,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
    ),
    builder: (sheetCtx) => Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(sheetCtx).viewInsets.bottom,
      ),
      child: SingleChildScrollView(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 500),
            child: ProfileForm(
              uid: uid,
              initialName: name,
              initialPhone: phone,
            ),
          ),
        ),
      ),
    ),
  );
}

/// Mandatory dialog: cannot be dismissed until name + phone are saved.
Future<bool?> showCompleteProfileDialog(
  BuildContext context, {
  required String uid,
  String name = '',
  String phone = '',
}) {
  return showDialog<bool>(
    context: context,
    barrierDismissible: false,
    builder: (_) => PopScope(
      canPop: false, // blocks the Android back button too
      child: Dialog(
        backgroundColor: Colors.white,
        insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 440),
          child: SingleChildScrollView(
            child: ProfileForm(
              uid: uid,
              initialName: name,
              initialPhone: phone,
              mandatory: true,
            ),
          ),
        ),
      ),
    ),
  );
}

class ProfileForm extends StatefulWidget {
  const ProfileForm({
    super.key,
    required this.uid,
    this.initialName = '',
    this.initialPhone = '',
    this.mandatory = false,
  });

  final String uid;
  final String initialName;
  final String initialPhone;
  final bool mandatory;

  @override
  State<ProfileForm> createState() => _ProfileFormState();
}

class _ProfileFormState extends State<ProfileForm> {
  late final TextEditingController _name = TextEditingController(
    text: widget.initialName,
  );
  late final TextEditingController _phone = TextEditingController(
    text: widget.initialPhone,
  );
  bool _saving = false;
  String? _nameErr, _phoneErr, _formErr;

  @override
  void dispose() {
    // Safe: the State owns the controllers, so they die with the widget
    // (fixes "TextEditingController used after being disposed").
    _name.dispose();
    _phone.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final n = _name.text.trim();
    final p = _phone.text.trim();
    final digits = p.replaceAll(RegExp(r'\D'), '');

    setState(() {
      _nameErr = n.isEmpty ? 'Please enter your full name' : null;
      _phoneErr = digits.length < 7 ? 'Enter a valid phone number' : null;
      _formErr = null;
    });
    if (_nameErr != null || _phoneErr != null) return;

    setState(() => _saving = true);
    try {
      final user = FirebaseAuth.instance.currentUser;

      // set(merge) works whether or not the document already exists
      // (update() throws "not-found" when users/{uid} is missing).
      await FirebaseFirestore.instance.collection('users').doc(widget.uid).set({
        'uid': widget.uid,
        if ((user?.email ?? '').isNotEmpty) 'email': user!.email,
        'name': n,
        'phone': p,
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      // Non-critical: never let this fail the whole save
      try {
        await user?.updateDisplayName(n);
      } catch (_) {}

      if (mounted) Navigator.of(context).pop(true);
    } on FirebaseException catch (e) {
      if (!mounted) return;
      setState(() {
        _saving = false;
        _formErr = e.code == 'permission-denied'
            ? 'Permission denied. Check your Firestore rules for users/{uid}.'
            : 'Could not save your profile (${e.code}). Please try again.';
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _saving = false;
        _formErr = 'Something went wrong. Please try again.';
      });
    }
  }

  InputDecoration _deco(String label, IconData icon, String? error) =>
      InputDecoration(
        labelText: label,
        errorText: error,
        labelStyle: const TextStyle(color: _muted),
        floatingLabelStyle: const TextStyle(color: _orange),
        prefixIcon: Icon(icon, color: _muted, size: 20),
        filled: true,
        fillColor: _bg,
        contentPadding: const EdgeInsets.symmetric(
          vertical: 16,
          horizontal: 14,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: _border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: _orange, width: 1.6),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: _red),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: _red, width: 1.6),
        ),
      );

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(22, 22, 22, 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (widget.mandatory) ...[
            Center(
              child: Container(
                width: 64,
                height: 64,
                decoration: const BoxDecoration(
                  color: _orangeSoft,
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.person_add_alt_1_rounded,
                  color: _orange,
                  size: 30,
                ),
              ),
            ),
            const SizedBox(height: 16),
            const Center(
              child: Text(
                'Complete your profile',
                style: TextStyle(
                  color: _ink,
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
            const SizedBox(height: 6),
            const Center(
              child: Text(
                'Add your name and phone number so we can\nreach you about your quotes and jobs.',
                textAlign: TextAlign.center,
                style: TextStyle(color: _muted, fontSize: 13.5, height: 1.4),
              ),
            ),
          ] else
            const Text(
              'Edit profile',
              style: TextStyle(
                color: _ink,
                fontSize: 20,
                fontWeight: FontWeight.w800,
              ),
            ),
          const SizedBox(height: 20),
          TextField(
            controller: _name,
            enabled: !_saving,
            cursorColor: _orange,
            textCapitalization: TextCapitalization.words,
            textInputAction: TextInputAction.next,
            style: const TextStyle(color: _ink, fontWeight: FontWeight.w600),
            decoration: _deco('Full name', Icons.person_outline, _nameErr),
          ),
          const SizedBox(height: 14),
          TextField(
            controller: _phone,
            enabled: !_saving,
            cursorColor: _orange,
            keyboardType: TextInputType.phone,
            textInputAction: TextInputAction.done,
            onSubmitted: (_) => _save(),
            style: const TextStyle(color: _ink, fontWeight: FontWeight.w600),
            decoration: _deco('Phone', Icons.call_outlined, _phoneErr),
          ),
          if (_formErr != null) ...[
            const SizedBox(height: 12),
            Text(_formErr!, style: const TextStyle(color: _red, fontSize: 13)),
          ],
          const SizedBox(height: 22),
          SizedBox(
            width: double.infinity,
            height: 52,
            child: ElevatedButton(
              onPressed: _saving ? null : _save,
              style: ElevatedButton.styleFrom(
                backgroundColor: _orange,
                foregroundColor: Colors.white,
                disabledBackgroundColor: _orange.withOpacity(0.6),
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
              child: _saving
                  ? const SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(
                        strokeWidth: 2.5,
                        color: Colors.white,
                      ),
                    )
                  : Text(
                      widget.mandatory ? 'Save & continue' : 'Save changes',
                      style: const TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 16,
                      ),
                    ),
            ),
          ),
          SizedBox(height: 50),
        ],
      ),
    );
  }
}

// import 'package:flutter/material.dart';
// import 'package:flutter/services.dart';
// import 'package:get/get.dart';
// import 'package:twin/views/mainsplash.dart';
// import 'package:url_launcher/url_launcher.dart';
// import 'package:firebase_auth/firebase_auth.dart';
// import 'package:cloud_firestore/cloud_firestore.dart';
// import 'package:twin/views/Authrization/login_page.dart';
// // UserModel lives in your register file - adjust the file name if different.
// import 'package:twin/views/Authrization/register_page.dart' show UserModel;
// import 'chat_view.dart';
// import 'extras_view.dart';
// import 'invoices_view.dart';

// // ── Palette: clean light UI + orange accent ─────────────────────────────────
// const _orange = Color(0xFFFF7A00);
// const _orangeSoft = Color(0xFFFFF1E3);
// const _bg = Color(0xFFF5F6FA);
// const _card = Colors.white;
// const _border = Color(0xFFE8EAF0);
// const _ink = Color(0xFF14142B);
// const _muted = Color(0xFF6B7280);
// const _red = Color(0xFFE5484D);

// // =========================================================
// // ACCOUNT VIEW  (live data from Firestore: users/{uid})
// // =========================================================
// class AccountView extends StatelessWidget {
//   const AccountView({super.key});

//   @override
//   Widget build(BuildContext context) {
//     final authUser = FirebaseAuth.instance.currentUser;

//     return Scaffold(
//       backgroundColor: _bg,
//       body: SafeArea(
//         child: authUser == null
//             ? const Center(
//                 child: Text(
//                   'You are not logged in',
//                   style: TextStyle(color: _muted),
//                 ),
//               )
//             : StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
//                 stream: FirebaseFirestore.instance
//                     .collection('users')
//                     .doc(authUser.uid)
//                     .snapshots(),
//                 builder: (context, snap) {
//                   if (snap.hasError) {
//                     return const Center(
//                       child: Text(
//                         'Could not load your profile',
//                         style: TextStyle(color: _muted),
//                       ),
//                     );
//                   }
//                   if (!snap.hasData) {
//                     return const Center(
//                       child: CircularProgressIndicator(color: _orange),
//                     );
//                   }
//                   final data = snap.data!.data();
//                   final user = data != null
//                       ? UserModel.fromMap(data)
//                       : UserModel(
//                           uid: authUser.uid,
//                           name: authUser.displayName ?? 'Customer',
//                           email: authUser.email ?? '',
//                           phone: authUser.phoneNumber ?? '',
//                         );
//                   return _Page(user: user);
//                 },
//               ),
//       ),
//     );
//   }
// }

// // ── Simple white card ───────────────────────────────────────────────────────
// class _Card extends StatelessWidget {
//   const _Card({required this.child, this.padding = EdgeInsets.zero});
//   final Widget child;
//   final EdgeInsets padding;

//   @override
//   Widget build(BuildContext context) => Container(
//     width: double.infinity,
//     padding: padding,
//     decoration: BoxDecoration(
//       color: _card,
//       borderRadius: BorderRadius.circular(16),
//       border: Border.all(color: _border),
//     ),
//     child: ClipRRect(borderRadius: BorderRadius.circular(16), child: child),
//   );
// }

// // =========================================================
// // PAGE  (one scrolling column, centred on big screens)
// // =========================================================
// class _Page extends StatelessWidget {
//   const _Page({required this.user});
//   final UserModel user;

//   @override
//   Widget build(BuildContext context) {
//     return Center(
//       child: ConstrainedBox(
//         constraints: const BoxConstraints(maxWidth: 600),
//         child: ListView(
//           padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
//           children: [
//             const Padding(
//               padding: EdgeInsets.fromLTRB(4, 4, 4, 16),
//               child: Text(
//                 'Account',
//                 style: TextStyle(
//                   color: _ink,
//                   fontSize: 28,
//                   fontWeight: FontWeight.w800,
//                 ),
//               ),
//             ),

//             _Header(user: user),

//             _Group('Profile', [
//               _Item(Icons.person_outline_rounded, 'Name', user.name),
//               _Item(Icons.mail_outline_rounded, 'Email', user.email),
//               _Item(Icons.call_outlined, 'Phone', user.phone),
//             ]),

//             _Group('Activity', [
//               _Item(
//                 Icons.receipt_long_outlined,
//                 'Invoices & payments',
//                 null,
//                 onTap: () => Get.to(() => const InvoicesView()),
//               ),
//               _Item(
//                 Icons.chat_bubble_outline_rounded,
//                 'Messages',
//                 null,
//                 onTap: () => Get.to(() => const ChatPage()),
//               ),
//               _Item(
//                 Icons.notifications_none_rounded,
//                 'Notifications',
//                 null,
//                 onTap: () => Get.to(() => const NotificationsView()),
//               ),
//               _Item(
//                 Icons.star_border_rounded,
//                 'Reviews',
//                 null,
//                 onTap: () => Get.to(() => ReviewsView()),
//               ),
//             ]),

//             _Group('Contact us', [
//               _Item(
//                 Icons.call_outlined,
//                 'Phone',
//                 '908-803-8111',
//                 onTap: () => _open(
//                   Uri(scheme: 'tel', path: '+19088038111'),
//                   '908-803-8111',
//                 ),
//               ),
//               _Item(
//                 Icons.phone_forwarded_outlined,
//                 'Phone',
//                 '908-567-9897',
//                 onTap: () => _open(
//                   Uri(scheme: 'tel', path: '+19085679897'),
//                   '908-567-9897',
//                 ),
//               ),
//               _Item(
//                 Icons.mail_outline_rounded,
//                 'Email',
//                 'mathew@twinshandymanllc.com',
//                 onTap: () => _open(
//                   Uri(scheme: 'mailto', path: 'mathew@twinshandymanllc.com'),
//                   'mathew@twinshandymanllc.com',
//                 ),
//               ),
//               _Item(
//                 Icons.location_on_outlined,
//                 'Address',
//                 '1156 Liberty Avenue, Hillside, NJ 07205',
//                 onTap: () => _open(
//                   Uri.https('www.google.com', '/maps/search/', {
//                     'api': '1',
//                     'query': '1156 Liberty Avenue, Hillside, NJ 07205',
//                   }),
//                   '1156 Liberty Avenue, Hillside, NJ 07205',
//                 ),
//               ),
//               _Item(Icons.access_time_rounded, 'Hours', '9:00 AM – 9:00 PM'),
//             ]),

//             _Group('Company', [
//               _Item(
//                 Icons.account_balance_outlined,
//                 'Business & government documents',
//                 null,
//                 onTap: () => Get.to(() => const GovDocsView()),
//               ),
//               if (user.role == 'admin')
//                 _Item(
//                   Icons.dashboard_outlined,
//                   'Owner dashboard',
//                   null,
//                   onTap: () => Get.to(() => const AdminView()),
//                 ),
//             ]),

//             const SizedBox(height: 28),
//             const _LogoutButton(),
//           ],
//         ),
//       ),
//     );
//   }
// }

// // =========================================================
// // HEADER  (avatar + name + email + role)
// // =========================================================
// class _Header extends StatelessWidget {
//   const _Header({required this.user});
//   final UserModel user;

//   String get _initials {
//     final parts = user.name.trim().split(RegExp(r'\s+'));
//     if (parts.isEmpty || parts.first.isEmpty) return '?';
//     final a = parts.first[0];
//     final b = parts.length > 1 ? parts.last[0] : '';
//     return (a + b).toUpperCase();
//   }

//   String? get _since {
//     final d = user.createdAt;
//     if (d == null) return null;
//     const m = [
//       'Jan',
//       'Feb',
//       'Mar',
//       'Apr',
//       'May',
//       'Jun',
//       'Jul',
//       'Aug',
//       'Sep',
//       'Oct',
//       'Nov',
//       'Dec',
//     ];
//     return 'Member since ${m[d.month - 1]} ${d.year}';
//   }

//   @override
//   Widget build(BuildContext context) {
//     return _Card(
//       padding: const EdgeInsets.all(18),
//       child: Row(
//         children: [
//           CircleAvatar(
//             radius: 30,
//             backgroundColor: _orangeSoft,
//             child: Text(
//               _initials,
//               style: const TextStyle(
//                 color: _orange,
//                 fontSize: 20,
//                 fontWeight: FontWeight.w800,
//               ),
//             ),
//           ),
//           const SizedBox(width: 16),
//           Expanded(
//             child: Column(
//               crossAxisAlignment: CrossAxisAlignment.start,
//               children: [
//                 Text(
//                   user.name,
//                   maxLines: 1,
//                   overflow: TextOverflow.ellipsis,
//                   style: const TextStyle(
//                     color: _ink,
//                     fontSize: 18,
//                     fontWeight: FontWeight.w700,
//                   ),
//                 ),
//                 const SizedBox(height: 2),
//                 Text(
//                   user.email,
//                   maxLines: 1,
//                   overflow: TextOverflow.ellipsis,
//                   style: const TextStyle(color: _muted, fontSize: 13.5),
//                 ),
//                 const SizedBox(height: 8),
//                 Row(
//                   children: [
//                     Container(
//                       padding: const EdgeInsets.symmetric(
//                         horizontal: 9,
//                         vertical: 3,
//                       ),
//                       decoration: BoxDecoration(
//                         color: _orangeSoft,
//                         borderRadius: BorderRadius.circular(20),
//                       ),
//                       child: Text(
//                         user.role.toUpperCase(),
//                         style: const TextStyle(
//                           color: _orange,
//                           fontSize: 11,
//                           fontWeight: FontWeight.w800,
//                           letterSpacing: 0.6,
//                         ),
//                       ),
//                     ),
//                     if (_since != null) ...[
//                       const SizedBox(width: 8),
//                       Flexible(
//                         child: Text(
//                           _since!,
//                           overflow: TextOverflow.ellipsis,
//                           style: const TextStyle(color: _muted, fontSize: 12),
//                         ),
//                       ),
//                     ],
//                   ],
//                 ),
//               ],
//             ),
//           ),
//           IconButton(
//             tooltip: 'Edit profile',
//             onPressed: () => _editProfile(context, user),
//             icon: const Icon(Icons.edit_outlined, color: _ink, size: 20),
//           ),
//         ],
//       ),
//     );
//   }
// }

// // =========================================================
// // SECTION BLOCKS
// // =========================================================
// class _Group extends StatelessWidget {
//   const _Group(this.title, this.items);
//   final String title;
//   final List<Widget> items;

//   @override
//   Widget build(BuildContext context) => Column(
//     crossAxisAlignment: CrossAxisAlignment.start,
//     children: [
//       Padding(
//         padding: const EdgeInsets.fromLTRB(6, 24, 0, 8),
//         child: Text(
//           title.toUpperCase(),
//           style: const TextStyle(
//             color: _muted,
//             fontWeight: FontWeight.w700,
//             fontSize: 12,
//             letterSpacing: 1.2,
//           ),
//         ),
//       ),
//       _Card(
//         child: Column(
//           children: [
//             for (var i = 0; i < items.length; i++) ...[
//               items[i],
//               if (i != items.length - 1)
//                 const Divider(
//                   height: 1,
//                   thickness: 1,
//                   indent: 62,
//                   color: _border,
//                 ),
//             ],
//           ],
//         ),
//       ),
//     ],
//   );
// }

// class _Item extends StatelessWidget {
//   const _Item(this.icon, this.label, this.value, {this.onTap});
//   final IconData icon;
//   final String label;
//   final String? value; // null = simple navigation row
//   final VoidCallback? onTap;

//   @override
//   Widget build(BuildContext context) => InkWell(
//     onTap: onTap,
//     onLongPress: value == null || value!.isEmpty
//         ? null
//         : () {
//             Clipboard.setData(ClipboardData(text: value!));
//             Get.snackbar('Copied', value!);
//           },
//     child: Padding(
//       padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
//       child: Row(
//         children: [
//           Container(
//             width: 36,
//             height: 36,
//             decoration: BoxDecoration(
//               borderRadius: BorderRadius.circular(10),
//               color: _orangeSoft,
//             ),
//             child: Icon(icon, size: 19, color: _orange),
//           ),
//           const SizedBox(width: 14),
//           Expanded(
//             child: value == null
//                 ? Text(
//                     label,
//                     style: const TextStyle(
//                       color: _ink,
//                       fontWeight: FontWeight.w600,
//                       fontSize: 15,
//                     ),
//                   )
//                 : Column(
//                     crossAxisAlignment: CrossAxisAlignment.start,
//                     children: [
//                       Text(
//                         label,
//                         style: const TextStyle(color: _muted, fontSize: 12),
//                       ),
//                       const SizedBox(height: 1),
//                       Text(
//                         value!.isEmpty ? '—' : value!,
//                         style: const TextStyle(
//                           color: _ink,
//                           fontWeight: FontWeight.w600,
//                           fontSize: 15,
//                         ),
//                       ),
//                     ],
//                   ),
//           ),
//           if (onTap != null)
//             const Icon(
//               Icons.chevron_right_rounded,
//               size: 22,
//               color: Color(0xFFB4B8C5),
//             ),
//         ],
//       ),
//     ),
//   );
// }

// class _LogoutButton extends StatelessWidget {
//   const _LogoutButton();

//   @override
//   Widget build(BuildContext context) => SizedBox(
//     height: 52,
//     child: OutlinedButton.icon(
//       onPressed: () async {
//         await FirebaseAuth.instance.signOut();
//         Get.offAll(() => const SplashLogin());
//       },
//       icon: const Icon(Icons.logout_rounded, size: 20),
//       label: const Text(
//         'Log out',
//         style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15.5),
//       ),
//       style: OutlinedButton.styleFrom(
//         foregroundColor: _red,
//         backgroundColor: _card,
//         side: const BorderSide(color: _border),
//         shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
//       ),
//     ),
//   );
// }

// Future<void> _open(Uri uri, String copyText) async {
//   try {
//     if (await launchUrl(uri, mode: LaunchMode.externalApplication)) return;
//   } catch (_) {}
//   await Clipboard.setData(ClipboardData(text: copyText));
//   Get.snackbar('Copied', copyText);
// }

// // =========================================================
// // EDIT PROFILE (writes to Firestore, screen updates live)
// // =========================================================
// InputDecoration _fieldDeco(String label, IconData icon) => InputDecoration(
//   labelText: label,
//   labelStyle: const TextStyle(color: _muted),
//   floatingLabelStyle: const TextStyle(color: _orange),
//   prefixIcon: Icon(icon, color: _muted, size: 20),
//   filled: true,
//   fillColor: _bg,
//   contentPadding: const EdgeInsets.symmetric(vertical: 16, horizontal: 14),
//   enabledBorder: OutlineInputBorder(
//     borderRadius: BorderRadius.circular(12),
//     borderSide: const BorderSide(color: _border),
//   ),
//   focusedBorder: OutlineInputBorder(
//     borderRadius: BorderRadius.circular(12),
//     borderSide: const BorderSide(color: _orange, width: 1.6),
//   ),
// );

// Future<void> _editProfile(BuildContext context, UserModel user) async {
//   final name = TextEditingController(text: user.name);
//   final phone = TextEditingController(text: user.phone);
//   final saving = false.obs;

//   await showModalBottomSheet(
//     context: context,
//     isScrollControlled: true,
//     backgroundColor: Colors.white,
//     shape: const RoundedRectangleBorder(
//       borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
//     ),
//     builder: (ctx) => Padding(
//       padding: EdgeInsets.fromLTRB(
//         22,
//         12,
//         22,
//         MediaQuery.of(ctx).viewInsets.bottom + 24,
//       ),
//       child: Center(
//         heightFactor: 1,
//         child: ConstrainedBox(
//           constraints: const BoxConstraints(maxWidth: 500),
//           child: Column(
//             mainAxisSize: MainAxisSize.min,
//             crossAxisAlignment: CrossAxisAlignment.start,
//             children: [
//               Center(
//                 child: Container(
//                   width: 40,
//                   height: 4,
//                   decoration: BoxDecoration(
//                     color: _border,
//                     borderRadius: BorderRadius.circular(4),
//                   ),
//                 ),
//               ),
//               const SizedBox(height: 18),
//               const Text(
//                 'Edit profile',
//                 style: TextStyle(
//                   color: _ink,
//                   fontSize: 20,
//                   fontWeight: FontWeight.w800,
//                 ),
//               ),
//               const SizedBox(height: 18),
//               TextField(
//                 controller: name,
//                 cursorColor: _orange,
//                 style: const TextStyle(
//                   color: _ink,
//                   fontWeight: FontWeight.w600,
//                 ),
//                 decoration: _fieldDeco('Full name', Icons.person_outline),
//               ),
//               const SizedBox(height: 14),
//               TextField(
//                 controller: phone,
//                 keyboardType: TextInputType.phone,
//                 cursorColor: _orange,
//                 style: const TextStyle(
//                   color: _ink,
//                   fontWeight: FontWeight.w600,
//                 ),
//                 decoration: _fieldDeco('Phone', Icons.call_outlined),
//               ),
//               const SizedBox(height: 22),
//               Obx(
//                 () => SizedBox(
//                   width: double.infinity,
//                   height: 52,
//                   child: ElevatedButton(
//                     onPressed: saving.value
//                         ? null
//                         : () async {
//                             final n = name.text.trim();
//                             final p = phone.text.trim();
//                             if (n.isEmpty || p.isEmpty) {
//                               Get.snackbar(
//                                 'Missing info',
//                                 'Name and phone cannot be empty',
//                               );
//                               return;
//                             }
//                             saving.value = true;
//                             try {
//                               await FirebaseFirestore.instance
//                                   .collection('users')
//                                   .doc(user.uid)
//                                   .update({'name': n, 'phone': p});
//                               await FirebaseAuth.instance.currentUser
//                                   ?.updateDisplayName(n);
//                               if (ctx.mounted) Navigator.of(ctx).pop();
//                             } catch (_) {
//                               Get.snackbar(
//                                 'Error',
//                                 'Could not update your profile',
//                               );
//                             } finally {
//                               saving.value = false;
//                             }
//                           },
//                     style: ElevatedButton.styleFrom(
//                       backgroundColor: _orange,
//                       foregroundColor: Colors.white,
//                       disabledBackgroundColor: _orange.withOpacity(0.6),
//                       elevation: 0,
//                       shape: RoundedRectangleBorder(
//                         borderRadius: BorderRadius.circular(14),
//                       ),
//                     ),
//                     child: saving.value
//                         ? const SizedBox(
//                             width: 22,
//                             height: 22,
//                             child: CircularProgressIndicator(
//                               strokeWidth: 2.5,
//                               color: Colors.white,
//                             ),
//                           )
//                         : const Text(
//                             'Save changes',
//                             style: TextStyle(
//                               fontWeight: FontWeight.w700,
//                               fontSize: 16,
//                             ),
//                           ),
//                   ),
//                 ),
//               ),
//             ],
//           ),
//         ),
//       ),
//     ),
//   );

//   name.dispose();
//   phone.dispose();
// }
// // import 'package:flutter/material.dart';
// // import 'package:get/get.dart';
// // import 'package:twin/views/Authrization/login_page.dart';
// // import '../core/theme.dart';
// // import '../core/widgets.dart';
// // import '../data/models.dart';
// // import 'chat_view.dart';
// // import 'extras_view.dart';
// // import 'invoices_view.dart';
// // import 'login_view.dart';

// // class AccountView extends StatelessWidget {
// //   const AccountView({super.key});
// //   @override
// //   Widget build(BuildContext context) {
// //     Widget tile(IconData i, String t, VoidCallback f) => InkWell(
// //       onTap: f,
// //       child: Padding(
// //         padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
// //         child: Row(
// //           children: [
// //             Icon(i, size: 19, color: C.blue),
// //             const SizedBox(width: 12),
// //             Expanded(
// //               child: Text(
// //                 t,
// //                 style: const TextStyle(fontWeight: FontWeight.w600),
// //               ),
// //             ),
// //             const Icon(Icons.chevron_right, size: 18),
// //           ],
// //         ),
// //       ),
// //     );
// //     Widget group(String t, List<Widget> l) => Column(
// //       crossAxisAlignment: CrossAxisAlignment.start,
// //       children: [
// //         gap(18),
// //         Text(
// //           t,
// //           style: const TextStyle(
// //             fontWeight: FontWeight.w700,
// //             color: C.soft,
// //             fontSize: 13,
// //           ),
// //         ),
// //         gap(8),
// //         Container(
// //           decoration: BoxDecoration(
// //             color: Colors.white,
// //             borderRadius: BorderRadius.circular(14),
// //           ),
// //           child: Column(children: l),
// //         ),
// //       ],
// //     );
// //     return Body(
// //       ListView(
// //         padding: const EdgeInsets.all(20),
// //         children: [
// //           const Row(
// //             children: [
// //               CircleAvatar(
// //                 radius: 30,
// //                 backgroundColor: C.ink,
// //                 child: Text(
// //                   'S',
// //                   style: TextStyle(
// //                     color: Colors.white,
// //                     fontSize: 22,
// //                     fontWeight: FontWeight.w800,
// //                   ),
// //                 ),
// //               ),
// //               SizedBox(width: 14),
// //               Column(
// //                 crossAxisAlignment: CrossAxisAlignment.start,
// //                 children: [
// //                   Text(
// //                     'Sarah Malik',
// //                     style: TextStyle(fontWeight: FontWeight.w800, fontSize: 18),
// //                   ),
// //                   Text('sarah.malik@email.com'),
// //                   Text('(201) 555-0148'),
// //                 ],
// //               ),
// //             ],
// //           ),
// //           group('Saved addresses', [
// //             for (final a in kAddresses)
// //               tile(Icons.location_on_outlined, a, () {}),
// //             tile(Icons.add, 'Add new address', () => toast('Add address form')),
// //           ]),
// //           group('Payment methods', [
// //             tile(Icons.credit_card, 'Visa •••• 4242', () {}),
// //             tile(
// //               Icons.add,
// //               'Add payment method',
// //               () => toast('Handled by payment processor'),
// //             ),
// //           ]),
// //           group('Activity', [
// //             tile(
// //               Icons.payments_outlined,
// //               'Invoices & payments',
// //               () => Get.to(() => const InvoicesView()),
// //             ),
// //             tile(
// //               Icons.chat_bubble_outline,
// //               'Messages',
// //               () => Get.to(() => const ChatPage()),
// //             ),
// //             tile(
// //               Icons.notifications_outlined,
// //               'Notifications',
// //               () => Get.to(() => const NotificationsView()),
// //             ),
// //             tile(
// //               Icons.star_outline,
// //               'Reviews',
// //               () => Get.to(() => ReviewsView()),
// //             ),
// //           ]),
// //           group('Company', [
// //             tile(
// //               Icons.account_balance_outlined,
// //               'Business & government documents',
// //               () => Get.to(() => const GovDocsView()),
// //             ),
// //             tile(
// //               Icons.call_outlined,
// //               'Call Twins Handyman',
// //               () => toast('Calling… (demo)'),
// //             ),
// //             tile(
// //               Icons.dashboard_outlined,
// //               'Owner dashboard (preview)',
// //               () => Get.to(() => const AdminView()),
// //             ),
// //           ]),
// //           gap(18),
// //           OutlinedButton(
// //             onPressed: () => Get.offAll(() => LoginView()),
// //             style: OutlinedButton.styleFrom(
// //               foregroundColor: C.red,
// //               minimumSize: const Size.fromHeight(48),
// //             ),
// //             child: const Text('Log out'),
// //           ),
// //         ],
// //       ),
// //     );
// //   }
// // }
