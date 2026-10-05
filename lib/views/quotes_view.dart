import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../controllers/app_controller.dart';
import '../core/theme.dart';
import '../core/widgets.dart';
import '../data/models.dart';
import 'pay_view.dart';

class QuotesView extends StatelessWidget {
  const QuotesView({super.key});
  @override
  Widget build(BuildContext context) {
    final c = Get.find<AppController>();
    return Body(Obx(() => ListView(padding: const EdgeInsets.all(20), children: [
          h('Your quotes', size: 22), gap(),
          for (final q in c.quotes)
            Box(onTap: () => Get.to(() => QuoteDetailView(q: q)), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [h(q.service, size: 15), Obx(() => Tag(q.status.value))]),
              gap(4), sub('${q.id} · Expires ${q.expires}'), gap(8),
              Text(money(q.total), style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 17)),
            ])),
        ])));
  }
}

class QuoteDetailView extends StatelessWidget {
  final Quote q;
  const QuoteDetailView({super.key, required this.q});

  @override
  Widget build(BuildContext context) {
    final c = Get.find<AppController>();
    return Scaffold(
      appBar: AppBar(title: Text(q.id)),
      body: Body(Obx(() {
        final open = q.status.value == 'Sent' || q.status.value == 'Pending' || q.status.value == 'Changes requested';
        return ListView(padding: const EdgeInsets.all(20), children: [
          Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [h(q.service, size: 20), Tag(q.status.value)]),
          gap(4), sub('${q.address}\nIssued ${q.issued} · Expires ${q.expires}'), gap(16),
          Box(child: Column(children: [
            KV('Labor', money(q.labor)), KV('Materials', money(q.materials)), KV('Service / travel fees', money(q.fees)),
            KV('Discount', '-${money(q.discount)}'), KV('Tax (6.625%)', money(q.tax)), const Divider(),
            KV('Project total', money(q.total), bold: true), gap(4),
            KV('Deposit (${q.depositPct.toStringAsFixed(0)}%)', money(q.deposit), bold: true), KV('Remaining balance', money(q.remaining)),
          ])),
          Box(color: C.info, child: Text(q.notes, style: const TextStyle(color: C.blue))),
          TextButton.icon(onPressed: _terms, icon: const Icon(Icons.description_outlined), label: const Text('Terms & conditions')),
          gap(),
          if (open) ...[
            cta('Approve quote', () { c.acceptQuote(q); _payDeposit(c); }), gap(8),
            Row(children: [
              Expanded(child: OutlinedButton(onPressed: _changes, child: const Text('Request changes'))),
              const SizedBox(width: 10),
              Expanded(child: OutlinedButton(onPressed: () { q.status.value = 'Rejected'; toast('Quote declined'); }, child: const Text('Decline'))),
            ]),
          ] else if (q.status.value == 'Accepted' && !c.hasInvoice(q))
            cta('Pay deposit — ${money(q.deposit)}', () => _payDeposit(c)),
        ]);
      })),
    );
  }

  void _payDeposit(AppController c) => Get.to(() => PayView(
      title: 'Deposit · ${q.service}', amount: q.deposit, summary: 'Total ${money(q.total)} · Remaining ${money(q.remaining)}',
      onPaid: (m) { final i = c.payDeposit(q, m); return i.id; }));

  void _changes() {
    final t = TextEditingController();
    Get.defaultDialog(
        title: 'Request changes', content: TextField(controller: t, maxLines: 3, decoration: const InputDecoration(hintText: 'What should we change?')),
        textConfirm: 'Send', confirmTextColor: Colors.white, buttonColor: C.orange, textCancel: 'Cancel',
        onConfirm: () { q.status.value = 'Changes requested'; Get.back(); toast('Change request sent'); });
  }

  void _terms() => Get.bottomSheet(
      Container(padding: const EdgeInsets.all(20), color: Colors.white,
          child: const Text('1. Quotes are valid until the expiration date.\n\n2. A deposit is required before scheduling.\n\n3. Scope changes on site are approved before work continues.\n\n4. Cancellations within 24 hours may incur a fee.\n\n(Placeholder — replace with final legal terms.)', style: TextStyle(height: 1.5))));
}
