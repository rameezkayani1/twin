// =============================================================
// quotes_view.dart  —  Customer "Your quotes" (single file, v2 design)
//
// Reads  : quote_requests  (where userId == current user)
// Updates: status / statusHistory / customerNote (customer actions)
//
// pubspec: get, firebase_auth, cloud_firestore
//
// Usage:
//   QuotesView(onPayDeposit: (q) => Get.to(() => PayView(...)))
//
// Design notes
//  - Phone  (<600)  : 1 column
//  - Tablet (<960)  : 2 columns
//  - Desktop        : 3 columns, content capped at 1100px
//  - Detail page    : single column on phone, two columns when wide
//  - No fixed card heights -> no overflow with large system fonts
// =============================================================
import 'dart:async';
import 'dart:math' as math;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

// ---------------------------------------------------------
// THEME + HELPERS
// ---------------------------------------------------------
class _T {
  static const orange = Color(0xFFFF7A00);
  static const orangeDark = Color(0xFFE55F00);
  static const ink = Color(0xFF1B1F2A);
  static const bg = Color(0xFFF5F3EF); // warm paper
  static const surface = Colors.white;
  static const muted = Color(0xFF787F90);
  static const line = Color(0xFFE9E5DD);
  static const green = Color(0xFF1FAE6B);
  static const red = Color(0xFFE4513F);
  static const blue = Color(0xFF2D8CDB);
  static const purple = Color(0xFF8E54E0);
}

const _months = [
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

String _date(DateTime? d) =>
    d == null ? '—' : '${_months[d.month - 1]} ${d.day}, ${d.year}';

String _money(num v) {
  final parts = v.toStringAsFixed(2).split('.');
  final whole = parts[0].replaceAllMapped(
    RegExp(r'\B(?=(\d{3})+(?!\d))'),
    (_) => ',',
  );
  return '\$$whole.${parts[1]}';
}

double _n(dynamic v) => v is num ? v.toDouble() : (double.tryParse('$v') ?? 0);
DateTime? _dt(dynamic v) => v is Timestamp ? v.toDate() : null;

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
    case 'Assembly':
      return Icons.construction_rounded;
    case 'Waste Disposal':
      return Icons.delete_outline_rounded;
    case 'Lawn Services':
    case 'Landscaping':
      return Icons.yard_rounded;
    case 'AC Repair':
      return Icons.ac_unit;
    case 'Carpentry':
      return Icons.carpenter;
    case 'Roofing':
      return Icons.roofing;
    case 'Moving':
      return Icons.local_shipping_rounded;
    default:
      return Icons.handyman_rounded;
  }
}

// ---------------------------------------------------------
// STATUS DEFINITIONS
// ---------------------------------------------------------
class QS {
  static const pending = 'pending';
  static const reviewing = 'reviewing';
  static const quoted = 'quoted';
  static const changes = 'changes_requested';
  static const accepted = 'accepted';
  static const scheduled = 'scheduled';
  static const completed = 'completed';
  static const rejected = 'rejected';
  static const cancelled = 'cancelled';

  /// Happy-path flow used by the progress tracker
  static const flow = [
    pending,
    reviewing,
    quoted,
    accepted,
    scheduled,
    completed,
  ];

  static const flowLabels = [
    'Sent',
    'Review',
    'Quote',
    'Approved',
    'Booked',
    'Done',
  ];
}

class _Meta {
  final String label, desc;
  final Color color;
  final IconData icon;
  const _Meta(this.label, this.desc, this.color, this.icon);
}

_Meta _meta(String s) {
  switch (s) {
    case QS.pending:
      return const _Meta(
        'Pending',
        'Your request was received and is waiting to be reviewed.',
        Color(0xFFF2994A),
        Icons.hourglass_top_rounded,
      );
    case QS.reviewing:
      return const _Meta(
        'In review',
        'Our team is reviewing your request and preparing a quote.',
        _T.blue,
        Icons.manage_search_rounded,
      );
    case QS.quoted:
      return const _Meta(
        'Quote ready',
        'Your quote is ready. Please review and approve, or ask for changes.',
        _T.purple,
        Icons.request_quote_rounded,
      );
    case QS.changes:
      return const _Meta(
        'Changes requested',
        'We received your change request and will send an updated quote.',
        Color(0xFFE0A800),
        Icons.edit_note_rounded,
      );
    case QS.accepted:
      return const _Meta(
        'Approved',
        'You approved the quote. A deposit is needed before scheduling.',
        _T.green,
        Icons.thumb_up_alt_rounded,
      );
    case QS.scheduled:
      return const _Meta(
        'Scheduled',
        'Your job is scheduled. We will see you on the planned date.',
        Color(0xFF00A8A8),
        Icons.event_available_rounded,
      );
    case QS.completed:
      return const _Meta(
        'Completed',
        'The job is finished. Thank you for choosing us!',
        _T.green,
        Icons.verified_rounded,
      );
    case QS.rejected:
      return const _Meta(
        'Declined',
        'This quote was declined.',
        _T.red,
        Icons.cancel_rounded,
      );
    case QS.cancelled:
      return const _Meta(
        'Cancelled',
        'This request was cancelled.',
        _T.muted,
        Icons.block_rounded,
      );
    default:
      return _Meta(s, '', _T.muted, Icons.info_outline_rounded);
  }
}

// ---------------------------------------------------------
// MODELS
// ---------------------------------------------------------
class QuoteBreakdown {
  final double labor,
      materials,
      fees,
      discount,
      tax,
      total,
      depositPct,
      deposit;
  final DateTime? expiresAt, issuedAt;
  final String notes;
  QuoteBreakdown({
    required this.labor,
    required this.materials,
    required this.fees,
    required this.discount,
    required this.tax,
    required this.total,
    required this.depositPct,
    required this.deposit,
    this.expiresAt,
    this.issuedAt,
    this.notes = '',
  });

