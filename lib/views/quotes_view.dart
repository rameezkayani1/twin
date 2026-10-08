// =============================================================
// quotes_view.dart  —  Customer "Your quotes" (single file)
//
// Reads  : quote_requests  (where userId == current user)
// Updates: status / statusHistory / customerNote (customer actions)
//
// pubspec: get, firebase_auth, cloud_firestore
//
// Usage:
//   QuotesView(onPayDeposit: (q) => Get.to(() => PayView(...)))
// =============================================================
import 'dart:async';

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
  static const ink = Color(0xFF1F2430);
  static const bg = Color(0xFFF6F7FB);
  static const muted = Color(0xFF7A8194);
  static const line = Color(0xFFE6E9F2);
  static const green = Color(0xFF22B573);
  static const red = Color(0xFFEB5757);
  static const blue = Color(0xFF2D9CDB);
  static const purple = Color(0xFF9B51E0);
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
        Color(0xFFF2C94C),
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
// CONTROLLER
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
// QUOTES LIST PAGE
// ---------------------------------------------------------
class QuotesView extends StatelessWidget {
  final void Function(QuoteModel q)? onPayDeposit;
  const QuotesView({super.key, this.onPayDeposit});

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
            final cols = w > 980 ? 3 : (w > 640 ? 2 : 1);
            final pad = w > 640 ? 24.0 : 16.0;
            return CustomScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              slivers: [
                SliverToBoxAdapter(child: _Header(c: c)),
                SliverToBoxAdapter(
                  child: _FilterBar(c: c, pad: pad),
                ),
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
                  return SliverPadding(
                    padding: EdgeInsets.fromLTRB(pad, 4, pad, 40),
                    sliver: SliverGrid(
                      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: cols,
                        mainAxisSpacing: 14,
                        crossAxisSpacing: 14,
                        mainAxisExtent: 196,
                      ),
                      delegate: SliverChildBuilderDelegate(
                        (_, i) => _QuoteCard(
                          q: list[i],
                          onTap: () => Get.to(
                            () => QuoteDetailView(
                              q: list[i],
                              onPayDeposit: onPayDeposit,
                            ),
                          ),
                          index: i,
                        ),
                        childCount: list.length,
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

class _Header extends StatelessWidget {
  final QuotesController c;
  const _Header({required this.c});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.fromLTRB(
        20,
        MediaQuery.of(context).padding.top + 20,
        20,
        22,
      ),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [_T.orange, _T.orangeDark],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.vertical(bottom: Radius.circular(32)),
      ),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1000),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Expanded(
                    child: Text(
                      'Your quotes',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 26,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  IconButton(
                    tooltip: 'Refresh',
                    onPressed: c.refreshData,
                    icon: const Icon(
                      Icons.refresh_rounded,
                      color: Colors.white,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                'Track every request from submission to completion.',
                style: TextStyle(color: Colors.white.withValues(alpha: .9)),
              ),
              const SizedBox(height: 18),
              Obx(
                () => Row(
                  children: [
                    _stat('Total', c.quotes.length, Icons.folder_open_rounded),
                    const SizedBox(width: 10),
                    _stat(
                      'Action needed',
                      c.count('Action needed'),
                      Icons.bolt_rounded,
                    ),
                    const SizedBox(width: 10),
                    _stat(
                      'In progress',
                      c.count('In progress'),
                      Icons.autorenew_rounded,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _stat(String label, int n, IconData icon) => Expanded(
    child: Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: .18),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: Colors.white, size: 18),
          const SizedBox(height: 6),
          Text(
            '$n',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 22,
              fontWeight: FontWeight.w800,
            ),
          ),
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: Colors.white.withValues(alpha: .9),
              fontSize: 11.5,
            ),
          ),
        ],
      ),
    ),
  );
}

class _FilterBar extends StatelessWidget {
  final QuotesController c;
  final double pad;
  const _FilterBar({required this.c, required this.pad});

