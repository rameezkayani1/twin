// =============================================================
// quotes_view.dart — Customer quotes + invoice + advance payment
//
// FLOW
//   1. Admin writes the quote + status 'quoted' on quote_requests/{id}
//   2. Customer sees a live banner: TOTAL, then DEPOSIT NOW
//   3. Quote screen: TOTAL first -> Deposit now -> Deposit later
//   4. "Approve" -> safe transaction -> status 'accepted'
//      + invoice snapshot + paymentStatus 'unpaid' -> Invoice opens
//   5. Pay deposit now (DEMO gateway) -> paymentStatus 'paid'
//
// WHAT THE ADMIN APP MAY WRITE (both layouts are supported)
//   A) Top-level fields (same as request_view.dart QuotePricing.adminPayload)
//        quoteTotal, depositNow, depositLater, paymentNote, quotedAt
//   B) Nested map  quote: { total, depositNow | deposit | advance,
//        depositLater | balance, labor, materials, fees, discount, tax,
//        expiresAt, issuedAt, notes }
//   Nested values win; top-level values are the fallback.
//   If only a percent is given (depositPct / advancePct) it is used,
//   otherwise the default is 30%.
//
// WRITTEN BY THIS APP (customer side)
//   status: 'accepted', acceptedAt
//   paymentStatus: 'unpaid' | 'paid'
//   advancePaid / depositPaid: bool   (both kept in sync)
//   advancePaidAt / depositPaidAt, depositAmount, paymentMethod, paymentRef
//   invoice: { number, issuedAt, total, advance, balance, advancePct,
//              status: 'advance_unpaid' | 'advance_paid', paidAt }
//
// pubspec: get, firebase_auth, cloud_firestore
// Needs get ^4.6 (Get.to(routeName:) and Get.until).
//
// Usage:  QuotesView()                        // built-in payment screen
//         QuotesView(onPayDeposit: (q) {...}) // your own gateway later
// =============================================================
import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';

/// Payment is demo for now. Set false after you integrate a real gateway.
const bool kDemoPayment = true;

/// Shown on the invoice. Replace with your real business details.
const String kCompanyName = 'Your Company';
const String kCompanyTagline = 'Home services you can trust';

// ---------------------------------------------------------
// THEME + HELPERS
// ---------------------------------------------------------
class _T {
  static const orange = Color(0xFFFF7A00);
  static const orangeDark = Color(0xFFE55F00);
  static const ink = Color(0xFF1B1F2A);
  static const bg = Color(0xFFF5F3EF);
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

/// Tolerant number parser: accepts num, "450", "$1,250.50", null.
double _n(dynamic v) {
  if (v is num) return v.toDouble();
  return double.tryParse('$v'.replaceAll(RegExp(r'[^0-9.\-]'), '')) ?? 0;
}

double _r2(double v) => (v * 100).roundToDouble() / 100;

/// First positive number found under any of [keys].
double _pick(Map m, List<String> keys) {
  for (final k in keys) {
    final v = _n(m[k]);
    if (v > 0) return v;
  }
  return 0;
}

/// Accepts Timestamp, DateTime, ISO string, or millis.
DateTime? _dt(dynamic v) {
  if (v is Timestamp) return v.toDate();
  if (v is DateTime) return v;
  if (v is int) return DateTime.fromMillisecondsSinceEpoch(v);
  if (v is String) return DateTime.tryParse(v);
  return null;
}

String _cap(String s) => s.isEmpty ? '—' : s[0].toUpperCase() + s.substring(1);

const _serviceIcons = <String, IconData>{
  'Plumbing': Icons.plumbing,
  'Electrical': Icons.electrical_services,
  'Painting': Icons.format_paint_rounded,
  'Cleaning': Icons.cleaning_services_rounded,
  'Pressure Washing': Icons.water_drop_rounded,
  'Assembly': Icons.construction_rounded,
  'Waste Disposal': Icons.delete_outline_rounded,
  'Lawn Services': Icons.yard_rounded,
  'Landscaping': Icons.yard_rounded,
  'AC Repair': Icons.ac_unit,
  'Carpentry': Icons.carpenter,
  'Roofing': Icons.roofing,
  'Moving': Icons.local_shipping_rounded,
  'General Handyman': Icons.handyman_rounded,
};

IconData _serviceIcon(String s) => _serviceIcons[s] ?? Icons.handyman_rounded;

// ---------------------------------------------------------
// STATUS
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

  /// Statuses where an invoice exists.
  static const invoiced = [accepted, scheduled, completed];
}

class _Meta {
  final String label, desc;
  final Color color;
  final IconData icon;
  const _Meta(this.label, this.desc, this.color, this.icon);
}

const _metas = <String, _Meta>{
  QS.pending: _Meta(
    'Pending',
    'Your request was received and is waiting to be reviewed.',
    Color(0xFFF2994A),
    Icons.hourglass_top_rounded,
  ),
  QS.reviewing: _Meta(
    'In review',
    'Our team is reviewing your request and preparing a quote.',
    _T.blue,
    Icons.manage_search_rounded,
  ),
  QS.quoted: _Meta(
    'Quote ready',
    'Your quote is ready. Review the amounts, then approve or ask for changes.',
    _T.purple,
    Icons.request_quote_rounded,
  ),
  QS.changes: _Meta(
    'Changes requested',
    'We received your change request and will send an updated quote.',
    Color(0xFFE0A800),
    Icons.edit_note_rounded,
  ),
  QS.accepted: _Meta(
    'Approved',
    'Quote approved and invoice generated. Pay the deposit to get your job scheduled.',
    _T.green,
    Icons.thumb_up_alt_rounded,
  ),
  QS.scheduled: _Meta(
    'Scheduled',
    'Your job is scheduled. We will see you on the planned date.',
    Color(0xFF00A8A8),
    Icons.event_available_rounded,
  ),
  QS.completed: _Meta(
    'Completed',
    'The job is finished. Thank you for choosing us!',
    _T.green,
    Icons.verified_rounded,
  ),
  QS.rejected: _Meta(
    'Declined',
    'This quote was declined.',
    _T.red,
    Icons.cancel_rounded,
  ),
  QS.cancelled: _Meta(
    'Cancelled',
    'This request was cancelled.',
    _T.muted,
    Icons.block_rounded,
  ),
};

const _expiredMeta = _Meta(
  'Expired',
  'This quote has expired. Please contact us for a new one.',
  _T.red,
  Icons.timer_off_rounded,
);

const _invoiceMeta = _Meta(
  'Invoice generated',
  '',
  _T.blue,
  Icons.receipt_long_rounded,
);

const _paidMeta = _Meta('Advance paid', '', _T.green, Icons.payments_rounded);

_Meta _meta(String s) =>
    _metas[s] ?? _Meta(s, '', _T.muted, Icons.info_outline_rounded);

/// Timeline entries can be a status change, an invoice or a payment.
_Meta _histMeta(Map<String, dynamic> h) {
  switch ((h['type'] ?? '').toString()) {
    case 'invoice':
      return _invoiceMeta;
    case 'payment':
      return _paidMeta;
    default:
      return _meta((h['status'] ?? '').toString());
  }
}

// ---------------------------------------------------------
// MODELS
// ---------------------------------------------------------
class QuoteBreakdown {
  final double labor, materials, fees, discount, tax;
  final double total, deposit, depositPct;
  final DateTime? expiresAt, issuedAt;
  final String notes;

  const QuoteBreakdown({
    required this.labor,
    required this.materials,
    required this.fees,
    required this.discount,
    required this.tax,
    required this.total,
    required this.deposit,
    required this.depositPct,
    this.expiresAt,
    this.issuedAt,
    this.notes = '',
  });

  /// Balance to pay after the job ("deposit later").
  double get remaining => _r2(total - deposit);

  // ---- keys inside the nested `quote` map ----
  static const _nestedTotalKeys = [
    'total',
    'amount',
    'quoteTotal',
    'quoteAmount',
    'price',
  ];
  static const _advanceKeys = [
    'depositNow',
    'deposit',
    'depositAmount',
    'advance',
    'advanceAmount',
    'payNow',
  ];
  static const _laterKeys = [
    'depositLater',
    'payLater',
    'balance',
    'balanceAmount',
    'remaining',
    'payAfter',
  ];
  static const _pctKeys = [
    'depositPct',
    'advancePct',
    'depositPercent',
    'advancePercent',
  ];

  // ---- keys at the TOP LEVEL of the document (request_view.dart) ----
  // NOTE: `depositAmount` is deliberately NOT here: this app writes it
  // after the customer pays, so it must never be read back as the quote.
  static const _topTotalKeys = ['quoteTotal', 'quoteAmount', 'quotedAmount'];
  static const _topAdvanceKeys = ['depositNow', 'advanceAmount', 'payNow'];
  static const _topLaterKeys = ['depositLater', 'payLater'];