  /// Admin writes a `quote` map on the request document.
  static QuoteBreakdown? from(Map<String, dynamic> d) {
    final m = d['quote'];
    if (m is Map<String, dynamic>) {
      final total = _n(m['total']);
      final pct = m['depositPct'] == null ? 30.0 : _n(m['depositPct']);
      return QuoteBreakdown(
        labor: _n(m['labor']),
        materials: _n(m['materials']),
        fees: _n(m['fees']),
        discount: _n(m['discount']),
        tax: _n(m['tax']),
        total: total,
        depositPct: pct,
        deposit: m['deposit'] == null ? total * pct / 100 : _n(m['deposit']),
        expiresAt: _dt(m['expiresAt']),
        issuedAt: _dt(m['issuedAt']),
        notes: (m['notes'] ?? '').toString(),
      );
    }
    final amt = d['quoteAmount'];
    if (amt is num) {
      return QuoteBreakdown(
        labor: amt.toDouble(),
        materials: 0,
        fees: 0,
        discount: 0,
        tax: 0,
        total: amt.toDouble(),
        depositPct: 30,
        deposit: amt * 0.3,
      );
    }
    return null;
  }

  double get remaining => total - deposit;
}

class QuoteModel {
  final String id, number, service, description, name, phone, email, address;
  final String urgency, slot, status, adminNote;
  final double budget;
  final bool depositPaid;
  final DateTime? preferredDate, createdAt, updatedAt;
  final List<Map<String, dynamic>> attachments, history;
  final QuoteBreakdown? quote;

  QuoteModel({
    required this.id,
    required this.number,
    required this.service,
    required this.description,
    required this.name,
    required this.phone,
    required this.email,
    required this.address,
    required this.urgency,
    required this.slot,
    required this.status,
    required this.adminNote,
    required this.budget,
    required this.depositPaid,
    required this.attachments,
    required this.history,
    this.preferredDate,
    this.createdAt,
    this.updatedAt,
    this.quote,
  });

  factory QuoteModel.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final d = doc.data() ?? {};
    List<Map<String, dynamic>> list(dynamic v) => v is List
        ? v.whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList()
        : <Map<String, dynamic>>[];
    return QuoteModel(
      id: doc.id,
      number: (d['requestNumber'] ?? doc.id.substring(0, 6).toUpperCase())
          .toString(),
      service: (d['service'] ?? 'Service').toString(),
      description: (d['description'] ?? '').toString(),
      name: (d['customerName'] ?? '').toString(),
      phone: (d['phone'] ?? '').toString(),
      email: (d['email'] ?? '').toString(),
      address: (d['address'] ?? '').toString(),
      urgency: (d['urgency'] ?? '').toString(),
      slot: (d['preferredSlot'] ?? '').toString(),
      status: (d['status'] ?? QS.pending).toString(),
      adminNote: (d['adminNote'] ?? '').toString(),
      budget: _n(d['budget']),
      depositPaid: d['depositPaid'] == true,
      preferredDate: _dt(d['preferredDate']),
      createdAt: _dt(d['createdAt']),
      updatedAt: _dt(d['updatedAt']),
      attachments: list(d['attachments']),
      history: list(d['statusHistory']),
      quote: QuoteBreakdown.from(d),
    );
  }

  bool get expired =>
      status == QS.quoted &&
      quote?.expiresAt != null &&
      quote!.expiresAt!.isBefore(DateTime.now());
}

// ---------------------------------------------------------
// CONTROLLER  (logic unchanged)
// ---------------------------------------------------------
class QuotesController extends GetxController {
  final _db = FirebaseFirestore.instance;
  final quotes = <QuoteModel>[].obs;
  final loading = true.obs;
  final error = ''.obs;
  final filter = 'All'.obs;
  final busy = false.obs;
  StreamSubscription? _sub;

  static const filters = ['All', 'Action needed', 'In progress', 'Closed'];

  Query<Map<String, dynamic>>? get _query {
    final u = FirebaseAuth.instance.currentUser;
    if (u == null) return null;
    return _db.collection('quote_requests').where('userId', isEqualTo: u.uid);
  }

  @override
  void onInit() {
    super.onInit();
    _listen();
  }

  void _apply(QuerySnapshot<Map<String, dynamic>> snap) {
    final list = snap.docs.map(QuoteModel.fromDoc).toList()
      ..sort(
        (a, b) => (b.createdAt ?? DateTime.now()).compareTo(
          a.createdAt ?? DateTime.now(),
        ),
      );
    quotes.assignAll(list);
    loading.value = false;
    error.value = '';
  }

  void _listen() {
    final q = _query;
    if (q == null) {
      loading.value = false;
      error.value = 'Please log in to see your quotes.';
      return;
    }
    _sub?.cancel();
    _sub = q.snapshots().listen(
      _apply,
      onError: (e) {
        loading.value = false;
        error.value = 'Could not load quotes. Pull down to retry.';
      },
    );
  }

  /// Pull-to-refresh: force a fresh read from the server.
  Future<void> refreshData() async {
    final q = _query;
    if (q == null) return;
    try {
      final snap = await q.get(const GetOptions(source: Source.server));
      _apply(snap);
    } catch (_) {
      error.value = 'You appear to be offline.';
      _snack('Could not refresh. Check your connection.', true);
    }
    _listen();
  }

  bool matches(QuoteModel q, String f) {
    switch (f) {
      case 'Action needed':
        return q.status == QS.quoted;
      case 'In progress':
        return const [
          QS.pending,
          QS.reviewing,
          QS.changes,
          QS.accepted,
          QS.scheduled,
        ].contains(q.status);
      case 'Closed':
        return const [
          QS.completed,
          QS.rejected,
          QS.cancelled,
        ].contains(q.status);
      default:
        return true;
    }
  }

  List<QuoteModel> get visible =>
      quotes.where((q) => matches(q, filter.value)).toList();

  int count(String f) => quotes.where((q) => matches(q, f)).length;

