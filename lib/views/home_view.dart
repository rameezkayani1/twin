// =============================================================
// home_view.dart — "Bento" home screen (single file, new design)
//
// Layout
//   1. Greeting row  : avatar initial · time-based greeting · bell + badge
//   2. Journey card  : LATEST request as a colourful 6-step journey
//                      (animated nodes, pulsing current step, big price,
//                       one smart button: Review / Pay / View)
//   3. Bento tiles   : big "Request a quote" tile + live "My quotes"
//                      and "Pay invoice" tiles
//   4. Promo ribbon
//   5. Services      : adaptive pill tiles (2 / 3 / 4 columns)
//
// Live data: quote_requests (userId == me)   -> journey + counts
//            users/{uid}.name                -> greeting
//
// Responsive: content centred, max 880px; paddings and columns adapt;
// no fixed heights anywhere (safe with large system fonts).
//
// Needs from your project: AppController (tab, notifs), kServices,
// NotificationsView, InvoicesView, QuotesView
// =============================================================
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:twin/views/quotes_view.dart';
import '../controllers/app_controller.dart';
import '../data/models.dart';
import 'extras_view.dart';
import 'invoices_view.dart';
import 'quotes_view.dart'; // <- adjust path/file name if needed
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

// ---------------------------------------------------------
// PALETTE
// ---------------------------------------------------------
class _P {
  static const bg = Color(0xFFF7F2EA); // warm sand
  static const ink = Color(0xFF14171F);
  static const muted = Color(0xFF6F7685);
  static const line = Color(0xFFE8E0D3);
  static const card = Colors.white;
  static const coral = Color(0xFFFF6B2C);
  static const sun = Color(0xFFFFB020);
  static const mint = Color(0xFF16A34A);
  static const sky = Color(0xFF3B82F6);
  static const lilac = Color(0xFF8B5CF6);
  static const teal = Color(0xFF0D9488);
  static const rose = Color(0xFFE5484D);
  static const tints = [coral, sky, lilac, teal];
}

// ---------------------------------------------------------
// SMALL ANIMATION HELPERS
// ---------------------------------------------------------
/// Fade + slide up, staggered by [delay] ms.
class _Reveal extends StatelessWidget {
  final Widget child;
  final int delay;
  const _Reveal({required this.child, this.delay = 0});
  @override
  Widget build(BuildContext context) {
    final total = 520 + delay;
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: Duration(milliseconds: total),
      curve: Interval(delay / total, 1, curve: Curves.easeOutCubic),
      builder: (_, v, ch) => Opacity(
        opacity: v,
        child: Transform.translate(offset: Offset(0, 18 * (1 - v)), child: ch),
      ),
      child: child,
    );
  }
}

/// Expanding ring used behind the current journey node.
class _Ring extends StatefulWidget {
  final Color color;
  const _Ring({required this.color});
  @override
  State<_Ring> createState() => _RingState();
}

class _RingState extends State<_Ring> with SingleTickerProviderStateMixin {
  late final AnimationController _ac = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1500),
  )..repeat();
  @override
  void dispose() {
    _ac.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: _ac,
    builder: (_, __) {
      final t = Curves.easeOut.transform(_ac.value);
      final s = 26 + 16 * t;
      return Container(
        width: s,
        height: s,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(
            color: widget.color.withOpacity(.55 * (1 - t)),
            width: 2,
          ),
        ),
      );
    },
  );
}

class _Breathing extends StatefulWidget {
  final Widget child;
  const _Breathing({required this.child});
  @override
  State<_Breathing> createState() => _BreathingState();
}

class _BreathingState extends State<_Breathing>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ac = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 900),
  )..repeat(reverse: true);
  @override
  void dispose() {
    _ac.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => FadeTransition(
    opacity: Tween(
      begin: .45,
      end: 1.0,
    ).animate(CurvedAnimation(parent: _ac, curve: Curves.easeInOut)),
    child: widget.child,
  );
}

/// Press-down scale feedback for tiles.
class _Tap extends StatefulWidget {
  final Widget child;
  final VoidCallback onTap;
  const _Tap({required this.child, required this.onTap});
  @override
  State<_Tap> createState() => _TapState();
}

class _TapState extends State<_Tap> {
  bool _down = false;
  @override
  Widget build(BuildContext context) => GestureDetector(
    behavior: HitTestBehavior.opaque,
    onTapDown: (_) => setState(() => _down = true),
    onTapCancel: () => setState(() => _down = false),
    onTapUp: (_) => setState(() => _down = false),
    onTap: widget.onTap,
    child: AnimatedScale(
      scale: _down ? .96 : 1,
      duration: const Duration(milliseconds: 120),
      curve: Curves.easeOut,
      child: widget.child,
    ),
  );
}

// ---------------------------------------------------------
// HOME
// ---------------------------------------------------------
class HomeView extends StatelessWidget {
  HomeView({super.key});
  final c = Get.find<AppController>();

