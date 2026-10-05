import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../controllers/app_controller.dart';
import '../core/theme.dart';
import '../core/widgets.dart';
import '../data/models.dart';
import 'pay_view.dart';

class InvoicesView extends StatelessWidget {
  const InvoicesView({super.key});
  @override
  Widget build(BuildContext context) {
    final c = Get.find<AppController>();
    return Scaffold(
      appBar: AppBar(title: const Text('Invoices & payments')),
      body: Body(Obx(() => ListView(padding: const EdgeInsets.all(20), children: [
            for (final i in c.invoices)
              Box(onTap: () => Get.to(() => InvoiceDetailView(inv: i)), child: Row(children: [
                Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(i.title, style: const TextStyle(fontWeight: FontWeight.w700)), sub('${i.id} · ${i.date}')])),
                Column(crossAxisAlignment: CrossAxisAlignment.end, children: [Text(money(i.total), style: const TextStyle(fontWeight: FontWeight.w800)), gap(4), Tag(i.status)]),
              ])),
          ]))),
    );
  }
}

class InvoiceDetailView extends StatelessWidget {
  final Invoice inv;
  const InvoiceDetailView({super.key, required this.inv});
  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: Text('Invoice ${inv.id}')),
        body: Body(Obx(() => ListView(padding: const EdgeInsets.all(20), children: [
              const Row(children: [Icon(Icons.handyman, color: C.orange), SizedBox(width: 8), Text('Twins Handyman LLC', style: TextStyle(fontWeight: FontWeight.w800))]), gap(),
              Box(child: Column(children: [
                KV('Project', inv.title), KV('Date', inv.date), KV('Total', money(inv.total)),
                KV('Deposit / paid', money(inv.paid.value)), KV('Remaining balance', money(inv.remaining), bold: true),
                KV('Status', inv.status), if (inv.method.value.isNotEmpty) KV('Method', inv.method.value),
              ])),
              OutlinedButton.icon(onPressed: () => toast('Invoice PDF downloaded (demo)'), icon: const Icon(Icons.download), label: const Text('Download invoice')),
              gap(),
              if (inv.remaining > 0)
                cta('PAY NOW — ${money(inv.remaining)}', () => Get.to(() => PayView(
                    title: 'Invoice ${inv.id}', amount: inv.remaining, summary: inv.title,
                    onPaid: (m) { Get.find<AppController>().payInvoice(inv, m); return inv.id; }))),
            ]))),
      );
}
