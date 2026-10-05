import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../controllers/app_controller.dart';
import '../core/theme.dart';
import '../core/widgets.dart';
import '../data/models.dart';

class RequestController extends GetxController {
  final service = ''.obs, addr = kAddresses.first.obs, files = <String>[].obs;
  final date = DateTime.now().add(const Duration(days: 3)).obs;
  final time = const TimeOfDay(hour: 10, minute: 0).obs;
  final desc = TextEditingController(), budget = TextEditingController();
  final name = TextEditingController(text: 'Sarah Malik'), phone = TextEditingController(text: '(201) 555-0148');
  final email = TextEditingController(text: 'sarah.malik@email.com');
  final key = GlobalKey<FormState>();
}

class RequestView extends StatelessWidget {
  RequestView({super.key});
  final r = Get.put(RequestController());
  final c = Get.find<AppController>();
  String? _req(String? v) => (v == null || v.trim().isEmpty) ? 'Required' : null;

  @override
  Widget build(BuildContext context) => Body(Form(
        key: r.key,
        child: ListView(padding: const EdgeInsets.all(20), children: [
          h('Request a quote', size: 22), gap(4), sub('Tell us about the job and we will send a quote.'), gap(16),
          h('Service', size: 15), gap(8),
          Obx(() => Wrap(spacing: 8, runSpacing: 8, children: [
                for (final s in kServices)
                  ChoiceChip(
                      avatar: Icon(s.$2, size: 16), label: Text(s.$1), selected: r.service.value == s.$1,
                      selectedColor: C.orange.withValues(alpha: .18), onSelected: (_) => r.service.value = s.$1),
              ])),
          gap(16),
          TextFormField(controller: r.desc, maxLines: 4, validator: _req, decoration: const InputDecoration(labelText: 'Description of work')),
          gap(),
          TextFormField(controller: r.budget, keyboardType: TextInputType.number, validator: _req,
              decoration: const InputDecoration(labelText: 'Budget', prefixText: '\$ ')),
          gap(),
          TextFormField(controller: r.name, validator: _req, decoration: const InputDecoration(labelText: 'Full name')),
          gap(),
          LayoutBuilder(builder: (_, b) {
            final f1 = TextFormField(controller: r.phone, validator: _req, keyboardType: TextInputType.phone, decoration: const InputDecoration(labelText: 'Phone'));
            final f2 = TextFormField(controller: r.email, validator: _req, keyboardType: TextInputType.emailAddress, decoration: const InputDecoration(labelText: 'Email'));
            return b.maxWidth > 560
                ? Row(children: [Expanded(child: f1), const SizedBox(width: 12), Expanded(child: f2)])
                : Column(children: [f1, gap(), f2]);
          }),
          gap(),
          Obx(() => DropdownButtonFormField<String>(
              initialValue: r.addr.value, decoration: const InputDecoration(labelText: 'Property address'),
              items: [for (final a in kAddresses) DropdownMenuItem(value: a, child: Text(a, overflow: TextOverflow.ellipsis))],
              onChanged: (v) => r.addr.value = v!)),
          gap(),
          Row(children: [
            Expanded(child: Obx(() => OutlinedButton.icon(
                icon: const Icon(Icons.calendar_today, size: 16),
                label: Text('${r.date.value.month}/${r.date.value.day}/${r.date.value.year}'),
                onPressed: () async {
                  final d = await showDatePicker(context: context, initialDate: r.date.value, firstDate: DateTime.now(), lastDate: DateTime.now().add(const Duration(days: 365)));
                  if (d != null) r.date.value = d;
                }))),
            const SizedBox(width: 12),
            Expanded(child: Obx(() => OutlinedButton.icon(
                icon: const Icon(Icons.schedule, size: 16), label: Text(r.time.value.format(context)),
                onPressed: () async {
                  final t = await showTimePicker(context: context, initialTime: r.time.value);
                  if (t != null) r.time.value = t;
                }))),
          ]),
          gap(16), h('Photos, videos & documents', size: 15), gap(8),
          Obx(() => Wrap(spacing: 8, runSpacing: 8, children: [
                for (final f in r.files) Chip(label: Text(f), onDeleted: () => r.files.remove(f)),
                ActionChip(avatar: const Icon(Icons.image_outlined, size: 16), label: const Text('Photo'), onPressed: () => r.files.add('photo_${r.files.length + 1}.jpg')),
                ActionChip(avatar: const Icon(Icons.videocam_outlined, size: 16), label: const Text('Video'), onPressed: () => r.files.add('video_${r.files.length + 1}.mp4')),
                ActionChip(avatar: const Icon(Icons.description_outlined, size: 16), label: const Text('Document'), onPressed: () => r.files.add('doc_${r.files.length + 1}.pdf')),
              ])),
          gap(24),
          cta('Submit request', () {
            if (r.service.value.isEmpty) return toast('Please select a service');
            if (!r.key.currentState!.validate()) return;
            c.submitRequest(r.service.value, r.addr.value, '${r.date.value.month}/${r.date.value.day}/${r.date.value.year}');
            final s = r.service.value;
            r.service.value = ''; r.desc.clear(); r.budget.clear(); r.files.clear();
            Get.to(() => _Done(s));
          }),
        ]),
      ));
}

class _Done extends StatelessWidget {
  final String service;
  const _Done(this.service);
  @override
  Widget build(BuildContext context) => Scaffold(
      body: SafeArea(child: Body(Padding(padding: const EdgeInsets.all(28), child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
        const Icon(Icons.check_circle, color: C.green, size: 72), gap(),
        h('Request submitted!', size: 22), gap(8),
        Text('We received your $service request. You will get a quote and a notification shortly.', textAlign: TextAlign.center),
        gap(24),
        cta('Track this request', () { Get.back(); Get.find<AppController>().tab.value = 3; }),
        TextButton(onPressed: () { Get.back(); Get.find<AppController>().tab.value = 0; }, child: const Text('Back to home')),
      ])))));
}
