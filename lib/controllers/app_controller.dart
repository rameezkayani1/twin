import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../data/models.dart';

class AppController extends GetxController {
  final tab = 0.obs;
  final quotes = <Quote>[
    Quote(id: 'Q-1042', service: 'Pressure Washing', issued: 'Sep 28, 2026', expires: 'Oct 12, 2026', address: kAddresses[0],
        notes: 'Deposit required to schedule.', labor: 350, materials: 40, fees: 25, discount: 15, taxRate: .06625, depositPct: 50, st: 'Sent'),
    Quote(id: 'Q-1039', service: 'Painting', issued: 'Sep 20, 2026', expires: 'Oct 4, 2026', address: kAddresses[1],
        notes: 'Client-supplied color. 2 coats.', labor: 1100, materials: 350, fees: 50, discount: 0, taxRate: .06625, depositPct: 75, st: 'Accepted'),
  ].obs;
  final jobs = <Job>[
    Job('J-2201', 'Painting', kAddresses[1], 'Oct 2, 2026', '9:00 AM', 'Crew A', '2 days', 'Q-1039', 3),
    Job('J-2188', 'Lawn Services', kAddresses[0], 'Sep 10, 2026', '2:00 PM', 'Crew B', '2 hrs', 'Q-1020', 11),
  ].obs;
  final invoices = <Invoice>[
    Invoice('TH-2026-0048', 'Painting — Living room & hallway', 1650, 'Sep 24, 2026', 'Q-1039', paidAmt: 1237.5),
    Invoice('TH-2026-0041', 'Lawn Services — Biweekly mow', 250, 'Sep 10, 2026', 'Q-1020', paidAmt: 250),
  ].obs;
  final notifs = <Notif>[
    const Notif('Quote received', 'Q-1042 Pressure Washing is ready to review.', '2h ago', Icons.receipt_long_outlined),
    const Notif('Deposit confirmed', 'Payment of \$1,237.50 received.', 'Sep 24', Icons.payments_outlined),
    const Notif('Appointment reminder', 'Painting starts Oct 2 at 9:00 AM.', 'Sep 29', Icons.event_outlined),
  ].obs;
  final reviews = <Map<String, dynamic>>[
    {'stars': 5, 'text': 'Lawn looked great, on time.', 'job': 'J-2188'},
  ].obs;

  void submitRequest(String service, String addr, String date) {
    final n = 2300 + jobs.length;
    jobs.insert(0, Job('J-$n', service, addr, date, '10:00 AM', 'Unassigned', 'TBD', 'Q-new', 0));
    notifs.insert(0, Notif('Request received', '$service request submitted.', 'Now', Icons.check_circle_outline));
  }

  void acceptQuote(Quote q) {
    q.status.value = 'Accepted';
    jobs.firstWhereOrNull((j) => j.quoteId == q.id)?.stage.value = 2;
  }

  bool hasInvoice(Quote q) => invoices.any((i) => i.quoteId == q.id);

  Invoice payDeposit(Quote q, String method) {
    final inv = Invoice('TH-2026-${49 + invoices.length}', '${q.service} — ${q.id}', q.total, 'Today', q.id, paidAmt: q.deposit);
    inv.method.value = method;
    invoices.insert(0, inv);
    jobs.firstWhereOrNull((j) => j.quoteId == q.id)?.stage.value = 3;
    notifs.insert(0, Notif('Deposit confirmed', '\$${q.deposit.toStringAsFixed(2)} received.', 'Now', Icons.payments_outlined));
    return inv;
  }

  void payInvoice(Invoice i, String method) {
    i.paid.value = i.total;
    i.method.value = method;
    jobs.firstWhereOrNull((j) => j.quoteId == i.quoteId)?.stage.value = 10;
  }
}
