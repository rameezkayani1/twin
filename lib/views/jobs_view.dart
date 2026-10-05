import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../controllers/app_controller.dart';
import '../core/theme.dart';
import '../core/widgets.dart';
import '../data/models.dart';
import 'job_detail_view.dart';

class JobsView extends StatelessWidget {
  JobsView({super.key});
  final seg = 0.obs;
  final c = Get.find<AppController>();
  @override
  Widget build(BuildContext context) => Body(Obx(() {
        final list = c.jobs.where((j) => seg.value == 0 ? j.stage.value < 11 : j.stage.value >= 11).toList();
        return ListView(padding: const EdgeInsets.all(20), children: [
          h('Your jobs', size: 22), gap(),
          SegmentedButton<int>(
              segments: const [ButtonSegment(value: 0, label: Text('Upcoming')), ButtonSegment(value: 1, label: Text('Past'))],
              selected: {seg.value}, onSelectionChanged: (s) => seg.value = s.first),
          gap(),
          if (list.isEmpty) const Center(child: Padding(padding: EdgeInsets.all(40), child: Text('Nothing here yet'))),
          for (final j in list)
            Box(onTap: () => Get.to(() => JobDetailView(job: j)), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [h(j.service, size: 15), Tag(stages[j.stage.value])]),
              gap(4), sub('${j.date} · ${j.time} · ${j.crew}'), gap(10),
              LinearProgressIndicator(value: (j.stage.value + 1) / stages.length, color: C.green, backgroundColor: C.line, minHeight: 5, borderRadius: BorderRadius.circular(4)),
            ])),
        ]);
      }));
}
