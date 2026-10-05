import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../controllers/app_controller.dart';
import '../core/theme.dart';
import '../core/widgets.dart';
import '../data/models.dart';
import 'chat_view.dart';
import 'extras_view.dart';
import 'invoices_view.dart';
import 'job_detail_view.dart';

class HomeView extends StatelessWidget {
  HomeView({super.key});
  final c = Get.find<AppController>();

  // ───────── Recent activity sidebar ─────────
  void _openActivity(BuildContext context) {
    showGeneralDialog(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'Activity',
      barrierColor: Colors.black54,
      transitionDuration: const Duration(milliseconds: 280),
      pageBuilder: (_, __, ___) => Align(
        alignment: Alignment.centerRight,
        child: Material(
          color: Colors.white,
          child: SizedBox(
            width: (MediaQuery.of(context).size.width * 0.84).clamp(
              280.0,
              420.0,
            ),
            height: double.infinity,
            child: SafeArea(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 16, 8, 8),
                    child: Row(
                      children: [
                        Expanded(child: h('Recent activity', size: 20)),
                        IconButton(
                          onPressed: () => Navigator.of(context).pop(),
                          icon: const Icon(Icons.close),
                        ),
                      ],
                    ),
                  ),
                  const Divider(height: 1, color: C.line),
                  Expanded(
                    child: Obx(
                      () => c.notifs.isEmpty
                          ? Center(child: sub('Nothing new yet'))
                          : ListView.separated(
                              padding: const EdgeInsets.all(16),
                              itemCount: c.notifs.length,
                              separatorBuilder: (_, __) =>
                                  const SizedBox(height: 10),
                              itemBuilder: (_, i) {
                                final n = c.notifs[i];
                                return Container(
                                  padding: const EdgeInsets.all(14),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFF6F7F9),
                                    borderRadius: BorderRadius.circular(14),
                                  ),
                                  child: Row(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Container(
                                        padding: const EdgeInsets.all(8),
                                        decoration: BoxDecoration(
                                          color: C.blue.withOpacity(.12),
                                          shape: BoxShape.circle,
                                        ),
                                        child: Icon(
                                          n.icon,
                                          color: C.blue,
                                          size: 20,
                                        ),
                                      ),
                                      const SizedBox(width: 12),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              n.title,
                                              style: const TextStyle(
                                                fontWeight: FontWeight.w700,
                                              ),
                                            ),
                                            const SizedBox(height: 2),
                                            sub(n.body),
                                            const SizedBox(height: 6),
                                            Text(
                                              n.time,
                                              style: const TextStyle(
                                                fontSize: 11,
                                                color: Colors.grey,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                                );
                              },
                            ),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: cta('View all notifications', () {
                      Navigator.of(context).pop();
                      Get.to(() => const NotificationsView());
                    }),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
      transitionBuilder: (_, anim, __, child) => SlideTransition(
        position: Tween<Offset>(
          begin: const Offset(1, 0),
          end: Offset.zero,
        ).animate(CurvedAnimation(parent: anim, curve: Curves.easeOutCubic)),
        child: child,
      ),
    );
  }

  // ───────── Simple service tile ─────────
  Widget _serviceTile(int i) {
    final tints = <Color>[C.orange, C.blue, C.ink];
    final color = tints[i % tints.length];
    final s = kServices[i];
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: () => c.tab.value = 1,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: C.line),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 46,
                height: 46,
                decoration: BoxDecoration(
                  color: color.withOpacity(.12),
                  shape: BoxShape.circle,
                ),
                child: Icon(s.$2, color: color, size: 24),
              ),
              const SizedBox(height: 8),
              Text(
                s.$1,
                maxLines: 2,
                textAlign: TextAlign.center,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  height: 1.2,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final actions = <(IconData, String, VoidCallback)>[
      (Icons.add_circle_outline, 'Request a Quote', () => c.tab.value = 1),
      (Icons.receipt_long_outlined, 'My Quotes', () => c.tab.value = 2),
      (
        Icons.payments_outlined,
        'Pay Invoice',
        () => Get.to(() => const InvoicesView()),
      ),
    ];
    return Body(
      Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 720),
          child: ListView(
            padding: const EdgeInsets.all(20),
            children: [
              // ───────── Header + bell ─────────
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        sub('Welcome, Sarah'),
                        h('What do you need done?', size: 22),
                      ],
                    ),
                  ),
                  Obx(
                    () => Stack(
                      clipBehavior: Clip.none,
                      children: [
                        IconButton.filled(
                          style: IconButton.styleFrom(
                            backgroundColor: Colors.white,
                            foregroundColor: C.ink,
                          ),
                          onPressed: () => _openActivity(context),
                          icon: const Icon(Icons.notifications_outlined),
                        ),
                        if (c.notifs.isNotEmpty)
                          Positioned(
                            right: 2,
                            top: 2,
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 5,
                                vertical: 1,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.redAccent,
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(
                                  color: Colors.white,
                                  width: 1.5,
                                ),
                              ),
                              child: Text(
                                '${c.notifs.length}',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 10,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
              gap(16),

              // ───────── Next appointment ─────────
              Obx(() {
                final j = c.jobs.firstWhereOrNull((j) => j.stage.value < 8);
                if (j == null) return const SizedBox();
                return Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: C.ink,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'NEXT APPOINTMENT',
                        style: TextStyle(
                          color: C.orange,
                          fontWeight: FontWeight.w800,
                          fontSize: 11.5,
                        ),
                      ),
                      gap(8),
                      Text(
                        j.service,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 20,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      gap(4),
                      Text(
                        '${j.date} · ${j.time}\n${j.address}',
                        style: const TextStyle(
                          color: Color(0xFFB9BFC6),
                          height: 1.5,
                        ),
                      ),
                      gap(14),
                      Tag(stages[j.stage.value]),
                      gap(14),
                      cta(
                        'View details',
                        () => Get.to(() => JobDetailView(job: j)),
                      ),
                    ],
                  ),
                );
              }),
              gap(10),

              // ───────── Promo ─────────
              Box(
                color: C.info,
                child: const Row(
                  children: [
                    Icon(Icons.local_offer_outlined, color: C.blue),
                    SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'Fall special: 10% off pressure washing booked before Oct 31.',
                        style: TextStyle(
                          color: C.blue,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              gap(6),

              // ───────── Quick actions ─────────
              h('Quick actions'),
              gap(),
              LayoutBuilder(
                builder: (_, b) => Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  children: [
                    for (final a in actions)
                      SizedBox(
                        width: (b.maxWidth - 20) / 3,
                        child: Material(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(16),
                          child: InkWell(
                            borderRadius: BorderRadius.circular(16),
                            onTap: a.$3,
                            child: Padding(
                              padding: const EdgeInsets.symmetric(
                                vertical: 16,
                                horizontal: 6,
                              ),
                              child: Column(
                                children: [
                                  Icon(a.$1, color: C.orange),
                                  gap(6),
                                  Text(
                                    a.$2,
                                    textAlign: TextAlign.center,
                                    style: const TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              gap(20),

              // ───────── Our services (grid) ─────────
              Row(
                children: [
                  Expanded(child: h('Our services')),
                  GestureDetector(
                    onTap: () => c.tab.value = 1,
                    child: const Text(
                      'See all',
                      style: TextStyle(
                        color: C.blue,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
              ),
              gap(),
              GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: kServices.length,
                // Auto columns: ~3 on phones, more on tablets. Fixed height
                // keeps tiles safe from overflow with large system fonts.
                gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                  maxCrossAxisExtent: 130,
                  mainAxisExtent: 112,
                  mainAxisSpacing: 10,
                  crossAxisSpacing: 10,
                ),
                itemBuilder: (_, i) => _serviceTile(i),
              ),
              gap(10),
            ],
          ),
        ),
      ),
    );
  }
}
