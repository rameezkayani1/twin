import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../controllers/app_controller.dart';
import '../core/theme.dart';
import '../core/widgets.dart';
import '../data/models.dart';
import 'chat_view.dart';
import 'extras_view.dart';
import 'invoices_view.dart';
import 'quotes_view.dart'; // <- adjust path/file name if QuotesView lives elsewhere
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

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
                        StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
                          stream: FirebaseFirestore.instance
                              .collection('users')
                              .doc(FirebaseAuth.instance.currentUser?.uid)
                              .snapshots(),
                          builder: (context, snapshot) {
                            if (!snapshot.hasData) {
                              return sub('Welcome');
                            }

                            final data = snapshot.data?.data();
                            final name = data?['name'] ?? 'there';

                            return sub('Welcome, $name');
                          },
                        ),
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

              // ───────── Latest quote (live from Firebase) ─────────
              _LatestQuoteCard(
                onViewDetails: () => Get.to(() => const QuotesView()),
                onRequest: () => c.tab.value = 1,
              ),
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

// =============================================================
// LATEST QUOTE CARD  (reads quote_requests for the signed-in user)
// =============================================================
class _LatestQuoteCard extends StatelessWidget {
  final VoidCallback onViewDetails;
  final VoidCallback onRequest;
  const _LatestQuoteCard({
    required this.onViewDetails,
    required this.onRequest,
  });

  static const _flow = [
    'pending',
    'reviewing',
    'quoted',
    'accepted',
    'scheduled',
    'completed',
  ];
  static const _months = [
    'Jan',
    'Feb',
    'Mar',
    'Apr',
    'May',
    'Jun',
    'Jul',
    'Aug',
    'Sep',
    'Oct',
    'Nov',
    'Dec',
  ];

  static const _green = Color(0xFF22B573);
  static const _red = Color(0xFFEB5757);

  // status -> (label, color, message)
  (String, Color, String) _meta(String s) {
    switch (s) {
      case 'reviewing':
        return (
          'In review',
          const Color(0xFF56CCF2),
          'Our team is reviewing your job',
        );
      case 'quoted':
        return ('Quote ready', _green, 'Your quote is ready — take a look');
      case 'accepted':
        return ('Accepted', _green, 'Great! We are preparing your booking');
      case 'scheduled':
        return (
          'Scheduled',
          const Color(0xFFB794F4),
          'Your job is on the calendar',
        );
      case 'completed':
        return ('Completed', _green, 'Job finished — thank you!');
      case 'rejected':
        return ('Declined', _red, 'We could not take this job');
      case 'cancelled':
        return (
          'Cancelled',
          const Color(0xFF9AA1AD),
          'This request was cancelled',
        );
      default:
        return ('Pending', C.orange, 'We received your request');
    }
  }

  IconData _icon(String service) {
    switch (service) {
      case 'Plumbing':
        return Icons.plumbing;
      case 'Electrical':
        return Icons.electrical_services;
      case 'Painting':
        return Icons.format_paint;
      case 'Cleaning':
        return Icons.cleaning_services;
      case 'AC Repair':
        return Icons.ac_unit;
      case 'Carpentry':
        return Icons.carpenter;
      case 'Roofing':
        return Icons.roofing;
      case 'Landscaping':
        return Icons.yard;
      case 'Moving':
        return Icons.local_shipping;
      default:
        return Icons.handyman_rounded;
    }
  }

  String _date(dynamic ts) {
    if (ts is! Timestamp) return '—';
    final d = ts.toDate();
    return '${_months[d.month - 1]} ${d.day}, ${d.year}';
  }

  DateTime _created(Map<String, dynamic> m) {
    final t = m['createdAt'];
    return t is Timestamp ? t.toDate() : DateTime.now();
  }

  @override
  Widget build(BuildContext context) {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return _empty();

    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance
          .collection('quote_requests')
          .where('userId', isEqualTo: uid)
          .snapshots(),
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting && !snap.hasData) {
          return _skeleton();
        }
        if (snap.hasError) return _empty(message: 'Could not load your quotes');
        final docs = snap.data?.docs ?? [];
        if (docs.isEmpty) return _empty();

