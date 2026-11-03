import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:twin/views/invoices_view.dart';
import '../controllers/app_controller.dart';
import 'account_view.dart'; // also provides showCompleteProfileDialog
import 'home_view.dart';
import 'quotes_view.dart';
import 'request_view.dart';

class ShellView extends StatefulWidget {
  const ShellView({super.key});

  @override
  State<ShellView> createState() => _ShellViewState();
}

class _ShellViewState extends State<ShellView> {
  @override
  void initState() {
    super.initState();
    // Run after the first frame so the dialog has a valid context.
    WidgetsBinding.instance.addPostFrameCallback((_) => _checkProfile());
  }

  /// Opens a mandatory dialog if name or phone is empty in users/{uid}.
  Future<void> _checkProfile() async {
    final authUser = FirebaseAuth.instance.currentUser;
    if (authUser == null) return;

    try {
      final snap = await FirebaseFirestore.instance
          .collection('users')
          .doc(authUser.uid)
          .get();
      final data = snap.data();

      final name = (data?['name'] ?? '').toString().trim();
      final phone = (data?['phone'] ?? '').toString().trim();

      // Profile complete -> do nothing, no dialog.
      if (name.isNotEmpty && phone.isNotEmpty) return;
      if (!mounted) return;

      await showCompleteProfileDialog(
        context,
        uid: authUser.uid,
        name: name.isNotEmpty ? name : (authUser.displayName ?? ''),
        phone: phone,
      );
    } catch (_) {
      // Offline or rules error: don't block the app.
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = Get.find<AppController>();
    final pages = [
      HomeView(),
      const QuotesView(),
      RequestView(),
      InvoicesView(),
      const AccountView(),
    ];
    const items = [
      (Icons.home_outlined, 'Home'),
      (Icons.receipt_long_outlined, 'Quotes'),
      (Icons.add_circle_outline, 'Request'),
      (Icons.event_note_outlined, 'Invoices'),
      (Icons.person_outline, 'Account'),
    ];

    return LayoutBuilder(
      builder: (_, b) {
        final wide = b.maxWidth >= 800; // tablet/desktop -> side rail
        return Obx(
          () => Scaffold(
            bottomNavigationBar: wide
                ? null
                : NavigationBar(
                    selectedIndex: c.tab.value,
                    onDestinationSelected: (i) => c.tab.value = i,
                    destinations: [
                      for (final e in items)
                        NavigationDestination(icon: Icon(e.$1), label: e.$2),
                    ],
                  ),
            body: Row(
              children: [
                if (wide)
                  NavigationRail(
                    selectedIndex: c.tab.value,
                    onDestinationSelected: (i) => c.tab.value = i,
                    labelType: NavigationRailLabelType.all,
                    destinations: [
                      for (final e in items)
                        NavigationRailDestination(
                          icon: Icon(e.$1),
                          label: Text(e.$2),
                        ),
                    ],
                  ),
                Expanded(
                  child: SafeArea(
                    child: IndexedStack(index: c.tab.value, children: pages),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
// import 'package:flutter/material.dart';
// import 'package:get/get.dart';
// import 'package:twin/views/invoices_view.dart';
// import 'package:twin/views/quotes_view.dart';
// import '../controllers/app_controller.dart';
// import 'account_view.dart';
// import 'home_view.dart';
// import 'jobs_view.dart';
// import 'quotes_view.dart';
// import 'request_view.dart';

// class ShellView extends StatelessWidget {
//   const ShellView({super.key});
//   @override
//   Widget build(BuildContext context) {
//     final c = Get.find<AppController>();
//     final pages = [
//       HomeView(),
//       const QuotesView(),
//       RequestView(),

//       // JobsView(),
//       InvoicesView(),
//       const AccountView(),
//     ];
//     const items = [
//       (Icons.home_outlined, 'Home'),
//       (Icons.receipt_long_outlined, 'Quotes'),
//       (Icons.add_circle_outline, 'Request'),
//       (Icons.event_note_outlined, 'Invoices'),
//       (Icons.person_outline, 'Account'),
//     ];
//     return LayoutBuilder(
//       builder: (_, b) {
//         final wide = b.maxWidth >= 800; // tablet/desktop -> side rail
//         return Obx(
//           () => Scaffold(
//             bottomNavigationBar: wide
//                 ? null
//                 : NavigationBar(
//                     selectedIndex: c.tab.value,
//                     onDestinationSelected: (i) => c.tab.value = i,
//                     destinations: [
//                       for (final e in items)
//                         NavigationDestination(icon: Icon(e.$1), label: e.$2),
//                     ],
//                   ),
//             body: Row(
//               children: [
//                 if (wide)
//                   NavigationRail(
//                     selectedIndex: c.tab.value,
//                     onDestinationSelected: (i) => c.tab.value = i,
//                     labelType: NavigationRailLabelType.all,
//                     destinations: [
//                       for (final e in items)
//                         NavigationRailDestination(
//                           icon: Icon(e.$1),
//                           label: Text(e.$2),
//                         ),
//                     ],
//                   ),
//                 Expanded(
//                   child: SafeArea(
//                     child: IndexedStack(index: c.tab.value, children: pages),
//                   ),
//                 ),
//               ],
//             ),
//           ),
//         );
//       },
//     );
//   }
// }
