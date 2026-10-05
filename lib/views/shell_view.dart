import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../controllers/app_controller.dart';
import 'account_view.dart';
import 'home_view.dart';
import 'jobs_view.dart';
import 'quotes_view.dart';
import 'request_view.dart';

class ShellView extends StatelessWidget {
  const ShellView({super.key});
  @override
  Widget build(BuildContext context) {
    final c = Get.find<AppController>();
    final pages = [HomeView(), RequestView(), const QuotesView(), JobsView(), const AccountView()];
    const items = [
      (Icons.home_outlined, 'Home'), (Icons.add_circle_outline, 'Request'), (Icons.receipt_long_outlined, 'Quotes'),
      (Icons.event_note_outlined, 'Jobs'), (Icons.person_outline, 'Account'),
    ];
    return LayoutBuilder(builder: (_, b) {
      final wide = b.maxWidth >= 800; // tablet/desktop -> side rail
      return Obx(() => Scaffold(
            bottomNavigationBar: wide
                ? null
                : NavigationBar(
                    selectedIndex: c.tab.value, onDestinationSelected: (i) => c.tab.value = i,
                    destinations: [for (final e in items) NavigationDestination(icon: Icon(e.$1), label: e.$2)]),
            body: Row(children: [
              if (wide)
                NavigationRail(
                    selectedIndex: c.tab.value, onDestinationSelected: (i) => c.tab.value = i,
                    labelType: NavigationRailLabelType.all,
                    destinations: [for (final e in items) NavigationRailDestination(icon: Icon(e.$1), label: Text(e.$2))]),
              Expanded(child: SafeArea(child: IndexedStack(index: c.tab.value, children: pages))),
            ]),
          ));
    });
  }
}