  /// Returns null when the document has no usable quote amount.
  static QuoteBreakdown? from(Map<String, dynamic> d) {
    final raw = d['quote'];
    final m = raw is Map ? Map<String, dynamic>.from(raw) : <String, dynamic>{};

    final labor = _n(m['labor']);
    final materials = _n(m['materials']);
    final fees = _n(m['fees']);
    final discount = _n(m['discount']);
    final tax = _n(m['tax']);
    final parts = labor + materials + fees - discount + tax;

    // nested first, then top-level (this was the main bug before: the
    // top-level depositNow / depositLater written by admin were ignored).
    var advance = _pick(m, _advanceKeys);
    if (advance <= 0) advance = _pick(d, _topAdvanceKeys);
    var later = _pick(m, _laterKeys);
    if (later <= 0) later = _pick(d, _topLaterKeys);

    var total = _pick(m, _nestedTotalKeys);
    if (total <= 0) total = _pick(d, _topTotalKeys);
    if (total <= 0) total = parts;
    if (total <= 0 && advance > 0 && later > 0) total = advance + later;
    if (total <= 0) return null;

    // Deposit now: explicit amount > (total - balance) > percent > 30%.
    if (advance <= 0 && later > 0 && later < total) advance = total - later;
    if (advance <= 0) {
      var pct = _pick(m, _pctKeys);
      if (pct <= 0) pct = _pick(d, _pctKeys);
      advance = total * (pct > 0 ? pct.clamp(1.0, 100.0) : 30.0) / 100;
    }
    if (advance > total) advance = total;
    advance = _r2(advance);

    if (later > 0 && (advance + later - total).abs() > 0.01) {
      debugPrint(
        '[quotes] deposit now ($advance) + deposit later ($later) != total '
        '($total). Using total and deposit now; later = total - now.',
      );
    }

    return QuoteBreakdown(
      labor: parts > 0 ? labor : total, // only a total given -> show as labor
      materials: materials,
      fees: fees,
      discount: discount,
      tax: tax,
      total: _r2(total),
      deposit: advance,
      depositPct: advance / total * 100,
      expiresAt: _dt(m['expiresAt'] ?? d['expiresAt']),
      issuedAt: _dt(m['issuedAt'] ?? d['quotedAt']),
      notes: (m['notes'] ?? d['paymentNote'] ?? '').toString(),
    );
  }
}

/// Invoice snapshot written when the customer approves the quote.
class InvoiceInfo {
  final String number;
  final DateTime? issuedAt, paidAt;
  final double total, advance, balance;
  const InvoiceInfo({
    required this.number,
    required this.total,
    required this.advance,
    required this.balance,
    this.issuedAt,
    this.paidAt,
  });
}

class QuoteModel {
  final String id, number, service, description, name, phone, email, address;
  final String urgency, slot, status, adminNote;
  final String paymentMethod, paymentRef;
  final double budget;
  final bool advancePaid;
  final DateTime? preferredDate, createdAt, updatedAt, advancePaidAt;
  final List<Map<String, dynamic>> attachments, history;
  final QuoteBreakdown? quote;
  final InvoiceInfo? invoice;

  const QuoteModel({
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
    required this.paymentMethod,
    required this.paymentRef,
    required this.budget,
    required this.advancePaid,
    required this.attachments,
    required this.history,
    this.preferredDate,
    this.createdAt,
    this.updatedAt,
    this.advancePaidAt,
    this.quote,
    this.invoice,
  });

  factory QuoteModel.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final d = doc.data() ?? {};
    String s(String k) => (d[k] ?? '').toString();
    List<Map<String, dynamic>> list(dynamic v) => v is List
        ? v.whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList()
        : <Map<String, dynamic>>[];

    final status = d['status'] == null ? QS.pending : s('status');
    final quote = QuoteBreakdown.from(d);
    if (status == QS.quoted && quote == null) {
      debugPrint('[quotes] ${doc.id} is "quoted" but has no readable amount.');
    }

    final number = d['requestNumber'] != null
        ? s('requestNumber')
        : doc.id
              .substring(0, doc.id.length < 6 ? doc.id.length : 6)
              .toUpperCase();

    // ----- invoice (stored snapshot, or derived for older documents) -----
    final invRaw = d['invoice'];
    final inv = invRaw is Map
        ? Map<String, dynamic>.from(invRaw)
        : <String, dynamic>{};

    // Admin app uses `advancePaid`, this app also writes `depositPaid`.
    final paid =
        d['advancePaid'] == true ||
        d['depositPaid'] == true ||
        s('paymentStatus') == 'paid' ||
        inv['status'] == 'advance_paid';

    InvoiceInfo? invoice;
    final total = _pick(inv, ['total']) > 0
        ? _pick(inv, ['total'])
        : (quote?.total ?? 0);
    if ((inv.isNotEmpty || QS.invoiced.contains(status)) && total > 0) {
      final hasAdv = inv.containsKey('advance');
      final adv = hasAdv ? _n(inv['advance']) : (quote?.deposit ?? 0);
      final bal = inv.containsKey('balance')
          ? _n(inv['balance'])
          : _r2(total - adv);
      invoice = InvoiceInfo(
        number: inv['number'] != null ? '${inv['number']}' : 'INV-$number',
        total: total,
        advance: adv,
        balance: bal,
        issuedAt: _dt(inv['issuedAt']),
        paidAt:
            _dt(inv['paidAt']) ??
            _dt(d['depositPaidAt']) ??
            _dt(d['advancePaidAt']),
      );
    }