  @override
  Widget build(BuildContext context) => SizedBox(
    height: 64,
    child: Obx(
      () => ListView(
        scrollDirection: Axis.horizontal,
        padding: EdgeInsets.symmetric(horizontal: pad, vertical: 14),
        children: [
          for (final f in QuotesController.filters)
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: ChoiceChip(
                label: Text('$f  ${c.count(f)}'),
                selected: c.filter.value == f,
                onSelected: (_) => c.filter.value = f,
                showCheckmark: false,
                selectedColor: _T.orange,
                backgroundColor: Colors.white,
                side: const BorderSide(color: _T.line),
                labelStyle: TextStyle(
                  fontWeight: FontWeight.w700,
                  color: c.filter.value == f ? Colors.white : _T.ink,
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
          child: const Icon(Icons.inbox_rounded, color: _T.orange, size: 48),
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
          Text(
            m.label,
            style: TextStyle(
              color: m.color,
              fontWeight: FontWeight.w800,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }
}

/// Segmented progress tracker for the happy-path flow
class _Track extends StatelessWidget {
  final String status;
  const _Track(this.status);
  @override
  Widget build(BuildContext context) {
    final failed = status == QS.rejected || status == QS.cancelled;
    var idx = QS.flow.indexOf(status);
    if (status == QS.changes) idx = 1;
    if (failed) idx = QS.flow.length; // all segments red-tinted below
    final col = failed ? _T.red : _meta(status).color;
    return Row(
      children: [
        for (var i = 0; i < QS.flow.length; i++)
          Expanded(
            child: Container(
              height: 6,
              margin: EdgeInsets.only(right: i == QS.flow.length - 1 ? 0 : 4),
              decoration: BoxDecoration(
                color: failed
                    ? col.withValues(alpha: .35)
                    : (i <= idx ? col : _T.line),
                borderRadius: BorderRadius.circular(6),
              ),
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
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: Duration(milliseconds: 300 + (index.clamp(0, 6)) * 60),
      curve: Curves.easeOut,
      builder: (_, v, child) => Opacity(
        opacity: v,
        child: Transform.translate(
          offset: Offset(0, 16 * (1 - v)),
          child: child,
        ),
      ),
      child: Material(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        elevation: 0,
        child: InkWell(
          borderRadius: BorderRadius.circular(22),
          onTap: onTap,
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(22),
              border: Border.all(
                color: q.status == QS.quoted
                    ? _T.purple.withValues(alpha: .5)
                    : _T.line,
              ),
              boxShadow: [
                BoxShadow(
                  color: _T.ink.withValues(alpha: .05),
                  blurRadius: 18,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: m.color.withValues(alpha: .13),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Icon(_serviceIcon(q.service), color: m.color),
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
                            style: const TextStyle(
                              color: _T.muted,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                    _StatusChip(q.status, expired: q.expired),
                  ],
                ),
                const SizedBox(height: 14),
                _Track(q.status),
                const Spacer(),
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            q.quote != null ? 'Quote total' : 'Your budget',
                            style: const TextStyle(
                              color: _T.muted,
                              fontSize: 11.5,
                            ),
                          ),
                          Text(
                            _money(q.quote?.total ?? q.budget),
                            style: const TextStyle(
                              fontSize: 19,
                              fontWeight: FontWeight.w800,
                              color: _T.ink,
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (q.status == QS.quoted && !q.expired)
                      const Text(
                        'Review →',
                        style: TextStyle(
                          color: _T.purple,
                          fontWeight: FontWeight.w800,
                        ),
                      )
                    else
                      const Icon(Icons.chevron_right_rounded, color: _T.muted),
                  ],
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
            elevation: 0,
            foregroundColor: _T.ink,
            title: Text(
              cur.number,
              style: const TextStyle(fontWeight: FontWeight.w800),
            ),
          ),
          bottomNavigationBar: _actionBar(context, c, cur),
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
                final wide = box.maxWidth > 820;
                final left = <Widget>[
                  _hero(cur),
                  if (cur.quote != null) _breakdown(cur),
                  if (cur.adminNote.isNotEmpty) _adminNote(cur),
                ];
                final right = <Widget>[
                  _info(cur),
                  if (cur.attachments.isNotEmpty) _attachments(cur),
                  _timeline(cur),
                ];
                return ListView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.fromLTRB(16, 4, 16, 32),
                  children: [
                    Center(
                      child: ConstrainedBox(
                        constraints: BoxConstraints(
                          maxWidth: wide ? 1040 : 640,
                        ),
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
  Widget _card(String? title, Widget child, {Color? color}) => Container(
    width: double.infinity,
    margin: const EdgeInsets.only(bottom: 14),
    padding: const EdgeInsets.all(18),
    decoration: BoxDecoration(
      color: color ?? Colors.white,
      borderRadius: BorderRadius.circular(22),
      boxShadow: [
        BoxShadow(
          color: _T.ink.withValues(alpha: .05),
          blurRadius: 18,
          offset: const Offset(0, 6),
        ),
      ],
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
      Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 54,
                height: 54,
                decoration: BoxDecoration(
                  color: m.color.withValues(alpha: .13),
                  borderRadius: BorderRadius.circular(17),
                ),
                child: Icon(m.icon, color: m.color, size: 28),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      x.service,
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w800,
                        color: _T.ink,
                      ),
                    ),
                    const SizedBox(height: 4),
                    _StatusChip(x.status, expired: x.expired),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Text(m.desc, style: const TextStyle(color: _T.muted, height: 1.4)),
          const SizedBox(height: 16),
          _Track(x.status),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: const [
              Text(
                'Submitted',
                style: TextStyle(fontSize: 10.5, color: _T.muted),
              ),
              Text('Quote', style: TextStyle(fontSize: 10.5, color: _T.muted)),
              Text('Done', style: TextStyle(fontSize: 10.5, color: _T.muted)),
            ],
          ),
        ],
      ),
    );
  }

  // ----- quote breakdown -----
  Widget _breakdown(QuoteModel x) {
    final b = x.quote!;
    return _card(
      'Quote breakdown',
      Column(
        children: [
          _kv('Labor', _money(b.labor)),
          _kv('Materials', _money(b.materials)),
          _kv('Service / travel fees', _money(b.fees)),
          _kv('Discount', '-${_money(b.discount)}', color: _T.green),
          _kv('Tax', _money(b.tax)),
          const Divider(height: 22),
          _kv('Project total', _money(b.total), bold: true),
          _kv(
            'Deposit (${b.depositPct.toStringAsFixed(0)}%)',
            _money(b.deposit),
            bold: true,
            color: _T.orange,
          ),
          _kv('Remaining balance', _money(b.remaining)),
          if (b.expiresAt != null) ...[
            const Divider(height: 22),
            _kv('Issued', _date(b.issuedAt)),
            _kv(
              'Valid until',
              _date(b.expiresAt),
              color: x.expired ? _T.red : _T.ink,
            ),
          ],
          if (b.notes.isNotEmpty) ...[
            const SizedBox(height: 10),
            Container(
              width: double.infinity,
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
          ],
          const SizedBox(height: 6),
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton.icon(
              onPressed: _terms,
              icon: const Icon(Icons.description_outlined, size: 18),
              label: const Text('Terms & conditions'),
              style: TextButton.styleFrom(foregroundColor: _T.orange),
            ),
          ),
        ],
      ),
    );
  }

  Widget _adminNote(QuoteModel x) => _card(
    'Message from our team',
    Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Icon(Icons.support_agent_rounded, color: _T.orange),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            x.adminNote,
            style: const TextStyle(height: 1.4, color: _T.ink),
          ),
        ),
      ],
    ),
    color: _T.orange.withValues(alpha: .08),
  );

  // ----- request info -----
  Widget _info(QuoteModel x) => _card(
    'Your request',
    Column(
      children: [
        _kv('Service', x.service),
        _kv('Description', x.description),
        _kv('Budget', _money(x.budget)),
        _kv('Urgency', x.urgency.isEmpty ? '—' : x.urgency),
        _kv('Preferred date', _date(x.preferredDate)),
        _kv('Time slot', x.slot.isEmpty ? '—' : x.slot),
        _kv('Address', x.address),
        const Divider(height: 22),
        _kv('Name', x.name),
        _kv('Phone', x.phone),
        _kv('Email', x.email),
      ],
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
  Widget? _actionBar(BuildContext context, QuotesController c, QuoteModel x) {
    Widget? content;
    if (x.status == QS.quoted && !x.expired) {
      content = Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _primary(
            'Approve quote',
            Icons.check_circle_rounded,
            _T.green,
            c.busy.value ? null : () => _approve(context, c, x),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: _outline(
                  'Request changes',
                  Icons.edit_note_rounded,
                  _T.orange,
                  c.busy.value
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
                  c.busy.value
                      ? null
                      : () => _askNote(context, c, x, QS.rejected),
                ),
              ),
            ],
          ),
        ],
      );
    } else if (x.status == QS.accepted && !x.depositPaid && x.quote != null) {
      content = _primary(
        'Pay deposit — ${_money(x.quote!.deposit)}',
        Icons.payments_rounded,
        _T.orange,
        onPayDeposit == null ? null : () => onPayDeposit!(x),
      );
    } else if (x.status == QS.pending ||
        x.status == QS.reviewing ||
        x.status == QS.changes) {
      content = _outline(
        'Cancel request',
        Icons.block_rounded,
        _T.red,
        c.busy.value ? null : () => _askNote(context, c, x, QS.cancelled),
      );
    }
    if (content == null) return null;
    return SafeArea(
      child: Container(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
        decoration: BoxDecoration(
          color: Colors.white,
          boxShadow: [
            BoxShadow(
              color: _T.ink.withValues(alpha: .08),
              blurRadius: 20,
              offset: const Offset(0, -4),
            ),
          ],
        ),
        child: Center(
          heightFactor: 1,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 640),
            child: Obx(
              () => AbsorbPointer(absorbing: c.busy.value, child: content),
            ),
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
      label: Text(
        t,
        style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15),
      ),
      style: ElevatedButton.styleFrom(
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
      label: Text(t, style: const TextStyle(fontWeight: FontWeight.w700)),
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
      builder: (_) => _NoteSheet(
        title: title,
        required: isChanges,
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
// NOTE BOTTOM SHEET
// ---------------------------------------------------------
class _NoteSheet extends StatefulWidget {
  final String title, confirm;
  final bool required, danger;
  const _NoteSheet({
    required this.title,
    required this.confirm,
    required this.required,
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
                  hintText: widget.required
                      ? 'Describe the changes…'
                      : 'Reason (optional)',
                  errorText: _err,
                  prefixIcon: const Padding(
                    padding: EdgeInsets.only(bottom: 56),
                    child: Icon(Icons.chat_bubble_outline_rounded),
                  ),
                  filled: true,
                  fillColor: const Color(0xFFF8F9FC),
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
                        if (widget.required && _t.text.trim().isEmpty) {
                          setState(() => _err = 'Please add a short note');
                          return;
                        }
                        Navigator.pop(context, _t.text.trim());
                      },
                      style: ElevatedButton.styleFrom(
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
