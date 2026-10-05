import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'theme.dart';

String money(num v) => '\$${v.toStringAsFixed(2)}';
void toast(String m) => Get.snackbar('Twins Handyman', m,
    snackPosition: SnackPosition.BOTTOM, margin: const EdgeInsets.all(12), backgroundColor: C.ink, colorText: Colors.white);
Widget h(String s, {double size = 18}) => Text(s, style: TextStyle(fontWeight: FontWeight.w800, fontSize: size, color: C.ink));
Widget sub(String s) => Text(s, style: const TextStyle(color: C.soft, fontSize: 13));
Widget cta(String l, VoidCallback f) => ElevatedButton(onPressed: f, child: Text(l));
Widget gap([double v = 12]) => SizedBox(height: v);

/// Centers content and caps width so layouts stay readable on tablets/desktop.
class Body extends StatelessWidget {
  final Widget child;
  const Body(this.child, {super.key});
  @override
  Widget build(BuildContext context) =>
      Center(child: ConstrainedBox(constraints: const BoxConstraints(maxWidth: 760), child: child));
}

class Box extends StatelessWidget {
  final Widget child;
  final VoidCallback? onTap;
  final Color color;
  const Box({super.key, required this.child, this.onTap, this.color = Colors.white});
  @override
  Widget build(BuildContext context) => Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Material(
          color: color, borderRadius: BorderRadius.circular(16),
          child: InkWell(borderRadius: BorderRadius.circular(16), onTap: onTap,
              child: Padding(padding: const EdgeInsets.all(16), child: child))));
}

class Tag extends StatelessWidget {
  final String s;
  const Tag(this.s, {super.key});
  @override
  Widget build(BuildContext context) {
    final col = const ['Accepted', 'Paid', 'Job Closed', 'Work Completed', 'Final Payment Received'].contains(s)
        ? C.green
        : s == 'Rejected'
            ? C.red
            : const ['Pending', 'Due', 'Quote Submitted', 'Final Payment Due', 'Changes requested'].contains(s)
                ? C.amber
                : C.blue;
    return Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(color: col.withValues(alpha: .12), borderRadius: BorderRadius.circular(8)),
        child: Text(s, style: TextStyle(color: col, fontWeight: FontWeight.w700, fontSize: 12)));
  }
}

class KV extends StatelessWidget {
  final String a, b;
  final bool bold;
  const KV(this.a, this.b, {super.key, this.bold = false});
  @override
  Widget build(BuildContext context) {
    final st = TextStyle(fontSize: 13.5, fontWeight: bold ? FontWeight.w800 : FontWeight.w500);
    return Padding(
        padding: const EdgeInsets.symmetric(vertical: 5),
        child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          Text(a, style: st), Flexible(child: Text(b, style: st, textAlign: TextAlign.right))]));
  }
}
