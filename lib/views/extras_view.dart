import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../controllers/app_controller.dart';
import '../core/theme.dart';
import '../core/widgets.dart';
import '../data/models.dart';

class NotificationsView extends StatelessWidget {
  const NotificationsView({super.key});
  @override
  Widget build(BuildContext context) {
    final c = Get.find<AppController>();
    return Scaffold(
      appBar: AppBar(title: const Text('Notifications')),
      body: Body(Obx(() => ListView(padding: const EdgeInsets.all(20), children: [
            for (final n in c.notifs)
              Box(child: Row(children: [Icon(n.icon, color: C.blue), const SizedBox(width: 12),
                Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(n.title, style: const TextStyle(fontWeight: FontWeight.w700)), sub(n.body)])), sub(n.time)])),
          ]))),
    );
  }
}

class ReviewsView extends StatelessWidget {
  ReviewsView({super.key});
  final stars = 5.obs;
  final tc = TextEditingController();
  final c = Get.find<AppController>();
  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: const Text('Reviews')),
        body: Body(ListView(padding: const EdgeInsets.all(20), children: [
          h('How was your experience?'), gap(8),
          Obx(() => Row(children: [for (var i = 1; i <= 5; i++) IconButton(onPressed: () => stars.value = i, icon: Icon(i <= stars.value ? Icons.star : Icons.star_border, color: C.orange, size: 34))])),
          TextField(controller: tc, maxLines: 4, decoration: const InputDecoration(hintText: 'Write your review')), gap(8),
          OutlinedButton.icon(onPressed: () => toast('Photo added (demo)'), icon: const Icon(Icons.add_a_photo_outlined), label: const Text('Add photos (optional)')), gap(),
          cta('Submit review', () { c.reviews.insert(0, {'stars': stars.value, 'text': tc.text, 'job': 'New'}); tc.clear(); toast('Thanks for your review!'); }), gap(8),
          OutlinedButton.icon(onPressed: () => toast('Opens Google reviews (link placeholder)'), icon: const Icon(Icons.open_in_new), label: const Text('Also review us on Google')),
          gap(20), h('Your reviews', size: 15), gap(8),
          Obx(() => Column(children: [for (final r in c.reviews) Box(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Row(children: [for (var i = 0; i < (r['stars'] as int); i++) const Icon(Icons.star, size: 16, color: C.orange)]), gap(4), Text(r['text'] as String)]))])),
        ])),
      );
}

class GovDocsView extends StatelessWidget {
  const GovDocsView({super.key});
  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: const Text('Business & government')),
        body: Body(ListView(padding: const EdgeInsets.all(20), children: [
          Box(color: C.ink, child: const Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('Twins Handyman LLC', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 18)),
            SizedBox(height: 8),
            Text('Hillside, NJ · North Jersey & Staten Island\nUEI: (add) · CAGE: pending\nNAICS: 238320, 561720, 561730, 484210 (edit as needed)', style: TextStyle(color: Color(0xFFB9BFC6), height: 1.6)),
          ])),
          for (final d in ['Capability Statement', 'Organizational Chart', 'Certificate of Insurance', 'MBE Certification', 'SBE Certification', 'Business Registration Certificate'])
            Box(onTap: () => toast('Downloading $d.pdf (demo)'), child: Row(children: [const Icon(Icons.picture_as_pdf_outlined, color: C.red), const SizedBox(width: 12), Expanded(child: Text(d, style: const TextStyle(fontWeight: FontWeight.w600))), const Icon(Icons.download)])),
        ])),
      );
}

/// Owner dashboard preview (design only). Wraps to any width.
class AdminView extends StatelessWidget {
  const AdminView({super.key});
  @override
  Widget build(BuildContext context) {
    final c = Get.find<AppController>();
    return Scaffold(
      appBar: AppBar(title: const Text('Owner dashboard')),
      body: Obx(() {
        final stats = [
          ('Today\'s jobs', '${c.jobs.where((j) => j.stage.value < 8).length}'),
          ('Pending quotes', '${c.quotes.where((q) => q.status.value == 'Sent' || q.status.value == 'Pending').length}'),
          ('Outstanding', money(c.invoices.fold<double>(0, (s, i) => s + i.remaining))),
          ('Monthly revenue', money(c.invoices.fold<double>(0, (s, i) => s + i.paid.value))),
        ];
        return Body(ListView(padding: const EdgeInsets.all(20), children: [
          LayoutBuilder(builder: (_, b) => Wrap(spacing: 10, runSpacing: 10, children: [
                for (final s in stats)
                  SizedBox(width: b.maxWidth > 500 ? (b.maxWidth - 30) / 4 : (b.maxWidth - 10) / 2,
                      child: Box(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [sub(s.$1), gap(4), h(s.$2, size: 20)]))),
              ])),
          h('Schedule', size: 15), gap(8),
          for (final j in c.jobs.where((j) => j.stage.value < 8))
            Box(child: Row(children: [Expanded(child: Text('${j.service} · ${j.address}', overflow: TextOverflow.ellipsis)), Text('${j.date} ${j.time} · ${j.crew}')])),
          gap(8), h('Invoices to verify', size: 15), gap(8),
          for (final i in c.invoices.where((i) => i.remaining > 0))
            Box(child: Row(children: [Expanded(child: Text('${i.id} · ${money(i.remaining)} due')), TextButton(onPressed: () => c.payInvoice(i, 'Zelle'), child: const Text('Mark Zelle paid'))])),
          gap(8), h('Roles', size: 15), gap(8),
          const Box(child: Column(children: [KV('Owner', 'Full access'), KV('Manager', 'Operations, no financial settings'), KV('Crew', 'Assigned jobs only'), KV('Customer', 'Own account only')])),
        ]));
      }),
    );
  }
}