  /// Customer-side status change (approve / decline / changes / cancel)
  Future<bool> updateStatus(
    QuoteModel q,
    String status, {
    String note = '',
  }) async {
    try {
      busy.value = true;
      await _db.collection('quote_requests').doc(q.id).update({
        'status': status,
        if (note.isNotEmpty) 'customerNote': note,
        'updatedAt': FieldValue.serverTimestamp(),
        'statusHistory': FieldValue.arrayUnion([
          {
            'status': status,
            'at': Timestamp.now(),
            'by': 'customer',
            'note': note,
          },
        ]),
      });
      _snack('Status updated to ${_meta(status).label}', false);
      return true;
    } on FirebaseException catch (e) {
      _snack(e.message ?? 'Update failed', true);
    } catch (_) {
      _snack('Something went wrong', true);
    } finally {
      busy.value = false;
    }
    return false;
  }

  void _snack(String m, bool err) => Get.snackbar(
    err ? 'Oops' : 'Done',
    m,
    snackPosition: SnackPosition.BOTTOM,
    margin: const EdgeInsets.all(16),
    borderRadius: 14,
    backgroundColor: err ? _T.red : _T.green,
    colorText: Colors.white,
  );

  @override
  void onClose() {
    _sub?.cancel();
    super.onClose();
  }
}

// ---------------------------------------------------------
// LAYOUT HELPERS
// ---------------------------------------------------------
class _Page extends StatelessWidget {
  final Widget child;
  final double max;
  const _Page({required this.child, this.max = 1100});
  @override
  Widget build(BuildContext context) => Center(
    child: ConstrainedBox(
      constraints: BoxConstraints(maxWidth: max),
      child: child,
    ),
  );
}

int _columns(double w) => w >= 960 ? 3 : (w >= 600 ? 2 : 1);
double _gutter(double w) => w >= 600 ? 24 : 16;

// ---------------------------------------------------------
// QUOTES LIST PAGE
// ---------------------------------------------------------
class QuotesView extends StatelessWidget {
  final void Function(QuoteModel q)? onPayDeposit;
  const QuotesView({super.key, this.onPayDeposit});

  void _open(QuoteModel q) =>
      Get.to(() => QuoteDetailView(q: q, onPayDeposit: onPayDeposit));