        // newest first (sorted on device -> no composite index needed)
        final list = docs.map((d) => d.data()).toList()
          ..sort((a, b) => _created(b).compareTo(_created(a)));
        return _card(list.first, list.length);
      },
    );
  }

  // ───────── filled card ─────────
  Widget _card(Map<String, dynamic> q, int total) {
    final status = (q['status'] ?? 'pending').toString();
    final (label, color, message) = _meta(status);
    final service = (q['service'] ?? 'Service').toString();
    final number = (q['requestNumber'] ?? '').toString();
    final desc = (q['description'] ?? '').toString();
    final address = (q['address'] ?? '').toString();
    final slot = (q['preferredSlot'] ?? '').toString();
    final urgency = (q['urgency'] ?? '').toString();
    final amount = q['quoteAmount'];
    final budget = q['budget'];
    final step = _flow.indexOf(status); // -1 for rejected/cancelled
    final hasAmount = amount is num;

    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        gradient: const LinearGradient(
          colors: [Color(0xFF1F2430), Color(0xFF30384A)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        boxShadow: [
          BoxShadow(
            color: C.ink.withOpacity(.25),
            blurRadius: 24,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: Stack(
          children: [
            // decorative glow circles
            Positioned(
              right: -40,
              top: -40,
              child: Container(
                width: 150,
                height: 150,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: color.withOpacity(.14),
                ),
              ),
            ),
            Positioned(
              right: 40,
              bottom: -60,
              child: Container(
                width: 120,
                height: 120,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.white.withOpacity(.04),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // top row: label + request number
                  Row(
                    children: [
                      const Icon(Icons.bolt_rounded, color: C.orange, size: 16),
                      const SizedBox(width: 4),
                      const Text(
                        'LATEST QUOTE',
                        style: TextStyle(
                          color: C.orange,
                          fontWeight: FontWeight.w800,
                          fontSize: 11.5,
                          letterSpacing: 1,
                        ),
                      ),
                      const Spacer(),
                      if (number.isNotEmpty)
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(.1),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(
                            number,
                            style: const TextStyle(
                              color: Colors.white70,
                              fontWeight: FontWeight.w700,
                              fontSize: 11.5,
                              letterSpacing: .6,
                            ),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // service + status
                  Row(
                    children: [
                      Container(
                        width: 52,
                        height: 52,
                        decoration: BoxDecoration(
                          color: color.withOpacity(.18),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: color.withOpacity(.5)),
                        ),
                        child: Icon(_icon(service), color: color, size: 27),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              service,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 20,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            const SizedBox(height: 5),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 3,
                              ),
                              decoration: BoxDecoration(
                                color: color.withOpacity(.2),
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Container(
                                    width: 7,
                                    height: 7,
                                    decoration: BoxDecoration(
                                      color: color,
                                      shape: BoxShape.circle,
                                    ),
                                  ),
                                  const SizedBox(width: 6),
                                  Text(
                                    label,
                                    style: TextStyle(
                                      color: color,
                                      fontWeight: FontWeight.w800,
                                      fontSize: 12,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),

                  if (desc.isNotEmpty) ...[
                    const SizedBox(height: 14),
                    Text(
                      desc,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Color(0xFFB9BFC6),
                        height: 1.4,
                        fontSize: 13.5,
                      ),
                    ),
                  ],

                  // progress
                  const SizedBox(height: 16),
                  if (step >= 0) ...[
                    Row(
                      children: [
                        for (var i = 0; i < _flow.length; i++)
                          Expanded(
                            child: Container(
                              height: 5,
                              margin: EdgeInsets.only(
                                right: i == _flow.length - 1 ? 0 : 4,
                              ),
                              decoration: BoxDecoration(
                                color: i <= step
                                    ? color
                                    : Colors.white.withOpacity(.14),
                                borderRadius: BorderRadius.circular(6),
                              ),
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 8),
                  ],
                  Text(
                    step >= 0
                        ? 'Step ${step + 1} of ${_flow.length} · $message'
                        : message,
                    style: const TextStyle(
                      color: Color(0xFFB9BFC6),
                      fontSize: 12.5,
                      fontWeight: FontWeight.w600,
                    ),
                  ),

                  // amount / info tiles
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        flex: 5,
                        child: _tile(
                          hasAmount ? 'QUOTED PRICE' : 'YOUR BUDGET',
                          hasAmount
                              ? '\$${(amount).toStringAsFixed(0)}'
                              : (budget is num && budget > 0
                                    ? '\$${budget.toStringAsFixed(0)}'
                                    : 'Awaiting quote'),
                          highlight: hasAmount,
                          color: _green,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        flex: 5,
                        child: _tile(
                          'PREFERRED DATE',
                          _date(q['preferredDate']),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 14,
                    runSpacing: 6,
                    children: [
                      if (slot.isNotEmpty) _meta2(Icons.schedule_rounded, slot),
                      if (urgency.isNotEmpty)
                        _meta2(Icons.flash_on_rounded, urgency),
                      if (address.isNotEmpty)
                        _meta2(Icons.place_outlined, address),
                    ],
                  ),

                  // CTA
                  const SizedBox(height: 18),
                  SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: ElevatedButton(
                      onPressed: onViewDetails,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: C.orange,
                        foregroundColor: Colors.white,
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            total > 1
                                ? 'View details · $total quotes'
                                : 'View details',
                            style: const TextStyle(
                              fontWeight: FontWeight.w800,
                              fontSize: 15,
                            ),
                          ),
                          const SizedBox(width: 6),
                          const Icon(Icons.arrow_forward_rounded, size: 19),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _tile(
    String label,
    String value, {
    bool highlight = false,
    Color color = Colors.white,
  }) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
    decoration: BoxDecoration(
      color: Colors.white.withOpacity(highlight ? .1 : .07),
      borderRadius: BorderRadius.circular(14),
      border: Border.all(
        color: highlight
            ? color.withOpacity(.6)
            : Colors.white.withOpacity(.08),
      ),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            color: Color(0xFF8B93A3),
            fontSize: 10.5,
            fontWeight: FontWeight.w700,
            letterSpacing: .8,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          value,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            color: highlight ? color : Colors.white,
            fontSize: highlight ? 22 : 15,
            fontWeight: FontWeight.w800,
          ),
        ),
      ],
    ),
  );

  Widget _meta2(IconData icon, String text) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      Icon(icon, size: 14, color: const Color(0xFF8B93A3)),
      const SizedBox(width: 5),
      ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 240),
        child: Text(
          text,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(color: Color(0xFFB9BFC6), fontSize: 12),
        ),
      ),
    ],
  );

  // ───────── empty state ─────────
  Widget _empty({String? message}) => Container(
    padding: const EdgeInsets.all(22),
    decoration: BoxDecoration(
      borderRadius: BorderRadius.circular(24),
      gradient: const LinearGradient(
        colors: [Color(0xFF1F2430), Color(0xFF30384A)],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      ),
    ),
    child: Row(
      children: [
        Container(
          width: 56,
          height: 56,
          decoration: BoxDecoration(
            color: C.orange.withOpacity(.18),
            borderRadius: BorderRadius.circular(18),
          ),
          child: const Icon(
            Icons.request_quote_rounded,
            color: C.orange,
            size: 28,
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                message ?? 'No quotes yet',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 17,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 4),
              const Text(
                'Tell us about your job and get a price.',
                style: TextStyle(color: Color(0xFFB9BFC6), fontSize: 13),
              ),
              const SizedBox(height: 10),
              GestureDetector(
                onTap: onRequest,
                child: const Text(
                  'Request a quote →',
                  style: TextStyle(
                    color: C.orange,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    ),
  );

  // ───────── loading skeleton ─────────
  Widget _skeleton() => Container(
    height: 260,
    alignment: Alignment.center,
    decoration: BoxDecoration(
      color: C.ink,
      borderRadius: BorderRadius.circular(24),
    ),
    child: const CircularProgressIndicator(color: C.orange, strokeWidth: 3),
  );
}
// import 'package:flutter/material.dart';
// import 'package:get/get.dart';
// import '../controllers/app_controller.dart';
// import '../core/theme.dart';
// import '../core/widgets.dart';
// import '../data/models.dart';
// import 'chat_view.dart';
// import 'extras_view.dart';
// import 'invoices_view.dart';
// import 'job_detail_view.dart';
// import 'package:cloud_firestore/cloud_firestore.dart';
// import 'package:firebase_auth/firebase_auth.dart';

// class HomeView extends StatelessWidget {
//   HomeView({super.key});
//   final c = Get.find<AppController>();

//   // ───────── Recent activity sidebar ─────────
//   void _openActivity(BuildContext context) {
//     showGeneralDialog(
//       context: context,
//       barrierDismissible: true,
//       barrierLabel: 'Activity',
//       barrierColor: Colors.black54,
//       transitionDuration: const Duration(milliseconds: 280),
//       pageBuilder: (_, __, ___) => Align(
//         alignment: Alignment.centerRight,
//         child: Material(
//           color: Colors.white,
//           child: SizedBox(
//             width: (MediaQuery.of(context).size.width * 0.84).clamp(
//               280.0,
//               420.0,
//             ),
//             height: double.infinity,
//             child: SafeArea(
//               child: Column(
//                 crossAxisAlignment: CrossAxisAlignment.start,
//                 children: [
//                   Padding(
//                     padding: const EdgeInsets.fromLTRB(20, 16, 8, 8),
//                     child: Row(
//                       children: [
//                         Expanded(child: h('Recent activity', size: 20)),
//                         IconButton(
//                           onPressed: () => Navigator.of(context).pop(),
//                           icon: const Icon(Icons.close),
//                         ),
//                       ],
//                     ),
//                   ),
//                   const Divider(height: 1, color: C.line),
//                   Expanded(
//                     child: Obx(
//                       () => c.notifs.isEmpty
//                           ? Center(child: sub('Nothing new yet'))
//                           : ListView.separated(
//                               padding: const EdgeInsets.all(16),
//                               itemCount: c.notifs.length,
//                               separatorBuilder: (_, __) =>
//                                   const SizedBox(height: 10),
//                               itemBuilder: (_, i) {
//                                 final n = c.notifs[i];
//                                 return Container(
//                                   padding: const EdgeInsets.all(14),
//                                   decoration: BoxDecoration(
//                                     color: const Color(0xFFF6F7F9),
//                                     borderRadius: BorderRadius.circular(14),
//                                   ),
//                                   child: Row(
//                                     crossAxisAlignment:
//                                         CrossAxisAlignment.start,
//                                     children: [
//                                       Container(
//                                         padding: const EdgeInsets.all(8),
//                                         decoration: BoxDecoration(
//                                           color: C.blue.withOpacity(.12),
//                                           shape: BoxShape.circle,
//                                         ),
//                                         child: Icon(
//                                           n.icon,
//                                           color: C.blue,
//                                           size: 20,
//                                         ),
//                                       ),
//                                       const SizedBox(width: 12),
//                                       Expanded(
//                                         child: Column(
//                                           crossAxisAlignment:
//                                               CrossAxisAlignment.start,
//                                           children: [
//                                             Text(
//                                               n.title,
//                                               style: const TextStyle(
//                                                 fontWeight: FontWeight.w700,
//                                               ),
//                                             ),
//                                             const SizedBox(height: 2),
//                                             sub(n.body),
//                                             const SizedBox(height: 6),
//                                             Text(
//                                               n.time,
//                                               style: const TextStyle(
//                                                 fontSize: 11,
//                                                 color: Colors.grey,
//                                               ),
//                                             ),
//                                           ],
//                                         ),
//                                       ),
//                                     ],
//                                   ),
//                                 );
//                               },
//                             ),
//                     ),
//                   ),
//                   Padding(
//                     padding: const EdgeInsets.all(16),
//                     child: cta('View all notifications', () {
//                       Navigator.of(context).pop();
//                       Get.to(() => const NotificationsView());
//                     }),
//                   ),
//                 ],
//               ),
//             ),
//           ),
//         ),
//       ),
//       transitionBuilder: (_, anim, __, child) => SlideTransition(
//         position: Tween<Offset>(
//           begin: const Offset(1, 0),
//           end: Offset.zero,
//         ).animate(CurvedAnimation(parent: anim, curve: Curves.easeOutCubic)),
//         child: child,
//       ),
//     );
//   }

//   // ───────── Simple service tile ─────────
//   Widget _serviceTile(int i) {
//     final tints = <Color>[C.orange, C.blue, C.ink];
//     final color = tints[i % tints.length];
//     final s = kServices[i];
//     return Material(
//       color: Colors.white,
//       borderRadius: BorderRadius.circular(18),
//       child: InkWell(
//         borderRadius: BorderRadius.circular(18),
//         onTap: () => c.tab.value = 1,
//         child: Container(
//           padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 12),
//           decoration: BoxDecoration(
//             borderRadius: BorderRadius.circular(18),
//             border: Border.all(color: C.line),
//           ),
//           child: Column(
//             mainAxisAlignment: MainAxisAlignment.center,
//             children: [
//               Container(
//                 width: 46,
//                 height: 46,
//                 decoration: BoxDecoration(
//                   color: color.withOpacity(.12),
//                   shape: BoxShape.circle,
//                 ),
//                 child: Icon(s.$2, color: color, size: 24),
//               ),
//               const SizedBox(height: 8),
//               Text(
//                 s.$1,
//                 maxLines: 2,
//                 textAlign: TextAlign.center,
//                 overflow: TextOverflow.ellipsis,
//                 style: const TextStyle(
//                   fontSize: 12,
//                   fontWeight: FontWeight.w700,
//                   height: 1.2,
//                 ),
//               ),
//             ],
//           ),
//         ),
//       ),
//     );
//   }

//   @override
//   Widget build(BuildContext context) {
//     final actions = <(IconData, String, VoidCallback)>[
//       (Icons.add_circle_outline, 'Request a Quote', () => c.tab.value = 1),
//       (Icons.receipt_long_outlined, 'My Quotes', () => c.tab.value = 2),
//       (
//         Icons.payments_outlined,
//         'Pay Invoice',
//         () => Get.to(() => const InvoicesView()),
//       ),
//     ];
//     return Body(
//       Center(
//         child: ConstrainedBox(
//           constraints: const BoxConstraints(maxWidth: 720),
//           child: ListView(
//             padding: const EdgeInsets.all(20),
//             children: [
//               // ───────── Header + bell ─────────
//               Row(
//                 children: [
//                   Expanded(
//                     child: Expanded(
//                       child: Column(
//                         crossAxisAlignment: CrossAxisAlignment.start,
//                         children: [
//                           StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
//                             stream: FirebaseFirestore.instance
//                                 .collection('users')
//                                 .doc(FirebaseAuth.instance.currentUser?.uid)
//                                 .snapshots(),
//                             builder: (context, snapshot) {
//                               if (!snapshot.hasData) {
//                                 return sub('Welcome');
//                               }

//                               final data = snapshot.data?.data();
//                               final name = data?['name'] ?? 'there';

//                               return sub('Welcome, $name');
//                             },
//                           ),
//                           h('What do you need done?', size: 22),
//                         ],
//                       ),
//                     ),
//                     //  Column(
//                     //   crossAxisAlignment: CrossAxisAlignment.start,
//                     //   children: [
//                     //     sub('Welcome, Sarah'),
//                     //     h('What do you need done?', size: 22),
//                     //   ],
//                     // ),
//                   ),
//                   Obx(
//                     () => Stack(
//                       clipBehavior: Clip.none,
//                       children: [
//                         IconButton.filled(
//                           style: IconButton.styleFrom(
//                             backgroundColor: Colors.white,
//                             foregroundColor: C.ink,
//                           ),
//                           onPressed: () => _openActivity(context),
//                           icon: const Icon(Icons.notifications_outlined),
//                         ),
//                         if (c.notifs.isNotEmpty)
//                           Positioned(
//                             right: 2,
//                             top: 2,
//                             child: Container(
//                               padding: const EdgeInsets.symmetric(
//                                 horizontal: 5,
//                                 vertical: 1,
//                               ),
//                               decoration: BoxDecoration(
//                                 color: Colors.redAccent,
//                                 borderRadius: BorderRadius.circular(10),
//                                 border: Border.all(
//                                   color: Colors.white,
//                                   width: 1.5,
//                                 ),
//                               ),
//                               child: Text(
//                                 '${c.notifs.length}',
//                                 style: const TextStyle(
//                                   color: Colors.white,
//                                   fontSize: 10,
//                                   fontWeight: FontWeight.w800,
//                                 ),
//                               ),
//                             ),
//                           ),
//                       ],
//                     ),
//                   ),
//                 ],
//               ),
//               gap(16),

//               // ───────── Next appointment ─────────
//               Obx(() {
//                 final j = c.jobs.firstWhereOrNull((j) => j.stage.value < 8);
//                 if (j == null) return const SizedBox();
//                 return Container(
//                   padding: const EdgeInsets.all(20),
//                   decoration: BoxDecoration(
//                     color: C.ink,
//                     borderRadius: BorderRadius.circular(20),
//                   ),
//                   child: Column(
//                     crossAxisAlignment: CrossAxisAlignment.start,
//                     children: [
//                       const Text(
//                         'NEXT APPOINTMENT',
//                         style: TextStyle(
//                           color: C.orange,
//                           fontWeight: FontWeight.w800,
//                           fontSize: 11.5,
//                         ),
//                       ),
//                       gap(8),
//                       Text(
//                         j.service,
//                         style: const TextStyle(
//                           color: Colors.white,
//                           fontSize: 20,
//                           fontWeight: FontWeight.w800,
//                         ),
//                       ),
//                       gap(4),
//                       Text(
//                         '${j.date} · ${j.time}\n${j.address}',
//                         style: const TextStyle(
//                           color: Color(0xFFB9BFC6),
//                           height: 1.5,
//                         ),
//                       ),
//                       gap(14),
//                       Tag(stages[j.stage.value]),
//                       gap(14),
//                       cta(
//                         'View details',
//                         () => Get.to(() => JobDetailView(job: j)),
//                       ),
//                     ],
//                   ),
//                 );
//               }),
//               gap(10),

//               // ───────── Promo ─────────
//               Box(
//                 color: C.info,
//                 child: const Row(
//                   children: [
//                     Icon(Icons.local_offer_outlined, color: C.blue),
//                     SizedBox(width: 12),
//                     Expanded(
//                       child: Text(
//                         'Fall special: 10% off pressure washing booked before Oct 31.',
//                         style: TextStyle(
//                           color: C.blue,
//                           fontWeight: FontWeight.w600,
//                         ),
//                       ),
//                     ),
//                   ],
//                 ),
//               ),
//               gap(6),

//               // ───────── Quick actions ─────────
//               h('Quick actions'),
//               gap(),
//               LayoutBuilder(
//                 builder: (_, b) => Wrap(
//                   spacing: 10,
//                   runSpacing: 10,
//                   children: [
//                     for (final a in actions)
//                       SizedBox(
//                         width: (b.maxWidth - 20) / 3,
//                         child: Material(
//                           color: Colors.white,
//                           borderRadius: BorderRadius.circular(16),
//                           child: InkWell(
//                             borderRadius: BorderRadius.circular(16),
//                             onTap: a.$3,
//                             child: Padding(
//                               padding: const EdgeInsets.symmetric(
//                                 vertical: 16,
//                                 horizontal: 6,
//                               ),
//                               child: Column(
//                                 children: [
//                                   Icon(a.$1, color: C.orange),
//                                   gap(6),
//                                   Text(
//                                     a.$2,
//                                     textAlign: TextAlign.center,
//                                     style: const TextStyle(
//                                       fontSize: 12,
//                                       fontWeight: FontWeight.w700,
//                                     ),
//                                   ),
//                                 ],
//                               ),
//                             ),
//                           ),
//                         ),
//                       ),
//                   ],
//                 ),
//               ),
//               gap(20),

//               // ───────── Our services (grid) ─────────
//               Row(
//                 children: [
//                   Expanded(child: h('Our services')),
//                   GestureDetector(
//                     onTap: () => c.tab.value = 1,
//                     child: const Text(
//                       'See all',
//                       style: TextStyle(
//                         color: C.blue,
//                         fontWeight: FontWeight.w700,
//                       ),
//                     ),
//                   ),
//                 ],
//               ),
//               gap(),
//               GridView.builder(
//                 shrinkWrap: true,
//                 physics: const NeverScrollableScrollPhysics(),
//                 itemCount: kServices.length,
//                 // Auto columns: ~3 on phones, more on tablets. Fixed height
//                 // keeps tiles safe from overflow with large system fonts.
//                 gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
//                   maxCrossAxisExtent: 130,
//                   mainAxisExtent: 112,
//                   mainAxisSpacing: 10,
//                   crossAxisSpacing: 10,
//                 ),
//                 itemBuilder: (_, i) => _serviceTile(i),
//               ),
//               gap(10),
//             ],
//           ),
//         ),
//       ),
//     );
//   }
// }
