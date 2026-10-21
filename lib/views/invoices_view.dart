// =============================================================
// invoices_view.dart — Customer "Invoices & payments" screen
//
// Works on top of quotes_view.dart (same Firestore documents):
//   an invoice exists on quote_requests/{id} once the customer approves
//   a quote (invoice map, status 'advance_unpaid' | 'advance_paid').
//
// WHAT YOU GET
//   InvoicesView          full list screen: summary, filters, cards
//   InvoicesController    live list + NOTIFICATIONS (alert when a new
//                         invoice is generated / unpaid invoices waiting)
//   InvoiceAlertBanner    small dark banner for your home screen
//
// TAP FLOW
//   alert / banner / card  ->  invoice detail (InvoiceView in
//   quotes_view.dart)  ->  "Pay deposit now"  ->  PaymentView  ->  PAID
//
// SETUP (once, right after the user logs in, e.g. in your home view):
//   Get.put(InvoicesController(), permanent: true);
//
// OPEN THE SCREEN (menu item, bottom tab, etc.):
//   Get.to(() => const InvoicesView(), routeName: '/invoices');
//   // or embed as a tab:  const InvoicesView(embedded: true)
//
// Place the banner on any screen:   const InvoiceAlertBanner()
//
// pubspec: get (same as quotes_view.dart). Needs get ^4.6.
// =============================================================
import 'package:flutter/material.dart';
import 'package:get/get.dart';

import 'quotes_view.dart';

// ---------------------------------------------------------
// THEME + HELPERS (local copies, the originals are private)
// ---------------------------------------------------------
class _I {
  static const orange = Color(0xFFFF7A00);
  static const orangeDark = Color(0xFFE55F00);
  static const ink = Color(0xFF1B1F2A);
  static const bg = Color(0xFFF5F3EF);
  static const surface = Colors.white;
  static const muted = Color(0xFF787F90);
  static const line = Color(0xFFE9E5DD);
  static const green = Color(0xFF1FAE6B);
  static const blue = Color(0xFF2D8CDB);
}