  @override
  Widget build(BuildContext context) {
    final c = Get.put(QuotesController());
    return Scaffold(
      backgroundColor: _T.bg,
      body: RefreshIndicator(
        color: _T.orange,
        onRefresh: c.refreshData,
        child: LayoutBuilder(
          builder: (context, box) {
            final w = box.maxWidth;
            final pad = _gutter(w);
            final contentW = math.min(w, 1100.0) - pad * 2;
            final cols = _columns(w);
            const gap = 14.0;
            final itemW = (contentW - gap * (cols - 1)) / cols;
            final top = MediaQuery.of(context).padding.top;

            return CustomScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              slivers: [
                // ---- title bar
                SliverToBoxAdapter(
                  child: _Page(
                    child: Padding(
                      padding: EdgeInsets.fromLTRB(pad, top + 18, pad, 6),
                      child: Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'Your quotes',
                                  style: TextStyle(
                                    fontSize: 30,
                                    height: 1.1,
                                    fontWeight: FontWeight.w900,
                                    color: _T.ink,
                                    letterSpacing: -.5,
                                  ),
                                ),
                                const SizedBox(height: 6),
                                Obx(
                                  () => Text(
                                    c.quotes.isEmpty
                                        ? 'From request to finished job.'
                                        : '${c.quotes.length} request${c.quotes.length == 1 ? '' : 's'} · tracked live',
                                    style: const TextStyle(color: _T.muted),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Material(
                            color: _T.surface,
                            shape: const CircleBorder(
                              side: BorderSide(color: _T.line),
                            ),
                            child: IconButton(
                              tooltip: 'Refresh',
                              onPressed: c.refreshData,
                              icon: const Icon(
                                Icons.refresh_rounded,
                                color: _T.ink,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),

                // ---- spotlight: quote waiting on the customer
                SliverToBoxAdapter(
                  child: Obx(() {
                    final waiting = c.quotes
                        .where((q) => q.status == QS.quoted && !q.expired)
                        .toList();
                    if (waiting.isEmpty) return const SizedBox.shrink();
                    return _Page(
                      child: Padding(
                        padding: EdgeInsets.fromLTRB(pad, 14, pad, 0),
                        child: _Spotlight(
                          q: waiting.first,
                          more: waiting.length - 1,
                          onTap: () => _open(waiting.first),
                        ),
                      ),
                    );
                  }),
                ),

                // ---- filter pills
                SliverToBoxAdapter(
                  child: _Page(
                    child: _FilterBar(c: c, pad: pad),
                  ),
                ),

                // ---- content
                Obx(() {
                  if (c.loading.value) {
                    return const SliverFillRemaining(
                      hasScrollBody: false,
                      child: Center(
                        child: CircularProgressIndicator(color: _T.orange),
                      ),
                    );
                  }
                  final list = c.visible;
                  if (list.isEmpty) {
                    return SliverFillRemaining(
                      hasScrollBody: false,
                      child: _Empty(
                        message: c.error.value.isNotEmpty
                            ? c.error.value
                            : (c.quotes.isEmpty
                                  ? 'No quotes yet.\nSubmit a request and it will show up here.'
                                  : 'Nothing in this tab.'),
                      ),
                    );
                  }
                  return SliverToBoxAdapter(
                    child: _Page(
                      child: Padding(
                        padding: EdgeInsets.fromLTRB(pad, 4, pad, 40),
                        child: Wrap(
                          spacing: gap,
                          runSpacing: gap,
                          children: [
                            for (var i = 0; i < list.length; i++)
                              SizedBox(
                                width: itemW,
                                child: _QuoteCard(
                                  q: list[i],
                                  index: i,
                                  onTap: () => _open(list[i]),
                                ),
                              ),
                          ],
                        ),
                      ),
                    ),
                  );
                }),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _Spotlight extends StatelessWidget {
  final QuoteModel q;
  final int more;
  final VoidCallback onTap;
  const _Spotlight({required this.q, required this.more, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: _T.ink,
      borderRadius: BorderRadius.circular(24),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Stack(
          children: [
            Positioned(
              right: -30,
              top: -30,
              child: Container(
                width: 130,
                height: 130,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: _T.orange.withValues(alpha: .22),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(18),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            const Icon(
                              Icons.bolt_rounded,
                              color: _T.orange,
                              size: 18,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              more > 0
                                  ? 'Your quote is ready  ·  +$more more'
                                  : 'Your quote is ready',
                              style: TextStyle(
                                color: Colors.white.withValues(alpha: .75),
                                fontSize: 12.5,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Text(
                          q.service,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 20,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          _money(q.quote?.total ?? q.budget),
                          style: const TextStyle(
                            color: _T.orange,
                            fontSize: 24,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 12,
                    ),
                    decoration: BoxDecoration(
                      color: _T.orange,
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          'Review',
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        SizedBox(width: 4),
                        Icon(
                          Icons.arrow_forward_rounded,
                          color: Colors.white,
                          size: 18,
                        ),
                      ],
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
}

class _FilterBar extends StatelessWidget {
  final QuotesController c;
  final double pad;
  const _FilterBar({required this.c, required this.pad});

  @override
  Widget build(BuildContext context) => SizedBox(
    height: 70,
    child: Obx(
      () => ListView(
        scrollDirection: Axis.horizontal,
        padding: EdgeInsets.symmetric(horizontal: pad, vertical: 14),
        children: [
          for (final f in QuotesController.filters)
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: _pill(f, c.filter.value == f, c.count(f)),
            ),
        ],
      ),
    ),
  );

  Widget _pill(String f, bool on, int n) => GestureDetector(
    onTap: () => c.filter.value = f,
    child: AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      padding: const EdgeInsets.symmetric(horizontal: 14),
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: on ? _T.ink : _T.surface,
        borderRadius: BorderRadius.circular(30),
        border: Border.all(color: on ? _T.ink : _T.line),
      ),
      child: Row(
        children: [
          Text(
            f,
            style: TextStyle(
              fontWeight: FontWeight.w700,
              color: on ? Colors.white : _T.ink,
            ),
          ),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
            decoration: BoxDecoration(
              color: on ? _T.orange : _T.bg,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Text(
              '$n',
              style: TextStyle(
                fontSize: 11.5,
                fontWeight: FontWeight.w800,
                color: on ? Colors.white : _T.muted,
              ),
            ),
          ),
        ],
      ),
    ),
  );
}

class _Empty extends StatelessWidget {
  final String message;
  const _Empty({required this.message});
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.all(32),
    child: Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Container(
          padding: const EdgeInsets.all(22),
          decoration: BoxDecoration(
            color: _T.orange.withValues(alpha: .1),
            shape: BoxShape.circle,
          ),
          child: const Icon(Icons.inbox_rounded, color: _T.orange, size: 44),
        ),
        const SizedBox(height: 16),
        Text(
          message,
          textAlign: TextAlign.center,
          style: const TextStyle(color: _T.muted, height: 1.4),
        ),
      ],
    ),
  );
}

// ---------------------------------------------------------
// SHARED SMALL WIDGETS
// ---------------------------------------------------------
class _StatusChip extends StatelessWidget {
  final String status;
  final bool expired;
  const _StatusChip(this.status, {this.expired = false});
  @override
  Widget build(BuildContext context) {
    final m = expired
        ? const _Meta('Expired', '', _T.red, Icons.timer_off_rounded)
        : _meta(status);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: m.color.withValues(alpha: .13),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(m.icon, size: 14, color: m.color),
          const SizedBox(width: 5),
          Flexible(
            child: Text(
              m.label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: m.color,
                fontWeight: FontWeight.w800,
                fontSize: 12,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Dot-and-line journey tracker. Each stage is its own cell so labels
/// always sit exactly under their dot, at any width.
class _Stepper extends StatelessWidget {
  final String status;
  final bool labels;
  final double dot;
  const _Stepper(this.status, {this.labels = false, this.dot = 10});

  @override
  Widget build(BuildContext context) {
    final failed = status == QS.rejected || status == QS.cancelled;
    var idx = QS.flow.indexOf(status);
    if (status == QS.changes) idx = 1;
    final base = failed ? _T.red : _meta(status).color;
    final last = QS.flow.length - 1;

    Color seg(bool on) =>
        failed ? base.withValues(alpha: .3) : (on ? base : _T.line);

    return Row(
      children: [
        for (var i = 0; i <= last; i++)
          Expanded(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Container(
                        height: 3,
                        color: i == 0 ? Colors.transparent : seg(i <= idx),
                      ),
                    ),
                    Container(
                      width: dot,
                      height: dot,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: seg(i <= idx),
                        border: !failed && i == idx
                            ? Border.all(
                                color: base.withValues(alpha: .3),
                                width: dot * .35,
                              )
                            : null,
                      ),
                    ),
                    Expanded(
                      child: Container(
                        height: 3,
                        color: i == last ? Colors.transparent : seg(i < idx),
                      ),
                    ),
                  ],
                ),
                if (labels) ...[
                  const SizedBox(height: 6),
                  Text(
                    QS.flowLabels[i],
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 10.5,
                      fontWeight: i == idx && !failed
                          ? FontWeight.w800
                          : FontWeight.w500,
                      color: i == idx && !failed ? _T.ink : _T.muted,
                    ),
                  ),
                ],
              ],
            ),
          ),
      ],
    );
  }
}

// ---------------------------------------------------------
// LIST CARD
// ---------------------------------------------------------
class _QuoteCard extends StatelessWidget {
  final QuoteModel q;
  final VoidCallback onTap;
  final int index;
  const _QuoteCard({required this.q, required this.onTap, required this.index});

  @override
  Widget build(BuildContext context) {
    final m = _meta(q.status);
    final accent = q.expired ? _T.red : m.color;
    final hasQuote = q.quote != null;

    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: Duration(milliseconds: 280 + (index.clamp(0, 6)) * 60),
      curve: Curves.easeOut,
      builder: (_, v, child) => Opacity(
        opacity: v,
        child: Transform.translate(
          offset: Offset(0, 14 * (1 - v)),
          child: child,
        ),
      ),
      child: Material(
        color: _T.surface,
        clipBehavior: Clip.antiAlias,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: BorderSide(
            color: q.status == QS.quoted && !q.expired
                ? _T.purple.withValues(alpha: .55)
                : _T.line,
            width: q.status == QS.quoted && !q.expired ? 1.5 : 1,
          ),
        ),
        child: InkWell(
          onTap: onTap,
          child: IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Container(width: 5, color: accent),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(14, 14, 14, 12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Container(
                              width: 42,
                              height: 42,
                              decoration: BoxDecoration(
                                color: accent.withValues(alpha: .12),
                                borderRadius: BorderRadius.circular(13),
                              ),
                              child: Icon(
                                _serviceIcon(q.service),
                                color: accent,
                                size: 22,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    q.service,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w800,
                                      color: _T.ink,
                                    ),
                                  ),
                                  Text(
                                    '${q.number} · ${_date(q.createdAt)}',
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                      color: _T.muted,
                                      fontSize: 12,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 8),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                Text(
                                  hasQuote ? 'TOTAL' : 'BUDGET',
                                  style: const TextStyle(
                                    color: _T.muted,
                                    fontSize: 9.5,
                                    letterSpacing: .8,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                                Text(
                                  _money(q.quote?.total ?? q.budget),
                                  style: const TextStyle(
                                    fontSize: 17,
                                    fontWeight: FontWeight.w900,
                                    color: _T.ink,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                        if (q.description.isNotEmpty) ...[
                          const SizedBox(height: 10),
                          Text(
                            q.description,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: _T.muted,
                              height: 1.35,
                              fontSize: 13,
                            ),
                          ),
                        ],
                        const SizedBox(height: 14),
                        _Stepper(q.status),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            Flexible(
                              child: _StatusChip(q.status, expired: q.expired),
                            ),
                            const Spacer(),
                            if (q.status == QS.quoted && !q.expired)
                              const Text(
                                'Review →',
                                style: TextStyle(
                                  color: _T.purple,
                                  fontWeight: FontWeight.w800,
                                ),
                              )
                            else
                              const Icon(
                                Icons.chevron_right_rounded,
                                color: _T.muted,
                              ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------
// DETAIL PAGE (live document stream)
// ---------------------------------------------------------
class QuoteDetailView extends StatelessWidget {
  final QuoteModel q;
  final void Function(QuoteModel q)? onPayDeposit;
  const QuoteDetailView({super.key, required this.q, this.onPayDeposit});

  @override
  Widget build(BuildContext context) {
    final c = Get.find<QuotesController>();
    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance
          .collection('quote_requests')
          .doc(q.id)
          .snapshots(),
      builder: (context, snap) {
        final cur = (snap.hasData && snap.data!.exists)
            ? QuoteModel.fromDoc(snap.data!)
            : q;
        return Scaffold(
          backgroundColor: _T.bg,
          appBar: AppBar(
            backgroundColor: _T.bg,
            surfaceTintColor: Colors.transparent,
            elevation: 0,
            foregroundColor: _T.ink,
            centerTitle: false,
            title: Text(
              cur.number,
              style: const TextStyle(fontWeight: FontWeight.w900),
            ),
          ),
          bottomNavigationBar: _hasAction(cur)
              ? _actionBar(context, c, cur)
              : null,
          body: RefreshIndicator(
            color: _T.orange,
            onRefresh: () async {
              await FirebaseFirestore.instance
                  .collection('quote_requests')
                  .doc(q.id)
                  .get(const GetOptions(source: Source.server));
            },
            child: LayoutBuilder(
              builder: (context, box) {
                final wide = box.maxWidth > 860;
                final left = <Widget>[
                  _hero(cur),
                  if (cur.quote != null) _money_(cur),
                  if (cur.adminNote.isNotEmpty) _adminNote(cur),
                ];
                final right = <Widget>[
                  _info(cur),
                  if (cur.attachments.isNotEmpty) _attachments(cur),
                  _timeline(cur),
                ];
                return ListView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: EdgeInsets.fromLTRB(
                    _gutter(box.maxWidth),
                    4,
                    _gutter(box.maxWidth),
                    32,
                  ),
                  children: [
                    _Page(
                      max: wide ? 1080 : 640,
                      child: wide
                          ? Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Expanded(child: Column(children: left)),
                                const SizedBox(width: 16),
                                Expanded(child: Column(children: right)),
                              ],
                            )
                          : Column(children: [...left, ...right]),
                    ),
                  ],
                );
              },
            ),
          ),
        );
      },
    );
  }

  // ----- containers -----
  Widget _card(
    String? title,
    Widget child, {
    Color? color,
    Color? border,
    EdgeInsets? pad,
  }) => Container(
    width: double.infinity,
    margin: const EdgeInsets.only(bottom: 14),
    padding: pad ?? const EdgeInsets.all(18),
    decoration: BoxDecoration(
      color: color ?? _T.surface,
      borderRadius: BorderRadius.circular(22),
      border: Border.all(color: border ?? _T.line),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (title != null) ...[
          Text(
            title,
            style: const TextStyle(
              fontSize: 15.5,
              fontWeight: FontWeight.w800,
              color: _T.ink,
            ),
          ),
          const SizedBox(height: 14),
        ],
        child,
      ],
    ),
  );

  Widget _kv(String k, String v, {bool bold = false, Color? color}) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 5),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          flex: 4,
          child: Text(
            k,
            style: TextStyle(
              color: bold ? _T.ink : _T.muted,
              fontWeight: bold ? FontWeight.w800 : FontWeight.w500,
            ),
          ),
        ),
        Expanded(
          flex: 6,
          child: Text(
            v,
            textAlign: TextAlign.right,
            style: TextStyle(
              color: color ?? _T.ink,
              fontWeight: bold ? FontWeight.w800 : FontWeight.w600,
              fontSize: bold ? 16 : 14,
            ),
          ),
        ),
      ],
    ),
  );

  // ----- hero -----
  Widget _hero(QuoteModel x) {
    final m = x.expired
        ? const _Meta(
            'Expired',
            'This quote has expired. Please contact us for a new one.',
            _T.red,
            Icons.timer_off_rounded,
          )
        : _meta(x.status);
    return _card(
      null,
      color: m.color.withValues(alpha: .07),
      border: m.color.withValues(alpha: .25),
      Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  color: m.color,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Icon(m.icon, color: Colors.white, size: 26),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      x.service,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w900,
                        color: _T.ink,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      m.label,
                      style: TextStyle(
                        color: m.color,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Text(m.desc, style: const TextStyle(color: _T.ink, height: 1.4)),
          const SizedBox(height: 20),
          _Stepper(x.status, labels: true, dot: 14),
        ],
      ),
    );
  }

  // ----- money: ring + breakdown -----
  Widget _money_(QuoteModel x) {
    final b = x.quote!;
    final frac = b.total > 0 ? (b.deposit / b.total).clamp(0.0, 1.0) : 0.0;
    Widget legend(Color c, String label, String value, {String? sub}) => Row(
      children: [
        Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(color: c, shape: BoxShape.circle),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                sub == null ? label : '$label · $sub',
                style: const TextStyle(color: _T.muted, fontSize: 12),
              ),
              Text(
                value,
                style: const TextStyle(
                  fontWeight: FontWeight.w900,
                  fontSize: 16,
                  color: _T.ink,
                ),
              ),
            ],
          ),
        ),
      ],
    );

    return _card(
      'Your quote',
      Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              SizedBox(
                width: 112,
                height: 112,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    CustomPaint(
                      size: const Size(112, 112),
                      painter: _RingPainter(frac, _T.orange, _T.line),
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 18),
                      child: FittedBox(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Text(
                              'TOTAL',
                              style: TextStyle(
                                fontSize: 9.5,
                                letterSpacing: .8,
                                color: _T.muted,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            Text(
                              _money(b.total),
                              style: const TextStyle(
                                fontWeight: FontWeight.w900,
                                fontSize: 16,
                                color: _T.ink,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 18),
              Expanded(
                child: Column(
                  children: [
                    legend(
                      _T.orange,
                      'Deposit',
                      _money(b.deposit),
                      sub: '${b.depositPct.toStringAsFixed(0)}%',
                    ),
                    const SizedBox(height: 14),
                    legend(_T.line, 'Remaining', _money(b.remaining)),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          if (b.expiresAt != null)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
              decoration: BoxDecoration(
                color: (x.expired ? _T.red : _T.green).withValues(alpha: .1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    x.expired
                        ? Icons.timer_off_rounded
                        : Icons.schedule_rounded,
                    size: 16,
                    color: x.expired ? _T.red : _T.green,
                  ),
                  const SizedBox(width: 6),
                  Flexible(
                    child: Text(
                      x.expired
                          ? 'Expired ${_date(b.expiresAt)}'
                          : 'Valid until ${_date(b.expiresAt)}',
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 12.5,
                        color: x.expired ? _T.red : _T.green,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          Theme(
            data: Theme.of(
              Get.context!,
            ).copyWith(dividerColor: Colors.transparent),
            child: ExpansionTile(
              tilePadding: EdgeInsets.zero,
              childrenPadding: EdgeInsets.zero,
              iconColor: _T.orange,
              collapsedIconColor: _T.muted,
              title: const Text(
                'See price breakdown',
                style: TextStyle(fontWeight: FontWeight.w800, fontSize: 14),
              ),
              children: [
                _kv('Labor', _money(b.labor)),
                if (b.materials > 0) _kv('Materials', _money(b.materials)),
                if (b.fees > 0) _kv('Service / travel fees', _money(b.fees)),
                if (b.discount > 0)
                  _kv('Discount', '-${_money(b.discount)}', color: _T.green),
                if (b.tax > 0) _kv('Tax', _money(b.tax)),
                const Divider(height: 20),
                _kv('Project total', _money(b.total), bold: true),
                if (b.issuedAt != null) _kv('Issued', _date(b.issuedAt)),
              ],
            ),
          ),
          if (b.notes.isNotEmpty)
            Container(
              width: double.infinity,
              margin: const EdgeInsets.only(top: 4),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: _T.blue.withValues(alpha: .1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                b.notes,
                style: const TextStyle(color: _T.blue, height: 1.4),
              ),
            ),
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton.icon(
              onPressed: _terms,
              icon: const Icon(Icons.description_outlined, size: 18),
              label: const Text('Terms & conditions'),
              style: TextButton.styleFrom(
                foregroundColor: _T.orange,
                padding: const EdgeInsets.only(top: 6),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _adminNote(QuoteModel x) => _card(
    null,
    color: _T.orange.withValues(alpha: .08),
    border: _T.orange.withValues(alpha: .25),
    Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Icon(Icons.support_agent_rounded, color: _T.orange),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Message from our team',
                style: TextStyle(
                  fontWeight: FontWeight.w800,
                  color: _T.orangeDark,
                  fontSize: 12.5,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                x.adminNote,
                style: const TextStyle(height: 1.4, color: _T.ink),
              ),
            ],
          ),
        ),
      ],
    ),
  );

  // ----- request info -----
  Widget _fact(IconData icon, String label, String value) => Container(
    padding: const EdgeInsets.all(12),
    decoration: BoxDecoration(
      color: _T.bg,
      borderRadius: BorderRadius.circular(14),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 18, color: _T.orange),
        const SizedBox(height: 8),
        Text(label, style: const TextStyle(color: _T.muted, fontSize: 11.5)),
        const SizedBox(height: 1),
        Text(
          value,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(fontWeight: FontWeight.w800, color: _T.ink),
        ),
      ],
    ),
  );

  Widget _line(IconData i, String v) => v.isEmpty
      ? const SizedBox.shrink()
      : Padding(
          padding: const EdgeInsets.only(top: 10),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(i, size: 18, color: _T.muted),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  v,
                  style: const TextStyle(color: _T.ink, height: 1.3),
                ),
              ),
            ],
          ),
        );

  Widget _info(QuoteModel x) => _card(
    'Your request',
    LayoutBuilder(
      builder: (context, box) {
        final tileW = (box.maxWidth - 10) / 2;
        Widget tile(Widget w) => SizedBox(width: tileW, child: w);
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (x.description.isNotEmpty)
              Text(
                x.description,
                style: const TextStyle(color: _T.ink, height: 1.45),
              ),
            if (x.description.isNotEmpty) const SizedBox(height: 14),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: [
                tile(
                  _fact(
                    Icons.event_rounded,
                    'Preferred date',
                    _date(x.preferredDate),
                  ),
                ),
                tile(
                  _fact(
                    Icons.schedule_rounded,
                    'Time slot',
                    x.slot.isEmpty ? '—' : x.slot,
                  ),
                ),
                tile(
                  _fact(
                    Icons.bolt_rounded,
                    'Urgency',
                    x.urgency.isEmpty ? '—' : x.urgency,
                  ),
                ),
                tile(
                  _fact(Icons.savings_rounded, 'Your budget', _money(x.budget)),
                ),
              ],
            ),
            const Divider(height: 28),
            _line(Icons.location_on_outlined, x.address),
            _line(Icons.person_outline_rounded, x.name),
            _line(Icons.phone_outlined, x.phone),
            _line(Icons.mail_outline_rounded, x.email),
          ],
        );
      },
    ),
  );

  Widget _attachments(QuoteModel x) => _card(
    'Attachments (${x.attachments.length})',
    Wrap(
      spacing: 10,
      runSpacing: 10,
      children: [
        for (final a in x.attachments)
          SizedBox(
            width: 84,
            child: Column(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(14),
                  child: SizedBox(
                    width: 84,
                    height: 84,
                    child: a['type'] == 'image' && a['url'] != null
                        ? Image.network(
                            a['url'],
                            fit: BoxFit.cover,
                            errorBuilder: (_, __, ___) => _fileIcon(a),
                          )
                        : _fileIcon(a),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '${a['name']}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 11, color: _T.muted),
                ),
              ],
            ),
          ),
      ],
    ),
  );

  Widget _fileIcon(Map<String, dynamic> a) => Container(
    color: _T.orange.withValues(alpha: .1),
    child: Icon(
      a['type'] == 'video'
          ? Icons.play_circle_outline_rounded
          : Icons.insert_drive_file_outlined,
      color: _T.orange,
      size: 30,
    ),
  );

  // ----- timeline -----
  Widget _timeline(QuoteModel x) {
    final items = x.history.reversed.toList();
    return _card(
      'Activity',
      items.isEmpty
          ? const Text('No activity yet.', style: TextStyle(color: _T.muted))
          : Column(
              children: [
                for (var i = 0; i < items.length; i++)
                  _tlRow(items[i], i == 0, i == items.length - 1),
              ],
            ),
    );
  }

  Widget _tlRow(Map<String, dynamic> h, bool first, bool last) {
    final m = _meta((h['status'] ?? '').toString());
    final note = (h['note'] ?? '').toString();
    final by = (h['by'] ?? '').toString();
    final at = _dt(h['at']);
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(
            width: 30,
            child: Column(
              children: [
                Container(
                  width: 24,
                  height: 24,
                  decoration: BoxDecoration(
                    color: first ? m.color : m.color.withValues(alpha: .18),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    m.icon,
                    size: 14,
                    color: first ? Colors.white : m.color,
                  ),
                ),
                if (!last) Expanded(child: Container(width: 2, color: _T.line)),
              ],
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(bottom: 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    m.label,
                    style: const TextStyle(
                      fontWeight: FontWeight.w800,
                      color: _T.ink,
                    ),
                  ),
                  Text(
                    '${_date(at)}${by.isEmpty ? '' : ' · ${by == 'customer' ? 'You' : 'Our team'}'}',
                    style: const TextStyle(color: _T.muted, fontSize: 12),
                  ),
                  if (note.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Text(
                        '"$note"',
                        style: const TextStyle(
                          color: _T.ink,
                          fontStyle: FontStyle.italic,
                          height: 1.3,
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ----- sticky action bar (changes with status) -----
  bool _hasAction(QuoteModel x) =>
      (x.status == QS.quoted && !x.expired) ||
      (x.status == QS.accepted && !x.depositPaid && x.quote != null) ||
      x.status == QS.pending ||
      x.status == QS.reviewing ||
      x.status == QS.changes;

  Widget _actionBar(BuildContext context, QuotesController c, QuoteModel x) {
    return SafeArea(
      child: Container(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
        decoration: const BoxDecoration(
          color: _T.surface,
          border: Border(top: BorderSide(color: _T.line)),
        ),
        child: Center(
          heightFactor: 1,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 640),
            child: Obx(() {
              final busy = c.busy.value;
              Widget content;
              if (x.status == QS.quoted && !x.expired) {
                content = Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _primary(
                      'Approve quote',
                      Icons.check_circle_rounded,
                      _T.green,
                      busy ? null : () => _approve(context, c, x),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child: _outline(
                            'Request changes',
                            Icons.edit_note_rounded,
                            _T.orange,
                            busy
                                ? null
                                : () => _askNote(context, c, x, QS.changes),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: _outline(
                            'Decline',
                            Icons.close_rounded,
                            _T.red,
                            busy
                                ? null
                                : () => _askNote(context, c, x, QS.rejected),
                          ),
                        ),
                      ],
                    ),
                  ],
                );
              } else if (x.status == QS.accepted &&
                  !x.depositPaid &&
                  x.quote != null) {
                content = _primary(
                  'Pay deposit — ${_money(x.quote!.deposit)}',
                  Icons.payments_rounded,
                  _T.orange,
                  onPayDeposit == null ? null : () => onPayDeposit!(x),
                );
              } else {
                content = _outline(
                  'Cancel request',
                  Icons.block_rounded,
                  _T.red,
                  busy ? null : () => _askNote(context, c, x, QS.cancelled),
                );
              }
              return AbsorbPointer(absorbing: busy, child: content);
            }),
          ),
        ),
      ),
    );
  }

  Widget _primary(String t, IconData i, Color col, VoidCallback? f) => SizedBox(
    width: double.infinity,
    height: 52,
    child: ElevatedButton.icon(
      onPressed: f,
      icon: Icon(i),
      label: Flexible(
        child: Text(
          t,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15),
        ),
      ),
      style: ElevatedButton.styleFrom(
        elevation: 0,
        backgroundColor: col,
        foregroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
    ),
  );

  Widget _outline(String t, IconData i, Color col, VoidCallback? f) => SizedBox(
    height: 48,
    width: double.infinity,
    child: OutlinedButton.icon(
      onPressed: f,
      icon: Icon(i, size: 18),
      label: Flexible(
        child: Text(
          t,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(fontWeight: FontWeight.w700),
        ),
      ),
      style: OutlinedButton.styleFrom(
        foregroundColor: col,
        side: BorderSide(color: col.withValues(alpha: .6)),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ),
    ),
  );

  // ----- actions -----
  Future<void> _approve(
    BuildContext ctx,
    QuotesController c,
    QuoteModel x,
  ) async {
    final ok = await showDialog<bool>(
      context: ctx,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Approve this quote?'),
        content: Text(
          'You agree to the total of ${_money(x.quote?.total ?? 0)}. A deposit will be needed before scheduling.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Not yet'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: _T.green,
              foregroundColor: Colors.white,
            ),
            child: const Text('Approve'),
          ),
        ],
      ),
    );
    if (ok == true) await c.updateStatus(x, QS.accepted);
  }

  Future<void> _askNote(
    BuildContext ctx,
    QuotesController c,
    QuoteModel x,
    String status,
  ) async {
    final isChanges = status == QS.changes;
    final title = isChanges
        ? 'What should we change?'
        : status == QS.rejected
        ? 'Decline quote'
        : 'Cancel request';
    final note = await showModalBottomSheet<String>(
      context: ctx,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      constraints: const BoxConstraints(maxWidth: 640),
      builder: (_) => _NoteSheet(
        title: title,
        isRequired: isChanges,
        confirm: isChanges ? 'Send request' : 'Confirm',
        danger: !isChanges,
      ),
    );
    if (note == null) return;
    await c.updateStatus(x, status, note: note);
  }

  void _terms() => Get.bottomSheet(
    Container(
      padding: const EdgeInsets.all(24),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: const SafeArea(
        child: Text(
          '1. Quotes are valid until the expiration date.\n\n'
          '2. A deposit is required before scheduling.\n\n'
          '3. Scope changes on site are approved before work continues.\n\n'
          '4. Cancellations within 24 hours may incur a fee.\n\n'
          '(Placeholder — replace with final legal terms.)',
          style: TextStyle(height: 1.5),
        ),
      ),
    ),
  );
}

// ---------------------------------------------------------
// DEPOSIT RING
// ---------------------------------------------------------
class _RingPainter extends CustomPainter {
  final double frac;
  final Color fg, bg;
  _RingPainter(this.frac, this.fg, this.bg);

  @override
  void paint(Canvas canvas, Size size) {
    const stroke = 12.0;
    final rect = Rect.fromLTWH(
      stroke / 2,
      stroke / 2,
      size.width - stroke,
      size.height - stroke,
    );
    final track = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke
      ..color = bg;
    canvas.drawArc(rect, -math.pi / 2, math.pi * 2, false, track);
    final arc = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke
      ..strokeCap = StrokeCap.round
      ..color = fg;
    canvas.drawArc(rect, -math.pi / 2, math.pi * 2 * frac, false, arc);
  }

  @override
  bool shouldRepaint(covariant _RingPainter old) =>
      old.frac != frac || old.fg != fg || old.bg != bg;
}

// ---------------------------------------------------------
// NOTE BOTTOM SHEET
// ---------------------------------------------------------
class _NoteSheet extends StatefulWidget {
  final String title, confirm;
  final bool isRequired, danger;
  const _NoteSheet({
    required this.title,
    required this.confirm,
    required this.isRequired,
    required this.danger,
  });
  @override
  State<_NoteSheet> createState() => _NoteSheetState();
}

class _NoteSheetState extends State<_NoteSheet> {
  final _t = TextEditingController();
  String? _err;

  @override
  void dispose() {
    _t.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final col = widget.danger ? _T.red : _T.orange;
    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        ),
        child: SafeArea(
          top: false,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 44,
                height: 5,
                decoration: BoxDecoration(
                  color: _T.line,
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              const SizedBox(height: 16),
              Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  widget.title,
                  style: const TextStyle(
                    fontSize: 19,
                    fontWeight: FontWeight.w800,
                    color: _T.ink,
                  ),
                ),
              ),
              const SizedBox(height: 14),
              TextField(
                controller: _t,
                maxLines: 4,
                textCapitalization: TextCapitalization.sentences,
                decoration: InputDecoration(
                  hintText: widget.isRequired
                      ? 'Describe the changes…'
                      : 'Reason (optional)',
                  errorText: _err,
                  filled: true,
                  fillColor: _T.bg,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
              const SizedBox(height: 14),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.pop(context),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: _T.ink,
                        minimumSize: const Size.fromHeight(48),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                      child: const Text('Back'),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () {
                        if (widget.isRequired && _t.text.trim().isEmpty) {
                          setState(() => _err = 'Please add a short note');
                          return;
                        }
                        Navigator.pop(context, _t.text.trim());
                      },
                      style: ElevatedButton.styleFrom(
                        elevation: 0,
                        backgroundColor: col,
                        foregroundColor: Colors.white,
                        minimumSize: const Size.fromHeight(48),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                      child: Text(widget.confirm),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