    return QuoteModel(
      id: doc.id,
      number: number,
      service: d['service'] != null ? s('service') : 'Service',
      description: s('description'),
      name: s('customerName'),
      phone: s('phone'),
      email: s('email'),
      address: s('address'),
      urgency: s('urgency'),
      slot: s('preferredSlot'),
      status: status,
      adminNote: s('adminNote'),
      paymentMethod: s('paymentMethod'),
      paymentRef: s('paymentRef'),
      budget: _n(d['budget']),
      advancePaid: paid,
      preferredDate: _dt(d['preferredDate']),
      createdAt: _dt(d['createdAt']),
      updatedAt: _dt(d['updatedAt']),
      advancePaidAt: _dt(d['depositPaidAt']) ?? _dt(d['advancePaidAt']),
      attachments: list(d['attachments']),
      history: list(d['statusHistory']),
      quote: quote,
      invoice: invoice,
    );
  }

  bool get hasQuote => quote != null;
  bool get hasInvoice => invoice != null;

  bool get expired =>
      status == QS.quoted &&
      quote?.expiresAt != null &&
      quote!.expiresAt!.isBefore(DateTime.now());

  /// Admin sent a quote and the customer can still approve it.
  bool get isQuoteReady => status == QS.quoted && hasQuote && !expired;

  /// Approved, deposit still unpaid.
  bool get needsPayment =>
      status == QS.accepted && !advancePaid && hasQuote && advanceDue > 0;

  /// Show the "Advance paid / unpaid" badge.
  bool get showPayState =>
      QS.invoiced.contains(status) && hasQuote && advanceDue > 0;

  bool get canCancel =>
      const [QS.pending, QS.reviewing, QS.changes].contains(status);

  bool get needsAction => isQuoteReady || needsPayment;

  /// Amount shown everywhere: quote total when available, else customer budget.
  double get amount => quote?.total ?? budget;

  // Invoice snapshot wins over the live quote once approved.
  double get totalDue => invoice?.total ?? quote?.total ?? 0;
  double get advanceDue => invoice?.advance ?? quote?.deposit ?? 0;
  double get balanceDue => invoice?.balance ?? quote?.remaining ?? 0;
  double get advancePct => totalDue > 0 ? advanceDue / totalDue * 100 : 0;
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

  /// Optional custom payment hook (set by QuotesView).
  void Function(QuoteModel q)? onPayDeposit;

  /// Quote versions we already notified about (id:total:advance) — a
  /// revised amount triggers a new notification.
  final _notified = <String>{};

  static const filters = ['All', 'Action needed', 'In progress', 'Closed'];

  // Route names: lets "Back to my quotes" pop exactly the quote screens.
  static const rDetail = '/quote-detail';
  static const rInvoice = '/quote-invoice';
  static const rPay = '/quote-pay';

  CollectionReference<Map<String, dynamic>> get _col =>
      _db.collection('quote_requests');

  Query<Map<String, dynamic>>? get _query {
    final u = FirebaseAuth.instance.currentUser;
    return u == null ? null : _col.where('userId', isEqualTo: u.uid);
  }

  @override
  void onInit() {
    super.onInit();
    _listen();
  }

  @override
  void onClose() {
    _sub?.cancel();
    super.onClose();
  }

  /// Live stream of a single request (detail, invoice, payment screens).
  Stream<QuoteModel?> watch(String id) => _col
      .doc(id)
      .snapshots()
      .map((s) => s.exists ? QuoteModel.fromDoc(s) : null);

  void openDetail(QuoteModel q) => Get.to(
    () => QuoteDetailView(q: q, onPayDeposit: onPayDeposit),
    routeName: rDetail,
  );

  void openInvoice(QuoteModel q) =>
      Get.to(() => InvoiceView(q: q), routeName: rInvoice);

  void openPayment(QuoteModel q) {
    if (onPayDeposit != null) {
      onPayDeposit!(q);
    } else {
      Get.to(() => PaymentView(q: q), routeName: rPay);
    }
  }

  /// Pops detail / invoice / payment and lands on the quotes list.
  void backToQuotes() =>
      Get.until((r) => !(r.settings.name ?? '').startsWith('/quote-'));

  // ----- loading -----
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
      onError: (_) {
        loading.value = false;
        error.value = 'Could not load quotes. Pull down to retry.';
      },
    );
  }

  void _apply(QuerySnapshot<Map<String, dynamic>> snap) {
    final now = DateTime.now();
    final list = snap.docs.map(QuoteModel.fromDoc).toList()
      ..sort((a, b) => (b.createdAt ?? now).compareTo(a.createdAt ?? now));
    quotes.assignAll(list);
    loading.value = false;
    error.value = '';
    // _notifyNewQuotes(list);
  }

  Future<void> refreshData() async {
    final q = _query;
    if (q == null) return;
    try {
      _apply(await q.get(const GetOptions(source: Source.server)));
    } catch (_) {
      error.value = 'You appear to be offline.';
      snack('Could not refresh. Check your connection.', true);
    }
    _listen();
  }

  // ----- notification -----
  String _key(QuoteModel q) => '${q.id}:${q.quote!.total}:${q.quote!.deposit}';

  void _notifyNewQuotes(List<QuoteModel> list) {
    final fresh = list
        .where((q) => q.isQuoteReady && !_notified.contains(_key(q)))
        .toList();
    if (fresh.isEmpty) return;
    _notified.addAll(fresh.map(_key));
    final q = fresh.first;

    Future.delayed(const Duration(milliseconds: 600), () {
      if (Get.context == null) return;
      Get.snackbar(
        '',
        '',
        titleText: Row(
          children: [
            const Icon(
              Icons.request_quote_rounded,
              color: Colors.white,
              size: 20,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                fresh.length > 1
                    ? '${fresh.length} new quotes are ready'
                    : 'Your quote is ready',
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w800,
                  fontSize: 15,
                ),
              ),
            ),
          ],
        ),
        messageText: Padding(
          padding: const EdgeInsets.only(top: 2),
          child: Text(
            '${q.service} · Total ${_money(q.amount)} · '
            'Deposit now ${_money(q.advanceDue)}  —  tap to review',
            style: TextStyle(color: Colors.white.withValues(alpha: .9)),
          ),
        ),
        snackPosition: SnackPosition.TOP,
        margin: const EdgeInsets.all(16),
        maxWidth: 560,
        borderRadius: 16,
        backgroundColor: _T.purple,
        duration: const Duration(seconds: 8),
        onTap: (_) {
          Get.closeCurrentSnackbar();
          openDetail(q);
        },
      );
    });
  }

  // ----- filtering -----
  bool matches(QuoteModel q, String f) {
    switch (f) {
      case 'Action needed':
        return q.needsAction;
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

  // ----- writes -----
  Future<bool> updateStatus(
    QuoteModel q,
    String status, {
    String note = '',
  }) async {
    try {
      busy.value = true;
      await _col.doc(q.id).update({
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
      snack('Status updated to ${_meta(status).label}', false);
      return true;
    } on FirebaseException catch (e) {
      snack(e.message ?? 'Update failed', true);
    } catch (_) {
      snack('Something went wrong', true);
    } finally {
      busy.value = false;
    }
    return false;
  }

  /// Approve the quote the customer SAW. Runs in a transaction so that:
  ///  - a quote the admin revised in the meantime (total OR deposit) is NOT
  ///    approved silently
  ///  - an expired / already-handled quote is rejected
  /// On success it also writes the invoice snapshot + unpaid payment state.
  Future<bool> approveQuote(QuoteModel seen) async {
    final seenTotal = seen.quote?.total ?? 0;
    final seenAdvance = seen.quote?.deposit ?? 0;
    try {
      busy.value = true;
      final ref = _col.doc(seen.id);

      final result = await _db.runTransaction<String>((tx) async {
        final snap = await tx.get(ref);
        if (!snap.exists) return 'gone';
        final cur = QuoteModel.fromDoc(snap);
        if (cur.status != QS.quoted) return 'changed';
        if (cur.expired) return 'expired';
        final b = cur.quote;
        if (b == null ||
            (b.total - seenTotal).abs() > 0.009 ||
            (b.deposit - seenAdvance).abs() > 0.009) {
          return 'revised';
        }

        final invNo = 'INV-${cur.number}';
        final needsDeposit = b.deposit > 0;
        tx.update(ref, {
          'status': QS.accepted,
          'acceptedAt': FieldValue.serverTimestamp(),
          'paymentStatus': needsDeposit ? 'unpaid' : 'paid',
          'depositPaid': !needsDeposit,
          'advancePaid': !needsDeposit,
          'invoice': {
            'number': invNo,
            'issuedAt': FieldValue.serverTimestamp(),
            'total': b.total,
            'advance': b.deposit,
            'balance': b.remaining,
            'advancePct': b.depositPct,
            'status': needsDeposit ? 'advance_unpaid' : 'advance_paid',
          },
          'updatedAt': FieldValue.serverTimestamp(),
          'statusHistory': FieldValue.arrayUnion([
            {
              'status': QS.accepted,
              'at': Timestamp.now(),
              'by': 'customer',
              'note': 'Quote approved (${_money(b.total)})',
            },
            {
              'status': QS.accepted,
              'type': 'invoice',
              'at': Timestamp.now(),
              'by': 'system',
              'note': '$invNo · deposit now ${_money(b.deposit)} due',
            },
          ]),
        });
        return 'ok';
      });

      switch (result) {
        case 'ok':
          return true;
        case 'revised':
          snack('The quote was just updated. Please review it again.', true);
          break;
        case 'expired':
          snack('This quote has expired. Please contact us.', true);
          break;
        case 'gone':
          snack('This request no longer exists.', true);
          break;
        default:
          snack('This quote was already updated.', true);
      }
    } on FirebaseException catch (e) {
      snack(e.message ?? 'Could not approve the quote', true);
    } catch (_) {
      snack('Could not approve. Check your connection.', true);
    } finally {
      busy.value = false;
    }
    return false;
  }

  /// Called after a successful deposit payment (demo or real).
  /// Transaction: a double tap / second device can never pay twice.
  Future<bool> markAdvancePaid(
    QuoteModel q,
    String method,
    String reference,
  ) async {
    final ref = _col.doc(q.id);
    try {
      await _db.runTransaction((tx) async {
        final snap = await tx.get(ref);
        if (!snap.exists) throw StateError('missing');
        final cur = QuoteModel.fromDoc(snap);
        if (cur.advancePaid) return; // already paid -> nothing to do
        final amount = cur.advanceDue;
        tx.update(ref, {
          'depositPaid': true,
          'advancePaid': true,
          'paymentStatus': 'paid',
          'depositAmount': amount,
          'depositPaidAt': FieldValue.serverTimestamp(),
          'advancePaidAt': FieldValue.serverTimestamp(),
          'paymentMethod': method,
          'paymentRef': reference,
          'invoice.status': 'advance_paid',
          'invoice.paidAt': FieldValue.serverTimestamp(),
          'updatedAt': FieldValue.serverTimestamp(),
          'statusHistory': FieldValue.arrayUnion([
            {
              'status': cur.status,
              'type': 'payment',
              'at': Timestamp.now(),
              'by': 'customer',
              'note': 'Deposit paid (${_money(amount)}) · Ref $reference',
            },
          ]),
        });
      });
      return true;
    } catch (e) {
      debugPrint('[quotes] markAdvancePaid failed: $e');
      return false;
    }
  }

  void snack(String m, bool err) => Get.snackbar(
    err ? 'Oops' : 'Done',
    m,
    snackPosition: SnackPosition.BOTTOM,
    margin: const EdgeInsets.all(16),
    maxWidth: 560,
    borderRadius: 14,
    backgroundColor: err ? _T.red : _T.green,
    colorText: Colors.white,
  );
}

// ---------------------------------------------------------
// SHARED WIDGETS
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

/// White rounded card with an optional title.
class _Card extends StatelessWidget {
  final String? title;
  final Widget child;
  final Color? color, border;
  const _Card({this.title, required this.child, this.color, this.border});

  @override
  Widget build(BuildContext context) => Container(
    width: double.infinity,
    margin: const EdgeInsets.only(bottom: 14),
    padding: const EdgeInsets.all(18),
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
            title!,
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
}

/// Label / value row.
class _KV extends StatelessWidget {
  final String k, v;
  final bool bold;
  final Color? color;
  const _KV(this.k, this.v, {this.bold = false, this.color});

  @override
  Widget build(BuildContext context) => Padding(
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
              fontWeight: bold ? FontWeight.w900 : FontWeight.w600,
              fontSize: bold ? 17 : 14,
            ),
          ),
        ),
      ],
    ),
  );
}

/// Icon + text line (address, phone, ...). Empty value renders nothing.
class _InfoLine extends StatelessWidget {
  final IconData icon;
  final String value;
  const _InfoLine(this.icon, this.value);

  @override
  Widget build(BuildContext context) => value.isEmpty
      ? const SizedBox.shrink()
      : Padding(
          padding: const EdgeInsets.only(top: 8),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(icon, size: 18, color: _T.muted),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  value,
                  style: const TextStyle(color: _T.ink, height: 1.3),
                ),
              ),
            ],
          ),
        );
}

/// Two-tone bar: deposit-now share vs deposit-later share.
class _SplitBar extends StatelessWidget {
  final double pct;
  final Color advance, balance;
  const _SplitBar({
    required this.pct,
    required this.advance,
    required this.balance,
  });

  @override
  Widget build(BuildContext context) {
    final a = pct.round().clamp(1, 99).toInt();
    return ClipRRect(
      borderRadius: BorderRadius.circular(6),
      child: SizedBox(
        height: 8,
        child: Row(
          children: [
            Expanded(
              flex: a,
              child: Container(color: advance),
            ),
            Expanded(
              flex: 100 - a,
              child: Container(color: balance),
            ),
          ],
        ),
      ),
    );
  }
}