const _mon = [
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

String _fmtDate(DateTime? d) =>
    d == null ? '—' : '${_mon[d.month - 1]} ${d.day}, ${d.year}';

String _fmtMoney(num v) {
  final p = v.toStringAsFixed(2).split('.');
  final whole = p[0].replaceAllMapped(
    RegExp(r'\B(?=(\d{3})+(?!\d))'),
    (_) => ',',
  );
  return '\$$whole.${p[1]}';
}

/// Deposit paid (or no deposit needed at all).
bool _isPaid(QuoteModel q) => q.advancePaid || q.advanceDue <= 0;

DateTime _invDate(QuoteModel q) =>
    q.invoice?.issuedAt ??
    q.updatedAt ??
    q.createdAt ??
    DateTime.fromMillisecondsSinceEpoch(0);

// ---------------------------------------------------------
// CONTROLLER (list + notifications)
// ---------------------------------------------------------
class InvoicesController extends GetxController {
  late final QuotesController qc;
  final filter = 'All'.obs;
  static const filters = ['All', 'Unpaid', 'Paid'];

  final _seen = <String>{};
  bool _first = true;
  Worker? _worker;

  static const routeName = '/invoices';

  /// Open the invoices list from anywhere.
  static void openList() =>
      Get.to(() => const InvoicesView(), routeName: routeName);

  @override
  void onInit() {
    super.onInit();
    qc = Get.isRegistered<QuotesController>()
        ? Get.find<QuotesController>()
        : Get.put(QuotesController());
    _worker = ever<List<QuoteModel>>(qc.quotes, _onQuotes);
    if (qc.quotes.isNotEmpty) _onQuotes(qc.quotes);
  }

  @override
  void onClose() {
    _worker?.dispose();
    super.onClose();
  }

  // ----- data -----
  /// Unpaid first, then newest first.
  List<QuoteModel> get all {
    final l = qc.quotes.where((q) => q.hasInvoice).toList()
      ..sort((a, b) {
        final pa = _isPaid(a) ? 1 : 0;
        final pb = _isPaid(b) ? 1 : 0;
        if (pa != pb) return pa.compareTo(pb);
        return _invDate(b).compareTo(_invDate(a));
      });
    return l;
  }

  List<QuoteModel> get unpaid => all.where((q) => !_isPaid(q)).toList();

  bool _match(QuoteModel q, String f) =>
      f == 'Unpaid' ? !_isPaid(q) : (f == 'Paid' ? _isPaid(q) : true);

  List<QuoteModel> get visible =>
      all.where((q) => _match(q, filter.value)).toList();

  int count(String f) => all.where((q) => _match(q, f)).length;

  /// Deposit amount still to pay across all unpaid invoices.
  double get dueNow => unpaid.fold(0.0, (s, q) => s + q.advanceDue);

  /// Deposits already received.
  double get paidTotal => all
      .where((q) => _isPaid(q))
      .fold(0.0, (s, q) => s + (q.advancePaid ? q.advanceDue : 0));

  /// Deposit-later balances that will be due after the jobs.
  double get laterTotal => all.fold(0.0, (s, q) => s + q.balanceDue);

  // ----- notifications -----
  void _onQuotes(List<QuoteModel> list) {
    final inv = list.where((q) => q.hasInvoice).toList();
    final unpaidList = inv.where((q) => !_isPaid(q)).toList();

    if (_first) {
      _first = false;
      _seen.addAll(inv.map((q) => q.id));
      if (unpaidList.isNotEmpty) _summaryAlert(unpaidList);
      return;
    }

    final fresh = unpaidList.where((q) => !_seen.contains(q.id)).toList();
    _seen.addAll(inv.map((q) => q.id));
    if (fresh.isNotEmpty) _newInvoiceAlert(fresh.first);
  }

  // Do not pop an alert while the customer is already on a quote screen
  // (e.g. right after tapping "Approve" the invoice screen is opening).
  bool get _onQuoteScreen => Get.currentRoute.startsWith('/quote-');

  void _newInvoiceAlert(QuoteModel q) {
    if (_onQuoteScreen) return;
    _show(
      title: 'Invoice generated',
      message:
          '${q.invoice?.number ?? q.number} · ${q.service} · '
          'Pay ${_fmtMoney(q.advanceDue)} now',
      onTap: () => qc.openInvoice(q),
    );
  }

  void _summaryAlert(List<QuoteModel> unpaidList) {
    if (_onQuoteScreen) return;
    final n = unpaidList.length;
    final due = unpaidList.fold(0.0, (s, q) => s + q.advanceDue);
    _show(
      title: n == 1 ? '1 invoice is waiting' : '$n invoices are waiting',
      message: 'Deposit due now ${_fmtMoney(due)} — tap to pay',
      onTap: () => n == 1 ? qc.openInvoice(unpaidList.first) : openList(),
    );
  }

  void _show({
    required String title,
    required String message,
    required VoidCallback onTap,
  }) {
    Future.delayed(const Duration(milliseconds: 700), () {
      if (Get.context == null) return;
      Get.snackbar(
        '',
        '',
        titleText: Row(
          children: [
            const Icon(Icons.receipt_long_rounded, color: _I.orange, size: 20),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                title,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w800,
                  fontSize: 15,
                ),
              ),
            ),
          ],
        ),
        messageText: Text(
          message,
          style: TextStyle(color: Colors.white.withValues(alpha: .85)),
        ),
        snackPosition: SnackPosition.TOP,
        margin: const EdgeInsets.all(16),
        maxWidth: 560,
        borderRadius: 16,
        backgroundColor: _I.ink,
        duration: const Duration(seconds: 8),
        onTap: (_) {
          Get.closeCurrentSnackbar();
          onTap();
        },
      );
    });
  }
}

// ---------------------------------------------------------
// INVOICES LIST SCREEN
// ---------------------------------------------------------
class InvoicesView extends StatelessWidget {
  /// true when used as a tab (no back button).
  final bool embedded;
  const InvoicesView({super.key, this.embedded = false});

