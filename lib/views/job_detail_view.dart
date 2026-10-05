import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../controllers/app_controller.dart';
import '../core/theme.dart';
import '../core/widgets.dart';
import '../data/models.dart';
import 'chat_view.dart';
import 'invoices_view.dart';

class JobDetailView extends StatelessWidget {
  final Job job;
  const JobDetailView({super.key, required this.job});

  @override
  Widget build(BuildContext context) => DefaultTabController(
        length: 4,
        child: Scaffold(
          appBar: AppBar(title: Text('${job.id} · ${job.service}'),
              bottom: const TabBar(isScrollable: true, tabAlignment: TabAlignment.start, labelColor: C.orange, indicatorColor: C.orange,
                  tabs: [Tab(text: 'Status'), Tab(text: 'Photos'), Tab(text: 'Documents'), Tab(text: 'Messages')])),
          body: Body(TabBarView(children: [_status(), _photos(), _docs(), ChatView()])),
        ),
      );

  Widget _status() => Obx(() => ListView(padding: const EdgeInsets.all(20), children: [
        Box(child: Column(children: [KV('Address', job.address), KV('Date', '${job.date} · ${job.time}'), KV('Crew', job.crew), KV('Est. duration', job.duration)])),
        for (var i = 0; i < stages.length; i++)
          Padding(padding: const EdgeInsets.symmetric(vertical: 6), child: Row(children: [
            Icon(i <= job.stage.value ? Icons.check_circle : Icons.radio_button_unchecked, color: i <= job.stage.value ? C.green : C.line, size: 20),
            const SizedBox(width: 12),
            Text(stages[i], style: TextStyle(fontWeight: i == job.stage.value ? FontWeight.w800 : FontWeight.w500, color: i <= job.stage.value ? C.ink : C.soft)),
            if (i == job.stage.value) const Padding(padding: EdgeInsets.only(left: 8), child: Text('Current', style: TextStyle(color: C.orange, fontSize: 12))),
          ])),
        gap(16),
        Row(children: [
          Expanded(child: OutlinedButton.icon(icon: const Icon(Icons.event_repeat), label: const Text('Reschedule'), onPressed: () async {
            final d = await showDatePicker(context: Get.context!, initialDate: DateTime.now().add(const Duration(days: 3)), firstDate: DateTime.now(), lastDate: DateTime.now().add(const Duration(days: 180)));
            if (d != null) toast('Reschedule requested for ${d.month}/${d.day}/${d.year}');
          })),
        ]),
        gap(8), sub('You will get a reminder 24 hours before your appointment.'),
      ]));

  Widget _photos() => ListView(padding: const EdgeInsets.all(20), children: [
        for (final t in ['Before', 'After']) ...[
          h('$t photos', size: 15), gap(8),
          Wrap(spacing: 8, runSpacing: 8, children: [
            for (var i = 0; i < 3; i++)
              Container(width: 100, height: 100, decoration: BoxDecoration(color: C.info, borderRadius: BorderRadius.circular(12)), child: const Icon(Icons.image_outlined, color: C.blue)),
          ]), gap(16),
        ],
      ]);

  Widget _docs() {
    final c = Get.find<AppController>();
    Widget tile(IconData i, String t, VoidCallback f) => Box(onTap: f, child: Row(children: [Icon(i, color: C.blue), const SizedBox(width: 12), Expanded(child: Text(t, style: const TextStyle(fontWeight: FontWeight.w600))), const Icon(Icons.chevron_right)]));
    final inv = c.invoices.firstWhereOrNull((i) => i.quoteId == job.quoteId);
    return ListView(padding: const EdgeInsets.all(20), children: [
      tile(Icons.receipt_long_outlined, 'Quote ${job.quoteId}', () => c.tab.value = 2),
      tile(Icons.description_outlined, inv == null ? 'Invoice (not issued yet)' : 'Invoice ${inv.id}', () => inv == null ? toast('No invoice yet') : Get.to(() => InvoiceDetailView(inv: inv))),
      tile(Icons.verified_outlined, 'Receipt', () => toast('Receipt shown after payment')),
    ]);
  }
}
