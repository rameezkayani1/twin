import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:twin/views/Authrization/login_page.dart';
import '../core/theme.dart';
import '../core/widgets.dart';
import '../data/models.dart';
import 'chat_view.dart';
import 'extras_view.dart';
import 'invoices_view.dart';
import 'login_view.dart';

class AccountView extends StatelessWidget {
  const AccountView({super.key});
  @override
  Widget build(BuildContext context) {
    Widget tile(IconData i, String t, VoidCallback f) => InkWell(
      onTap: f,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
        child: Row(
          children: [
            Icon(i, size: 19, color: C.blue),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                t,
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
            ),
            const Icon(Icons.chevron_right, size: 18),
          ],
        ),
      ),
    );
    Widget group(String t, List<Widget> l) => Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        gap(18),
        Text(
          t,
          style: const TextStyle(
            fontWeight: FontWeight.w700,
            color: C.soft,
            fontSize: 13,
          ),
        ),
        gap(8),
        Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(14),
          ),
          child: Column(children: l),
        ),
      ],
    );
    return Body(
      ListView(
        padding: const EdgeInsets.all(20),
        children: [
          const Row(
            children: [
              CircleAvatar(
                radius: 30,
                backgroundColor: C.ink,
                child: Text(
                  'S',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              SizedBox(width: 14),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Sarah Malik',
                    style: TextStyle(fontWeight: FontWeight.w800, fontSize: 18),
                  ),
                  Text('sarah.malik@email.com'),
                  Text('(201) 555-0148'),
                ],
              ),
            ],
          ),
          group('Saved addresses', [
            for (final a in kAddresses)
              tile(Icons.location_on_outlined, a, () {}),
            tile(Icons.add, 'Add new address', () => toast('Add address form')),
          ]),
          group('Payment methods', [
            tile(Icons.credit_card, 'Visa •••• 4242', () {}),
            tile(
              Icons.add,
              'Add payment method',
              () => toast('Handled by payment processor'),
            ),
          ]),
          group('Activity', [
            tile(
              Icons.payments_outlined,
              'Invoices & payments',
              () => Get.to(() => const InvoicesView()),
            ),
            tile(
              Icons.chat_bubble_outline,
              'Messages',
              () => Get.to(() => const ChatPage()),
            ),
            tile(
              Icons.notifications_outlined,
              'Notifications',
              () => Get.to(() => const NotificationsView()),
            ),
            tile(
              Icons.star_outline,
              'Reviews',
              () => Get.to(() => ReviewsView()),
            ),
          ]),
          group('Company', [
            tile(
              Icons.account_balance_outlined,
              'Business & government documents',
              () => Get.to(() => const GovDocsView()),
            ),
            tile(
              Icons.call_outlined,
              'Call Twins Handyman',
              () => toast('Calling… (demo)'),
            ),
            tile(
              Icons.dashboard_outlined,
              'Owner dashboard (preview)',
              () => Get.to(() => const AdminView()),
            ),
          ]),
          gap(18),
          OutlinedButton(
            onPressed: () => Get.offAll(() => LoginView()),
            style: OutlinedButton.styleFrom(
              foregroundColor: C.red,
              minimumSize: const Size.fromHeight(48),
            ),
            child: const Text('Log out'),
          ),
        ],
      ),
    );
  }
}