  @override
  Widget build(BuildContext context) {
    final c = Get.isRegistered<InvoicesController>()
        ? Get.find<InvoicesController>()
        : Get.put(InvoicesController());

    return Scaffold(
      backgroundColor: _I.bg,
      body: RefreshIndicator(
        color: _I.orange,
        onRefresh: c.qc.refreshData,
        child: LayoutBuilder(
          builder: (context, box) {
            final w = box.maxWidth;
            final pad = w >= 600 ? 24.0 : 16.0;
            final cols = w >= 960 ? 3 : (w >= 600 ? 2 : 1);
            const gap = 14.0;
            final contentW = (w < 1100 ? w : 1100.0) - pad * 2;
            final itemW = (contentW - gap * (cols - 1)) / cols;
            final top = MediaQuery.of(context).padding.top;

            return CustomScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              slivers: [
                SliverToBoxAdapter(child: _header(context, c, pad, top)),
                SliverToBoxAdapter(child: _summary(c, pad)),
                SliverToBoxAdapter(
                  child: _Centered(
                    child: _Filters(c: c, pad: pad),
                  ),
                ),
                Obx(() {
                  if (c.qc.loading.value) {
                    return const SliverFillRemaining(
                      hasScrollBody: false,
                      child: Center(
                        child: CircularProgressIndicator(color: _I.orange),
                      ),
                    );
                  }
                  final list = c.visible;
                  if (list.isEmpty) {
                    return SliverFillRemaining(
                      hasScrollBody: false,
                      child: _EmptyState(
                        message: c.all.isEmpty
                            ? 'No invoices yet.\nApprove a quote and your invoice will appear here.'
                            : 'No ${c.filter.value.toLowerCase()} invoices.',
                      ),
                    );
                  }
                  return SliverToBoxAdapter(
                    child: _Centered(
                      child: Padding(
                        padding: EdgeInsets.fromLTRB(pad, 4, pad, 40),
                        child: Wrap(
                          spacing: gap,
                          runSpacing: gap,
                          children: [
                            for (var i = 0; i < list.length; i++)
                              SizedBox(
                                width: itemW,
                                child: _InvoiceCard(
                                  q: list[i],
                                  index: i,
                                  onOpen: () => c.qc.openInvoice(list[i]),
                                  onPay: () => c.qc.openPayment(list[i]),
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

  Widget _header(
    BuildContext context,
    InvoicesController c,
    double pad,
    double top,
  ) {
    final canPop = !embedded && Navigator.of(context).canPop();
    return _Centered(
      child: Padding(
        padding: EdgeInsets.fromLTRB(pad, top + 14, pad, 6),
        child: Row(
          children: [
            if (canPop) ...[
              Material(
                color: _I.surface,
                shape: const CircleBorder(side: BorderSide(color: _I.line)),
                child: IconButton(
                  onPressed: () => Navigator.of(context).maybePop(),
                  icon: const Icon(Icons.arrow_back_rounded, color: _I.ink),
                ),
              ),
              const SizedBox(width: 12),
            ],
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Invoices & payments',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 26,
                      height: 1.1,
                      fontWeight: FontWeight.w900,
                      color: _I.ink,
                      letterSpacing: -.5,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Obx(() {
                    final n = c.all.length;
                    final u = c.unpaid.length;
                    return Text(
                      n == 0
                          ? 'Generated when you approve a quote.'
                          : '$n invoice${n == 1 ? '' : 's'} · $u unpaid',
                      style: const TextStyle(color: _I.muted),
                    );
                  }),
                ],
              ),
            ),
            Material(
              color: _I.surface,
              shape: const CircleBorder(side: BorderSide(color: _I.line)),
              child: IconButton(
                tooltip: 'Refresh',
                onPressed: c.qc.refreshData,
                icon: const Icon(Icons.refresh_rounded, color: _I.ink),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Three tiles: due now / paid / due after jobs.
  Widget _summary(InvoicesController c, double pad) => _Centered(
    child: Padding(
      padding: EdgeInsets.fromLTRB(pad, 12, pad, 0),
      child: Obx(() {
        if (c.all.isEmpty) return const SizedBox.shrink();
        Widget tile(
          String label,
          double v,
          Color col,
          IconData icon, {
          bool dark = false,
        }) => Expanded(
          child: Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: dark ? _I.ink : _I.surface,
              borderRadius: BorderRadius.circular(18),
              border: dark ? null : Border.all(color: _I.line),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(icon, size: 15, color: col),
                    const SizedBox(width: 5),
                    Flexible(
                      child: Text(
                        label,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w800,
                          letterSpacing: .4,
                          color: dark
                              ? Colors.white.withValues(alpha: .7)
                              : _I.muted,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: Text(
                    _fmtMoney(v),
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w900,
                      color: dark ? col : _I.ink,
                    ),
                  ),
                ),
              ],
            ),
          ),
        );

        return Row(
          children: [
            tile(
              'DUE NOW',
              c.dueNow,
              _I.orange,
              Icons.bolt_rounded,
              dark: true,
            ),
            const SizedBox(width: 10),
            tile('PAID', c.paidTotal, _I.green, Icons.check_circle_rounded),
            const SizedBox(width: 10),
            tile('DUE LATER', c.laterTotal, _I.muted, Icons.schedule_rounded),
          ],
        );
      }),
    ),
  );
}

// ---------------------------------------------------------
// SMALL WIDGETS
// ---------------------------------------------------------
class _Centered extends StatelessWidget {
  final Widget child;
  const _Centered({required this.child});

  @override
  Widget build(BuildContext context) => Center(
    child: ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 1100),
      child: child,
    ),
  );
}

class _Filters extends StatelessWidget {
  final InvoicesController c;
  final double pad;
  const _Filters({required this.c, required this.pad});

  @override
  Widget build(BuildContext context) => SizedBox(
    height: 70,
    child: Obx(
      () => ListView(
        scrollDirection: Axis.horizontal,
        padding: EdgeInsets.symmetric(horizontal: pad, vertical: 14),
        children: [
          for (final f in InvoicesController.filters)
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
        color: on ? _I.ink : _I.surface,
        borderRadius: BorderRadius.circular(30),
        border: Border.all(color: on ? _I.ink : _I.line),
      ),
      child: Row(
        children: [
          Text(
            f,
            style: TextStyle(
              fontWeight: FontWeight.w700,
              color: on ? Colors.white : _I.ink,
            ),
          ),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
            decoration: BoxDecoration(
              color: on ? _I.orange : _I.bg,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Text(
              '$n',
              style: TextStyle(
                fontSize: 11.5,
                fontWeight: FontWeight.w800,
                color: on ? Colors.white : _I.muted,
              ),
            ),
          ),
        ],
      ),
    ),
  );
}

class _EmptyState extends StatelessWidget {
  final String message;
  const _EmptyState({required this.message});

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.all(32),
    child: Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Container(
          padding: const EdgeInsets.all(22),
          decoration: BoxDecoration(
            color: _I.orange.withValues(alpha: .1),
            shape: BoxShape.circle,
          ),
          child: const Icon(
            Icons.receipt_long_rounded,
            color: _I.orange,
            size: 44,
          ),
        ),
        const SizedBox(height: 16),
        Text(
          message,
          textAlign: TextAlign.center,
          style: const TextStyle(color: _I.muted, height: 1.4),
        ),
      ],
    ),
  );
}

class _StatusPill extends StatelessWidget {
  final bool paid;
  const _StatusPill({required this.paid});

  @override
  Widget build(BuildContext context) {
    final col = paid ? _I.green : _I.orangeDark;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: col.withValues(alpha: .12),
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
            paid ? 'PAID' : 'UNPAID',
            style: TextStyle(
              color: col,
              fontWeight: FontWeight.w900,
              fontSize: 11.5,
              letterSpacing: .6,
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------
// INVOICE CARD
// ---------------------------------------------------------
class _InvoiceCard extends StatelessWidget {
  final QuoteModel q;
  final int index;
  final VoidCallback onOpen, onPay;
  const _InvoiceCard({
    required this.q,
    required this.index,
    required this.onOpen,
    required this.onPay,
  });

  @override
  Widget build(BuildContext context) {
    final paid = _isPaid(q);
    final accent = paid ? _I.green : _I.orange;
    final number = q.invoice?.number ?? 'INV-${q.number}';

    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: Duration(milliseconds: 260 + index.clamp(0, 6) * 60),
      curve: Curves.easeOut,
      builder: (_, v, child) => Opacity(
        opacity: v,
        child: Transform.translate(
          offset: Offset(0, 14 * (1 - v)),
          child: child,
        ),
      ),
      child: Material(
        color: _I.surface,
        clipBehavior: Clip.antiAlias,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: BorderSide(
            color: paid ? _I.line : _I.orange.withValues(alpha: .55),
            width: paid ? 1 : 1.5,
          ),
        ),
        child: InkWell(
          onTap: onOpen,
          child: IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Container(width: 5, color: accent),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Container(
                              width: 44,
                              height: 44,
                              decoration: BoxDecoration(
                                color: accent.withValues(alpha: .12),
                                borderRadius: BorderRadius.circular(13),
                              ),
                              child: Icon(
                                Icons.receipt_long_rounded,
                                color: accent,
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
                                      color: _I.ink,
                                    ),
                                  ),
                                  Text(
                                    '$number · ${_fmtDate(_invDate(q))}',
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                      color: _I.muted,
                                      fontSize: 12,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 8),
                            _StatusPill(paid: paid),
                          ],
                        ),
                        const SizedBox(height: 14),
                        Text(
                          paid ? 'DEPOSIT PAID' : 'DEPOSIT DUE NOW',
                          style: const TextStyle(
                            color: _I.muted,
                            fontSize: 10.5,
                            letterSpacing: .8,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(height: 2),
                        FittedBox(
                          fit: BoxFit.scaleDown,
                          alignment: Alignment.centerLeft,
                          child: Text(
                            _fmtMoney(q.advanceDue),
                            style: TextStyle(
                              fontSize: 30,
                              height: 1.1,
                              fontWeight: FontWeight.w900,
                              color: paid ? _I.green : _I.ink,
                              letterSpacing: -.5,
                            ),
                          ),
                        ),
                        const SizedBox(height: 10),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 8,
                          ),
                          decoration: BoxDecoration(
                            color: _I.bg,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Row(
                            children: [
                              Expanded(
                                child: Text(
                                  'Total ${_fmtMoney(q.totalDue)}',
                                  style: const TextStyle(
                                    fontSize: 12.5,
                                    fontWeight: FontWeight.w700,
                                    color: _I.ink,
                                  ),
                                ),
                              ),
                              Text(
                                'Later ${_fmtMoney(q.balanceDue)}',
                                style: const TextStyle(
                                  fontSize: 12.5,
                                  fontWeight: FontWeight.w600,
                                  color: _I.muted,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 12),
                        paid
                            ? Row(
                                children: [
                                  Expanded(
                                    child: Text(
                                      q.advancePaidAt == null
                                          ? 'Deposit received'
                                          : 'Paid on ${_fmtDate(q.advancePaidAt)}',
                                      style: const TextStyle(
                                        color: _I.muted,
                                        fontSize: 12.5,
                                      ),
                                    ),
                                  ),
                                  const Text(
                                    'View →',
                                    style: TextStyle(
                                      color: _I.blue,
                                      fontWeight: FontWeight.w800,
                                    ),
                                  ),
                                ],
                              )
                            : Row(
                                children: [
                                  Expanded(
                                    child: SizedBox(
                                      height: 44,
                                      child: ElevatedButton.icon(
                                        onPressed: onPay,
                                        icon: const Icon(
                                          Icons.payments_rounded,
                                          size: 18,
                                        ),
                                        label: Flexible(
                                          child: Text(
                                            'Pay ${_fmtMoney(q.advanceDue)}',
                                            overflow: TextOverflow.ellipsis,
                                            style: const TextStyle(
                                              fontWeight: FontWeight.w800,
                                            ),
                                          ),
                                        ),
                                        style: ElevatedButton.styleFrom(
                                          elevation: 0,
                                          backgroundColor: _I.orange,
                                          foregroundColor: Colors.white,
                                          shape: RoundedRectangleBorder(
                                            borderRadius: BorderRadius.circular(
                                              13,
                                            ),
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  SizedBox(
                                    height: 44,
                                    child: OutlinedButton(
                                      onPressed: onOpen,
                                      style: OutlinedButton.styleFrom(
                                        foregroundColor: _I.ink,
                                        side: const BorderSide(color: _I.line),
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(
                                            13,
                                          ),
                                        ),
                                      ),
                                      child: const Text(
                                        'Invoice',
                                        style: TextStyle(
                                          fontWeight: FontWeight.w700,
                                        ),
                                      ),
                                    ),
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
// ALERT BANNER (put on your home / quotes screen)
// ---------------------------------------------------------
class InvoiceAlertBanner extends StatelessWidget {
  const InvoiceAlertBanner({super.key});

  @override
  Widget build(BuildContext context) {
    final c = Get.isRegistered<InvoicesController>()
        ? Get.find<InvoicesController>()
        : Get.put(InvoicesController());

    return Obx(() {
      final list = c.unpaid;
      if (list.isEmpty) return const SizedBox.shrink();
      final n = list.length;
      final due = c.dueNow;

      return Material(
        color: _I.ink,
        borderRadius: BorderRadius.circular(20),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: () => n == 1
              ? c.qc.openInvoice(list.first)
              : InvoicesController.openList(),
          child: Stack(
            children: [
              Positioned(
                right: -26,
                top: -26,
                child: Container(
                  width: 110,
                  height: 110,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: _I.orange.withValues(alpha: .22),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: _I.orange.withValues(alpha: .18),
                        borderRadius: BorderRadius.circular(13),
                      ),
                      child: const Icon(
                        Icons.receipt_long_rounded,
                        color: _I.orange,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            n == 1 ? '1 unpaid invoice' : '$n unpaid invoices',
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w800,
                              fontSize: 15,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'Deposit due now ${_fmtMoney(due)}',
                            style: TextStyle(
                              color: Colors.white.withValues(alpha: .75),
                              fontSize: 12.5,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 10,
                      ),
                      decoration: BoxDecoration(
                        color: _I.orange,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Text(
                        'Pay',
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w800,
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
    });
  }
}

// import 'package:flutter/material.dart';
// import 'package:get/get.dart';
// import '../controllers/app_controller.dart';
// import '../core/theme.dart';
// import '../core/widgets.dart';
// import '../data/models.dart';
// import 'pay_view.dart';

// class InvoicesView extends StatelessWidget {
//   const InvoicesView({super.key});
//   @override
//   Widget build(BuildContext context) {
//     final c = Get.find<AppController>();
//     return Scaffold(
//       appBar: AppBar(title: const Text('Invoices & payments')),
//       body: Body(Obx(() => ListView(padding: const EdgeInsets.all(20), children: [
//             for (final i in c.invoices)
//               Box(onTap: () => Get.to(() => InvoiceDetailView(inv: i)), child: Row(children: [
//                 Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
//                   Text(i.title, style: const TextStyle(fontWeight: FontWeight.w700)), sub('${i.id} · ${i.date}')])),
//                 Column(crossAxisAlignment: CrossAxisAlignment.end, children: [Text(money(i.total), style: const TextStyle(fontWeight: FontWeight.w800)), gap(4), Tag(i.status)]),
//               ])),
//           ]))),
//     );
//   }
// }

// class InvoiceDetailView extends StatelessWidget {
//   final Invoice inv;
//   const InvoiceDetailView({super.key, required this.inv});
//   @override
//   Widget build(BuildContext context) => Scaffold(
//         appBar: AppBar(title: Text('Invoice ${inv.id}')),
//         body: Body(Obx(() => ListView(padding: const EdgeInsets.all(20), children: [
//               const Row(children: [Icon(Icons.handyman, color: C.orange), SizedBox(width: 8), Text('Twins Handyman LLC', style: TextStyle(fontWeight: FontWeight.w800))]), gap(),
//               Box(child: Column(children: [
//                 KV('Project', inv.title), KV('Date', inv.date), KV('Total', money(inv.total)),
//                 KV('Deposit / paid', money(inv.paid.value)), KV('Remaining balance', money(inv.remaining), bold: true),
//                 KV('Status', inv.status), if (inv.method.value.isNotEmpty) KV('Method', inv.method.value),
//               ])),
//               OutlinedButton.icon(onPressed: () => toast('Invoice PDF downloaded (demo)'), icon: const Icon(Icons.download), label: const Text('Download invoice')),
//               gap(),
//               if (inv.remaining > 0)
//                 cta('PAY NOW — ${money(inv.remaining)}', () => Get.to(() => PayView(
//                     title: 'Invoice ${inv.id}', amount: inv.remaining, summary: inv.title,
//                     onPaid: (m) { Get.find<AppController>().payInvoice(inv, m); return inv.id; }))),
//             ]))),
//       );
// }