/// Big dark amount card (quote total on detail, deposit on payment).
class _AmountCard extends StatelessWidget {
  final String label, amount, subtitle;
  final IconData? icon;
  final Color amountColor;
  final List<Widget> children;
  const _AmountCard({
    required this.label,
    required this.amount,
    this.subtitle = '',
    this.icon,
    this.amountColor = Colors.white,
    this.children = const [],
  });

  @override
  Widget build(BuildContext context) => Container(
    width: double.infinity,
    margin: const EdgeInsets.only(bottom: 14),
    padding: const EdgeInsets.all(20),
    decoration: BoxDecoration(
      color: _T.ink,
      borderRadius: BorderRadius.circular(24),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            if (icon != null) ...[
              Icon(icon, color: _T.orange, size: 18),
              const SizedBox(width: 6),
            ],
            Text(
              label,
              style: TextStyle(
                color: Colors.white.withValues(alpha: .7),
                fontSize: 12,
                letterSpacing: 1,
                fontWeight: FontWeight.w800,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        FittedBox(
          fit: BoxFit.scaleDown,
          alignment: Alignment.centerLeft,
          child: Text(
            amount,
            style: TextStyle(
              color: amountColor,
              fontSize: 42,
              height: 1.1,
              fontWeight: FontWeight.w900,
              letterSpacing: -1,
            ),
          ),
        ),
        if (subtitle.isNotEmpty) ...[
          const SizedBox(height: 6),
          Text(
            subtitle,
            style: TextStyle(color: Colors.white.withValues(alpha: .75)),
          ),
        ],
        ...children,
      ],
    ),
  );
}

Widget _primaryBtn(String t, IconData i, Color col, VoidCallback? f) =>
    SizedBox(
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
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
        ),
      ),
    );

Widget _outlineBtn(String t, IconData i, Color col, VoidCallback? f) =>
    SizedBox(
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
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
        ),
      ),
    );

InputDecoration _inputDec(String label, {IconData? icon}) => InputDecoration(
  labelText: label,
  prefixIcon: icon == null ? null : Icon(icon, size: 20),
  filled: true,
  fillColor: _T.bg,
  border: OutlineInputBorder(
    borderRadius: BorderRadius.circular(14),
    borderSide: BorderSide.none,
  ),
);

class _StatusChip extends StatelessWidget {
  final String status;
  final bool expired;
  const _StatusChip(this.status, {this.expired = false});

  @override
  Widget build(BuildContext context) {
    final m = expired ? _expiredMeta : _meta(status);
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

/// "Advance paid" / "Advance unpaid" badge.
class _PayChip extends StatelessWidget {
  final bool paid;
  const _PayChip({required this.paid});

  @override
  Widget build(BuildContext context) {
    final col = paid ? _T.green : const Color(0xFFF2994A);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: col.withValues(alpha: .13),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            paid ? Icons.check_circle_rounded : Icons.schedule_rounded,
            size: 14,
            color: col,
          ),
          const SizedBox(width: 5),
          Text(
            paid ? 'Advance paid' : 'Advance unpaid',
            maxLines: 1,
            style: TextStyle(
              color: col,
              fontWeight: FontWeight.w800,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }
}

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
// QUOTES LIST PAGE
// ---------------------------------------------------------
class QuotesView extends StatelessWidget {
  final void Function(QuoteModel q)? onPayDeposit;
  const QuotesView({super.key, this.onPayDeposit});

  @override
  Widget build(BuildContext context) {
    final c = Get.put(QuotesController());
    c.onPayDeposit = onPayDeposit;

    return Scaffold(
      backgroundColor: _T.bg,
      body: RefreshIndicator(
        color: _T.orange,
        onRefresh: c.refreshData,
        child: LayoutBuilder(
          builder: (context, box) {
            final w = box.maxWidth;
            final pad = _gutter(w);
            final contentW = (w < 1100 ? w : 1100.0) - pad * 2;
            final cols = _columns(w);
            const gap = 14.0;
            final itemW = (contentW - gap * (cols - 1)) / cols;
            final top = MediaQuery.of(context).padding.top;

            return CustomScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              slivers: [
                SliverToBoxAdapter(child: _header(c, pad, top)),
                SliverToBoxAdapter(child: _spotlight(c, pad)),
                SliverToBoxAdapter(
                  child: _Page(
                    child: _FilterBar(c: c, pad: pad),
                  ),
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
                                  onTap: () => c.openDetail(list[i]),
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

  Widget _header(QuotesController c, double pad, double top) => _Page(
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
            shape: const CircleBorder(side: BorderSide(color: _T.line)),
            child: IconButton(
              tooltip: 'Refresh',
              onPressed: c.refreshData,
              icon: const Icon(Icons.refresh_rounded, color: _T.ink),
            ),
          ),
        ],
      ),
    ),
  );

  /// Highlights the quote waiting for the customer (amount first).
  Widget _spotlight(QuotesController c, double pad) => Obx(() {
    final todo = c.quotes.where((q) => q.needsAction).toList();
    if (todo.isEmpty) return const SizedBox.shrink();
    final target = todo.firstWhere(
      (q) => q.isQuoteReady,
      orElse: () => todo.first,
    );
    return _Page(
      child: Padding(
        padding: EdgeInsets.fromLTRB(pad, 14, pad, 0),
        child: _Spotlight(
          q: target,
          more: todo.length - 1,
          onTap: () => target.needsPayment
              ? c.openInvoice(target)
              : c.openDetail(target),
        ),
      ),
    );
  });
}

class _Spotlight extends StatelessWidget {
  final QuoteModel q;
  final int more;
  final VoidCallback onTap;
  const _Spotlight({required this.q, required this.more, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final pay = q.needsPayment;
    final head = pay ? 'Deposit due now' : 'Your quote is ready';
    final amount = pay ? q.advanceDue : q.amount;
    final sub = pay
        ? 'of ${_money(q.totalDue)} total · deposit later ${_money(q.balanceDue)}'
        : 'Deposit now ${_money(q.advanceDue)} · deposit later ${_money(q.balanceDue)}';

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
                            Flexible(
                              child: Text(
                                more > 0 ? '$head  ·  +$more more' : head,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  color: Colors.white.withValues(alpha: .75),
                                  fontSize: 12.5,
                                  fontWeight: FontWeight.w700,
                                ),
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
                          _money(amount),
                          style: const TextStyle(
                            color: _T.orange,
                            fontSize: 26,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          sub,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: .7),
                            fontSize: 12,
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
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          pay ? 'Pay' : 'Review',
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(width: 4),
                        const Icon(
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
// LIST CARD
// ---------------------------------------------------------
class _QuoteCard extends StatelessWidget {
  final QuoteModel q;
  final VoidCallback onTap;
  final int index;
  const _QuoteCard({required this.q, required this.onTap, required this.index});

  @override
  Widget build(BuildContext context) {
    final accent = q.expired ? _T.red : _meta(q.status).color;

    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: Duration(milliseconds: 280 + index.clamp(0, 6) * 60),
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
            color: q.isQuoteReady ? _T.purple.withValues(alpha: .55) : _T.line,
            width: q.isQuoteReady ? 1.5 : 1,
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
                        _top(accent),
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
                        if (q.isQuoteReady) ...[
                          const SizedBox(height: 10),
                          _split(),
                        ],
                        const SizedBox(height: 14),
                        _Stepper(q.status),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            Expanded(
                              child: Wrap(
                                spacing: 6,
                                runSpacing: 6,
                                children: [
                                  _StatusChip(q.status, expired: q.expired),
                                  if (q.showPayState)
                                    _PayChip(paid: q.advancePaid),
                                ],
                              ),
                            ),
                            const SizedBox(width: 6),
                            _trailing(),
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

  /// "Deposit now / Deposit later" mini line for ready quotes.
  Widget _split() => Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
    decoration: BoxDecoration(
      color: _T.purple.withValues(alpha: .07),
      borderRadius: BorderRadius.circular(10),
    ),
    child: Row(
      children: [
        Expanded(
          child: Text(
            'Deposit now ${_money(q.advanceDue)}',
            style: const TextStyle(
              fontSize: 12.5,
              fontWeight: FontWeight.w800,
              color: _T.orangeDark,
            ),
          ),
        ),
        Text(
          'Later ${_money(q.balanceDue)}',
          style: const TextStyle(
            fontSize: 12.5,
            fontWeight: FontWeight.w700,
            color: _T.muted,
          ),
        ),
      ],
    ),
  );

  Widget _top(Color accent) => Row(
    children: [
      Container(
        width: 42,
        height: 42,
        decoration: BoxDecoration(
          color: accent.withValues(alpha: .12),
          borderRadius: BorderRadius.circular(13),
        ),
        child: Icon(_serviceIcon(q.service), color: accent, size: 22),
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
              style: const TextStyle(color: _T.muted, fontSize: 12),
            ),
          ],
        ),
      ),
      const SizedBox(width: 8),
      Column(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Text(
            q.hasQuote ? 'TOTAL' : 'BUDGET',
            style: const TextStyle(
              color: _T.muted,
              fontSize: 9.5,
              letterSpacing: .8,
              fontWeight: FontWeight.w700,
            ),
          ),
          Text(
            _money(q.amount),
            style: const TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.w900,
              color: _T.ink,
            ),
          ),
        ],
      ),
    ],
  );

  Widget _trailing() {
    if (q.isQuoteReady) {
      return const Text(
        'Review →',
        style: TextStyle(color: _T.purple, fontWeight: FontWeight.w800),
      );
    }
    if (q.needsPayment) {
      return const Text(
        'Pay →',
        style: TextStyle(color: _T.orange, fontWeight: FontWeight.w800),
      );
    }
    return const Icon(Icons.chevron_right_rounded, color: _T.muted);
  }
}

// ---------------------------------------------------------
// DETAIL PAGE
// ---------------------------------------------------------
class QuoteDetailView extends StatelessWidget {
  final QuoteModel q;
  final void Function(QuoteModel q)? onPayDeposit;
  const QuoteDetailView({super.key, required this.q, this.onPayDeposit});

  @override
  Widget build(BuildContext context) {
    final c = Get.find<QuotesController>();
    return StreamBuilder<QuoteModel?>(
      stream: c.watch(q.id),
      initialData: q,
      builder: (context, snap) {
        final cur = snap.data ?? q; // always the LIVE quote
        final showBar = cur.needsAction || cur.canCancel;

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
          bottomNavigationBar: showBar ? _actionBar(context, c, cur) : null,
          body: RefreshIndicator(
            color: _T.orange,
            onRefresh: c.refreshData,
            child: LayoutBuilder(
              builder: (context, box) {
                final wide = box.maxWidth > 860;
                final gutter = _gutter(box.maxWidth);
                // TOTAL first, then status, how-it-works, invoice, breakdown
                final left = <Widget>[
                  if (cur.hasQuote) _amountCard(cur),
                  _hero(cur),
                  if (cur.isQuoteReady || cur.needsPayment) _howItWorks(cur),
                  if (cur.hasInvoice) _invoiceTile(c, cur),
                  if (cur.hasQuote) _breakdown(context, cur),
                  if (cur.adminNote.isNotEmpty) _adminNote(cur),
                ];
                final right = <Widget>[
                  _info(cur),
                  if (cur.attachments.isNotEmpty) _attachments(cur),
                  _timeline(cur),
                ];
                return ListView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: EdgeInsets.fromLTRB(gutter, 4, gutter, 32),
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

  // ----- quote amount (shown first): TOTAL, then deposit now + later -----
  Widget _amountCard(QuoteModel x) {
    // After approval the invoice snapshot is the source of truth.
    final total = x.totalDue;
    final adv = x.advanceDue;
    final bal = x.balanceDue;
    final pct = x.advancePct;
    final b = x.quote!;

    Widget box(
      String label,
      String sub,
      String value,
      Color color, {
      Widget? badge,
    }) => Expanded(
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: .08),
          borderRadius: BorderRadius.circular(14),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: TextStyle(
                color: Colors.white.withValues(alpha: .9),
                fontSize: 12,
                fontWeight: FontWeight.w800,
              ),
            ),
            Text(
              sub,
              style: TextStyle(
                color: Colors.white.withValues(alpha: .55),
                fontSize: 11,
              ),
            ),
            const SizedBox(height: 6),
            FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                value,
                style: TextStyle(
                  color: color,
                  fontWeight: FontWeight.w900,
                  fontSize: 20,
                ),
              ),
            ),
            if (badge != null) ...[const SizedBox(height: 6), badge],
          ],
        ),
      ),
    );

    final expiryColor = x.expired
        ? const Color(0xFFFF9A8C)
        : const Color(0xFF6FE3A8);

    return _AmountCard(
      label: 'TOTAL QUOTE',
      icon: Icons.request_quote_rounded,
      amount: _money(total),
      subtitle: 'Complete project price',
      children: [
        const SizedBox(height: 16),
        _SplitBar(
          pct: pct,
          advance: _T.orange,
          balance: Colors.white.withValues(alpha: .25),
        ),
        const SizedBox(height: 12),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            box(
              'Deposit now · ${pct.toStringAsFixed(0)}%',
              'Advance to book your job',
              _money(adv),
              _T.orange,
              badge: x.showPayState
                  ? Text(
                      x.advancePaid ? '✓ Paid' : 'Not paid yet',
                      style: TextStyle(
                        color: x.advancePaid
                            ? const Color(0xFF6FE3A8)
                            : const Color(0xFFFFC27A),
                        fontSize: 11.5,
                        fontWeight: FontWeight.w800,
                      ),
                    )
                  : null,
            ),
            const SizedBox(width: 10),
            box(
              'Deposit later · ${(100 - pct).toStringAsFixed(0)}%',
              bal > 0 ? 'Balance after the job' : 'Nothing due later',
              _money(bal),
              Colors.white,
            ),
          ],
        ),
        if (b.expiresAt != null && x.status == QS.quoted) ...[
          const SizedBox(height: 12),
          Row(
            children: [
              Icon(
                x.expired ? Icons.timer_off_rounded : Icons.schedule_rounded,
                size: 16,
                color: expiryColor,
              ),
              const SizedBox(width: 6),
              Flexible(
                child: Text(
                  x.expired
                      ? 'Expired ${_date(b.expiresAt)}'
                      : 'Valid until ${_date(b.expiresAt)}',
                  style: TextStyle(
                    color: expiryColor,
                    fontWeight: FontWeight.w700,
                    fontSize: 12.5,
                  ),
                ),
              ),
            ],
          ),
        ],
      ],
    );
  }

  // ----- 4-step explainer so the customer knows what happens next -----
  Widget _howItWorks(QuoteModel x) {
    final current = x.isQuoteReady ? 0 : 1;
    final steps = <List<String>>[
      ['Approve quote', 'An invoice is generated for you'],
      ['Pay deposit now', _money(x.advanceDue)],
      ['Job is scheduled', 'We confirm the date with you'],
      ['Pay deposit later', '${_money(x.balanceDue)} after the job'],
    ];
    return _Card(
      title: 'How it works',
      child: Column(
        children: [
          for (var i = 0; i < steps.length; i++)
            Padding(
              padding: EdgeInsets.only(bottom: i == steps.length - 1 ? 0 : 12),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 26,
                    height: 26,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: i < current
                          ? _T.green
                          : (i == current ? _T.orange : _T.bg),
                    ),
                    child: i < current
                        ? const Icon(
                            Icons.check_rounded,
                            size: 16,
                            color: Colors.white,
                          )
                        : Text(
                            '${i + 1}',
                            style: TextStyle(
                              fontSize: 12.5,
                              fontWeight: FontWeight.w800,
                              color: i == current ? Colors.white : _T.muted,
                            ),
                          ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          steps[i][0],
                          style: TextStyle(
                            fontWeight: FontWeight.w800,
                            color: i == current ? _T.ink : _T.muted,
                          ),
                        ),
                        Text(
                          steps[i][1],
                          style: const TextStyle(
                            color: _T.muted,
                            fontSize: 12.5,
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
    );
  }

  // ----- invoice shortcut -----
  Widget _invoiceTile(QuotesController c, QuoteModel x) {
    final inv = x.invoice!;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(22),
        onTap: () => c.openInvoice(x),
        child: _Card(
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: _T.blue.withValues(alpha: .12),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: const Icon(Icons.receipt_long_rounded, color: _T.blue),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      inv.number,
                      style: const TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 15.5,
                        color: _T.ink,
                      ),
                    ),
                    const SizedBox(height: 6),
                    _PayChip(paid: x.advancePaid),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right_rounded, color: _T.muted),
            ],
          ),
        ),
      ),
    );
  }

