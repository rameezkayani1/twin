import 'package:flutter/material.dart';
import 'package:get/get.dart';

const stages = [
  'Quote Submitted',
  'Quote Sent',
  'Quote Approved',
  'Deposit Paid',
  'Scheduled',
  'Crew Assigned',
  'Work Started',
  'Work In Progress',
  'Work Completed',
  'Final Payment Due',
  'Final Payment Received',
  'Job Closed',
];

const kServices = [
  ('Painting', Icons.format_paint_outlined),
  ('Moving', Icons.local_shipping_outlined),
  ('Cleaning', Icons.cleaning_services_outlined),
  ('Assembly', Icons.build_outlined),
  ('Lawn Services', Icons.grass_outlined),
  ('Waste Disposal', Icons.delete_outline),
  ('Pressure Washing', Icons.water_drop_outlined),
  ('General Handyman', Icons.handyman_outlined),
];
const kAddresses = [
  '25 Hillside Ave, Hillside, NJ',
  '140 Bay St, Staten Island, NY',
  '9 Elm Court, Newark, NJ',
];

class Quote {
  final String id, service, issued, expires, address, notes;
  final double labor, materials, fees, discount, taxRate, depositPct;
  final status = ''.obs;
  Quote({
    required this.id,
    required this.service,
    required this.issued,
    required this.expires,
    required this.address,
    required this.notes,
    required this.labor,
    required this.materials,
    required this.fees,
    required this.discount,
    required this.taxRate,
    required this.depositPct,
    required String st,
  }) {
    status.value = st;
  }
  double get subtotal => labor + materials + fees - discount;
  double get tax => subtotal * taxRate;
  double get total => subtotal + tax;
  double get deposit => total * depositPct / 100;
  double get remaining => total - deposit;
}

class Job {
  final String id, service, address, date, time, crew, duration, quoteId;
  final stage = 0.obs;
  Job(
    this.id,
    this.service,
    this.address,
    this.date,
    this.time,
    this.crew,
    this.duration,
    this.quoteId,
    int st,
  ) {
    stage.value = st;
  }
}

class Invoice {
  final String id, title, date, quoteId;
  final double total;
  final paid = 0.0.obs;
  final method = ''.obs;
  Invoice(
    this.id,
    this.title,
    this.total,
    this.date,
    this.quoteId, {
    double paidAmt = 0,
  }) {
    paid.value = paidAmt;
  }
  double get remaining => total - paid.value;
  String get status =>
      remaining <= 0 ? 'Paid' : (paid.value > 0 ? 'Deposit paid' : 'Due');
}

class Notif {
  final String title, body, time;
  final IconData icon;
  const Notif(this.title, this.body, this.time, this.icon);
}
