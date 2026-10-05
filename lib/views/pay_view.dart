import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../core/theme.dart';
import '../core/widgets.dart';

/// Reusable checkout for deposits and final payments.
class PayView extends StatelessWidget {
  final String title, summary;
  final double amount;
  final String Function(String method) onPaid; // returns invoice id
  PayView({super.key, required this.title, required this.amount, required this.summary, required this.onPaid});
  final method = 'Apple Pay'.obs;
  static const methods = [
    (Icons.apple, 'Apple Pay'), (Icons.g_mobiledata, 'Google Pay'), (Icons.credit_card, 'Card'),
    (Icons.account_balance, 'ACH bank transfer'), (Icons.qr_code_2, 'Zelle'),
  ];

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: const Text('Secure checkout')),
        body: Body(ListView(padding: const EdgeInsets.all(20), children: [
          Box(color: C.ink, child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(title, style: const TextStyle(color: Color(0xFFB9BFC6))), gap(4),
            Text(money(amount), style: const TextStyle(color: Colors.white, fontSize: 30, fontWeight: FontWeight.w800)), gap(4),
            Text(summary, style: const TextStyle(color: Color(0xFFB9BFC6), fontSize: 12.5)),
          ])),
          h('Payment method', size: 15), gap(8),
          Obx(() => Column(children: [
                for (final m in methods)
                  Box(onTap: () => method.value = m.$2, child: Row(children: [
                    Icon(m.$1, color: C.blue), const SizedBox(width: 12), Expanded(child: Text(m.$2, style: const TextStyle(fontWeight: FontWeight.w600))),
                    Icon(method.value == m.$2 ? Icons.radio_button_checked : Icons.radio_button_off, color: C.orange),
                  ])),
                if (method.value == 'Card') ...[
                  const TextField(decoration: InputDecoration(labelText: 'Card number', prefixIcon: Icon(Icons.credit_card))), gap(),
                  const Row(children: [Expanded(child: TextField(decoration: InputDecoration(labelText: 'MM/YY'))), SizedBox(width: 12), Expanded(child: TextField(decoration: InputDecoration(labelText: 'CVC')))]),
                ],
                if (method.value == 'Zelle')
                  Box(color: C.info, child: const Text('Send the amount via Zelle to payments@twinshandymanllc.com (placeholder), include your invoice # in the memo, then tap Confirm. Twins Handyman will verify and mark the invoice paid.', style: TextStyle(color: C.blue))),
              ])),
          gap(8),
          const Row(children: [Icon(Icons.lock_outline, size: 14, color: C.soft), SizedBox(width: 6), Expanded(child: Text('Payments are processed by a PCI-compliant processor. Card numbers are never stored by Twins Handyman.', style: TextStyle(fontSize: 12, color: C.soft)))]),
          gap(16),
          cta('Pay ${money(amount)}', () {
            final id = onPaid(method.value);
            Get.off(() => ReceiptView(id: id, amount: amount, method: method.value, title: title));
          }),
        ])),
      );
}

class ReceiptView extends StatelessWidget {
  final String id, method, title;
  final double amount;
  const ReceiptView({super.key, required this.id, required this.amount, required this.method, required this.title});
  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: const Text('Receipt')),
        body: Body(ListView(padding: const EdgeInsets.all(20), children: [
          const Icon(Icons.check_circle, color: C.green, size: 64), gap(8),
          Center(child: h('PAYMENT SUCCESSFUL', size: 20)), gap(16),
          Box(child: Column(children: [
            const KV('Business', 'Twins Handyman LLC'), KV('Invoice #', id), KV('For', title),
            KV('Amount paid', money(amount), bold: true), KV('Method', method), const KV('Status', 'PAID'),
          ])),
          Row(children: [
            Expanded(child: OutlinedButton.icon(onPressed: () => toast('Receipt downloaded (demo)'), icon: const Icon(Icons.download), label: const Text('Download'))),
            const SizedBox(width: 10),
            Expanded(child: OutlinedButton.icon(onPressed: () => toast('Receipt emailed (demo)'), icon: const Icon(Icons.email_outlined), label: const Text('Email'))),
          ]),
          gap(), cta('Done', () => Get.back()),
        ])),
      );
}