  // ----- status hero -----
  Widget _hero(QuoteModel x) {
    final m = x.expired ? _expiredMeta : _meta(x.status);
    final paid = x.advancePaid && x.status == QS.accepted;

    return _Card(
      color: m.color.withValues(alpha: .07),
      border: m.color.withValues(alpha: .25),
      child: Column(
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
                      paid ? 'Approved · deposit paid' : m.label,
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
          Text(
            paid
                ? 'Deposit received. We will schedule your job shortly.'
                : m.desc,
            style: const TextStyle(color: _T.ink, height: 1.4),
          ),
          const SizedBox(height: 20),
          _Stepper(x.status, labels: true, dot: 14),
        ],
      ),
    );
  }

  // ----- price breakdown -----
  Widget _breakdown(BuildContext context, QuoteModel x) {
    final b = x.quote!;
    return _Card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Theme(
            data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
            child: ExpansionTile(
              tilePadding: EdgeInsets.zero,
              childrenPadding: EdgeInsets.zero,
              iconColor: _T.orange,
              collapsedIconColor: _T.muted,
              title: const Text(
                'Price breakdown',
                style: TextStyle(fontWeight: FontWeight.w800, fontSize: 15),
              ),
              children: [
                _KV('Labor', _money(b.labor)),
                if (b.materials > 0) _KV('Materials', _money(b.materials)),
                if (b.fees > 0) _KV('Service / travel fees', _money(b.fees)),
                if (b.discount > 0)
                  _KV('Discount', '-${_money(b.discount)}', color: _T.green),
                if (b.tax > 0) _KV('Tax', _money(b.tax)),
                const Divider(height: 20),
                _KV('Project total', _money(b.total), bold: true),
                _KV(
                  'Deposit now (advance)',
                  _money(x.advanceDue),
                  color: _T.orangeDark,
                ),
                _KV('Deposit later (balance)', _money(x.balanceDue)),
                if (b.issuedAt != null) _KV('Quote issued', _date(b.issuedAt)),
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
          TextButton.icon(
            onPressed: _terms,
            icon: const Icon(Icons.description_outlined, size: 18),
            label: const Text('Terms & conditions'),
            style: TextButton.styleFrom(
              foregroundColor: _T.orange,
              padding: const EdgeInsets.only(top: 6),
            ),
          ),
        ],
      ),
    );
  }

  Widget _adminNote(QuoteModel x) => _Card(
    color: _T.orange.withValues(alpha: .08),
    border: _T.orange.withValues(alpha: .25),
    child: Row(
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

  Widget _info(QuoteModel x) => _Card(
    title: 'Your request',
    child: LayoutBuilder(
      builder: (context, box) {
        final tileW = (box.maxWidth - 10) / 2;
        Widget tile(IconData i, String l, String v) =>
            SizedBox(width: tileW, child: _fact(i, l, v));
        String orDash(String s) => s.isEmpty ? '—' : s;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (x.description.isNotEmpty) ...[
              Text(
                x.description,
                style: const TextStyle(color: _T.ink, height: 1.45),
              ),
              const SizedBox(height: 14),
            ],
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: [
                tile(
                  Icons.event_rounded,
                  'Preferred date',
                  _date(x.preferredDate),
                ),
                tile(Icons.schedule_rounded, 'Time slot', orDash(x.slot)),
                tile(Icons.bolt_rounded, 'Urgency', orDash(x.urgency)),
                tile(Icons.savings_rounded, 'Your budget', _money(x.budget)),
              ],
            ),
            const Divider(height: 28),
            _InfoLine(Icons.location_on_outlined, x.address),
            _InfoLine(Icons.person_outline_rounded, x.name),
            _InfoLine(Icons.phone_outlined, x.phone),
            _InfoLine(Icons.mail_outline_rounded, x.email),
          ],
        );
      },
    ),
  );

  Widget _attachments(QuoteModel x) => _Card(
    title: 'Attachments (${x.attachments.length})',
    child: Wrap(
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
    return _Card(
      title: 'Activity',
      child: items.isEmpty
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
    final m = _histMeta(h);
    final note = (h['note'] ?? '').toString();
    final by = (h['by'] ?? '').toString();
    final who = by == 'customer'
        ? 'You'
        : (by == 'system' ? 'System' : 'Our team');

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
                    '${_date(_dt(h['at']))}${by.isEmpty ? '' : ' · $who'}',
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

  // ----- sticky action bar -----
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
              final Widget content;

              if (x.isQuoteReady) {
                content = Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: Row(
                        children: [
                          Expanded(
                            child: Text(
                              'Deposit now: ${_money(x.advanceDue)}',
                              style: const TextStyle(
                                color: _T.orangeDark,
                                fontWeight: FontWeight.w800,
                                fontSize: 13,
                              ),
                            ),
                          ),
                          Text(
                            'Deposit later: ${_money(x.balanceDue)}',
                            style: const TextStyle(
                              color: _T.muted,
                              fontWeight: FontWeight.w600,
                              fontSize: 13,
                            ),
                          ),
                        ],
                      ),
                    ),
                    _primaryBtn(
                      'Approve quote · ${_money(x.quote!.total)}',
                      Icons.check_circle_rounded,
                      _T.green,
                      busy ? null : () => _approve(context, c, x),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child: _outlineBtn(
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
                          child: _outlineBtn(
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
              } else if (x.needsPayment) {
                content = _primaryBtn(
                  'View invoice · Pay ${_money(x.advanceDue)}',
                  Icons.receipt_long_rounded,
                  _T.orange,
                  () => c.openInvoice(x),
                );
              } else {
                content = _outlineBtn(
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

  // ----- actions -----
  /// Approve -> invoice generated (unpaid) -> invoice screen.
  Future<void> _approve(
    BuildContext ctx,
    QuotesController c,
    QuoteModel x,
  ) async {
    final b = x.quote!;
    final ok = await showDialog<bool>(
      context: ctx,
      builder: (dctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Approve this quote?'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _KV('Total quote', _money(b.total), bold: true),
            const Divider(height: 18),
            _KV('Deposit now', _money(b.deposit), color: _T.orangeDark),
            _KV('Deposit later', _money(b.remaining)),
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: _T.orange.withValues(alpha: .08),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                b.deposit > 0
                    ? 'An invoice is generated now. Pay ${_money(b.deposit)} '
                          'to confirm your booking.'
                    : 'An invoice is generated now. No deposit is needed.',
                style: const TextStyle(
                  color: _T.ink,
                  height: 1.4,
                  fontSize: 13,
                ),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dctx, false),
            child: const Text('Not yet'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(dctx, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: _T.green,
              foregroundColor: Colors.white,
            ),
            child: const Text('Approve & get invoice'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    if (await c.approveQuote(x)) c.openInvoice(x);
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
          '2. The deposit (paid now) is required before scheduling.\n\n'
          '3. The balance (paid later) is due after the job is completed.\n\n'
          '4. Scope changes on site are approved before work continues.\n\n'
          '5. Cancellations within 24 hours may incur a fee.\n\n'
          '(Placeholder — replace with final legal terms.)',
          style: TextStyle(height: 1.5),
        ),
      ),
    ),
  );
}

// ---------------------------------------------------------
// INVOICE
// ---------------------------------------------------------
class InvoiceView extends StatelessWidget {
  final QuoteModel q;
  const InvoiceView({super.key, required this.q});

  @override
  Widget build(BuildContext context) {
    final c = Get.find<QuotesController>();
    return StreamBuilder<QuoteModel?>(
      stream: c.watch(q.id),
      initialData: q,
      builder: (context, snap) {
        final x = snap.data ?? q;
        final inv = x.invoice;
        // Just approved: the invoice is still being written -> wait for it
        // (the stale model passed in has no invoice yet).
        final waiting =
            inv == null &&
            (snap.connectionState == ConnectionState.waiting ||
                x.status == QS.accepted);

        return Scaffold(
          backgroundColor: _T.bg,
          appBar: AppBar(
            backgroundColor: _T.bg,
            surfaceTintColor: Colors.transparent,
            elevation: 0,
            foregroundColor: _T.ink,
            centerTitle: false,
            title: const Text(
              'Invoice',
              style: TextStyle(fontWeight: FontWeight.w900),
            ),
            actions: [
              if (inv != null)
                IconButton(
                  tooltip: 'Copy invoice summary',
                  icon: const Icon(Icons.copy_all_rounded),
                  onPressed: () {
                    Clipboard.setData(
                      ClipboardData(text: _summaryText(x, inv)),
                    );
                    c.snack('Invoice summary copied', false);
                  },
                ),
            ],
          ),
          bottomNavigationBar: inv == null ? null : _bar(context, c, x),
          body: inv == null
              ? (waiting
                    ? const Center(
                        child: CircularProgressIndicator(color: _T.orange),
                      )
                    : const _Empty(message: 'No invoice for this request yet.'))
              : LayoutBuilder(
                  builder: (context, box) {
                    final pad = _gutter(box.maxWidth);
                    return SingleChildScrollView(
                      padding: EdgeInsets.fromLTRB(pad, 4, pad, 32),
                      child: _Page(
                        max: 640,
                        child: Column(
                          children: [
                            _statusBanner(x),
                            _head(x, inv),
                            _billTo(x),
                            _items(x),
                            _schedule(x),
                            if (x.advancePaid) _paymentInfo(x, inv),
                          ],
                        ),
                      ),
                    );
                  },
                ),
        );
      },
    );
  }

  String _summaryText(QuoteModel x, InvoiceInfo inv) =>
      '$kCompanyName — Invoice ${inv.number}\n'
      'Service: ${x.service} (${x.number})\n'
      'Total: ${_money(x.totalDue)}\n'
      'Deposit now: ${_money(x.advanceDue)} '
      '(${x.advancePaid ? 'PAID' : 'UNPAID'})\n'
      'Deposit later: ${_money(x.balanceDue)} (after the job)';

  /// Big paid / unpaid banner at the top of the invoice.
  Widget _statusBanner(QuoteModel x) {
    final paid = x.advancePaid || x.advanceDue <= 0;
    final col = paid ? _T.green : _T.orange;
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: col.withValues(alpha: .1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: col.withValues(alpha: .4)),
      ),
      child: Row(
        children: [
          Container(
            width: 46,
            height: 46,
            decoration: BoxDecoration(color: col, shape: BoxShape.circle),
            child: Icon(
              paid ? Icons.check_rounded : Icons.schedule_rounded,
              color: Colors.white,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  paid ? 'Deposit paid' : 'Deposit unpaid',
                  style: TextStyle(
                    fontWeight: FontWeight.w900,
                    fontSize: 16,
                    color: paid ? _T.green : _T.orangeDark,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  paid
                      ? 'Thank you! Deposit later: ${_money(x.balanceDue)} '
                            'is due after the job.'
                      : 'Pay ${_money(x.advanceDue)} now to confirm your '
                            'booking.',
                  style: const TextStyle(color: _T.ink, height: 1.35),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _head(QuoteModel x, InvoiceInfo inv) => _Card(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: _T.ink,
                borderRadius: BorderRadius.circular(13),
              ),
              child: const Icon(Icons.handyman_rounded, color: _T.orange),
            ),
            const SizedBox(width: 12),
            const Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    kCompanyName,
                    style: TextStyle(
                      fontWeight: FontWeight.w900,
                      fontSize: 16,
                      color: _T.ink,
                    ),
                  ),
                  Text(
                    kCompanyTagline,
                    style: TextStyle(color: _T.muted, fontSize: 12),
                  ),
                ],
              ),
            ),
            const Text(
              'INVOICE',
              style: TextStyle(
                fontWeight: FontWeight.w900,
                letterSpacing: 1.5,
                color: _T.muted,
                fontSize: 13,
              ),
            ),
          ],
        ),
        const Divider(height: 28),
        Row(
          children: [
            const Expanded(
              flex: 4,
              child: Text('Invoice no.', style: TextStyle(color: _T.muted)),
            ),
            Expanded(
              flex: 6,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  Flexible(
                    child: Text(
                      inv.number,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontWeight: FontWeight.w800,
                        color: _T.ink,
                      ),
                    ),
                  ),
                  InkWell(
                    borderRadius: BorderRadius.circular(8),
                    onTap: () {
                      Clipboard.setData(ClipboardData(text: inv.number));
                      Get.find<QuotesController>().snack(
                        'Invoice number copied',
                        false,
                      );
                    },
                    child: const Padding(
                      padding: EdgeInsets.all(6),
                      child: Icon(
                        Icons.copy_rounded,
                        size: 16,
                        color: _T.muted,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        _KV('Issued', _date(inv.issuedAt ?? x.updatedAt ?? DateTime.now())),
        _KV('Request', x.number),
        _KV('Service', x.service),
        Padding(
          padding: const EdgeInsets.only(top: 6),
          child: Row(
            children: [
              const Expanded(
                flex: 4,
                child: Text('Payment', style: TextStyle(color: _T.muted)),
              ),
              Expanded(
                flex: 6,
                child: Align(
                  alignment: Alignment.centerRight,
                  child: _PayChip(paid: x.advancePaid),
                ),
              ),
            ],
          ),
        ),
      ],
    ),
  );

  Widget _billTo(QuoteModel x) => _Card(
    title: 'Billed to',
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _InfoLine(Icons.person_outline_rounded, x.name),
        _InfoLine(Icons.location_on_outlined, x.address),
        _InfoLine(Icons.phone_outlined, x.phone),
        _InfoLine(Icons.mail_outline_rounded, x.email),
        if (x.name.isEmpty &&
            x.address.isEmpty &&
            x.phone.isEmpty &&
            x.email.isEmpty)
          const Text('—', style: TextStyle(color: _T.muted)),
      ],
    ),
  );

  Widget _items(QuoteModel x) {
    final b = x.quote;
    return _Card(
      title: 'Items',
      child: Column(
        children: [
          if (b != null) ...[
            _KV('Labor', _money(b.labor)),
            if (b.materials > 0) _KV('Materials', _money(b.materials)),
            if (b.fees > 0) _KV('Service / travel fees', _money(b.fees)),
            if (b.discount > 0)
              _KV('Discount', '-${_money(b.discount)}', color: _T.green),
            if (b.tax > 0) _KV('Tax', _money(b.tax)),
            const Divider(height: 20),
          ],
          _KV('Total', _money(x.totalDue), bold: true),
        ],
      ),
    );
  }

  Widget _schedule(QuoteModel x) {
    Widget row(String title, String sub, double amt, Widget trailing) => Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontWeight: FontWeight.w800,
                  color: _T.ink,
                ),
              ),
              Text(sub, style: const TextStyle(color: _T.muted, fontSize: 12)),
            ],
          ),
        ),
        Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(
              _money(amt),
              style: const TextStyle(
                fontWeight: FontWeight.w900,
                fontSize: 17,
                color: _T.ink,
              ),
            ),
            const SizedBox(height: 4),
            trailing,
          ],
        ),
      ],
    );

    final pct = x.advancePct;
    return _Card(
      title: 'Payment schedule',
      child: Column(
        children: [
          _SplitBar(pct: pct, advance: _T.orange, balance: _T.line),
          const SizedBox(height: 16),
          row(
            'Deposit now · ${pct.toStringAsFixed(0)}%',
            'Due now to book your job',
            x.advanceDue,
            _PayChip(paid: x.advancePaid),
          ),
          const Divider(height: 26),
          row(
            'Deposit later · ${(100 - pct).toStringAsFixed(0)}%',
            'Due after the job is completed',
            x.balanceDue,
            const Text(
              'Pending',
              style: TextStyle(
                color: _T.muted,
                fontWeight: FontWeight.w700,
                fontSize: 12,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _paymentInfo(QuoteModel x, InvoiceInfo inv) => _Card(
    color: _T.green.withValues(alpha: .07),
    border: _T.green.withValues(alpha: .25),
    title: 'Deposit payment received',
    child: Column(
      children: [
        _KV('Amount', _money(x.advanceDue), color: _T.green),
        _KV('Method', _cap(x.paymentMethod)),
        _KV('Reference', x.paymentRef.isEmpty ? '—' : x.paymentRef),
        _KV('Paid on', _date(inv.paidAt ?? x.advancePaidAt)),
      ],
    ),
  );

  Widget _bar(BuildContext context, QuotesController c, QuoteModel x) {
    final paid = x.advancePaid || x.advanceDue <= 0;
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
            child: paid
                ? _primaryBtn(
                    'Back to my quotes',
                    Icons.check_rounded,
                    _T.ink,
                    c.backToQuotes,
                  )
                : _primaryBtn(
                    'Pay deposit now — ${_money(x.advanceDue)}',
                    Icons.payments_rounded,
                    _T.orange,
                    () => c.openPayment(x),
                  ),
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------
// PAYMENT
// ---------------------------------------------------------
/// Replace the body of this class with your real gateway (Stripe, etc.).
/// For production, confirm the payment on your SERVER (webhook / Cloud
/// Function) and let the server write `paymentStatus: 'paid'`.
/// Never collect or store raw card numbers yourself — use the gateway's
/// own payment sheet.
class PaymentGateway {
  /// Returns a payment reference on success, or null on failure.
  static Future<String?> charge({
    required double amount,
    required String method,
    required String quoteId,
  }) async {
    await Future.delayed(const Duration(seconds: 2)); // DEMO
    return 'DEMO-${DateTime.now().millisecondsSinceEpoch}';
  }
}

class _CardFmt extends TextInputFormatter {
  final bool isNumber; // true = card number, false = MM/YY
  const _CardFmt.number() : isNumber = true;
  const _CardFmt.expiry() : isNumber = false;

  @override
  TextEditingValue formatEditUpdate(TextEditingValue o, TextEditingValue n) {
    final digits = n.text.replaceAll(RegExp(r'\D'), '');
    final max = isNumber ? 16 : 4;
    final t = digits.length > max ? digits.substring(0, max) : digits;
    final b = StringBuffer();
    for (var i = 0; i < t.length; i++) {
      if (isNumber && i > 0 && i % 4 == 0) b.write(' ');
      if (!isNumber && i == 2) b.write('/');
      b.write(t[i]);
    }
    final s = b.toString();
    return TextEditingValue(
      text: s,
      selection: TextSelection.collapsed(offset: s.length),
    );
  }
}

class PaymentView extends StatefulWidget {
  final QuoteModel q;
  const PaymentView({super.key, required this.q});

  @override
  State<PaymentView> createState() => _PaymentViewState();
}

class _PaymentViewState extends State<PaymentView> {
  final _formKey = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _num = TextEditingController();
  final _exp = TextEditingController();
  final _cvv = TextEditingController();

  late QuoteModel _q = widget.q; // kept in sync with the live document
  String _method = 'card';
  bool _paying = false;
  String? _ref;
  double _paidAmount = 0;

  @override
  void initState() {
    super.initState();
    _name.text = widget.q.name;
    if (kDemoPayment) {
      _num.text = '4242 4242 4242 4242';
      _exp.text = '12/30';
      _cvv.text = '123';
    }
  }

  @override
  void dispose() {
    _name.dispose();
    _num.dispose();
    _exp.dispose();
    _cvv.dispose();
    super.dispose();
  }

  Future<void> _pay() async {
    if (_paying || _q.advancePaid || _q.totalDue <= 0) return;
    if (_method == 'card' && !(_formKey.currentState?.validate() ?? false)) {
      return;
    }

    setState(() => _paying = true);
    final c = Get.find<QuotesController>();
    final amount = _q.advanceDue;

    final ref = await PaymentGateway.charge(
      amount: amount,
      method: _method,
      quoteId: _q.id,
    );
    if (ref == null) {
      if (mounted) setState(() => _paying = false);
      c.snack('Payment failed. Please try again.', true);
      return;
    }

    final saved = await c.markAdvancePaid(_q, _method, ref);
    if (!mounted) return;
    if (!saved) {
      // Check Firestore rules: the customer must be allowed to update
      // paymentStatus / advancePaid / invoice.* on their own request.
      setState(() => _paying = false);
      c.snack(
        kDemoPayment
            ? 'Could not save the payment. Check Firestore rules.'
            : 'Paid, but could not update your order. Contact support.',
        true,
      );
      return;
    }
    setState(() {
      _paying = false;
      _paidAmount = amount;
      _ref = ref;
    });
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuoteModel?>(
      stream: Get.find<QuotesController>().watch(widget.q.id),
      initialData: widget.q,
      builder: (context, snap) {
        _q = snap.data ?? _q; // latest data from Firebase

        // Opened for an invoice that is already paid -> show the receipt.
        if (_ref == null && _q.advancePaid) {
          _ref = _q.paymentRef.isEmpty ? '—' : _q.paymentRef;
          _paidAmount = _q.advanceDue;
        }

        return Scaffold(
          backgroundColor: _T.bg,
          appBar: AppBar(
            backgroundColor: _T.bg,
            surfaceTintColor: Colors.transparent,
            elevation: 0,
            foregroundColor: _T.ink,
            centerTitle: false,
            automaticallyImplyLeading: _ref == null,
            title: const Text(
              'Pay deposit',
              style: TextStyle(fontWeight: FontWeight.w900),
            ),
          ),
          body: SafeArea(
            child: LayoutBuilder(
              builder: (context, box) {
                if (_ref != null) return _success();
                if (_q.totalDue <= 0) {
                  return const _Empty(
                    message: 'The quote amount is not available yet.',
                  );
                }
                final wide = box.maxWidth > 760;
                final pad = _gutter(box.maxWidth);
                final summary = _summary();
                final form = _form();
                return SingleChildScrollView(
                  padding: EdgeInsets.fromLTRB(pad, 4, pad, 32),
                  child: _Page(
                    max: wide ? 960 : 560,
                    child: wide
                        ? Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Expanded(child: summary),
                              const SizedBox(width: 18),
                              Expanded(child: form),
                            ],
                          )
                        : Column(children: [summary, form]),
                  ),
                );
              },
            ),
          ),
        );
      },
    );
  }

  Widget _summary() => Column(
    children: [
      _AmountCard(
        label: 'DEPOSIT TO PAY NOW',
        amount: _money(_q.advanceDue),
        amountColor: _T.orange,
        subtitle:
            '${_q.advancePct.toStringAsFixed(0)}% of ${_money(_q.totalDue)} total',
      ),
      _Card(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(
                    color: _T.orange.withValues(alpha: .12),
                    borderRadius: BorderRadius.circular(13),
                  ),
                  child: Icon(_serviceIcon(_q.service), color: _T.orange),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _q.service,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontWeight: FontWeight.w800,
                          fontSize: 16,
                        ),
                      ),
                      Text(
                        _q.invoice?.number ?? _q.number,
                        style: const TextStyle(color: _T.muted, fontSize: 12),
                      ),
                    ],
                  ),
                ),
                const _PayChip(paid: false),
              ],
            ),
            const Divider(height: 26),
            _KV('Quote total', _money(_q.totalDue)),
            _KV(
              'Deposit now (${_q.advancePct.toStringAsFixed(0)}%)',
              _money(_q.advanceDue),
              color: _T.orange,
            ),
            _KV('Deposit later — after job', _money(_q.balanceDue)),
            const Divider(height: 22),
            _KV('Due today', _money(_q.advanceDue), bold: true),
          ],
        ),
      ),
    ],
  );

  Widget _methodTile(String id, IconData icon, String label) {
    final on = _method == id;
    return Expanded(
      child: GestureDetector(
        onTap: _paying ? null : () => setState(() => _method = id),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            color: on ? _T.orange.withValues(alpha: .1) : _T.bg,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: on ? _T.orange : _T.line,
              width: on ? 1.6 : 1,
            ),
          ),
          child: Column(
            children: [
              Icon(icon, color: on ? _T.orange : _T.muted),
              const SizedBox(height: 4),
              Text(
                label,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                  color: on ? _T.orangeDark : _T.muted,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _cardForm() => Form(
    key: _formKey,
    child: Column(
      children: [
        TextFormField(
          controller: _name,
          textCapitalization: TextCapitalization.words,
          decoration: _inputDec(
            'Name on card',
            icon: Icons.person_outline_rounded,
          ),
          validator: (v) =>
              (v ?? '').trim().isEmpty ? 'Enter the name on card' : null,
        ),
        const SizedBox(height: 12),
        TextFormField(
          controller: _num,
          keyboardType: TextInputType.number,
          inputFormatters: const [_CardFmt.number()],
          decoration: _inputDec('Card number', icon: Icons.credit_card_rounded),
          validator: (v) => (v ?? '').replaceAll(' ', '').length < 16
              ? 'Enter 16 digits'
              : null,
        ),
        const SizedBox(height: 12),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: TextFormField(
                controller: _exp,
                keyboardType: TextInputType.number,
                inputFormatters: const [_CardFmt.expiry()],
                decoration: _inputDec('MM/YY'),
                validator: (v) => (v ?? '').length < 5 ? 'Invalid' : null,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: TextFormField(
                controller: _cvv,
                keyboardType: TextInputType.number,
                obscureText: true,
                inputFormatters: [
                  FilteringTextInputFormatter.digitsOnly,
                  LengthLimitingTextInputFormatter(4),
                ],
                decoration: _inputDec('CVV'),
                validator: (v) => (v ?? '').length < 3 ? 'Invalid' : null,
              ),
            ),
          ],
        ),
      ],
    ),
  );

  Widget _form() => _Card(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (kDemoPayment)
          Container(
            width: double.infinity,
            margin: const EdgeInsets.only(bottom: 14),
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: _T.blue.withValues(alpha: .1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Row(
              children: [
                Icon(Icons.science_outlined, size: 18, color: _T.blue),
                SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Demo mode — no real money is charged.',
                    style: TextStyle(
                      color: _T.blue,
                      fontSize: 12.5,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ),
        const Text(
          'Payment method',
          style: TextStyle(fontSize: 15.5, fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            _methodTile('card', Icons.credit_card_rounded, 'Card'),
            const SizedBox(width: 8),
            _methodTile('bank', Icons.account_balance_rounded, 'Bank'),
            const SizedBox(width: 8),
            _methodTile(
              'wallet',
              Icons.account_balance_wallet_rounded,
              'Wallet',
            ),
          ],
        ),
        const SizedBox(height: 16),
        if (_method == 'card')
          _cardForm()
        else
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: _T.bg,
              borderRadius: BorderRadius.circular(14),
            ),
            child: Text(
              _method == 'bank'
                  ? 'You will be redirected to your bank to confirm the transfer.'
                  : 'You will confirm the payment in your wallet app.',
              style: const TextStyle(color: _T.muted, height: 1.4),
            ),
          ),
        const SizedBox(height: 18),
        SizedBox(
          width: double.infinity,
          height: 54,
          child: ElevatedButton.icon(
            onPressed: _paying ? null : _pay,
            icon: _paying
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                      strokeWidth: 2.4,
                      color: Colors.white,
                    ),
                  )
                : const Icon(Icons.lock_rounded, size: 18),
            label: Flexible(
              child: Text(
                _paying ? 'Processing…' : 'Pay ${_money(_q.advanceDue)}',
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontWeight: FontWeight.w800,
                  fontSize: 16,
                ),
              ),
            ),
            style: ElevatedButton.styleFrom(
              elevation: 0,
              backgroundColor: _T.orange,
              foregroundColor: Colors.white,
              disabledBackgroundColor: _T.orange.withValues(alpha: .6),
              disabledForegroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
            ),
          ),
        ),
        const SizedBox(height: 10),
        const Center(
          child: Text(
            'Secured payment · Your details are encrypted',
            style: TextStyle(color: _T.muted, fontSize: 12),
          ),
        ),
      ],
    ),
  );

  Widget _success() => Center(
    child: SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 440),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TweenAnimationBuilder<double>(
              tween: Tween(begin: 0, end: 1),
              duration: const Duration(milliseconds: 500),
              curve: Curves.elasticOut,
              builder: (_, v, child) => Transform.scale(scale: v, child: child),
              child: Container(
                padding: const EdgeInsets.all(26),
                decoration: BoxDecoration(
                  color: _T.green.withValues(alpha: .12),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.check_circle_rounded,
                  color: _T.green,
                  size: 72,
                ),
              ),
            ),
            const SizedBox(height: 20),
            const Text(
              'Deposit payment received',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.w900,
                color: _T.ink,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              '${_money(_paidAmount)} deposit paid for ${_q.service}.\n'
              'Deposit later: ${_money(_q.balanceDue)} is due after the job.\n'
              'We will schedule your job shortly.',
              textAlign: TextAlign.center,
              style: const TextStyle(color: _T.muted, height: 1.45),
            ),
            const SizedBox(height: 10),
            Text(
              'Ref: $_ref',
              style: const TextStyle(color: _T.muted, fontSize: 12),
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              height: 52,
              child: ElevatedButton.icon(
                onPressed: () => Get.back(), // back to the invoice (now PAID)
                icon: const Icon(Icons.receipt_long_rounded, size: 18),
                label: const Text(
                  'View paid invoice',
                  style: TextStyle(fontWeight: FontWeight.w800),
                ),
                style: ElevatedButton.styleFrom(
                  elevation: 0,
                  backgroundColor: _T.orange,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 10),
            SizedBox(
              width: double.infinity,
              height: 48,
              child: OutlinedButton(
                onPressed: Get.find<QuotesController>().backToQuotes,
                style: OutlinedButton.styleFrom(
                  foregroundColor: _T.ink,
                  side: const BorderSide(color: _T.line),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
                child: const Text(
                  'Back to my quotes',
                  style: TextStyle(fontWeight: FontWeight.w800),
                ),
              ),
            ),
          ],
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

  void _submit() {
    if (widget.isRequired && _t.text.trim().isEmpty) {
      setState(() => _err = 'Please add a short note');
      return;
    }
    Navigator.pop(context, _t.text.trim());
  }

  @override
  Widget build(BuildContext context) {
    final col = widget.danger ? _T.red : _T.orange;
    final shape = RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(14),
    );

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
                        shape: shape,
                      ),
                      child: const Text('Back'),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: _submit,
                      style: ElevatedButton.styleFrom(
                        elevation: 0,
                        backgroundColor: col,
                        foregroundColor: Colors.white,
                        minimumSize: const Size.fromHeight(48),
                        shape: shape,
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