  static const _flow = [
    'pending',
    'reviewing',
    'quoted',
    'accepted',
    'scheduled',
    'completed',
  ];
  static const _flowLabels = [
    'Sent',
    'Review',
    'Quote',
    'Approved',
    'Booked',
    'Done',
  ];
  static const _flowIcons = [
    Icons.send_rounded,
    Icons.manage_search_rounded,
    Icons.request_quote_rounded,
    Icons.thumb_up_alt_rounded,
    Icons.event_available_rounded,
    Icons.verified_rounded,
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

  // status -> (label, colour, one-line message)
  (String, Color, String) _meta(String s) {
    switch (s) {
      case 'reviewing':
        return ('In review', _P.sky, 'Our team is preparing your quote.');
      case 'quoted':
        return (
          'Quote ready',
          _P.lilac,
          'Your quote is ready — review and approve.',
        );
      case 'changes_requested':
        return ('Updating', _P.sun, 'We are updating your quote.');
      case 'accepted':
        return ('Approved', _P.mint, 'Pay the deposit to lock in your date.');
      case 'scheduled':
        return ('Scheduled', _P.teal, 'Your job is on the calendar.');
      case 'completed':
        return ('Completed', _P.mint, 'All done — thank you!');
      case 'rejected':
        return ('Declined', _P.rose, 'This quote was declined.');
      case 'cancelled':
        return ('Cancelled', _P.muted, 'This request was cancelled.');
      default:
        return ('Pending', _P.coral, 'We received your request.');
    }
  }

  IconData _serviceIcon(String s) {
    switch (s) {
      case 'Plumbing':
        return Icons.plumbing;
      case 'Electrical':
        return Icons.electrical_services;
      case 'Painting':
        return Icons.format_paint_rounded;
      case 'Cleaning':
        return Icons.cleaning_services_rounded;
      case 'Pressure Washing':
        return Icons.water_drop_rounded;
      case 'AC Repair':
        return Icons.ac_unit;
      case 'Carpentry':
        return Icons.carpenter;
      case 'Roofing':
        return Icons.roofing;
      case 'Landscaping':
      case 'Lawn Services':
        return Icons.yard_rounded;
      case 'Moving':
        return Icons.local_shipping_rounded;
      default:
        return Icons.handyman_rounded;
    }
  }

  DateTime _created(Map<String, dynamic> m) {
    final t = m['createdAt'];
    return t is Timestamp ? t.toDate() : DateTime.now();
  }

  double? _quoted(Map<String, dynamic> q) {
    final m = q['quote'];
    if (m is Map && m['total'] is num) return (m['total'] as num).toDouble();
    final a = q['quoteAmount'];
    return a is num ? a.toDouble() : null;
  }

  String _money(num v) =>
      '\$${v.toStringAsFixed(v % 1 == 0 ? 0 : 2).replaceAllMapped(RegExp(r'\B(?=(\d{3})+(?!\d))'), (_) => ',')}';

  bool _needsAction(Map<String, dynamic> m) {
    final s = (m['status'] ?? '').toString();
    return s == 'quoted' || (s == 'accepted' && m['depositPaid'] != true);
  }

  String _greeting() {
    final h = DateTime.now().hour;
    return h < 12
        ? 'Good morning'
        : (h < 17 ? 'Good afternoon' : 'Good evening');
  }

  // ───────────────────────── build ─────────────────────────
  @override
  Widget build(BuildContext context) {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    return Material(
      color: _P.bg,
      child: SafeArea(
        bottom: false,
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 880),
            child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
              stream: uid == null
                  ? null
                  : FirebaseFirestore.instance
                        .collection('quote_requests')
                        .where('userId', isEqualTo: uid)
                        .snapshots(),
              builder: (context, snap) {
                final loading =
                    uid != null &&
                    snap.connectionState == ConnectionState.waiting &&
                    !snap.hasData;
                final list =
                    (snap.data?.docs ?? []).map((d) => d.data()).toList()
                      ..sort((a, b) => _created(b).compareTo(_created(a)));
                final urgent = list.where(_needsAction).toList();
                // Hero always shows the LATEST quote (list is newest first).
                final shown = list.isNotEmpty ? list.first : null;

                return LayoutBuilder(
                  builder: (context, box) {
                    final w = box.maxWidth;
                    final pad = w >= 600 ? 24.0 : 16.0;
                    return ListView(
                      padding: EdgeInsets.fromLTRB(pad, 12, pad, 36),
                      children: [
                        _Reveal(child: _header(context, uid)),
                        const SizedBox(height: 18),
                        // _Reveal(
                        //   delay: 60,
                        //   child: Text(
                        //     'What do you\nneed done today?',
                        //     style: TextStyle(
                        //       fontSize: w < 360 ? 26 : 32,
                        //       height: 1.1,
                        //       fontWeight: FontWeight.w900,
                        //       letterSpacing: -1,
                        //       color: _P.ink,
                        //     ),
                        //   ),
                        // ),
                        const SizedBox(height: 18),
                        _Reveal(
                          delay: 120,
                          child: loading
                              ? _skeleton()
                              : (shown == null
                                    ? _emptyHero()
                                    : AnimatedSwitcher(
                                        duration: const Duration(
                                          milliseconds: 350,
                                        ),
                                        child: KeyedSubtree(
                                          key: ValueKey(
                                            '${shown['requestNumber']}-${shown['status']}-${_quoted(shown)}-${shown['depositPaid']}',
                                          ),
                                          child: _journey(shown, list.length),
                                        ),
                                      )),
                        ),
                        const SizedBox(height: 14),
                        _Reveal(
                          delay: 180,
                          child: _bento(list.length, urgent.length),
                        ),
                        const SizedBox(height: 14),
                        _Reveal(delay: 240, child: _promo()),
                        const SizedBox(height: 22),
                        _Reveal(delay: 300, child: _servicesHeader()),
                        const SizedBox(height: 12),
                        _Reveal(delay: 340, child: _services(w - pad * 2)),
                      ],
                    );
                  },
                );
              },
            ),
          ),
        ),
      ),
    );
  }

  // ───────────────────────── header ─────────────────────────
  Widget _header(BuildContext context, String? uid) {
    return Row(
      children: [
        StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
          stream: uid == null
              ? null
              : FirebaseFirestore.instance
                    .collection('users')
                    .doc(uid)
                    .snapshots(),
          builder: (context, s) {
            final name = (s.data?.data()?['name'] ?? '').toString().trim();
            final first = name.isEmpty ? 'there' : name.split(' ').first;
            final initial = name.isEmpty ? '👋' : name[0].toUpperCase();
            return Expanded(
              child: Row(
                children: [
                  Container(
                    width: 46,
                    height: 46,
                    alignment: Alignment.center,
                    decoration: const BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: LinearGradient(
                        colors: [_P.coral, _P.sun],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                    ),
                    child: Text(
                      initial,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 19,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _greeting(),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: _P.muted,
                            fontSize: 12.5,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        Text(
                          first,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: _P.ink,
                            fontSize: 19,
                            fontWeight: FontWeight.w900,
                            letterSpacing: -.3,
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
        const SizedBox(width: 10),
        Obx(
          () => _Tap(
            onTap: () => _openActivity(context),
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                Container(
                  width: 46,
                  height: 46,
                  decoration: BoxDecoration(
                    color: _P.card,
                    shape: BoxShape.circle,
                    border: Border.all(color: _P.line),
                  ),
                  child: const Icon(
                    Icons.notifications_none_rounded,
                    color: _P.ink,
                  ),
                ),
                if (c.notifs.isNotEmpty)
                  Positioned(
                    right: -2,
                    top: -2,
                    child: Container(
                      constraints: const BoxConstraints(minWidth: 20),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 5,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: _P.coral,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: _P.bg, width: 2),
                      ),
                      child: Text(
                        '${c.notifs.length}',
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 10,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  // ───────────────────────── journey card ─────────────────────────
  Widget _journey(Map<String, dynamic> q, int total) {
    final status = (q['status'] ?? 'pending').toString();
    final (label, color, message) = _meta(status);
    final service = (q['service'] ?? 'Service').toString();
    final number = (q['requestNumber'] ?? '').toString();
    final quoted = _quoted(q);
    final budget = q['budget'];
    final failed = status == 'rejected' || status == 'cancelled';
    var idx = _flow.indexOf(status);
    if (status == 'changes_requested') idx = 1;
    final needsReview = status == 'quoted';
    final needsPay = status == 'accepted' && q['depositPaid'] != true;
    final paid = status == 'accepted' && q['depositPaid'] == true;

    final priceLabel = quoted != null ? 'QUOTE' : 'BUDGET';
    final priceText = quoted != null
        ? _money(quoted)
        : (budget is num && budget > 0 ? _money(budget) : '—');

    final ctaText = needsReview
        ? 'Review your quote'
        : needsPay
        ? 'Pay deposit'
        : 'View details';

    return Container(
      decoration: BoxDecoration(
        color: Color.alphaBlend(color.withOpacity(.09), Colors.white),
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: color.withOpacity(.28)),
      ),
      clipBehavior: Clip.antiAlias,
      child: Stack(
        children: [
          // watermark icon
          Positioned(
            right: -14,
            top: -10,
            child: Transform.rotate(
              angle: -.22,
              child: Icon(
                _serviceIcon(service),
                size: 130,
                color: color.withOpacity(.09),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // tag row
                Row(
                  children: [
                    Flexible(
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 5,
                        ),
                        decoration: BoxDecoration(
                          color: color,
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(
                              Icons.bolt_rounded,
                              color: Colors.white,
                              size: 14,
                            ),
                            const SizedBox(width: 3),
                            Flexible(
                              child: Text(
                                label.toUpperCase(),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 11,
                                  fontWeight: FontWeight.w900,
                                  letterSpacing: .8,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    if (number.isNotEmpty) ...[
                      const SizedBox(width: 8),
                      Flexible(
                        child: Text(
                          number,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: _P.muted,
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ],
                    const Spacer(),
                    if (total > 1)
                      Text(
                        '+${total - 1} more',
                        style: const TextStyle(
                          color: _P.muted,
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 16),

                // service + price
                Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            service,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: _P.ink,
                              fontSize: 24,
                              fontWeight: FontWeight.w900,
                              letterSpacing: -.5,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            paid
                                ? 'Deposit received — we will schedule you shortly.'
                                : message,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: _P.muted,
                              fontSize: 13,
                              height: 1.3,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 12),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          priceLabel,
                          style: const TextStyle(
                            color: _P.muted,
                            fontSize: 10,
                            letterSpacing: 1,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        ConstrainedBox(
                          constraints: const BoxConstraints(maxWidth: 140),
                          child: FittedBox(
                            fit: BoxFit.scaleDown,
                            alignment: Alignment.centerRight,
                            child: Text(
                              priceText,
                              style: TextStyle(
                                color: quoted != null ? _P.ink : _P.muted,
                                fontSize: 32,
                                height: 1.05,
                                fontWeight: FontWeight.w900,
                                letterSpacing: -1,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 20),

                // journey track
                if (failed)
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: color.withOpacity(.12),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          status == 'rejected'
                              ? Icons.cancel_rounded
                              : Icons.block_rounded,
                          color: color,
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            message,
                            style: TextStyle(
                              color: color,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ],
                    ),
                  )
                else
                  _track(idx, color, pulse: needsReview || needsPay),
                const SizedBox(height: 18),

                // smart button
                _Tap(
                  onTap: () => Get.to(() => const QuotesView()),
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    decoration: BoxDecoration(
                      color: (needsReview || needsPay) ? _P.ink : Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: (needsReview || needsPay) ? _P.ink : _P.line,
                      ),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Flexible(
                          child: Text(
                            ctaText,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: (needsReview || needsPay)
                                  ? Colors.white
                                  : _P.ink,
                              fontWeight: FontWeight.w800,
                              fontSize: 15,
                            ),
                          ),
                        ),
                        const SizedBox(width: 6),
                        Icon(
                          Icons.arrow_forward_rounded,
                          size: 18,
                          color: (needsReview || needsPay) ? _P.coral : _P.ink,
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _track(int idx, Color color, {required bool pulse}) {
    final last = _flow.length - 1;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (var i = 0; i <= last; i++)
          Expanded(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                SizedBox(
                  height: 34,
                  child: Row(
                    children: [
                      Expanded(
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 500),
                          height: 3,
                          color: i == 0
                              ? Colors.transparent
                              : (i <= idx ? color : _P.line),
                        ),
                      ),
                      Stack(
                        alignment: Alignment.center,
                        children: [
                          if (i == idx && pulse) _Ring(color: color),
                          AnimatedContainer(
                            duration: const Duration(milliseconds: 450),
                            curve: Curves.easeOutBack,
                            width: i == idx ? 30 : 22,
                            height: i == idx ? 30 : 22,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: i <= idx ? color : Colors.white,
                              border: Border.all(
                                color: i <= idx ? color : _P.line,
                                width: 2,
                              ),
                              boxShadow: i == idx
                                  ? [
                                      BoxShadow(
                                        color: color.withOpacity(.4),
                                        blurRadius: 10,
                                        offset: const Offset(0, 3),
                                      ),
                                    ]
                                  : null,
                            ),
                            child: Icon(
                              i < idx ? Icons.check_rounded : _flowIcons[i],
                              size: i == idx ? 16 : 13,
                              color: i <= idx
                                  ? Colors.white
                                  : _P.muted.withOpacity(.6),
                            ),
                          ),
                        ],
                      ),
                      Expanded(
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 500),
                          height: 3,
                          color: i == last
                              ? Colors.transparent
                              : (i < idx ? color : _P.line),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 4),
                FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(
                    _flowLabels[i],
                    maxLines: 1,
                    style: TextStyle(
                      fontSize: 10.5,
                      fontWeight: i == idx ? FontWeight.w900 : FontWeight.w600,
                      color: i == idx ? _P.ink : _P.muted,
                    ),
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }

  Widget _emptyHero() => Container(
    padding: const EdgeInsets.all(20),
    decoration: BoxDecoration(
      borderRadius: BorderRadius.circular(28),
      gradient: const LinearGradient(
        colors: [Color(0xFFFFE3D0), Color(0xFFFFF1D6)],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      ),
    ),
    child: Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Your next project\nstarts here',
                style: TextStyle(
                  color: _P.ink,
                  fontSize: 21,
                  height: 1.15,
                  fontWeight: FontWeight.w900,
                  letterSpacing: -.4,
                ),
              ),
              const SizedBox(height: 6),
              const Text(
                'Describe the job, get a clear price.',
                style: TextStyle(color: _P.muted, fontSize: 13),
              ),
              const SizedBox(height: 14),
              _Tap(
                onTap: () => c.tab.value = 1,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 18,
                    vertical: 11,
                  ),
                  decoration: BoxDecoration(
                    color: _P.ink,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'Request a quote',
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      SizedBox(width: 6),
                      Icon(
                        Icons.arrow_forward_rounded,
                        color: _P.coral,
                        size: 18,
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 10),
        Transform.rotate(
          angle: -.15,
          child: const Icon(
            Icons.home_repair_service_rounded,
            size: 84,
            color: _P.coral,
          ),
        ),
      ],
    ),
  );

  Widget _skeleton() => _Breathing(
    child: Container(
      height: 210,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: _P.line),
      ),
      child: const Center(
        child: SizedBox(
          width: 24,
          height: 24,
          child: CircularProgressIndicator(color: _P.coral, strokeWidth: 2.6),
        ),
      ),
    ),
  );

  // ───────────────────────── bento tiles ─────────────────────────
  Widget _bento(int quoteCount, int actionCount) {
    Widget small(
      IconData icon,
      String title,
      String? badge,
      Color tint,
      VoidCallback onTap, {
      bool dot = false,
    }) {
      return _Tap(
        onTap: onTap,
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: _P.card,
            borderRadius: BorderRadius.circular(22),
            border: Border.all(color: _P.line),
          ),
          child: Row(
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: tint.withOpacity(.13),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: tint, size: 21),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: _P.ink,
                    fontWeight: FontWeight.w800,
                    fontSize: 13.5,
                    height: 1.15,
                  ),
                ),
              ),
              if (badge != null)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 3,
                  ),
                  decoration: BoxDecoration(
                    color: dot ? _P.coral : _P.bg,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    badge,
                    style: TextStyle(
                      color: dot ? Colors.white : _P.muted,
                      fontSize: 11.5,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
            ],
          ),
        ),
      );
    }

    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // big tile
          Expanded(
            flex: 5,
            child: _Tap(
              onTap: () => c.tab.value = 1,
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(22),
                  gradient: const LinearGradient(
                    colors: [_P.coral, Color(0xFFFF9248)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: _P.coral.withOpacity(.3),
                      blurRadius: 16,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Container(
                      width: 42,
                      height: 42,
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(.25),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.add_rounded,
                        color: Colors.white,
                        size: 26,
                      ),
                    ),
                    const SizedBox(height: 18),
                    const Text(
                      'Request\na quote',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 20,
                        height: 1.1,
                        fontWeight: FontWeight.w900,
                        letterSpacing: -.4,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Takes about a minute',
                      style: TextStyle(
                        color: Colors.white.withOpacity(.85),
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            flex: 6,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                small(
                  Icons.receipt_long_rounded,
                  actionCount > 0 ? 'My quotes' : 'My quotes',
                  actionCount > 0
                      ? '$actionCount'
                      : (quoteCount > 0 ? '$quoteCount' : null),
                  _P.lilac,
                  () => c.tab.value = 2,
                  dot: actionCount > 0,
                ),
                const SizedBox(height: 12),
                small(
                  Icons.payments_rounded,
                  'Pay invoice',
                  null,
                  _P.mint,
                  () => Get.to(() => const InvoicesView()),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ───────────────────────── promo ─────────────────────────
  Widget _promo() => Container(
    padding: const EdgeInsets.all(14),
    decoration: BoxDecoration(
      color: _P.ink,
      borderRadius: BorderRadius.circular(22),
    ),
    child: Row(
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          decoration: BoxDecoration(
            color: _P.sun,
            borderRadius: BorderRadius.circular(14),
          ),
          child: const Text(
            '10%\nOFF',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: _P.ink,
              fontWeight: FontWeight.w900,
              height: 1.05,
              fontSize: 14,
            ),
          ),
        ),
        const SizedBox(width: 14),
        const Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Fall special',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w900,
                  fontSize: 15,
                ),
              ),
              SizedBox(height: 2),
              Text(
                'Pressure washing booked before Oct 31.',
                style: TextStyle(
                  color: Color(0xFFB9BFC6),
                  fontSize: 12.5,
                  height: 1.3,
                ),
              ),
            ],
          ),
        ),
        const Icon(Icons.local_offer_rounded, color: _P.sun),
      ],
    ),
  );

  // ───────────────────────── services ─────────────────────────
  Widget _servicesHeader() => Row(
    children: [
      const Expanded(
        child: Text(
          'Our services',
          style: TextStyle(
            color: _P.ink,
            fontSize: 20,
            fontWeight: FontWeight.w900,
            letterSpacing: -.4,
          ),
        ),
      ),
      _Tap(
        onTap: () => c.tab.value = 1,
        child: const Padding(
          padding: EdgeInsets.symmetric(vertical: 4, horizontal: 4),
          child: Text(
            'See all →',
            style: TextStyle(color: _P.coral, fontWeight: FontWeight.w800),
          ),
        ),
      ),
    ],
  );

  Widget _services(double width) {
    final cols = width >= 700 ? 4 : (width >= 460 ? 3 : 2);
    const gap = 10.0;
    final itemW = (width - gap * (cols - 1)) / cols;
    return Wrap(
      spacing: gap,
      runSpacing: gap,
      children: [
        for (var i = 0; i < kServices.length; i++)
          SizedBox(
            width: itemW,
            child: _Reveal(
              delay: 380 + (i.clamp(0, 8)) * 40,
              child: _Tap(
                onTap: () => c.tab.value = 1,
                child: Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: _P.card,
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(color: _P.line),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 36,
                        height: 36,
                        decoration: BoxDecoration(
                          color: _P.tints[i % _P.tints.length].withOpacity(.13),
                          borderRadius: BorderRadius.circular(11),
                        ),
                        child: Icon(
                          kServices[i].$2,
                          color: _P.tints[i % _P.tints.length],
                          size: 20,
                        ),
                      ),
                      const SizedBox(width: 9),
                      Expanded(
                        child: Text(
                          kServices[i].$1,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: _P.ink,
                            fontSize: 12.5,
                            fontWeight: FontWeight.w800,
                            height: 1.15,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }

  // ───────────────────────── activity drawer ─────────────────────────
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
          color: _P.bg,
          borderRadius: const BorderRadius.horizontal(
            left: Radius.circular(28),
          ),
          clipBehavior: Clip.antiAlias,
          child: SizedBox(
            width: (MediaQuery.of(context).size.width * 0.86).clamp(
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
                        const Expanded(
                          child: Text(
                            'Recent activity',
                            style: TextStyle(
                              color: _P.ink,
                              fontSize: 21,
                              fontWeight: FontWeight.w900,
                              letterSpacing: -.4,
                            ),
                          ),
                        ),
                        IconButton(
                          onPressed: () => Navigator.of(context).pop(),
                          icon: const Icon(Icons.close_rounded),
                        ),
                      ],
                    ),
                  ),
                  Expanded(
                    child: Obx(
                      () => c.notifs.isEmpty
                          ? const Center(
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    Icons.notifications_off_outlined,
                                    color: _P.muted,
                                    size: 40,
                                  ),
                                  SizedBox(height: 8),
                                  Text(
                                    'Nothing new yet',
                                    style: TextStyle(color: _P.muted),
                                  ),
                                ],
                              ),
                            )
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
                                    color: _P.card,
                                    borderRadius: BorderRadius.circular(18),
                                    border: Border.all(color: _P.line),
                                  ),
                                  child: Row(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Container(
                                        padding: const EdgeInsets.all(9),
                                        decoration: BoxDecoration(
                                          color: _P.coral.withOpacity(.12),
                                          shape: BoxShape.circle,
                                        ),
                                        child: Icon(
                                          n.icon,
                                          color: _P.coral,
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
                                                color: _P.ink,
                                                fontWeight: FontWeight.w800,
                                              ),
                                            ),
                                            const SizedBox(height: 2),
                                            Text(
                                              n.body,
                                              style: const TextStyle(
                                                color: _P.muted,
                                                height: 1.3,
                                              ),
                                            ),
                                            const SizedBox(height: 6),
                                            Text(
                                              n.time,
                                              style: const TextStyle(
                                                fontSize: 11,
                                                color: _P.muted,
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
                    child: _Tap(
                      onTap: () {
                        Navigator.of(context).pop();
                        Get.to(() => const NotificationsView());
                      },
                      child: Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        decoration: BoxDecoration(
                          color: _P.ink,
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: const Center(
                          child: Text(
                            'View all notifications',
                            style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                      ),
                    ),
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
}

// // =============================================================
// // home_view.dart — "Bento" home screen (single file, new design)
// //
// // Layout
// //   1. Greeting row  : avatar initial · time-based greeting · bell + badge
// //   2. Journey card  : latest request as a colourful 6-step journey
// //                      (animated nodes, pulsing current step, big price,
// //                       one smart button: Review / Pay / View)
// //   3. Bento tiles   : big "Request a quote" tile + live "My quotes"
// //                      and "Pay invoice" tiles
// //   4. Promo ribbon
// //   5. Services      : adaptive pill tiles (2 / 3 / 4 columns)
// //
// // Live data: quote_requests (userId == me)   -> journey + counts
// //            users/{uid}.name                -> greeting
// //
// // Responsive: content centred, max 880px; paddings and columns adapt;
// // no fixed heights anywhere (safe with large system fonts).
// //
// // Needs from your project: AppController (tab, notifs), kServices,
// // NotificationsView, InvoicesView, QuotesView
// // =============================================================
// import 'package:flutter/material.dart';
// import 'package:get/get.dart';
// import 'package:twin/views/quotes_view.dart';
// import '../controllers/app_controller.dart';
// import '../data/models.dart';
// import 'extras_view.dart';
// import 'invoices_view.dart';
// import 'quotes_view.dart'; // <- adjust path/file name if needed
// import 'package:cloud_firestore/cloud_firestore.dart';
// import 'package:firebase_auth/firebase_auth.dart';

// // ---------------------------------------------------------
// // PALETTE
// // ---------------------------------------------------------
// class _P {
//   static const bg = Color(0xFFF7F2EA); // warm sand
//   static const ink = Color(0xFF14171F);
//   static const muted = Color(0xFF6F7685);
//   static const line = Color(0xFFE8E0D3);
//   static const card = Colors.white;
//   static const coral = Color(0xFFFF6B2C);
//   static const sun = Color(0xFFFFB020);
//   static const mint = Color(0xFF16A34A);
//   static const sky = Color(0xFF3B82F6);
//   static const lilac = Color(0xFF8B5CF6);
//   static const teal = Color(0xFF0D9488);
//   static const rose = Color(0xFFE5484D);
//   static const tints = [coral, sky, lilac, teal];
// }

// // ---------------------------------------------------------
// // SMALL ANIMATION HELPERS
// // ---------------------------------------------------------
// /// Fade + slide up, staggered by [delay] ms.
// class _Reveal extends StatelessWidget {
//   final Widget child;
//   final int delay;
//   const _Reveal({required this.child, this.delay = 0});
//   @override
//   Widget build(BuildContext context) {
//     final total = 520 + delay;
//     return TweenAnimationBuilder<double>(
//       tween: Tween(begin: 0, end: 1),
//       duration: Duration(milliseconds: total),
//       curve: Interval(delay / total, 1, curve: Curves.easeOutCubic),
//       builder: (_, v, ch) => Opacity(
//         opacity: v,
//         child: Transform.translate(offset: Offset(0, 18 * (1 - v)), child: ch),
//       ),
//       child: child,
//     );
//   }
// }

// /// Expanding ring used behind the current journey node.
// class _Ring extends StatefulWidget {
//   final Color color;
//   const _Ring({required this.color});
//   @override
//   State<_Ring> createState() => _RingState();
// }

// class _RingState extends State<_Ring> with SingleTickerProviderStateMixin {
//   late final AnimationController _ac = AnimationController(
//     vsync: this,
//     duration: const Duration(milliseconds: 1500),
//   )..repeat();
//   @override
//   void dispose() {
//     _ac.dispose();
//     super.dispose();
//   }

//   @override
//   Widget build(BuildContext context) => AnimatedBuilder(
//     animation: _ac,
//     builder: (_, __) {
//       final t = Curves.easeOut.transform(_ac.value);
//       final s = 26 + 16 * t;
//       return Container(
//         width: s,
//         height: s,
//         decoration: BoxDecoration(
//           shape: BoxShape.circle,
//           border: Border.all(
//             color: widget.color.withOpacity(.55 * (1 - t)),
//             width: 2,
//           ),
//         ),
//       );
//     },
//   );
// }

// class _Breathing extends StatefulWidget {
//   final Widget child;
//   const _Breathing({required this.child});
//   @override
//   State<_Breathing> createState() => _BreathingState();
// }

// class _BreathingState extends State<_Breathing>
//     with SingleTickerProviderStateMixin {
//   late final AnimationController _ac = AnimationController(
//     vsync: this,
//     duration: const Duration(milliseconds: 900),
//   )..repeat(reverse: true);
//   @override
//   void dispose() {
//     _ac.dispose();
//     super.dispose();
//   }

//   @override
//   Widget build(BuildContext context) => FadeTransition(
//     opacity: Tween(
//       begin: .45,
//       end: 1.0,
//     ).animate(CurvedAnimation(parent: _ac, curve: Curves.easeInOut)),
//     child: widget.child,
//   );
// }

// /// Press-down scale feedback for tiles.
// class _Tap extends StatefulWidget {
//   final Widget child;
//   final VoidCallback onTap;
//   const _Tap({required this.child, required this.onTap});
//   @override
//   State<_Tap> createState() => _TapState();
// }

// class _TapState extends State<_Tap> {
//   bool _down = false;
//   @override
//   Widget build(BuildContext context) => GestureDetector(
//     behavior: HitTestBehavior.opaque,
//     onTapDown: (_) => setState(() => _down = true),
//     onTapCancel: () => setState(() => _down = false),
//     onTapUp: (_) => setState(() => _down = false),
//     onTap: widget.onTap,
//     child: AnimatedScale(
//       scale: _down ? .96 : 1,
//       duration: const Duration(milliseconds: 120),
//       curve: Curves.easeOut,
//       child: widget.child,
//     ),
//   );
// }

// // ---------------------------------------------------------
// // HOME
// // ---------------------------------------------------------
// class HomeView extends StatelessWidget {
//   HomeView({super.key});
//   final c = Get.find<AppController>();

//   static const _flow = [
//     'pending',
//     'reviewing',
//     'quoted',
//     'accepted',
//     'scheduled',
//     'completed',
//   ];
//   static const _flowLabels = [
//     'Sent',
//     'Review',
//     'Quote',
//     'Approved',
//     'Booked',
//     'Done',
//   ];
//   static const _flowIcons = [
//     Icons.send_rounded,
//     Icons.manage_search_rounded,
//     Icons.request_quote_rounded,
//     Icons.thumb_up_alt_rounded,
//     Icons.event_available_rounded,
//     Icons.verified_rounded,
//   ];
//   static const _months = [
//     'Jan',
//     'Feb',
//     'Mar',
//     'Apr',
//     'May',
//     'Jun',
//     'Jul',
//     'Aug',
//     'Sep',
//     'Oct',
//     'Nov',
//     'Dec',
//   ];

//   // status -> (label, colour, one-line message)
//   (String, Color, String) _meta(String s) {
//     switch (s) {
//       case 'reviewing':
//         return ('In review', _P.sky, 'Our team is preparing your quote.');
//       case 'quoted':
//         return (
//           'Quote ready',
//           _P.lilac,
//           'Your quote is ready — review and approve.',
//         );
//       case 'changes_requested':
//         return ('Updating', _P.sun, 'We are updating your quote.');
//       case 'accepted':
//         return ('Approved', _P.mint, 'Pay the deposit to lock in your date.');
//       case 'scheduled':
//         return ('Scheduled', _P.teal, 'Your job is on the calendar.');
//       case 'completed':
//         return ('Completed', _P.mint, 'All done — thank you!');
//       case 'rejected':
//         return ('Declined', _P.rose, 'This quote was declined.');
//       case 'cancelled':
//         return ('Cancelled', _P.muted, 'This request was cancelled.');
//       default:
//         return ('Pending', _P.coral, 'We received your request.');
//     }
//   }

//   IconData _serviceIcon(String s) {
//     switch (s) {
//       case 'Plumbing':
//         return Icons.plumbing;
//       case 'Electrical':
//         return Icons.electrical_services;
//       case 'Painting':
//         return Icons.format_paint_rounded;
//       case 'Cleaning':
//         return Icons.cleaning_services_rounded;
//       case 'Pressure Washing':
//         return Icons.water_drop_rounded;
//       case 'AC Repair':
//         return Icons.ac_unit;
//       case 'Carpentry':
//         return Icons.carpenter;
//       case 'Roofing':
//         return Icons.roofing;
//       case 'Landscaping':
//       case 'Lawn Services':
//         return Icons.yard_rounded;
//       case 'Moving':
//         return Icons.local_shipping_rounded;
//       default:
//         return Icons.handyman_rounded;
//     }
//   }

//   DateTime _created(Map<String, dynamic> m) {
//     final t = m['createdAt'];
//     return t is Timestamp ? t.toDate() : DateTime.now();
//   }

//   double? _quoted(Map<String, dynamic> q) {
//     final m = q['quote'];
//     if (m is Map && m['total'] is num) return (m['total'] as num).toDouble();
//     final a = q['quoteAmount'];
//     return a is num ? a.toDouble() : null;
//   }

//   String _money(num v) =>
//       '\$${v.toStringAsFixed(v % 1 == 0 ? 0 : 2).replaceAllMapped(RegExp(r'\B(?=(\d{3})+(?!\d))'), (_) => ',')}';

//   bool _needsAction(Map<String, dynamic> m) {
//     final s = (m['status'] ?? '').toString();
//     return s == 'quoted' || (s == 'accepted' && m['depositPaid'] != true);
//   }

//   String _greeting() {
//     final h = DateTime.now().hour;
//     return h < 12
//         ? 'Good morning'
//         : (h < 17 ? 'Good afternoon' : 'Good evening');
//   }

//   // ───────────────────────── build ─────────────────────────
//   @override
//   Widget build(BuildContext context) {
//     final uid = FirebaseAuth.instance.currentUser?.uid;
//     return Material(
//       color: _P.bg,
//       child: SafeArea(
//         bottom: false,
//         child: Center(
//           child: ConstrainedBox(
//             constraints: const BoxConstraints(maxWidth: 880),
//             child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
//               stream: uid == null
//                   ? null
//                   : FirebaseFirestore.instance
//                         .collection('quote_requests')
//                         .where('userId', isEqualTo: uid)
//                         .snapshots(),
//               builder: (context, snap) {
//                 final loading =
//                     uid != null &&
//                     snap.connectionState == ConnectionState.waiting &&
//                     !snap.hasData;
//                 final list =
//                     (snap.data?.docs ?? []).map((d) => d.data()).toList()
//                       ..sort((a, b) => _created(b).compareTo(_created(a)));
//                 final urgent = list.where(_needsAction).toList();
//                 final shown = urgent.isNotEmpty
//                     ? urgent.first
//                     : (list.isNotEmpty ? list.first : null);

//                 return LayoutBuilder(
//                   builder: (context, box) {
//                     final w = box.maxWidth;
//                     final pad = w >= 600 ? 24.0 : 16.0;
//                     return ListView(
//                       padding: EdgeInsets.fromLTRB(pad, 12, pad, 36),
//                       children: [
//                         _Reveal(child: _header(context, uid)),
//                         const SizedBox(height: 18),
//                         // _Reveal(
//                         //   delay: 60,
//                         //   child: Text(
//                         //     'What do you\nneed done today?',
//                         //     style: TextStyle(
//                         //       fontSize: w < 360 ? 26 : 32,
//                         //       height: 1.1,
//                         //       fontWeight: FontWeight.w900,
//                         //       letterSpacing: -1,
//                         //       color: _P.ink,
//                         //     ),
//                         //   ),
//                         // ),
//                         const SizedBox(height: 18),
//                         _Reveal(
//                           delay: 120,
//                           child: loading
//                               ? _skeleton()
//                               : (shown == null
//                                     ? _emptyHero()
//                                     : AnimatedSwitcher(
//                                         duration: const Duration(
//                                           milliseconds: 350,
//                                         ),
//                                         child: KeyedSubtree(
//                                           key: ValueKey(
//                                             '${shown['requestNumber']}-${shown['status']}-${_quoted(shown)}-${shown['depositPaid']}',
//                                           ),
//                                           child: _journey(shown, list.length),
//                                         ),
//                                       )),
//                         ),
//                         const SizedBox(height: 14),
//                         _Reveal(
//                           delay: 180,
//                           child: _bento(list.length, urgent.length),
//                         ),
//                         const SizedBox(height: 14),
//                         _Reveal(delay: 240, child: _promo()),
//                         const SizedBox(height: 22),
//                         _Reveal(delay: 300, child: _servicesHeader()),
//                         const SizedBox(height: 12),
//                         _Reveal(delay: 340, child: _services(w - pad * 2)),
//                       ],
//                     );
//                   },
//                 );
//               },
//             ),
//           ),
//         ),
//       ),
//     );
//   }

//   // ───────────────────────── header ─────────────────────────
//   Widget _header(BuildContext context, String? uid) {
//     return Row(
//       children: [
//         StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
//           stream: uid == null
//               ? null
//               : FirebaseFirestore.instance
//                     .collection('users')
//                     .doc(uid)
//                     .snapshots(),
//           builder: (context, s) {
//             final name = (s.data?.data()?['name'] ?? '').toString().trim();
//             final first = name.isEmpty ? 'there' : name.split(' ').first;
//             final initial = name.isEmpty ? '👋' : name[0].toUpperCase();
//             return Expanded(
//               child: Row(
//                 children: [
//                   Container(
//                     width: 46,
//                     height: 46,
//                     alignment: Alignment.center,
//                     decoration: const BoxDecoration(
//                       shape: BoxShape.circle,
//                       gradient: LinearGradient(
//                         colors: [_P.coral, _P.sun],
//                         begin: Alignment.topLeft,
//                         end: Alignment.bottomRight,
//                       ),
//                     ),
//                     child: Text(
//                       initial,
//                       style: const TextStyle(
//                         color: Colors.white,
//                         fontSize: 19,
//                         fontWeight: FontWeight.w900,
//                       ),
//                     ),
//                   ),
//                   const SizedBox(width: 12),
//                   Expanded(
//                     child: Column(
//                       crossAxisAlignment: CrossAxisAlignment.start,
//                       children: [
//                         Text(
//                           _greeting(),
//                           maxLines: 1,
//                           overflow: TextOverflow.ellipsis,
//                           style: const TextStyle(
//                             color: _P.muted,
//                             fontSize: 12.5,
//                             fontWeight: FontWeight.w600,
//                           ),
//                         ),
//                         Text(
//                           first,
//                           maxLines: 1,
//                           overflow: TextOverflow.ellipsis,
//                           style: const TextStyle(
//                             color: _P.ink,
//                             fontSize: 19,
//                             fontWeight: FontWeight.w900,
//                             letterSpacing: -.3,
//                           ),
//                         ),
//                       ],
//                     ),
//                   ),
//                 ],
//               ),
//             );
//           },
//         ),
//         const SizedBox(width: 10),
//         Obx(
//           () => _Tap(
//             onTap: () => _openActivity(context),
//             child: Stack(
//               clipBehavior: Clip.none,
//               children: [
//                 Container(
//                   width: 46,
//                   height: 46,
//                   decoration: BoxDecoration(
//                     color: _P.card,
//                     shape: BoxShape.circle,
//                     border: Border.all(color: _P.line),
//                   ),
//                   child: const Icon(
//                     Icons.notifications_none_rounded,
//                     color: _P.ink,
//                   ),
//                 ),
//                 if (c.notifs.isNotEmpty)
//                   Positioned(
//                     right: -2,
//                     top: -2,
//                     child: Container(
//                       constraints: const BoxConstraints(minWidth: 20),
//                       padding: const EdgeInsets.symmetric(
//                         horizontal: 5,
//                         vertical: 2,
//                       ),
//                       decoration: BoxDecoration(
//                         color: _P.coral,
//                         borderRadius: BorderRadius.circular(10),
//                         border: Border.all(color: _P.bg, width: 2),
//                       ),
//                       child: Text(
//                         '${c.notifs.length}',
//                         textAlign: TextAlign.center,
//                         style: const TextStyle(
//                           color: Colors.white,
//                           fontSize: 10,
//                           fontWeight: FontWeight.w900,
//                         ),
//                       ),
//                     ),
//                   ),
//               ],
//             ),
//           ),
//         ),
//       ],
//     );
//   }

//   // ───────────────────────── journey card ─────────────────────────
//   Widget _journey(Map<String, dynamic> q, int total) {
//     final status = (q['status'] ?? 'pending').toString();
//     final (label, color, message) = _meta(status);
//     final service = (q['service'] ?? 'Service').toString();
//     final number = (q['requestNumber'] ?? '').toString();
//     final quoted = _quoted(q);
//     final budget = q['budget'];
//     final failed = status == 'rejected' || status == 'cancelled';
//     var idx = _flow.indexOf(status);
//     if (status == 'changes_requested') idx = 1;
//     final needsReview = status == 'quoted';
//     final needsPay = status == 'accepted' && q['depositPaid'] != true;
//     final paid = status == 'accepted' && q['depositPaid'] == true;

//     final priceLabel = quoted != null ? 'QUOTE' : 'BUDGET';
//     final priceText = quoted != null
//         ? _money(quoted)
//         : (budget is num && budget > 0 ? _money(budget) : '—');

//     final ctaText = needsReview
//         ? 'Review your quote'
//         : needsPay
//         ? 'Pay deposit'
//         : 'View details';

//     return Container(
//       decoration: BoxDecoration(
//         color: Color.alphaBlend(color.withOpacity(.09), Colors.white),
//         borderRadius: BorderRadius.circular(28),
//         border: Border.all(color: color.withOpacity(.28)),
//       ),
//       clipBehavior: Clip.antiAlias,
//       child: Stack(
//         children: [
//           // watermark icon
//           Positioned(
//             right: -14,
//             top: -10,
//             child: Transform.rotate(
//               angle: -.22,
//               child: Icon(
//                 _serviceIcon(service),
//                 size: 130,
//                 color: color.withOpacity(.09),
//               ),
//             ),
//           ),
//           Padding(
//             padding: const EdgeInsets.all(18),
//             child: Column(
//               crossAxisAlignment: CrossAxisAlignment.start,
//               children: [
//                 // tag row
//                 Row(
//                   children: [
//                     Flexible(
//                       child: Container(
//                         padding: const EdgeInsets.symmetric(
//                           horizontal: 10,
//                           vertical: 5,
//                         ),
//                         decoration: BoxDecoration(
//                           color: color,
//                           borderRadius: BorderRadius.circular(20),
//                         ),
//                         child: Row(
//                           mainAxisSize: MainAxisSize.min,
//                           children: [
//                             const Icon(
//                               Icons.bolt_rounded,
//                               color: Colors.white,
//                               size: 14,
//                             ),
//                             const SizedBox(width: 3),
//                             Flexible(
//                               child: Text(
//                                 label.toUpperCase(),
//                                 maxLines: 1,
//                                 overflow: TextOverflow.ellipsis,
//                                 style: const TextStyle(
//                                   color: Colors.white,
//                                   fontSize: 11,
//                                   fontWeight: FontWeight.w900,
//                                   letterSpacing: .8,
//                                 ),
//                               ),
//                             ),
//                           ],
//                         ),
//                       ),
//                     ),
//                     if (number.isNotEmpty) ...[
//                       const SizedBox(width: 8),
//                       Flexible(
//                         child: Text(
//                           number,
//                           maxLines: 1,
//                           overflow: TextOverflow.ellipsis,
//                           style: const TextStyle(
//                             color: _P.muted,
//                             fontSize: 12,
//                             fontWeight: FontWeight.w700,
//                           ),
//                         ),
//                       ),
//                     ],
//                     const Spacer(),
//                     if (total > 1)
//                       Text(
//                         '+${total - 1} more',
//                         style: const TextStyle(
//                           color: _P.muted,
//                           fontSize: 12,
//                           fontWeight: FontWeight.w700,
//                         ),
//                       ),
//                   ],
//                 ),
//                 const SizedBox(height: 16),

//                 // service + price
//                 Row(
//                   crossAxisAlignment: CrossAxisAlignment.end,
//                   children: [
//                     Expanded(
//                       child: Column(
//                         crossAxisAlignment: CrossAxisAlignment.start,
//                         children: [
//                           Text(
//                             service,
//                             maxLines: 1,
//                             overflow: TextOverflow.ellipsis,
//                             style: const TextStyle(
//                               color: _P.ink,
//                               fontSize: 24,
//                               fontWeight: FontWeight.w900,
//                               letterSpacing: -.5,
//                             ),
//                           ),
//                           const SizedBox(height: 4),
//                           Text(
//                             paid
//                                 ? 'Deposit received — we will schedule you shortly.'
//                                 : message,
//                             maxLines: 2,
//                             overflow: TextOverflow.ellipsis,
//                             style: const TextStyle(
//                               color: _P.muted,
//                               fontSize: 13,
//                               height: 1.3,
//                             ),
//                           ),
//                         ],
//                       ),
//                     ),
//                     const SizedBox(width: 12),
//                     Column(
//                       crossAxisAlignment: CrossAxisAlignment.end,
//                       children: [
//                         Text(
//                           priceLabel,
//                           style: const TextStyle(
//                             color: _P.muted,
//                             fontSize: 10,
//                             letterSpacing: 1,
//                             fontWeight: FontWeight.w800,
//                           ),
//                         ),
//                         ConstrainedBox(
//                           constraints: const BoxConstraints(maxWidth: 140),
//                           child: FittedBox(
//                             fit: BoxFit.scaleDown,
//                             alignment: Alignment.centerRight,
//                             child: Text(
//                               priceText,
//                               style: TextStyle(
//                                 color: quoted != null ? _P.ink : _P.muted,
//                                 fontSize: 32,
//                                 height: 1.05,
//                                 fontWeight: FontWeight.w900,
//                                 letterSpacing: -1,
//                               ),
//                             ),
//                           ),
//                         ),
//                       ],
//                     ),
//                   ],
//                 ),
//                 const SizedBox(height: 20),

//                 // journey track
//                 if (failed)
//                   Container(
//                     padding: const EdgeInsets.all(12),
//                     decoration: BoxDecoration(
//                       color: color.withOpacity(.12),
//                       borderRadius: BorderRadius.circular(14),
//                     ),
//                     child: Row(
//                       children: [
//                         Icon(
//                           status == 'rejected'
//                               ? Icons.cancel_rounded
//                               : Icons.block_rounded,
//                           color: color,
//                         ),
//                         const SizedBox(width: 10),
//                         Expanded(
//                           child: Text(
//                             message,
//                             style: TextStyle(
//                               color: color,
//                               fontWeight: FontWeight.w700,
//                             ),
//                           ),
//                         ),
//                       ],
//                     ),
//                   )
//                 else
//                   _track(idx, color, pulse: needsReview || needsPay),
//                 const SizedBox(height: 18),

//                 // smart button
//                 _Tap(
//                   onTap: () => Get.to(() => const QuotesView()),
//                   child: Container(
//                     width: double.infinity,
//                     padding: const EdgeInsets.symmetric(vertical: 14),
//                     decoration: BoxDecoration(
//                       color: (needsReview || needsPay) ? _P.ink : Colors.white,
//                       borderRadius: BorderRadius.circular(16),
//                       border: Border.all(
//                         color: (needsReview || needsPay) ? _P.ink : _P.line,
//                       ),
//                     ),
//                     child: Row(
//                       mainAxisAlignment: MainAxisAlignment.center,
//                       children: [
//                         Flexible(
//                           child: Text(
//                             ctaText,
//                             maxLines: 1,
//                             overflow: TextOverflow.ellipsis,
//                             style: TextStyle(
//                               color: (needsReview || needsPay)
//                                   ? Colors.white
//                                   : _P.ink,
//                               fontWeight: FontWeight.w800,
//                               fontSize: 15,
//                             ),
//                           ),
//                         ),
//                         const SizedBox(width: 6),
//                         Icon(
//                           Icons.arrow_forward_rounded,
//                           size: 18,
//                           color: (needsReview || needsPay) ? _P.coral : _P.ink,
//                         ),
//                       ],
//                     ),
//                   ),
//                 ),
//               ],
//             ),
//           ),
//         ],
//       ),
//     );
//   }

//   Widget _track(int idx, Color color, {required bool pulse}) {
//     final last = _flow.length - 1;
//     return Row(
//       crossAxisAlignment: CrossAxisAlignment.start,
//       children: [
//         for (var i = 0; i <= last; i++)
//           Expanded(
//             child: Column(
//               mainAxisSize: MainAxisSize.min,
//               children: [
//                 SizedBox(
//                   height: 34,
//                   child: Row(
//                     children: [
//                       Expanded(
//                         child: AnimatedContainer(
//                           duration: const Duration(milliseconds: 500),
//                           height: 3,
//                           color: i == 0
//                               ? Colors.transparent
//                               : (i <= idx ? color : _P.line),
//                         ),
//                       ),
//                       Stack(
//                         alignment: Alignment.center,
//                         children: [
//                           if (i == idx && pulse) _Ring(color: color),
//                           AnimatedContainer(
//                             duration: const Duration(milliseconds: 450),
//                             curve: Curves.easeOutBack,
//                             width: i == idx ? 30 : 22,
//                             height: i == idx ? 30 : 22,
//                             decoration: BoxDecoration(
//                               shape: BoxShape.circle,
//                               color: i <= idx ? color : Colors.white,
//                               border: Border.all(
//                                 color: i <= idx ? color : _P.line,
//                                 width: 2,
//                               ),
//                               boxShadow: i == idx
//                                   ? [
//                                       BoxShadow(
//                                         color: color.withOpacity(.4),
//                                         blurRadius: 10,
//                                         offset: const Offset(0, 3),
//                                       ),
//                                     ]
//                                   : null,
//                             ),
//                             child: Icon(
//                               i < idx ? Icons.check_rounded : _flowIcons[i],
//                               size: i == idx ? 16 : 13,
//                               color: i <= idx
//                                   ? Colors.white
//                                   : _P.muted.withOpacity(.6),
//                             ),
//                           ),
//                         ],
//                       ),
//                       Expanded(
//                         child: AnimatedContainer(
//                           duration: const Duration(milliseconds: 500),
//                           height: 3,
//                           color: i == last
//                               ? Colors.transparent
//                               : (i < idx ? color : _P.line),
//                         ),
//                       ),
//                     ],
//                   ),
//                 ),
//                 const SizedBox(height: 4),
//                 FittedBox(
//                   fit: BoxFit.scaleDown,
//                   child: Text(
//                     _flowLabels[i],
//                     maxLines: 1,
//                     style: TextStyle(
//                       fontSize: 10.5,
//                       fontWeight: i == idx ? FontWeight.w900 : FontWeight.w600,
//                       color: i == idx ? _P.ink : _P.muted,
//                     ),
//                   ),
//                 ),
//               ],
//             ),
//           ),
//       ],
//     );
//   }

//   Widget _emptyHero() => Container(
//     padding: const EdgeInsets.all(20),
//     decoration: BoxDecoration(
//       borderRadius: BorderRadius.circular(28),
//       gradient: const LinearGradient(
//         colors: [Color(0xFFFFE3D0), Color(0xFFFFF1D6)],
//         begin: Alignment.topLeft,
//         end: Alignment.bottomRight,
//       ),
//     ),
//     child: Row(
//       children: [
//         Expanded(
//           child: Column(
//             crossAxisAlignment: CrossAxisAlignment.start,
//             children: [
//               const Text(
//                 'Your next project\nstarts here',
//                 style: TextStyle(
//                   color: _P.ink,
//                   fontSize: 21,
//                   height: 1.15,
//                   fontWeight: FontWeight.w900,
//                   letterSpacing: -.4,
//                 ),
//               ),
//               const SizedBox(height: 6),
//               const Text(
//                 'Describe the job, get a clear price.',
//                 style: TextStyle(color: _P.muted, fontSize: 13),
//               ),
//               const SizedBox(height: 14),
//               _Tap(
//                 onTap: () => c.tab.value = 1,
//                 child: Container(
//                   padding: const EdgeInsets.symmetric(
//                     horizontal: 18,
//                     vertical: 11,
//                   ),
//                   decoration: BoxDecoration(
//                     color: _P.ink,
//                     borderRadius: BorderRadius.circular(14),
//                   ),
//                   child: const Row(
//                     mainAxisSize: MainAxisSize.min,
//                     children: [
//                       Text(
//                         'Request a quote',
//                         style: TextStyle(
//                           color: Colors.white,
//                           fontWeight: FontWeight.w800,
//                         ),
//                       ),
//                       SizedBox(width: 6),
//                       Icon(
//                         Icons.arrow_forward_rounded,
//                         color: _P.coral,
//                         size: 18,
//                       ),
//                     ],
//                   ),
//                 ),
//               ),
//             ],
//           ),
//         ),
//         const SizedBox(width: 10),
//         Transform.rotate(
//           angle: -.15,
//           child: const Icon(
//             Icons.home_repair_service_rounded,
//             size: 84,
//             color: _P.coral,
//           ),
//         ),
//       ],
//     ),
//   );

//   Widget _skeleton() => _Breathing(
//     child: Container(
//       height: 210,
//       decoration: BoxDecoration(
//         color: Colors.white,
//         borderRadius: BorderRadius.circular(28),
//         border: Border.all(color: _P.line),
//       ),
//       child: const Center(
//         child: SizedBox(
//           width: 24,
//           height: 24,
//           child: CircularProgressIndicator(color: _P.coral, strokeWidth: 2.6),
//         ),
//       ),
//     ),
//   );

//   // ───────────────────────── bento tiles ─────────────────────────
//   Widget _bento(int quoteCount, int actionCount) {
//     Widget small(
//       IconData icon,
//       String title,
//       String? badge,
//       Color tint,
//       VoidCallback onTap, {
//       bool dot = false,
//     }) {
//       return _Tap(
//         onTap: onTap,
//         child: Container(
//           width: double.infinity,
//           padding: const EdgeInsets.all(14),
//           decoration: BoxDecoration(
//             color: _P.card,
//             borderRadius: BorderRadius.circular(22),
//             border: Border.all(color: _P.line),
//           ),
//           child: Row(
//             children: [
//               Container(
//                 width: 38,
//                 height: 38,
//                 decoration: BoxDecoration(
//                   color: tint.withOpacity(.13),
//                   borderRadius: BorderRadius.circular(12),
//                 ),
//                 child: Icon(icon, color: tint, size: 21),
//               ),
//               const SizedBox(width: 10),
//               Expanded(
//                 child: Text(
//                   title,
//                   maxLines: 2,
//                   overflow: TextOverflow.ellipsis,
//                   style: const TextStyle(
//                     color: _P.ink,
//                     fontWeight: FontWeight.w800,
//                     fontSize: 13.5,
//                     height: 1.15,
//                   ),
//                 ),
//               ),
//               if (badge != null)
//                 Container(
//                   padding: const EdgeInsets.symmetric(
//                     horizontal: 8,
//                     vertical: 3,
//                   ),
//                   decoration: BoxDecoration(
//                     color: dot ? _P.coral : _P.bg,
//                     borderRadius: BorderRadius.circular(10),
//                   ),
//                   child: Text(
//                     badge,
//                     style: TextStyle(
//                       color: dot ? Colors.white : _P.muted,
//                       fontSize: 11.5,
//                       fontWeight: FontWeight.w900,
//                     ),
//                   ),
//                 ),
//             ],
//           ),
//         ),
//       );
//     }

//     return IntrinsicHeight(
//       child: Row(
//         crossAxisAlignment: CrossAxisAlignment.stretch,
//         children: [
//           // big tile
//           Expanded(
//             flex: 5,
//             child: _Tap(
//               onTap: () => c.tab.value = 1,
//               child: Container(
//                 padding: const EdgeInsets.all(16),
//                 decoration: BoxDecoration(
//                   borderRadius: BorderRadius.circular(22),
//                   gradient: const LinearGradient(
//                     colors: [_P.coral, Color(0xFFFF9248)],
//                     begin: Alignment.topLeft,
//                     end: Alignment.bottomRight,
//                   ),
//                   boxShadow: [
//                     BoxShadow(
//                       color: _P.coral.withOpacity(.3),
//                       blurRadius: 16,
//                       offset: const Offset(0, 8),
//                     ),
//                   ],
//                 ),
//                 child: Column(
//                   crossAxisAlignment: CrossAxisAlignment.start,
//                   mainAxisAlignment: MainAxisAlignment.spaceBetween,
//                   children: [
//                     Container(
//                       width: 42,
//                       height: 42,
//                       decoration: BoxDecoration(
//                         color: Colors.white.withOpacity(.25),
//                         shape: BoxShape.circle,
//                       ),
//                       child: const Icon(
//                         Icons.add_rounded,
//                         color: Colors.white,
//                         size: 26,
//                       ),
//                     ),
//                     const SizedBox(height: 18),
//                     const Text(
//                       'Request\na quote',
//                       style: TextStyle(
//                         color: Colors.white,
//                         fontSize: 20,
//                         height: 1.1,
//                         fontWeight: FontWeight.w900,
//                         letterSpacing: -.4,
//                       ),
//                     ),
//                     const SizedBox(height: 4),
//                     Text(
//                       'Takes about a minute',
//                       style: TextStyle(
//                         color: Colors.white.withOpacity(.85),
//                         fontSize: 12,
//                       ),
//                     ),
//                   ],
//                 ),
//               ),
//             ),
//           ),
//           const SizedBox(width: 12),
//           Expanded(
//             flex: 6,
//             child: Column(
//               mainAxisAlignment: MainAxisAlignment.spaceBetween,
//               children: [
//                 small(
//                   Icons.receipt_long_rounded,
//                   actionCount > 0 ? 'My quotes · action needed' : 'My quotes',
//                   actionCount > 0
//                       ? '$actionCount'
//                       : (quoteCount > 0 ? '$quoteCount' : null),
//                   _P.lilac,
//                   () => c.tab.value = 2,
//                   dot: actionCount > 0,
//                 ),
//                 const SizedBox(height: 12),
//                 small(
//                   Icons.payments_rounded,
//                   'Pay invoice',
//                   null,
//                   _P.mint,
//                   () => Get.to(() => const InvoicesView()),
//                 ),
//               ],
//             ),
//           ),
//         ],
//       ),
//     );
//   }

//   // ───────────────────────── promo ─────────────────────────
//   Widget _promo() => Container(
//     padding: const EdgeInsets.all(14),
//     decoration: BoxDecoration(
//       color: _P.ink,
//       borderRadius: BorderRadius.circular(22),
//     ),
//     child: Row(
//       children: [
//         Container(
//           padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
//           decoration: BoxDecoration(
//             color: _P.sun,
//             borderRadius: BorderRadius.circular(14),
//           ),
//           child: const Text(
//             '10%\nOFF',
//             textAlign: TextAlign.center,
//             style: TextStyle(
//               color: _P.ink,
//               fontWeight: FontWeight.w900,
//               height: 1.05,
//               fontSize: 14,
//             ),
//           ),
//         ),
//         const SizedBox(width: 14),
//         const Expanded(
//           child: Column(
//             crossAxisAlignment: CrossAxisAlignment.start,
//             children: [
//               Text(
//                 'Fall special',
//                 style: TextStyle(
//                   color: Colors.white,
//                   fontWeight: FontWeight.w900,
//                   fontSize: 15,
//                 ),
//               ),
//               SizedBox(height: 2),
//               Text(
//                 'Pressure washing booked before Oct 31.',
//                 style: TextStyle(
//                   color: Color(0xFFB9BFC6),
//                   fontSize: 12.5,
//                   height: 1.3,
//                 ),
//               ),
//             ],
//           ),
//         ),
//         const Icon(Icons.local_offer_rounded, color: _P.sun),
//       ],
//     ),
//   );

//   // ───────────────────────── services ─────────────────────────
//   Widget _servicesHeader() => Row(
//     children: [
//       const Expanded(
//         child: Text(
//           'Our services',
//           style: TextStyle(
//             color: _P.ink,
//             fontSize: 20,
//             fontWeight: FontWeight.w900,
//             letterSpacing: -.4,
//           ),
//         ),
//       ),
//       _Tap(
//         onTap: () => c.tab.value = 1,
//         child: const Padding(
//           padding: EdgeInsets.symmetric(vertical: 4, horizontal: 4),
//           child: Text(
//             'See all →',
//             style: TextStyle(color: _P.coral, fontWeight: FontWeight.w800),
//           ),
//         ),
//       ),
//     ],
//   );

//   Widget _services(double width) {
//     final cols = width >= 700 ? 4 : (width >= 460 ? 3 : 2);
//     const gap = 10.0;
//     final itemW = (width - gap * (cols - 1)) / cols;
//     return Wrap(
//       spacing: gap,
//       runSpacing: gap,
//       children: [
//         for (var i = 0; i < kServices.length; i++)
//           SizedBox(
//             width: itemW,
//             child: _Reveal(
//               delay: 380 + (i.clamp(0, 8)) * 40,
//               child: _Tap(
//                 onTap: () => c.tab.value = 1,
//                 child: Container(
//                   padding: const EdgeInsets.all(10),
//                   decoration: BoxDecoration(
//                     color: _P.card,
//                     borderRadius: BorderRadius.circular(18),
//                     border: Border.all(color: _P.line),
//                   ),
//                   child: Row(
//                     children: [
//                       Container(
//                         width: 36,
//                         height: 36,
//                         decoration: BoxDecoration(
//                           color: _P.tints[i % _P.tints.length].withOpacity(.13),
//                           borderRadius: BorderRadius.circular(11),
//                         ),
//                         child: Icon(
//                           kServices[i].$2,
//                           color: _P.tints[i % _P.tints.length],
//                           size: 20,
//                         ),
//                       ),
//                       const SizedBox(width: 9),
//                       Expanded(
//                         child: Text(
//                           kServices[i].$1,
//                           maxLines: 2,
//                           overflow: TextOverflow.ellipsis,
//                           style: const TextStyle(
//                             color: _P.ink,
//                             fontSize: 12.5,
//                             fontWeight: FontWeight.w800,
//                             height: 1.15,
//                           ),
//                         ),
//                       ),
//                     ],
//                   ),
//                 ),
//               ),
//             ),
//           ),
//       ],
//     );
//   }

//   // ───────────────────────── activity drawer ─────────────────────────
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
//           color: _P.bg,
//           borderRadius: const BorderRadius.horizontal(
//             left: Radius.circular(28),
//           ),
//           clipBehavior: Clip.antiAlias,
//           child: SizedBox(
//             width: (MediaQuery.of(context).size.width * 0.86).clamp(
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
//                         const Expanded(
//                           child: Text(
//                             'Recent activity',
//                             style: TextStyle(
//                               color: _P.ink,
//                               fontSize: 21,
//                               fontWeight: FontWeight.w900,
//                               letterSpacing: -.4,
//                             ),
//                           ),
//                         ),
//                         IconButton(
//                           onPressed: () => Navigator.of(context).pop(),
//                           icon: const Icon(Icons.close_rounded),
//                         ),
//                       ],
//                     ),
//                   ),
//                   Expanded(
//                     child: Obx(
//                       () => c.notifs.isEmpty
//                           ? const Center(
//                               child: Column(
//                                 mainAxisSize: MainAxisSize.min,
//                                 children: [
//                                   Icon(
//                                     Icons.notifications_off_outlined,
//                                     color: _P.muted,
//                                     size: 40,
//                                   ),
//                                   SizedBox(height: 8),
//                                   Text(
//                                     'Nothing new yet',
//                                     style: TextStyle(color: _P.muted),
//                                   ),
//                                 ],
//                               ),
//                             )
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
//                                     color: _P.card,
//                                     borderRadius: BorderRadius.circular(18),
//                                     border: Border.all(color: _P.line),
//                                   ),
//                                   child: Row(
//                                     crossAxisAlignment:
//                                         CrossAxisAlignment.start,
//                                     children: [
//                                       Container(
//                                         padding: const EdgeInsets.all(9),
//                                         decoration: BoxDecoration(
//                                           color: _P.coral.withOpacity(.12),
//                                           shape: BoxShape.circle,
//                                         ),
//                                         child: Icon(
//                                           n.icon,
//                                           color: _P.coral,
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
//                                                 color: _P.ink,
//                                                 fontWeight: FontWeight.w800,
//                                               ),
//                                             ),
//                                             const SizedBox(height: 2),
//                                             Text(
//                                               n.body,
//                                               style: const TextStyle(
//                                                 color: _P.muted,
//                                                 height: 1.3,
//                                               ),
//                                             ),
//                                             const SizedBox(height: 6),
//                                             Text(
//                                               n.time,
//                                               style: const TextStyle(
//                                                 fontSize: 11,
//                                                 color: _P.muted,
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
//                     child: _Tap(
//                       onTap: () {
//                         Navigator.of(context).pop();
//                         Get.to(() => const NotificationsView());
//                       },
//                       child: Container(
//                         width: double.infinity,
//                         padding: const EdgeInsets.symmetric(vertical: 14),
//                         decoration: BoxDecoration(
//                           color: _P.ink,
//                           borderRadius: BorderRadius.circular(16),
//                         ),
//                         child: const Center(
//                           child: Text(
//                             'View all notifications',
//                             style: TextStyle(
//                               color: Colors.white,
//                               fontWeight: FontWeight.w800,
//                             ),
//                           ),
//                         ),
//                       ),
//                     ),
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
// }
