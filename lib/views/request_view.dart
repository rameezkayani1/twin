// =============================================================
// request_view.dart  —  Request a Quote (single file)
//
// pubspec.yaml dependencies needed:
//   get, firebase_core, firebase_auth, cloud_firestore,
//   firebase_storage, file_picker
//
// Firestore collection : quote_requests/{requestId}
// Storage path         : quote_requests/{uid}/{requestId}/{file}
//
// QUOTE / PAYMENT FIELDS (written by ADMIN only, never by the form):
//   quoteTotal    number?  full price quoted by admin
//   quoteAmount   number?  legacy alias of quoteTotal (kept in sync)
//   depositNow    number?  advance the customer pays now
//   depositLater  number?  balance paid after the job (total - depositNow)
//   advancePaid   bool     true once the advance is received
//   advancePaidAt Timestamp?
//   paymentNote   string   optional note from admin
//   quotedAt      Timestamp?
// =============================================================
import 'dart:typed_data';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:file_picker/file_picker.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

// ---------------------------------------------------------
// THEME
// ---------------------------------------------------------
class _T {
  static const orange = Color(0xFFFF7A00);
  static const orangeDark = Color(0xFFE55F00);
  static const ink = Color(0xFF1F2430);
  static const bg = Color(0xFFF6F7FB);
  static const muted = Color(0xFF7A8194);
  static const green = Color(0xFF22B573);
}

// ---------------------------------------------------------
// STATUS VALUES (admin updates the `status` field)
// ---------------------------------------------------------
class QuoteStatus {
  static const pending = 'pending';
  static const reviewing = 'reviewing';
  static const quoted = 'quoted';
  static const accepted = 'accepted';
  static const scheduled = 'scheduled';
  static const completed = 'completed';
  static const rejected = 'rejected';
  static const cancelled = 'cancelled';
  static const all = [
    pending,
    reviewing,
    quoted,
    accepted,
    scheduled,
    completed,
    rejected,
    cancelled,
  ];

  /// Statuses where the customer has approved the quote.
  static const approvedStates = [accepted, scheduled, completed];

  /// One entry for the `statusHistory` array.
  static Map<String, dynamic> historyEntry(String status, String by) => {
    'status': status,
    'at': Timestamp.now(),
    'by': by,
  };
}

// ---------------------------------------------------------
// QUOTE PRICING (total / deposit now / deposit later)
// Values are entered by the admin and only READ here.
// ---------------------------------------------------------
class QuotePricing {
  final double total;
  final double depositNow; // advance
  final double depositLater; // balance
  final bool advancePaid;
  final String note;

  const QuotePricing({
    this.total = 0,
    this.depositNow = 0,
    this.depositLater = 0,
    this.advancePaid = false,
    this.note = '',
  });

  static double _num(dynamic v) =>
      v is num ? v.toDouble() : (double.tryParse('${v ?? ''}') ?? 0);

  factory QuotePricing.fromMap(Map<String, dynamic> d) {
    // quoteAmount is the legacy field name — still supported.
    final total = _num(d['quoteTotal'] ?? d['quoteAmount']);
    final now = _num(d['depositNow']);
    final rest = total - now;
    final later = d['depositLater'] != null
        ? _num(d['depositLater'])
        : (rest < 0 ? 0.0 : rest);
    return QuotePricing(
      total: total,
      depositNow: now,
      depositLater: later,
      advancePaid: d['advancePaid'] == true,
      note: (d['paymentNote'] ?? '').toString(),
    );
  }

  bool get hasQuote => total > 0;
  double get depositPercent => total > 0 ? (depositNow / total) * 100 : 0;

  static String money(double v) => '\$${v.toStringAsFixed(2)}';

  /// Used by the ADMIN side when sending a quote. Validates the numbers and
  /// returns the map to merge into quote_requests/{id}.
  /// Remember to also set `status: quoted` + a statusHistory entry.
  static Map<String, dynamic> adminPayload({
    required double total,
    required double depositNow,
    String? note,
  }) {
    if (total <= 0) {
      throw ArgumentError('Total must be greater than 0');
    }
    if (depositNow < 0 || depositNow > total) {
      throw ArgumentError('Deposit now must be between 0 and the total');
    }
    final later = double.parse((total - depositNow).toStringAsFixed(2));
    return {
      'quoteTotal': total,
      'quoteAmount': total, // legacy alias
      'depositNow': depositNow,
      'depositLater': later,
      'advancePaid': false,
      'paymentNote': (note ?? '').trim(),
      'quotedAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    };
  }
}

// ---------------------------------------------------------
// MODELS
// ---------------------------------------------------------
class ServiceItem {
  final String name;
  final IconData icon;
  final Color color;
  const ServiceItem(this.name, this.icon, this.color);
}

const kServiceItems = <ServiceItem>[
  ServiceItem('Painting', Icons.format_paint_outlined, Color(0xFFEB5757)),
  ServiceItem('Moving', Icons.local_shipping_outlined, Color(0xFF4F5D75)),
  ServiceItem('Cleaning', Icons.cleaning_services_outlined, Color(0xFF27AE60)),
  ServiceItem('Assembly', Icons.build_outlined, Color(0xFF9B51E0)),
  ServiceItem('Lawn Services', Icons.grass_outlined, Color(0xFF6FCF97)),
  ServiceItem('Waste Disposal', Icons.delete_outline, Color(0xFF828282)),
  ServiceItem('Pressure Washing', Icons.water_drop_outlined, Color(0xFF56CCF2)),
  ServiceItem('General Handyman', Icons.handyman_outlined, Color(0xFF2D9CDB)),
];

class PickedFile {
  final String name;
  final Uint8List bytes;
  final String kind; // image | video | document
  PickedFile(this.name, this.bytes, this.kind);
  double get mb => bytes.lengthInBytes / (1024 * 1024);

  /// Content type used for the Firebase Storage upload metadata.
  String get contentType {
    final ext = name.contains('.') ? name.split('.').last.toLowerCase() : '';
    switch (ext) {
      case 'jpg':
      case 'jpeg':
        return 'image/jpeg';
      case 'png':
        return 'image/png';
      case 'gif':
        return 'image/gif';
      case 'webp':
        return 'image/webp';
      case 'heic':
        return 'image/heic';
      case 'mp4':
        return 'video/mp4';
      case 'mov':
        return 'video/quicktime';
      case 'avi':
        return 'video/x-msvideo';
      case 'mkv':
        return 'video/x-matroska';
      case 'pdf':
        return 'application/pdf';
      case 'doc':
        return 'application/msword';
      case 'docx':
        return 'application/vnd.openxmlformats-officedocument.wordprocessingml.document';
      case 'txt':
        return 'text/plain';
      default:
        return 'application/octet-stream';
    }
  }
}

// ---------------------------------------------------------
// CONTROLLER (state + Firebase logic)
// ---------------------------------------------------------
class RequestController extends GetxController {
  final _auth = FirebaseAuth.instance;
  final _db = FirebaseFirestore.instance;

  final service = Rxn<ServiceItem>();
  final urgency = 'Flexible'.obs;
  final date = Rxn<DateTime>();
  final slot = 'Morning'.obs;
  final files = <PickedFile>[].obs;
  final loading = false.obs;
  final status = ''.obs;

  static const maxFileMb = 20.0;
  static const maxFiles = 8;
  static const urgencies = ['Flexible', 'Soon', 'Urgent'];
  static const slots = {
    'Morning': '8 AM – 12 PM',
    'Afternoon': '12 – 4 PM',
    'Evening': '4 – 8 PM',
  };

  void toast(String msg, {bool error = true}) => Get.snackbar(
    error ? 'Oops' : 'Done',
    msg,
    snackPosition: SnackPosition.BOTTOM,
    margin: const EdgeInsets.all(16),
    borderRadius: 14,
    backgroundColor: error ? const Color(0xFFEB5757) : _T.green,
    colorText: Colors.white,
  );

  // ---------------------------------------------------------
  // FILE PICKER (fixed)
  // ---------------------------------------------------------
  Future<void> pick(String kind) async {
    if (files.length >= maxFiles) {
      toast('You can attach up to $maxFiles files');
      return;
    }

    try {
      final FileType type;
      List<String>? exts;
      switch (kind) {
        case 'image':
          type = FileType.image;
          break;
        case 'video':
          type = FileType.video;
          break;
        default:
          type = FileType.custom;
          exts = ['pdf', 'doc', 'docx', 'txt'];
      }

      // file_picker 12+/13+: pickFiles() returns List<PlatformFile>
      // (empty list when cancelled) and allows multiple files by default.
      final picked = await FilePicker.pickFiles(
        type: type,
        allowedExtensions: exts, // only valid (and required) for custom
      );

      // user cancelled
      if (picked.isEmpty) return;

      var skippedBig = 0;
      var skippedNoData = 0;
      var hitLimit = false;

      for (final f in picked) {
        if (files.length >= maxFiles) {
          hitLimit = true;
          break;
        }

        // skip huge files before loading them into memory
        final size = f.lengthSync();
        if (size != null && size > maxFileMb * 1024 * 1024) {
          skippedBig++;
          continue;
        }

        // read bytes on demand (replaces the removed `withData: true`)
        Uint8List? bytes;
        try {
          bytes = await f.readAsBytes();
        } catch (_) {
          bytes = null;
        }
        if (bytes == null || bytes.isEmpty) {
          skippedNoData++;
          continue;
        }
        final p = PickedFile(f.name, bytes, kind);
        if (p.mb > maxFileMb) {
          skippedBig++;
          continue;
        }
        files.add(p);
      }

      if (skippedBig > 0) {
        toast(
          '$skippedBig file(s) skipped — larger than ${maxFileMb.toInt()} MB',
        );
      } else if (skippedNoData > 0) {
        toast('$skippedNoData file(s) could not be read');
      } else if (hitLimit) {
        toast('You can attach up to $maxFiles files');
      }
    } catch (e) {
      debugPrint('FilePicker error: $e');
      toast('Could not open file picker');
    }
  }

  /// Creates quote_requests/{id}. Returns the request number or null.
  Future<String?> submit({
    required String name,
    required String phone,
    required String email,
    required String address,
    required String description,
    required String budget,
  }) async {
    if (loading.value) return null; // block double taps
    final user = _auth.currentUser;
    if (user == null) {
      toast('Please log in first');
      return null;
    }
    try {
      loading.value = true;
      final ref = _db.collection('quote_requests').doc();
      // Derived from the unique doc id so two customers never share a number.
      final number = 'QR-${ref.id.substring(0, 6).toUpperCase()}';

      // 1) upload attachments
      final uploaded = <Map<String, dynamic>>[];
      for (var i = 0; i < files.length; i++) {
        status.value = 'Uploading file ${i + 1} of ${files.length}…';
        final f = files[i];
        final sref = FirebaseStorage.instance.ref(
          'quote_requests/${user.uid}/${ref.id}/${i}_${f.name}',
        );
        await sref.putData(
          f.bytes,
          SettableMetadata(contentType: f.contentType),
        );
        uploaded.add({
          'name': f.name,
          'type': f.kind,
          'url': await sref.getDownloadURL(),
        });
      }

      // 2) save request
      status.value = 'Sending your request…';
      await ref.set({
        'id': ref.id,
        'requestNumber': number,
        'userId': user.uid,
        'service': service.value!.name,
        'description': description.trim(),
        // customer's own estimate (the only money value the customer enters)
        'budget': double.tryParse(budget.trim()) ?? 0,
        'customerName': name.trim(),
        'phone': phone.trim(),
        'email': email.trim().toLowerCase(),
        'address': address.trim(),
        'urgency': urgency.value,
        'preferredDate': Timestamp.fromDate(date.value!),
        'preferredSlot': '${slot.value} (${slots[slot.value]})',
        'attachments': uploaded,
        // ----- admin-managed: status & assignment -----
        'status': QuoteStatus.pending,
        'adminNote': '',
        'assignedTo': null,
        // ----- admin-managed: quote & payment (backend only) -----
        'quoteTotal': null,
        'quoteAmount': null, // legacy alias of quoteTotal
        'depositNow': null, // advance
        'depositLater': null, // balance
        'advancePaid': false,
        'advancePaidAt': null,
        'paymentNote': '',
        'quotedAt': null,
        'acceptedAt': null,
        'statusHistory': [
          QuoteStatus.historyEntry(QuoteStatus.pending, 'customer'),
        ],
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });
      return number;
    } on FirebaseException catch (e) {
      toast(e.message ?? 'Could not submit request');
    } catch (_) {
      toast('Something went wrong. Please try again.');
    } finally {
      loading.value = false;
      status.value = '';
    }
    return null;
  }

  /// Customer approves a quote. Only allowed while status == quoted
  /// (enforce the same rule in Firestore security rules).
  Future<bool> acceptQuote(String requestId) async {
    final user = _auth.currentUser;
    if (user == null) {
      toast('Please log in first');
      return false;
    }
    try {
      loading.value = true;
      status.value = 'Approving quote…';
      await _db.collection('quote_requests').doc(requestId).update({
        'status': QuoteStatus.accepted,
        'acceptedAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
        'statusHistory': FieldValue.arrayUnion([
          QuoteStatus.historyEntry(QuoteStatus.accepted, 'customer'),
        ]),
      });
      toast('Quote approved', error: false);
      return true;
    } on FirebaseException catch (e) {
      toast(e.message ?? 'Could not approve quote');
    } catch (_) {
      toast('Something went wrong. Please try again.');
    } finally {
      loading.value = false;
      status.value = '';
    }
    return false;
  }

  void reset() {
    service.value = null;
    urgency.value = 'Flexible';
    date.value = null;
    slot.value = 'Morning';
    files.clear();
  }
}

// ---------------------------------------------------------
// REQUEST PAGE
// ---------------------------------------------------------
class RequestView extends StatefulWidget {
  /// Optional: called when user taps "Track this request" on success page.
  final VoidCallback? onTrack;
  const RequestView({super.key, this.onTrack});

  @override
  State<RequestView> createState() => _RequestViewState();
}

class _RequestViewState extends State<RequestView> {
  final c = Get.put(RequestController());
  final _form = GlobalKey<FormState>();
  final _desc = TextEditingController();
  final _budget = TextEditingController();
  final _name = TextEditingController();
  final _phone = TextEditingController();
  final _email = TextEditingController();
  final _address = TextEditingController();

  @override
  void initState() {
    super.initState();
    _prefill();
  }

  Future<void> _prefill() async {
    final u = FirebaseAuth.instance.currentUser;
    if (u == null) return;
    _name.text = u.displayName ?? '';
    _email.text = u.email ?? '';
    try {
      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(u.uid)
          .get();
      final d = doc.data();
      if (d != null && mounted) {
        if (_name.text.isEmpty) _name.text = d['name'] ?? '';
        _phone.text = d['phone'] ?? '';
      }
    } catch (_) {}
  }

  @override
  void dispose() {
    for (final t in [_desc, _budget, _name, _phone, _email, _address]) {
      t.dispose();
    }
    Get.delete<RequestController>();
    super.dispose();
  }

  String? _req(String? v) =>
      (v == null || v.trim().isEmpty) ? 'This field is required' : null;

  InputDecoration _dec(
    String label,
    IconData icon, {
    String? hint,
    String? prefixText,
  }) => InputDecoration(
    labelText: label,
    hintText: hint,
    prefixText: prefixText,
    prefixIcon: Icon(icon, color: _T.orange, size: 22),
    filled: true,
    fillColor: const Color(0xFFF8F9FC),
    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
    border: _border(Colors.transparent),
    enabledBorder: _border(const Color(0xFFE6E9F2)),
    focusedBorder: _border(_T.orange, w: 1.6),
    errorBorder: _border(const Color(0xFFEB5757)),
    focusedErrorBorder: _border(const Color(0xFFEB5757), w: 1.6),
  );

  OutlineInputBorder _border(Color col, {double w = 1}) => OutlineInputBorder(
    borderRadius: BorderRadius.circular(14),
    borderSide: BorderSide(color: col, width: w),
  );

  // ---------- service bottom sheet ----------
  Future<void> _pickService() async {
    FocusScope.of(context).unfocus();
    final picked = await showModalBottomSheet<ServiceItem>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _ServiceSheet(selected: c.service.value),
    );
    if (picked != null) c.service.value = picked;
  }

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final d = await showDatePicker(
      context: context,
      initialDate: c.date.value ?? now.add(const Duration(days: 2)),
      firstDate: now,
      lastDate: now.add(const Duration(days: 365)),
      builder: (ctx, child) => Theme(
        data: Theme.of(
          ctx,
        ).copyWith(colorScheme: const ColorScheme.light(primary: _T.orange)),
        child: child!,
      ),
    );
    if (d != null) c.date.value = d;
  }

  Future<void> _submit() async {
    if (c.loading.value) return;
    if (c.service.value == null) {
      c.toast('Please choose a service');
      return;
    }
    if (!_form.currentState!.validate()) return;
    if (c.date.value == null) {
      c.toast('Please pick a preferred date');
      return;
    }
    final number = await c.submit(
      name: _name.text,
      phone: _phone.text,
      email: _email.text,
      address: _address.text,
      description: _desc.text,
      budget: _budget.text,
    );
    if (number == null) return;
    final svc = c.service.value!;
    c.reset();
    _desc.clear();
    _budget.clear();
    _address.clear();
    Get.to(
      () => _SuccessPage(number: number, service: svc, onTrack: widget.onTrack),
    );
  }

  // ---------- build ----------
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _T.bg,
      body: Stack(
        children: [
          LayoutBuilder(
            builder: (context, box) {
              final wide = box.maxWidth > 640;
              return CustomScrollView(
                slivers: [
                  SliverToBoxAdapter(child: _header(wide)),
                  SliverToBoxAdapter(
                    child: Center(
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 760),
                        child: Padding(
                          padding: EdgeInsets.fromLTRB(
                            wide ? 24 : 16,
                            0,
                            wide ? 24 : 16,
                            40,
                          ),
                          child: Form(
                            key: _form,
                            child: Column(
                              children: [
                                _serviceCard(),
                                _detailsCard(),
                                _contactCard(wide),
                                _whenWhereCard(wide),
                                _attachCard(),
                                const SizedBox(height: 22),
                                _submitButton(),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              );
            },
          ),
          Obx(() => c.loading.value ? _loadingOverlay() : const SizedBox()),
        ],
      ),
    );
  }

  Widget _header(bool wide) => Container(
    padding: EdgeInsets.fromLTRB(
      24,
      MediaQuery.of(context).padding.top + 22,
      24,
      56,
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
        constraints: const BoxConstraints(maxWidth: 760),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Request a quote',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 26,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Tell us about the job — we will get back with a price.',
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: .9),
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: .2),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.request_quote_rounded,
                color: Colors.white,
                size: 34,
              ),
            ),
          ],
        ),
      ),
    ),
  );

  // ---------- section card ----------
  Widget _card(String title, IconData icon, int step, Widget child) =>
      Container(
        margin: const EdgeInsets.only(top: 16),
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(22),
          boxShadow: [
            BoxShadow(
              color: _T.ink.withValues(alpha: .06),
              blurRadius: 24,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 34,
                  height: 34,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: _T.orange.withValues(alpha: .12),
                    borderRadius: BorderRadius.circular(11),
                  ),
                  child: Icon(icon, color: _T.orange, size: 19),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    title,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                      color: _T.ink,
                    ),
                  ),
                ),
                Text(
                  '$step/5',
                  style: const TextStyle(
                    color: _T.muted,
                    fontWeight: FontWeight.w600,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            child,
          ],
        ),
      );

  // ---------- 1. service ----------
  Widget _serviceCard() => Transform.translate(
    offset: const Offset(0, -34),
    child: _card(
      'What do you need?',
      Icons.handyman_rounded,
      1,
      Obx(() {
        final s = c.service.value;
        return InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: _pickService,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 250),
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: (s?.color ?? _T.orange).withValues(alpha: .08),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: (s?.color ?? _T.orange).withValues(alpha: .5),
                width: 1.4,
              ),
            ),
            child: Row(
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: s?.color ?? _T.orange,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Icon(
                    s?.icon ?? Icons.add_rounded,
                    color: Colors.white,
                    size: 26,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        s?.name ?? 'Choose a service',
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                          color: _T.ink,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        s == null ? 'Tap to see all services' : 'Tap to change',
                        style: const TextStyle(color: _T.muted, fontSize: 12.5),
                      ),
                    ],
                  ),
                ),
                const Icon(
                  Icons.keyboard_arrow_down_rounded,
                  color: _T.ink,
                  size: 28,
                ),
              ],
            ),
          ),
        );
      }),
    ),
  );

  // ---------- 2. details ----------
  Widget _detailsCard() => Transform.translate(
    offset: const Offset(0, -34),
    child: _card(
      'Job details',
      Icons.edit_note_rounded,
      2,
      Column(
        children: [
          TextFormField(
            controller: _desc,
            maxLines: 4,
            maxLength: 500,
            textCapitalization: TextCapitalization.sentences,
            validator: (v) => (v == null || v.trim().length < 10)
                ? 'Please describe the work (min 10 characters)'
                : null,
            decoration: _dec(
              'Description of work',
              Icons.notes_rounded,
              hint: 'e.g. Kitchen sink is leaking underneath…',
            ),
          ),
          const SizedBox(height: 6),
          TextFormField(
            controller: _budget,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            validator: (v) {
              if (_req(v) != null) return 'This field is required';
              final n = double.tryParse(v!.trim());
              if (n == null) return 'Enter a number';
              if (n <= 0) return 'Budget must be greater than 0';
              return null;
            },
            decoration: _dec(
              'Estimated budget',
              Icons.payments_outlined,
              prefixText: '\$ ',
            ),
          ),
          const SizedBox(height: 16),
          Align(
            alignment: Alignment.centerLeft,
            child: Text(
              'How soon?',
              style: TextStyle(
                fontWeight: FontWeight.w700,
                color: _T.ink.withValues(alpha: .8),
              ),
            ),
          ),
          const SizedBox(height: 8),
          Obx(
            () => Row(
              children: [
                for (final u in RequestController.urgencies)
                  Expanded(
                    child: Padding(
                      padding: EdgeInsets.only(
                        right: u == RequestController.urgencies.last ? 0 : 8,
                      ),
                      child: _pill(
                        u,
                        u == 'Urgent'
                            ? Icons.bolt_rounded
                            : u == 'Soon'
                            ? Icons.timelapse_rounded
                            : Icons.event_available_rounded,
                        c.urgency.value == u,
                        () => c.urgency.value = u,
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

  Widget _pill(
    String label,
    IconData icon,
    bool on,
    VoidCallback tap, {
    String? sub,
  }) => InkWell(
    borderRadius: BorderRadius.circular(14),
    onTap: tap,
    child: AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 6),
      decoration: BoxDecoration(
        color: on ? _T.orange : const Color(0xFFF8F9FC),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: on ? _T.orange : const Color(0xFFE6E9F2)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 20, color: on ? Colors.white : _T.muted),
          const SizedBox(height: 4),
          Text(
            label,
            style: TextStyle(
              fontWeight: FontWeight.w700,
              fontSize: 13,
              color: on ? Colors.white : _T.ink,
            ),
          ),
          if (sub != null)
            Text(
              sub,
              style: TextStyle(
                fontSize: 10.5,
                color: on ? Colors.white70 : _T.muted,
              ),
            ),
        ],
      ),
    ),
  );

  // ---------- 3. contact ----------
  Widget _contactCard(bool wide) {
    final phone = TextFormField(
      controller: _phone,
      keyboardType: TextInputType.phone,
      validator: _req,
      decoration: _dec('Phone', Icons.call_outlined),
    );
    final email = TextFormField(
      controller: _email,
      keyboardType: TextInputType.emailAddress,
      validator: (v) =>
          GetUtils.isEmail((v ?? '').trim()) ? null : 'Enter a valid email',
      decoration: _dec('Email', Icons.mail_outline_rounded),
    );
    return Transform.translate(
      offset: const Offset(0, -34),
      child: _card(
        'Your contact info',
        Icons.person_rounded,
        3,
        Column(
          children: [
            TextFormField(
              controller: _name,
              textCapitalization: TextCapitalization.words,
              validator: _req,
              decoration: _dec('Full name', Icons.person_outline_rounded),
            ),
            const SizedBox(height: 14),
            wide
                ? Row(
                    children: [
                      Expanded(child: phone),
                      const SizedBox(width: 12),
                      Expanded(child: email),
                    ],
                  )
                : Column(children: [phone, const SizedBox(height: 14), email]),
          ],
        ),
      ),
    );
  }

  // ---------- 4. when & where ----------
  Widget _whenWhereCard(bool wide) => Transform.translate(
    offset: const Offset(0, -34),
    child: _card(
      'When & where',
      Icons.place_rounded,
      4,
      Column(
        children: [
          TextFormField(
            controller: _address,
            maxLines: 2,
            minLines: 1,
            validator: _req,
            textCapitalization: TextCapitalization.words,
            decoration: _dec(
              'Property address',
              Icons.home_outlined,
              hint: 'Street, city, ZIP',
            ),
          ),
          const SizedBox(height: 14),
          Obx(() {
            final d = c.date.value;
            return InkWell(
              borderRadius: BorderRadius.circular(14),
              onTap: _pickDate,
              child: InputDecorator(
                decoration: _dec('Preferred date', Icons.calendar_month_rounded)
                    .copyWith(
                      suffixIcon: const Icon(Icons.arrow_drop_down_rounded),
                    ),
                child: Text(
                  d == null
                      ? 'Select a date'
                      : '${_months[d.month - 1]} ${d.day}, ${d.year}',
                  style: TextStyle(
                    color: d == null ? _T.muted : _T.ink,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            );
          }),
          const SizedBox(height: 14),
          Obx(
            () => Row(
              children: [
                for (final e in RequestController.slots.entries)
                  Expanded(
                    child: Padding(
                      padding: EdgeInsets.only(
                        right: e.key == 'Evening' ? 0 : 8,
                      ),
                      child: _pill(
                        e.key,
                        e.key == 'Morning'
                            ? Icons.wb_sunny_outlined
                            : e.key == 'Afternoon'
                            ? Icons.wb_twilight_rounded
                            : Icons.nights_stay_outlined,
                        c.slot.value == e.key,
                        () => c.slot.value = e.key,
                        sub: e.value,
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

  // ---------- 5. attachments ----------
  Widget _attachCard() => Transform.translate(
    offset: const Offset(0, -34),
    child: _card(
      'Photos, videos & documents',
      Icons.attach_file_rounded,
      5,
      Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              _attachBtn(Icons.photo_camera_back_outlined, 'Photo', 'image'),
              const SizedBox(width: 10),
              _attachBtn(Icons.videocam_outlined, 'Video', 'video'),
              const SizedBox(width: 10),
              _attachBtn(Icons.description_outlined, 'Document', 'document'),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            'Optional • up to 8 files • max 20 MB each',
            style: TextStyle(color: _T.muted, fontSize: 12),
          ),
          Obx(
            () => c.files.isEmpty
                ? const SizedBox()
                : Padding(
                    padding: const EdgeInsets.only(top: 12),
                    child: Column(
                      children: [
                        for (var i = 0; i < c.files.length; i++)
                          _fileTile(c.files[i], i),
                      ],
                    ),
                  ),
          ),
        ],
      ),
    ),
  );

  Widget _attachBtn(IconData icon, String label, String kind) => Expanded(
    child: InkWell(
      borderRadius: BorderRadius.circular(14),
      onTap: () {
        FocusScope.of(context).unfocus();
        c.pick(kind);
      },
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(
          color: _T.orange.withValues(alpha: .06),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: _T.orange.withValues(alpha: .35)),
        ),
        child: Column(
          children: [
            Icon(icon, color: _T.orange),
            const SizedBox(height: 4),
            Text(
              label,
              style: const TextStyle(
                fontSize: 12.5,
                fontWeight: FontWeight.w700,
                color: _T.ink,
              ),
            ),
          ],
        ),
      ),
    ),
  );

  Widget _fileTile(PickedFile f, int i) => Container(
    margin: const EdgeInsets.only(bottom: 8),
    padding: const EdgeInsets.fromLTRB(8, 8, 4, 8),
    decoration: BoxDecoration(
      color: const Color(0xFFF8F9FC),
      borderRadius: BorderRadius.circular(14),
    ),
    child: Row(
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(10),
          child: SizedBox(
            width: 44,
            height: 44,
            child: f.kind == 'image'
                ? Image.memory(
                    f.bytes,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => Container(
                      color: _T.orange.withValues(alpha: .12),
                      child: const Icon(
                        Icons.image_not_supported_outlined,
                        color: _T.orange,
                      ),
                    ),
                  )
                : Container(
                    color: _T.orange.withValues(alpha: .12),
                    child: Icon(
                      f.kind == 'video'
                          ? Icons.play_circle_outline_rounded
                          : Icons.insert_drive_file_outlined,
                      color: _T.orange,
                    ),
                  ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                f.name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: 13.5,
                ),
              ),
              Text(
                '${f.mb.toStringAsFixed(1)} MB',
                style: const TextStyle(color: _T.muted, fontSize: 12),
              ),
            ],
          ),
        ),
        IconButton(
          onPressed: () => c.files.removeAt(i),
          icon: const Icon(Icons.close_rounded, size: 20),
        ),
      ],
    ),
  );

  // ---------- submit ----------
  Widget _submitButton() => Transform.translate(
    offset: const Offset(0, -34),
    child: SizedBox(
      width: double.infinity,
      height: 56,
      child: ElevatedButton.icon(
        onPressed: _submit,
        icon: const Icon(Icons.send_rounded),
        label: const Text(
          'Submit request',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
        ),
        style: ElevatedButton.styleFrom(
          backgroundColor: _T.orange,
          foregroundColor: Colors.white,
          elevation: 6,
          shadowColor: _T.orange.withValues(alpha: .5),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
          ),
        ),
      ),
    ),
  );

  Widget _loadingOverlay() => Container(
    color: Colors.black.withValues(alpha: .45),
    alignment: Alignment.center,
    child: Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const CircularProgressIndicator(color: _T.orange),
          const SizedBox(height: 16),
          Obx(
            () => Text(
              c.status.value.isEmpty ? 'Please wait…' : c.status.value,
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    ),
  );
}

// ---------------------------------------------------------
// SERVICE PICKER BOTTOM SHEET (creative dropdown)
// ---------------------------------------------------------
class _ServiceSheet extends StatelessWidget {
  final ServiceItem? selected;
  const _ServiceSheet({this.selected});

  @override
  Widget build(BuildContext context) {
    final w = MediaQuery.of(context).size.width;
    final cols = w > 700 ? 5 : (w > 420 ? 3 : 2);
    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * .8,
      ),
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
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
                color: const Color(0xFFDDE1EA),
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            const SizedBox(height: 16),
            const Align(
              alignment: Alignment.centerLeft,
              child: Text(
                'Select a service',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                  color: _T.ink,
                ),
              ),
            ),
            const SizedBox(height: 14),
            Flexible(
              child: GridView.builder(
                shrinkWrap: true,
                itemCount: kServiceItems.length,
                gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: cols,
                  mainAxisSpacing: 12,
                  crossAxisSpacing: 12,
                  childAspectRatio: 1.15,
                ),
                itemBuilder: (_, i) {
                  final s = kServiceItems[i];
                  final on = selected?.name == s.name;
                  return TweenAnimationBuilder<double>(
                    tween: Tween(begin: 0, end: 1),
                    duration: Duration(milliseconds: 250 + i * 40),
                    curve: Curves.easeOutBack,
                    builder: (_, v, child) => Transform.scale(
                      scale: v.clamp(0.0, 1.2),
                      child: Opacity(opacity: v.clamp(0.0, 1.0), child: child),
                    ),
                    child: InkWell(
                      borderRadius: BorderRadius.circular(18),
                      onTap: () => Navigator.pop(context, s),
                      child: Container(
                        decoration: BoxDecoration(
                          color: on ? s.color : s.color.withValues(alpha: .1),
                          borderRadius: BorderRadius.circular(18),
                          border: Border.all(
                            color: s.color.withValues(alpha: on ? 1 : .35),
                            width: on ? 2 : 1,
                          ),
                        ),
                        child: Stack(
                          children: [
                            Center(
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(
                                    s.icon,
                                    size: 32,
                                    color: on ? Colors.white : s.color,
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    s.name,
                                    style: TextStyle(
                                      fontWeight: FontWeight.w800,
                                      fontSize: 13.5,
                                      color: on ? Colors.white : _T.ink,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            if (on)
                              const Positioned(
                                top: 8,
                                right: 8,
                                child: Icon(
                                  Icons.check_circle,
                                  color: Colors.white,
                                  size: 20,
                                ),
                              ),
                          ],
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------
// QUOTE SUMMARY CARD
// Drop this into your "Track request" / request-details screen:
//
//   QuoteSummaryCard(
//     request: doc.data()!,
//     onApprove: () async {
//       final ok = await Get.put(RequestController()).acceptQuote(doc.id);
//     },
//   )
//
// Shows: total quote -> deposit now (advance) -> deposit later (balance).
// After approval it highlights the advance amount to pay.
// ---------------------------------------------------------
class QuoteSummaryCard extends StatelessWidget {
  final Map<String, dynamic> request;

  /// Shown as an "Approve quote" button while status == quoted.
  final Future<void> Function()? onApprove;

  const QuoteSummaryCard({super.key, required this.request, this.onApprove});

  @override
  Widget build(BuildContext context) {
    final status = (request['status'] ?? QuoteStatus.pending).toString();
    final q = QuotePricing.fromMap(request);

    if (!q.hasQuote) return _waiting(status);

    final approved = QuoteStatus.approvedStates.contains(status);
    final canApprove = status == QuoteStatus.quoted && onApprove != null;

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        boxShadow: [
          BoxShadow(
            color: _T.ink.withValues(alpha: .06),
            blurRadius: 24,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.request_quote_rounded, color: _T.orange),
              const SizedBox(width: 8),
              const Expanded(
                child: Text(
                  'Your quote',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    color: _T.ink,
                  ),
                ),
              ),
              if (approved) _chip('Approved', _T.green),
            ],
          ),
          const SizedBox(height: 14),
          // 1) total
          const Text(
            'Total amount',
            style: TextStyle(color: _T.muted, fontSize: 12.5),
          ),
          const SizedBox(height: 2),
          Text(
            QuotePricing.money(q.total),
            style: const TextStyle(
              fontSize: 30,
              fontWeight: FontWeight.w900,
              color: _T.ink,
            ),
          ),
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 14),
            child: Divider(height: 1, color: Color(0xFFE6E9F2)),
          ),
          // 2) deposit now / later
          _row(
            'Deposit now (advance)',
            QuotePricing.money(q.depositNow),
            sub: q.total > 0
                ? '${q.depositPercent.toStringAsFixed(0)}% of total'
                : null,
            highlight: true,
          ),
          const SizedBox(height: 10),
          _row(
            'Deposit later (balance)',
            QuotePricing.money(q.depositLater),
            sub: 'Due after the job is completed',
          ),
          if (q.note.isNotEmpty) ...[
            const SizedBox(height: 12),
            Text(
              q.note,
              style: const TextStyle(
                color: _T.muted,
                fontSize: 12.5,
                height: 1.4,
              ),
            ),
          ],
          // 3) approved -> advance banner
          if (approved) ...[const SizedBox(height: 14), _advanceBanner(q)],
          // 4) approve action
          if (canApprove) ...[
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton.icon(
                onPressed: () => _confirm(context, q),
                icon: const Icon(Icons.verified_outlined),
                label: const Text(
                  'Approve quote',
                  style: TextStyle(fontWeight: FontWeight.w800),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: _T.orange,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Future<void> _confirm(BuildContext context, QuotePricing q) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Approve this quote?'),
        content: Text(
          'Total: ${QuotePricing.money(q.total)}\n'
          'Advance to pay now: ${QuotePricing.money(q.depositNow)}\n'
          'Balance later: ${QuotePricing.money(q.depositLater)}',
          style: const TextStyle(height: 1.5),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel', style: TextStyle(color: _T.muted)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: _T.orange,
              foregroundColor: Colors.white,
            ),
            child: const Text('Approve'),
          ),
        ],
      ),
    );
    if (ok == true) await onApprove!();
  }

  Widget _advanceBanner(QuotePricing q) {
    final paid = q.advancePaid;
    final color = paid ? _T.green : _T.orange;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: color.withValues(alpha: .1),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withValues(alpha: .4)),
      ),
      child: Row(
        children: [
          Icon(
            paid
                ? Icons.check_circle_rounded
                : Icons.account_balance_wallet_outlined,
            color: color,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              paid
                  ? 'Advance of ${QuotePricing.money(q.depositNow)} received. '
                        'Balance ${QuotePricing.money(q.depositLater)} is due after the job.'
                  : 'Advance of ${QuotePricing.money(q.depositNow)} is required to confirm your booking.',
              style: const TextStyle(
                fontWeight: FontWeight.w600,
                fontSize: 13,
                color: _T.ink,
                height: 1.35,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _waiting(String status) => Container(
    padding: const EdgeInsets.all(18),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(22),
    ),
    child: Row(
      children: [
        const Icon(Icons.hourglass_top_rounded, color: _T.orange),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            status == QuoteStatus.rejected || status == QuoteStatus.cancelled
                ? 'No quote available for this request.'
                : 'Your quote is being prepared. We will notify you when it is ready.',
            style: const TextStyle(color: _T.muted, height: 1.4),
          ),
        ),
      ],
    ),
  );

  Widget _row(
    String label,
    String value, {
    String? sub,
    bool highlight = false,
  }) => Row(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Expanded(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: TextStyle(
                fontWeight: FontWeight.w700,
                color: _T.ink.withValues(alpha: .85),
              ),
            ),
            if (sub != null)
              Text(sub, style: const TextStyle(color: _T.muted, fontSize: 12)),
          ],
        ),
      ),
      Text(
        value,
        style: TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w800,
          color: highlight ? _T.orangeDark : _T.ink,
        ),
      ),
    ],
  );

  Widget _chip(String text, Color color) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
    decoration: BoxDecoration(
      color: color.withValues(alpha: .12),
      borderRadius: BorderRadius.circular(20),
    ),
    child: Text(
      text,
      style: TextStyle(color: color, fontWeight: FontWeight.w800, fontSize: 12),
    ),
  );
}

// ---------------------------------------------------------
// SUCCESS PAGE
// ---------------------------------------------------------
class _SuccessPage extends StatelessWidget {
  final String number;
  final ServiceItem service;
  final VoidCallback? onTrack;
  const _SuccessPage({
    required this.number,
    required this.service,
    this.onTrack,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _T.bg,
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 460),
            child: Padding(
              padding: const EdgeInsets.all(28),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  TweenAnimationBuilder<double>(
                    tween: Tween(begin: 0, end: 1),
                    duration: const Duration(milliseconds: 700),
                    curve: Curves.elasticOut,
                    builder: (_, v, child) =>
                        Transform.scale(scale: v, child: child),
                    child: Container(
                      padding: const EdgeInsets.all(26),
                      decoration: BoxDecoration(
                        color: _T.green.withValues(alpha: .12),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.check_circle_rounded,
                        color: _T.green,
                        size: 84,
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                  const Text(
                    'Request submitted!',
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.w800,
                      color: _T.ink,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    'We received your ${service.name} request. You will get a quote and a notification shortly.',
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: _T.muted, height: 1.4),
                  ),
                  const SizedBox(height: 20),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 18,
                      vertical: 12,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(service.icon, color: service.color),
                        const SizedBox(width: 10),
                        Text(
                          number,
                          style: const TextStyle(
                            fontWeight: FontWeight.w800,
                            letterSpacing: 1,
                            color: _T.ink,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 28),
                  SizedBox(
                    width: double.infinity,
                    height: 52,
                    child: ElevatedButton(
                      // FIX: previously only Get.back, so onTrack never fired.
                      onPressed: () {
                        Get.back();
                        onTrack?.call();
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _T.orange,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
                      child: const Text(
                        'Track this request',
                        style: TextStyle(fontWeight: FontWeight.w800),
                      ),
                    ),
                  ),
                  TextButton(
                    onPressed: Get.back,
                    child: const Text(
                      'Back to home',
                      style: TextStyle(color: _T.muted),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// // =============================================================
// // request_view.dart  —  Request a Quote (single file)
// //
// // pubspec.yaml dependencies needed:
// //   get, firebase_core, firebase_auth, cloud_firestore,
// //   firebase_storage, file_picker
// //
// // Firestore collection : quote_requests/{requestId}
// // Storage path         : quote_requests/{uid}/{requestId}/{file}
// // =============================================================
// import 'dart:typed_data';

// import 'package:cloud_firestore/cloud_firestore.dart';
// import 'package:file_picker/file_picker.dart';
// import 'package:firebase_auth/firebase_auth.dart';
// import 'package:firebase_storage/firebase_storage.dart';
// import 'package:flutter/material.dart';
// import 'package:get/get.dart';

// // ---------------------------------------------------------
// // THEME
// // ---------------------------------------------------------
// class _T {
//   static const orange = Color(0xFFFF7A00);
//   static const orangeDark = Color(0xFFE55F00);
//   static const ink = Color(0xFF1F2430);
//   static const bg = Color(0xFFF6F7FB);
//   static const muted = Color(0xFF7A8194);
//   static const green = Color(0xFF22B573);
// }

// // ---------------------------------------------------------
// // STATUS VALUES (admin updates the `status` field)
// // ---------------------------------------------------------
// class QuoteStatus {
//   static const pending = 'pending';
//   static const reviewing = 'reviewing';
//   static const quoted = 'quoted';
//   static const accepted = 'accepted';
//   static const scheduled = 'scheduled';
//   static const completed = 'completed';
//   static const rejected = 'rejected';
//   static const cancelled = 'cancelled';
//   static const all = [
//     pending,
//     reviewing,
//     quoted,
//     accepted,
//     scheduled,
//     completed,
//     rejected,
//     cancelled,
//   ];
// }

// // ---------------------------------------------------------
// // MODELS
// // ---------------------------------------------------------
// class ServiceItem {
//   final String name;
//   final IconData icon;
//   final Color color;
//   const ServiceItem(this.name, this.icon, this.color);
// }

// const kServiceItems = <ServiceItem>[
//   ServiceItem('Painting', Icons.format_paint_outlined, Color(0xFFEB5757)),
//   ServiceItem('Moving', Icons.local_shipping_outlined, Color(0xFF4F5D75)),
//   ServiceItem('Cleaning', Icons.cleaning_services_outlined, Color(0xFF27AE60)),
//   ServiceItem('Assembly', Icons.build_outlined, Color(0xFF9B51E0)),
//   ServiceItem('Lawn Services', Icons.grass_outlined, Color(0xFF6FCF97)),
//   ServiceItem('Waste Disposal', Icons.delete_outline, Color(0xFF828282)),
//   ServiceItem('Pressure Washing', Icons.water_drop_outlined, Color(0xFF56CCF2)),
//   ServiceItem('General Handyman', Icons.handyman_outlined, Color(0xFF2D9CDB)),
// ];

// class PickedFile {
//   final String name;
//   final Uint8List bytes;
//   final String kind; // image | video | document
//   PickedFile(this.name, this.bytes, this.kind);
//   double get mb => bytes.lengthInBytes / (1024 * 1024);

//   /// Content type used for the Firebase Storage upload metadata.
//   String get contentType {
//     final ext = name.contains('.') ? name.split('.').last.toLowerCase() : '';
//     switch (ext) {
//       case 'jpg':
//       case 'jpeg':
//         return 'image/jpeg';
//       case 'png':
//         return 'image/png';
//       case 'gif':
//         return 'image/gif';
//       case 'webp':
//         return 'image/webp';
//       case 'heic':
//         return 'image/heic';
//       case 'mp4':
//         return 'video/mp4';
//       case 'mov':
//         return 'video/quicktime';
//       case 'avi':
//         return 'video/x-msvideo';
//       case 'mkv':
//         return 'video/x-matroska';
//       case 'pdf':
//         return 'application/pdf';
//       case 'doc':
//         return 'application/msword';
//       case 'docx':
//         return 'application/vnd.openxmlformats-officedocument.wordprocessingml.document';
//       case 'txt':
//         return 'text/plain';
//       default:
//         return 'application/octet-stream';
//     }
//   }
// }

// // ---------------------------------------------------------
// // CONTROLLER (state + Firebase logic)
// // ---------------------------------------------------------
// class RequestController extends GetxController {
//   final _auth = FirebaseAuth.instance;
//   final _db = FirebaseFirestore.instance;

//   final service = Rxn<ServiceItem>();
//   final urgency = 'Flexible'.obs;
//   final date = Rxn<DateTime>();
//   final slot = 'Morning'.obs;
//   final files = <PickedFile>[].obs;
//   final loading = false.obs;
//   final status = ''.obs;

//   static const maxFileMb = 20.0;
//   static const maxFiles = 8;
//   static const urgencies = ['Flexible', 'Soon', 'Urgent'];
//   static const slots = {
//     'Morning': '8 AM – 12 PM',
//     'Afternoon': '12 – 4 PM',
//     'Evening': '4 – 8 PM',
//   };

//   void toast(String msg, {bool error = true}) => Get.snackbar(
//     error ? 'Oops' : 'Done',
//     msg,
//     snackPosition: SnackPosition.BOTTOM,
//     margin: const EdgeInsets.all(16),
//     borderRadius: 14,
//     backgroundColor: error ? const Color(0xFFEB5757) : _T.green,
//     colorText: Colors.white,
//   );

//   // ---------------------------------------------------------
//   // FILE PICKER (fixed)
//   // ---------------------------------------------------------
//   Future<void> pick(String kind) async {
//     if (files.length >= maxFiles) {
//       toast('You can attach up to $maxFiles files');
//       return;
//     }

//     try {
//       final FileType type;
//       List<String>? exts;
//       switch (kind) {
//         case 'image':
//           type = FileType.image;
//           break;
//         case 'video':
//           type = FileType.video;
//           break;
//         default:
//           type = FileType.custom;
//           exts = ['pdf', 'doc', 'docx', 'txt'];
//       }

//       // file_picker 12+/13+: pickFiles() returns List<PlatformFile>
//       // (empty list when cancelled) and allows multiple files by default.
//       final picked = await FilePicker.pickFiles(
//         type: type,
//         allowedExtensions: exts, // only valid (and required) for custom
//       );

//       // user cancelled
//       if (picked.isEmpty) return;

//       var skippedBig = 0;
//       var skippedNoData = 0;
//       var hitLimit = false;

//       for (final f in picked) {
//         if (files.length >= maxFiles) {
//           hitLimit = true;
//           break;
//         }

//         // skip huge files before loading them into memory
//         final size = f.lengthSync();
//         if (size != null && size > maxFileMb * 1024 * 1024) {
//           skippedBig++;
//           continue;
//         }

//         // read bytes on demand (replaces the removed `withData: true`)
//         Uint8List? bytes;
//         try {
//           bytes = await f.readAsBytes();
//         } catch (_) {
//           bytes = null;
//         }
//         if (bytes == null || bytes.isEmpty) {
//           skippedNoData++;
//           continue;
//         }
//         final p = PickedFile(f.name, bytes, kind);
//         if (p.mb > maxFileMb) {
//           skippedBig++;
//           continue;
//         }
//         files.add(p);
//       }

//       if (skippedBig > 0) {
//         toast(
//           '$skippedBig file(s) skipped — larger than ${maxFileMb.toInt()} MB',
//         );
//       } else if (skippedNoData > 0) {
//         toast('$skippedNoData file(s) could not be read');
//       } else if (hitLimit) {
//         toast('You can attach up to $maxFiles files');
//       }
//     } catch (e) {
//       debugPrint('FilePicker error: $e');
//       toast('Could not open file picker');
//     }
//   }

//   /// Creates quote_requests/{id}. Returns the request number or null.
//   Future<String?> submit({
//     required String name,
//     required String phone,
//     required String email,
//     required String address,
//     required String description,
//     required String budget,
//   }) async {
//     final user = _auth.currentUser;
//     if (user == null) {
//       toast('Please log in first');
//       return null;
//     }
//     try {
//       loading.value = true;
//       final ref = _db.collection('quote_requests').doc();
//       final number = 'QR-${DateTime.now().millisecondsSinceEpoch % 1000000}';

//       // 1) upload attachments
//       final uploaded = <Map<String, dynamic>>[];
//       for (var i = 0; i < files.length; i++) {
//         status.value = 'Uploading file ${i + 1} of ${files.length}…';
//         final f = files[i];
//         final sref = FirebaseStorage.instance.ref(
//           'quote_requests/${user.uid}/${ref.id}/${i}_${f.name}',
//         );
//         await sref.putData(
//           f.bytes,
//           SettableMetadata(contentType: f.contentType),
//         );
//         uploaded.add({
//           'name': f.name,
//           'type': f.kind,
//           'url': await sref.getDownloadURL(),
//         });
//       }

//       // 2) save request
//       status.value = 'Sending your request…';
//       await ref.set({
//         'id': ref.id,
//         'requestNumber': number,
//         'userId': user.uid,
//         'service': service.value!.name,
//         'description': description.trim(),
//         'budget': double.tryParse(budget.trim()) ?? 0,
//         'customerName': name.trim(),
//         'phone': phone.trim(),
//         'email': email.trim().toLowerCase(),
//         'address': address.trim(),
//         'urgency': urgency.value,
//         'preferredDate': Timestamp.fromDate(date.value!),
//         'preferredSlot': '${slot.value} (${slots[slot.value]})',
//         'attachments': uploaded,
//         // ----- admin-managed fields -----
//         'status': QuoteStatus.pending,
//         'quoteAmount': null,
//         'adminNote': '',
//         'assignedTo': null,
//         'statusHistory': [
//           {
//             'status': QuoteStatus.pending,
//             'at': Timestamp.now(),
//             'by': 'customer',
//           },
//         ],
//         'createdAt': FieldValue.serverTimestamp(),
//         'updatedAt': FieldValue.serverTimestamp(),
//       });
//       return number;
//     } on FirebaseException catch (e) {
//       toast(e.message ?? 'Could not submit request');
//     } catch (_) {
//       toast('Something went wrong. Please try again.');
//     } finally {
//       loading.value = false;
//       status.value = '';
//     }
//     return null;
//   }

//   void reset() {
//     service.value = null;
//     urgency.value = 'Flexible';
//     date.value = null;
//     slot.value = 'Morning';
//     files.clear();
//   }
// }

// // ---------------------------------------------------------
// // REQUEST PAGE
// // ---------------------------------------------------------
// class RequestView extends StatefulWidget {
//   /// Optional: called when user taps "Track this request" on success page.
//   final VoidCallback? onTrack;
//   const RequestView({super.key, this.onTrack});

//   @override
//   State<RequestView> createState() => _RequestViewState();
// }

// class _RequestViewState extends State<RequestView> {
//   final c = Get.put(RequestController());
//   final _form = GlobalKey<FormState>();
//   final _desc = TextEditingController();
//   final _budget = TextEditingController();
//   final _name = TextEditingController();
//   final _phone = TextEditingController();
//   final _email = TextEditingController();
//   final _address = TextEditingController();

//   @override
//   void initState() {
//     super.initState();
//     _prefill();
//   }

//   Future<void> _prefill() async {
//     final u = FirebaseAuth.instance.currentUser;
//     if (u == null) return;
//     _name.text = u.displayName ?? '';
//     _email.text = u.email ?? '';
//     try {
//       final doc = await FirebaseFirestore.instance
//           .collection('users')
//           .doc(u.uid)
//           .get();
//       final d = doc.data();
//       if (d != null && mounted) {
//         if (_name.text.isEmpty) _name.text = d['name'] ?? '';
//         _phone.text = d['phone'] ?? '';
//       }
//     } catch (_) {}
//   }

//   @override
//   void dispose() {
//     for (final t in [_desc, _budget, _name, _phone, _email, _address]) {
//       t.dispose();
//     }
//     Get.delete<RequestController>();
//     super.dispose();
//   }

//   String? _req(String? v) =>
//       (v == null || v.trim().isEmpty) ? 'This field is required' : null;

//   InputDecoration _dec(
//     String label,
//     IconData icon, {
//     String? hint,
//     String? prefixText,
//   }) => InputDecoration(
//     labelText: label,
//     hintText: hint,
//     prefixText: prefixText,
//     prefixIcon: Icon(icon, color: _T.orange, size: 22),
//     filled: true,
//     fillColor: const Color(0xFFF8F9FC),
//     contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
//     border: _border(Colors.transparent),
//     enabledBorder: _border(const Color(0xFFE6E9F2)),
//     focusedBorder: _border(_T.orange, w: 1.6),
//     errorBorder: _border(const Color(0xFFEB5757)),
//     focusedErrorBorder: _border(const Color(0xFFEB5757), w: 1.6),
//   );

//   OutlineInputBorder _border(Color col, {double w = 1}) => OutlineInputBorder(
//     borderRadius: BorderRadius.circular(14),
//     borderSide: BorderSide(color: col, width: w),
//   );

//   // ---------- service bottom sheet ----------
//   Future<void> _pickService() async {
//     FocusScope.of(context).unfocus();
//     final picked = await showModalBottomSheet<ServiceItem>(
//       context: context,
//       isScrollControlled: true,
//       backgroundColor: Colors.transparent,
//       builder: (_) => _ServiceSheet(selected: c.service.value),
//     );
//     if (picked != null) c.service.value = picked;
//   }

//   Future<void> _pickDate() async {
//     final now = DateTime.now();
//     final d = await showDatePicker(
//       context: context,
//       initialDate: c.date.value ?? now.add(const Duration(days: 2)),
//       firstDate: now,
//       lastDate: now.add(const Duration(days: 365)),
//       builder: (ctx, child) => Theme(
//         data: Theme.of(
//           ctx,
//         ).copyWith(colorScheme: const ColorScheme.light(primary: _T.orange)),
//         child: child!,
//       ),
//     );
//     if (d != null) c.date.value = d;
//   }

//   Future<void> _submit() async {
//     if (c.service.value == null) {
//       c.toast('Please choose a service');
//       return;
//     }
//     if (!_form.currentState!.validate()) return;
//     if (c.date.value == null) {
//       c.toast('Please pick a preferred date');
//       return;
//     }
//     final number = await c.submit(
//       name: _name.text,
//       phone: _phone.text,
//       email: _email.text,
//       address: _address.text,
//       description: _desc.text,
//       budget: _budget.text,
//     );
//     if (number == null) return;
//     final svc = c.service.value!;
//     c.reset();
//     _desc.clear();
//     _budget.clear();
//     _address.clear();
//     Get.to(
//       () => _SuccessPage(number: number, service: svc, onTrack: widget.onTrack),
//     );
//   }

//   // ---------- build ----------
//   @override
//   Widget build(BuildContext context) {
//     return Scaffold(
//       backgroundColor: _T.bg,
//       body: Stack(
//         children: [
//           LayoutBuilder(
//             builder: (context, box) {
//               final wide = box.maxWidth > 640;
//               return CustomScrollView(
//                 slivers: [
//                   SliverToBoxAdapter(child: _header(wide)),
//                   SliverToBoxAdapter(
//                     child: Center(
//                       child: ConstrainedBox(
//                         constraints: const BoxConstraints(maxWidth: 760),
//                         child: Padding(
//                           padding: EdgeInsets.fromLTRB(
//                             wide ? 24 : 16,
//                             0,
//                             wide ? 24 : 16,
//                             40,
//                           ),
//                           child: Form(
//                             key: _form,
//                             child: Column(
//                               children: [
//                                 _serviceCard(),
//                                 _detailsCard(),
//                                 _contactCard(wide),
//                                 _whenWhereCard(wide),
//                                 _attachCard(),
//                                 const SizedBox(height: 22),
//                                 _submitButton(),
//                               ],
//                             ),
//                           ),
//                         ),
//                       ),
//                     ),
//                   ),
//                 ],
//               );
//             },
//           ),
//           Obx(() => c.loading.value ? _loadingOverlay() : const SizedBox()),
//         ],
//       ),
//     );
//   }

//   Widget _header(bool wide) => Container(
//     padding: EdgeInsets.fromLTRB(
//       24,
//       MediaQuery.of(context).padding.top + 22,
//       24,
//       56,
//     ),
//     decoration: const BoxDecoration(
//       gradient: LinearGradient(
//         colors: [_T.orange, _T.orangeDark],
//         begin: Alignment.topLeft,
//         end: Alignment.bottomRight,
//       ),
//       borderRadius: BorderRadius.vertical(bottom: Radius.circular(32)),
//     ),
//     child: Center(
//       child: ConstrainedBox(
//         constraints: const BoxConstraints(maxWidth: 760),
//         child: Row(
//           children: [
//             Expanded(
//               child: Column(
//                 crossAxisAlignment: CrossAxisAlignment.start,
//                 children: [
//                   const Text(
//                     'Request a quote',
//                     style: TextStyle(
//                       color: Colors.white,
//                       fontSize: 26,
//                       fontWeight: FontWeight.w800,
//                     ),
//                   ),
//                   const SizedBox(height: 6),
//                   Text(
//                     'Tell us about the job — we will get back with a price.',
//                     style: TextStyle(
//                       color: Colors.white.withValues(alpha: .9),
//                       fontSize: 14,
//                     ),
//                   ),
//                 ],
//               ),
//             ),
//             const SizedBox(width: 12),
//             Container(
//               padding: const EdgeInsets.all(14),
//               decoration: BoxDecoration(
//                 color: Colors.white.withValues(alpha: .2),
//                 shape: BoxShape.circle,
//               ),
//               child: const Icon(
//                 Icons.request_quote_rounded,
//                 color: Colors.white,
//                 size: 34,
//               ),
//             ),
//           ],
//         ),
//       ),
//     ),
//   );

//   // ---------- section card ----------
//   Widget _card(String title, IconData icon, int step, Widget child) =>
//       Container(
//         margin: const EdgeInsets.only(top: 16),
//         padding: const EdgeInsets.all(18),
//         decoration: BoxDecoration(
//           color: Colors.white,
//           borderRadius: BorderRadius.circular(22),
//           boxShadow: [
//             BoxShadow(
//               color: _T.ink.withValues(alpha: .06),
//               blurRadius: 24,
//               offset: const Offset(0, 8),
//             ),
//           ],
//         ),
//         child: Column(
//           crossAxisAlignment: CrossAxisAlignment.start,
//           children: [
//             Row(
//               children: [
//                 Container(
//                   width: 34,
//                   height: 34,
//                   alignment: Alignment.center,
//                   decoration: BoxDecoration(
//                     color: _T.orange.withValues(alpha: .12),
//                     borderRadius: BorderRadius.circular(11),
//                   ),
//                   child: Icon(icon, color: _T.orange, size: 19),
//                 ),
//                 const SizedBox(width: 10),
//                 Expanded(
//                   child: Text(
//                     title,
//                     style: const TextStyle(
//                       fontSize: 16,
//                       fontWeight: FontWeight.w800,
//                       color: _T.ink,
//                     ),
//                   ),
//                 ),
//                 Text(
//                   '$step/5',
//                   style: const TextStyle(
//                     color: _T.muted,
//                     fontWeight: FontWeight.w600,
//                     fontSize: 12,
//                   ),
//                 ),
//               ],
//             ),
//             const SizedBox(height: 16),
//             child,
//           ],
//         ),
//       );

//   // ---------- 1. service ----------
//   Widget _serviceCard() => Transform.translate(
//     offset: const Offset(0, -34),
//     child: _card(
//       'What do you need?',
//       Icons.handyman_rounded,
//       1,
//       Obx(() {
//         final s = c.service.value;
//         return InkWell(
//           borderRadius: BorderRadius.circular(16),
//           onTap: _pickService,
//           child: AnimatedContainer(
//             duration: const Duration(milliseconds: 250),
//             padding: const EdgeInsets.all(14),
//             decoration: BoxDecoration(
//               color: (s?.color ?? _T.orange).withValues(alpha: .08),
//               borderRadius: BorderRadius.circular(16),
//               border: Border.all(
//                 color: (s?.color ?? _T.orange).withValues(alpha: .5),
//                 width: 1.4,
//               ),
//             ),
//             child: Row(
//               children: [
//                 Container(
//                   width: 48,
//                   height: 48,
//                   decoration: BoxDecoration(
//                     color: s?.color ?? _T.orange,
//                     borderRadius: BorderRadius.circular(14),
//                   ),
//                   child: Icon(
//                     s?.icon ?? Icons.add_rounded,
//                     color: Colors.white,
//                     size: 26,
//                   ),
//                 ),
//                 const SizedBox(width: 14),
//                 Expanded(
//                   child: Column(
//                     crossAxisAlignment: CrossAxisAlignment.start,
//                     children: [
//                       Text(
//                         s?.name ?? 'Choose a service',
//                         style: const TextStyle(
//                           fontSize: 16,
//                           fontWeight: FontWeight.w800,
//                           color: _T.ink,
//                         ),
//                       ),
//                       const SizedBox(height: 2),
//                       Text(
//                         s == null ? 'Tap to see all services' : 'Tap to change',
//                         style: const TextStyle(color: _T.muted, fontSize: 12.5),
//                       ),
//                     ],
//                   ),
//                 ),
//                 const Icon(
//                   Icons.keyboard_arrow_down_rounded,
//                   color: _T.ink,
//                   size: 28,
//                 ),
//               ],
//             ),
//           ),
//         );
//       }),
//     ),
//   );

//   // ---------- 2. details ----------
//   Widget _detailsCard() => Transform.translate(
//     offset: const Offset(0, -34),
//     child: _card(
//       'Job details',
//       Icons.edit_note_rounded,
//       2,
//       Column(
//         children: [
//           TextFormField(
//             controller: _desc,
//             maxLines: 4,
//             maxLength: 500,
//             textCapitalization: TextCapitalization.sentences,
//             validator: (v) => (v == null || v.trim().length < 10)
//                 ? 'Please describe the work (min 10 characters)'
//                 : null,
//             decoration: _dec(
//               'Description of work',
//               Icons.notes_rounded,
//               hint: 'e.g. Kitchen sink is leaking underneath…',
//             ),
//           ),
//           const SizedBox(height: 6),
//           TextFormField(
//             controller: _budget,
//             keyboardType: const TextInputType.numberWithOptions(decimal: true),
//             validator: (v) {
//               if (_req(v) != null) return 'This field is required';
//               if (double.tryParse(v!.trim()) == null) return 'Enter a number';
//               return null;
//             },
//             decoration: _dec(
//               'Estimated budget',
//               Icons.payments_outlined,
//               prefixText: '\$ ',
//             ),
//           ),
//           const SizedBox(height: 16),
//           Align(
//             alignment: Alignment.centerLeft,
//             child: Text(
//               'How soon?',
//               style: TextStyle(
//                 fontWeight: FontWeight.w700,
//                 color: _T.ink.withValues(alpha: .8),
//               ),
//             ),
//           ),
//           const SizedBox(height: 8),
//           Obx(
//             () => Row(
//               children: [
//                 for (final u in RequestController.urgencies)
//                   Expanded(
//                     child: Padding(
//                       padding: EdgeInsets.only(
//                         right: u == RequestController.urgencies.last ? 0 : 8,
//                       ),
//                       child: _pill(
//                         u,
//                         u == 'Urgent'
//                             ? Icons.bolt_rounded
//                             : u == 'Soon'
//                             ? Icons.timelapse_rounded
//                             : Icons.event_available_rounded,
//                         c.urgency.value == u,
//                         () => c.urgency.value = u,
//                       ),
//                     ),
//                   ),
//               ],
//             ),
//           ),
//         ],
//       ),
//     ),
//   );

//   Widget _pill(
//     String label,
//     IconData icon,
//     bool on,
//     VoidCallback tap, {
//     String? sub,
//   }) => InkWell(
//     borderRadius: BorderRadius.circular(14),
//     onTap: tap,
//     child: AnimatedContainer(
//       duration: const Duration(milliseconds: 200),
//       padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 6),
//       decoration: BoxDecoration(
//         color: on ? _T.orange : const Color(0xFFF8F9FC),
//         borderRadius: BorderRadius.circular(14),
//         border: Border.all(color: on ? _T.orange : const Color(0xFFE6E9F2)),
//       ),
//       child: Column(
//         mainAxisSize: MainAxisSize.min,
//         children: [
//           Icon(icon, size: 20, color: on ? Colors.white : _T.muted),
//           const SizedBox(height: 4),
//           Text(
//             label,
//             style: TextStyle(
//               fontWeight: FontWeight.w700,
//               fontSize: 13,
//               color: on ? Colors.white : _T.ink,
//             ),
//           ),
//           if (sub != null)
//             Text(
//               sub,
//               style: TextStyle(
//                 fontSize: 10.5,
//                 color: on ? Colors.white70 : _T.muted,
//               ),
//             ),
//         ],
//       ),
//     ),
//   );

//   // ---------- 3. contact ----------
//   Widget _contactCard(bool wide) {
//     final phone = TextFormField(
//       controller: _phone,
//       keyboardType: TextInputType.phone,
//       validator: _req,
//       decoration: _dec('Phone', Icons.call_outlined),
//     );
//     final email = TextFormField(
//       controller: _email,
//       keyboardType: TextInputType.emailAddress,
//       validator: (v) =>
//           GetUtils.isEmail((v ?? '').trim()) ? null : 'Enter a valid email',
//       decoration: _dec('Email', Icons.mail_outline_rounded),
//     );
//     return Transform.translate(
//       offset: const Offset(0, -34),
//       child: _card(
//         'Your contact info',
//         Icons.person_rounded,
//         3,
//         Column(
//           children: [
//             TextFormField(
//               controller: _name,
//               textCapitalization: TextCapitalization.words,
//               validator: _req,
//               decoration: _dec('Full name', Icons.person_outline_rounded),
//             ),
//             const SizedBox(height: 14),
//             wide
//                 ? Row(
//                     children: [
//                       Expanded(child: phone),
//                       const SizedBox(width: 12),
//                       Expanded(child: email),
//                     ],
//                   )
//                 : Column(children: [phone, const SizedBox(height: 14), email]),
//           ],
//         ),
//       ),
//     );
//   }

//   // ---------- 4. when & where ----------
//   Widget _whenWhereCard(bool wide) => Transform.translate(
//     offset: const Offset(0, -34),
//     child: _card(
//       'When & where',
//       Icons.place_rounded,
//       4,
//       Column(
//         children: [
//           TextFormField(
//             controller: _address,
//             maxLines: 2,
//             minLines: 1,
//             validator: _req,
//             textCapitalization: TextCapitalization.words,
//             decoration: _dec(
//               'Property address',
//               Icons.home_outlined,
//               hint: 'Street, city, ZIP',
//             ),
//           ),
//           const SizedBox(height: 14),
//           Obx(() {
//             final d = c.date.value;
//             return InkWell(
//               borderRadius: BorderRadius.circular(14),
//               onTap: _pickDate,
//               child: InputDecorator(
//                 decoration: _dec('Preferred date', Icons.calendar_month_rounded)
//                     .copyWith(
//                       suffixIcon: const Icon(Icons.arrow_drop_down_rounded),
//                     ),
//                 child: Text(
//                   d == null
//                       ? 'Select a date'
//                       : '${_months[d.month - 1]} ${d.day}, ${d.year}',
//                   style: TextStyle(
//                     color: d == null ? _T.muted : _T.ink,
//                     fontWeight: FontWeight.w600,
//                   ),
//                 ),
//               ),
//             );
//           }),
//           const SizedBox(height: 14),
//           Obx(
//             () => Row(
//               children: [
//                 for (final e in RequestController.slots.entries)
//                   Expanded(
//                     child: Padding(
//                       padding: EdgeInsets.only(
//                         right: e.key == 'Evening' ? 0 : 8,
//                       ),
//                       child: _pill(
//                         e.key,
//                         e.key == 'Morning'
//                             ? Icons.wb_sunny_outlined
//                             : e.key == 'Afternoon'
//                             ? Icons.wb_twilight_rounded
//                             : Icons.nights_stay_outlined,
//                         c.slot.value == e.key,
//                         () => c.slot.value = e.key,
//                         sub: e.value,
//                       ),
//                     ),
//                   ),
//               ],
//             ),
//           ),
//         ],
//       ),
//     ),
//   );

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

//   // ---------- 5. attachments ----------
//   Widget _attachCard() => Transform.translate(
//     offset: const Offset(0, -34),
//     child: _card(
//       'Photos, videos & documents',
//       Icons.attach_file_rounded,
//       5,
//       Column(
//         crossAxisAlignment: CrossAxisAlignment.start,
//         children: [
//           Row(
//             children: [
//               _attachBtn(Icons.photo_camera_back_outlined, 'Photo', 'image'),
//               const SizedBox(width: 10),
//               _attachBtn(Icons.videocam_outlined, 'Video', 'video'),
//               const SizedBox(width: 10),
//               _attachBtn(Icons.description_outlined, 'Document', 'document'),
//             ],
//           ),
//           const SizedBox(height: 6),
//           Text(
//             'Optional • up to 8 files • max 20 MB each',
//             style: TextStyle(color: _T.muted, fontSize: 12),
//           ),
//           Obx(
//             () => c.files.isEmpty
//                 ? const SizedBox()
//                 : Padding(
//                     padding: const EdgeInsets.only(top: 12),
//                     child: Column(
//                       children: [
//                         for (var i = 0; i < c.files.length; i++)
//                           _fileTile(c.files[i], i),
//                       ],
//                     ),
//                   ),
//           ),
//         ],
//       ),
//     ),
//   );

//   Widget _attachBtn(IconData icon, String label, String kind) => Expanded(
//     child: InkWell(
//       borderRadius: BorderRadius.circular(14),
//       onTap: () {
//         FocusScope.of(context).unfocus();
//         c.pick(kind);
//       },
//       child: Container(
//         padding: const EdgeInsets.symmetric(vertical: 14),
//         decoration: BoxDecoration(
//           color: _T.orange.withValues(alpha: .06),
//           borderRadius: BorderRadius.circular(14),
//           border: Border.all(color: _T.orange.withValues(alpha: .35)),
//         ),
//         child: Column(
//           children: [
//             Icon(icon, color: _T.orange),
//             const SizedBox(height: 4),
//             Text(
//               label,
//               style: const TextStyle(
//                 fontSize: 12.5,
//                 fontWeight: FontWeight.w700,
//                 color: _T.ink,
//               ),
//             ),
//           ],
//         ),
//       ),
//     ),
//   );

//   Widget _fileTile(PickedFile f, int i) => Container(
//     margin: const EdgeInsets.only(bottom: 8),
//     padding: const EdgeInsets.fromLTRB(8, 8, 4, 8),
//     decoration: BoxDecoration(
//       color: const Color(0xFFF8F9FC),
//       borderRadius: BorderRadius.circular(14),
//     ),
//     child: Row(
//       children: [
//         ClipRRect(
//           borderRadius: BorderRadius.circular(10),
//           child: SizedBox(
//             width: 44,
//             height: 44,
//             child: f.kind == 'image'
//                 ? Image.memory(
//                     f.bytes,
//                     fit: BoxFit.cover,
//                     errorBuilder: (_, __, ___) => Container(
//                       color: _T.orange.withValues(alpha: .12),
//                       child: const Icon(
//                         Icons.image_not_supported_outlined,
//                         color: _T.orange,
//                       ),
//                     ),
//                   )
//                 : Container(
//                     color: _T.orange.withValues(alpha: .12),
//                     child: Icon(
//                       f.kind == 'video'
//                           ? Icons.play_circle_outline_rounded
//                           : Icons.insert_drive_file_outlined,
//                       color: _T.orange,
//                     ),
//                   ),
//           ),
//         ),
//         const SizedBox(width: 12),
//         Expanded(
//           child: Column(
//             crossAxisAlignment: CrossAxisAlignment.start,
//             children: [
//               Text(
//                 f.name,
//                 maxLines: 1,
//                 overflow: TextOverflow.ellipsis,
//                 style: const TextStyle(
//                   fontWeight: FontWeight.w700,
//                   fontSize: 13.5,
//                 ),
//               ),
//               Text(
//                 '${f.mb.toStringAsFixed(1)} MB',
//                 style: const TextStyle(color: _T.muted, fontSize: 12),
//               ),
//             ],
//           ),
//         ),
//         IconButton(
//           onPressed: () => c.files.removeAt(i),
//           icon: const Icon(Icons.close_rounded, size: 20),
//         ),
//       ],
//     ),
//   );

//   // ---------- submit ----------
//   Widget _submitButton() => Transform.translate(
//     offset: const Offset(0, -34),
//     child: SizedBox(
//       width: double.infinity,
//       height: 56,
//       child: ElevatedButton.icon(
//         onPressed: _submit,
//         icon: const Icon(Icons.send_rounded),
//         label: const Text(
//           'Submit request',
//           style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
//         ),
//         style: ElevatedButton.styleFrom(
//           backgroundColor: _T.orange,
//           foregroundColor: Colors.white,
//           elevation: 6,
//           shadowColor: _T.orange.withValues(alpha: .5),
//           shape: RoundedRectangleBorder(
//             borderRadius: BorderRadius.circular(18),
//           ),
//         ),
//       ),
//     ),
//   );

//   Widget _loadingOverlay() => Container(
//     color: Colors.black.withValues(alpha: .45),
//     alignment: Alignment.center,
//     child: Container(
//       padding: const EdgeInsets.all(24),
//       decoration: BoxDecoration(
//         color: Colors.white,
//         borderRadius: BorderRadius.circular(20),
//       ),
//       child: Column(
//         mainAxisSize: MainAxisSize.min,
//         children: [
//           const CircularProgressIndicator(color: _T.orange),
//           const SizedBox(height: 16),
//           Obx(
//             () => Text(
//               c.status.value.isEmpty ? 'Please wait…' : c.status.value,
//               style: const TextStyle(fontWeight: FontWeight.w600),
//             ),
//           ),
//         ],
//       ),
//     ),
//   );
// }

// // ---------------------------------------------------------
// // SERVICE PICKER BOTTOM SHEET (creative dropdown)
// // ---------------------------------------------------------
// class _ServiceSheet extends StatelessWidget {
//   final ServiceItem? selected;
//   const _ServiceSheet({this.selected});

//   @override
//   Widget build(BuildContext context) {
//     final w = MediaQuery.of(context).size.width;
//     final cols = w > 700 ? 5 : (w > 420 ? 3 : 2);
//     return Container(
//       constraints: BoxConstraints(
//         maxHeight: MediaQuery.of(context).size.height * .8,
//       ),
//       padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
//       decoration: const BoxDecoration(
//         color: Colors.white,
//         borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
//       ),
//       child: SafeArea(
//         top: false,
//         child: Column(
//           mainAxisSize: MainAxisSize.min,
//           children: [
//             Container(
//               width: 44,
//               height: 5,
//               decoration: BoxDecoration(
//                 color: const Color(0xFFDDE1EA),
//                 borderRadius: BorderRadius.circular(8),
//               ),
//             ),
//             const SizedBox(height: 16),
//             const Align(
//               alignment: Alignment.centerLeft,
//               child: Text(
//                 'Select a service',
//                 style: TextStyle(
//                   fontSize: 20,
//                   fontWeight: FontWeight.w800,
//                   color: _T.ink,
//                 ),
//               ),
//             ),
//             const SizedBox(height: 14),
//             Flexible(
//               child: GridView.builder(
//                 shrinkWrap: true,
//                 itemCount: kServiceItems.length,
//                 gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
//                   crossAxisCount: cols,
//                   mainAxisSpacing: 12,
//                   crossAxisSpacing: 12,
//                   childAspectRatio: 1.15,
//                 ),
//                 itemBuilder: (_, i) {
//                   final s = kServiceItems[i];
//                   final on = selected?.name == s.name;
//                   return TweenAnimationBuilder<double>(
//                     tween: Tween(begin: 0, end: 1),
//                     duration: Duration(milliseconds: 250 + i * 40),
//                     curve: Curves.easeOutBack,
//                     builder: (_, v, child) => Transform.scale(
//                       scale: v.clamp(0.0, 1.2),
//                       child: Opacity(opacity: v.clamp(0.0, 1.0), child: child),
//                     ),
//                     child: InkWell(
//                       borderRadius: BorderRadius.circular(18),
//                       onTap: () => Navigator.pop(context, s),
//                       child: Container(
//                         decoration: BoxDecoration(
//                           color: on ? s.color : s.color.withValues(alpha: .1),
//                           borderRadius: BorderRadius.circular(18),
//                           border: Border.all(
//                             color: s.color.withValues(alpha: on ? 1 : .35),
//                             width: on ? 2 : 1,
//                           ),
//                         ),
//                         child: Stack(
//                           children: [
//                             Center(
//                               child: Column(
//                                 mainAxisAlignment: MainAxisAlignment.center,
//                                 children: [
//                                   Icon(
//                                     s.icon,
//                                     size: 32,
//                                     color: on ? Colors.white : s.color,
//                                   ),
//                                   const SizedBox(height: 8),
//                                   Text(
//                                     s.name,
//                                     style: TextStyle(
//                                       fontWeight: FontWeight.w800,
//                                       fontSize: 13.5,
//                                       color: on ? Colors.white : _T.ink,
//                                     ),
//                                   ),
//                                 ],
//                               ),
//                             ),
//                             if (on)
//                               const Positioned(
//                                 top: 8,
//                                 right: 8,
//                                 child: Icon(
//                                   Icons.check_circle,
//                                   color: Colors.white,
//                                   size: 20,
//                                 ),
//                               ),
//                           ],
//                         ),
//                       ),
//                     ),
//                   );
//                 },
//               ),
//             ),
//           ],
//         ),
//       ),
//     );
//   }
// }

// // ---------------------------------------------------------
// // SUCCESS PAGE
// // ---------------------------------------------------------
// class _SuccessPage extends StatelessWidget {
//   final String number;
//   final ServiceItem service;
//   final VoidCallback? onTrack;
//   const _SuccessPage({
//     required this.number,
//     required this.service,
//     this.onTrack,
//   });

//   @override
//   Widget build(BuildContext context) {
//     return Scaffold(
//       backgroundColor: _T.bg,
//       body: SafeArea(
//         child: Center(
//           child: ConstrainedBox(
//             constraints: const BoxConstraints(maxWidth: 460),
//             child: Padding(
//               padding: const EdgeInsets.all(28),
//               child: Column(
//                 mainAxisAlignment: MainAxisAlignment.center,
//                 children: [
//                   TweenAnimationBuilder<double>(
//                     tween: Tween(begin: 0, end: 1),
//                     duration: const Duration(milliseconds: 700),
//                     curve: Curves.elasticOut,
//                     builder: (_, v, child) =>
//                         Transform.scale(scale: v, child: child),
//                     child: Container(
//                       padding: const EdgeInsets.all(26),
//                       decoration: BoxDecoration(
//                         color: _T.green.withValues(alpha: .12),
//                         shape: BoxShape.circle,
//                       ),
//                       child: const Icon(
//                         Icons.check_circle_rounded,
//                         color: _T.green,
//                         size: 84,
//                       ),
//                     ),
//                   ),
//                   const SizedBox(height: 24),
//                   const Text(
//                     'Request submitted!',
//                     style: TextStyle(
//                       fontSize: 24,
//                       fontWeight: FontWeight.w800,
//                       color: _T.ink,
//                     ),
//                   ),
//                   const SizedBox(height: 10),
//                   Text(
//                     'We received your ${service.name} request. You will get a quote and a notification shortly.',
//                     textAlign: TextAlign.center,
//                     style: const TextStyle(color: _T.muted, height: 1.4),
//                   ),
//                   const SizedBox(height: 20),
//                   Container(
//                     padding: const EdgeInsets.symmetric(
//                       horizontal: 18,
//                       vertical: 12,
//                     ),
//                     decoration: BoxDecoration(
//                       color: Colors.white,
//                       borderRadius: BorderRadius.circular(14),
//                     ),
//                     child: Row(
//                       mainAxisSize: MainAxisSize.min,
//                       children: [
//                         Icon(service.icon, color: service.color),
//                         const SizedBox(width: 10),
//                         Text(
//                           number,
//                           style: const TextStyle(
//                             fontWeight: FontWeight.w800,
//                             letterSpacing: 1,
//                             color: _T.ink,
//                           ),
//                         ),
//                       ],
//                     ),
//                   ),
//                   const SizedBox(height: 28),
//                   SizedBox(
//                     width: double.infinity,
//                     height: 52,
//                     child: ElevatedButton(
//                       onPressed: Get.back,

//                       style: ElevatedButton.styleFrom(
//                         backgroundColor: _T.orange,
//                         foregroundColor: Colors.white,
//                         shape: RoundedRectangleBorder(
//                           borderRadius: BorderRadius.circular(16),
//                         ),
//                       ),
//                       child: const Text(
//                         'Track this request',
//                         style: TextStyle(fontWeight: FontWeight.w800),
//                       ),
//                     ),
//                   ),
//                   TextButton(
//                     onPressed: Get.back,
//                     child: const Text(
//                       'Back to home',
//                       style: TextStyle(color: _T.muted),
//                     ),
//                   ),
//                 ],
//               ),
//             ),
//           ),
//         ),
//       ),
//     );
//   }
// }

// // // =============================================================
// // // request_view.dart  —  Request a Quote (single file)
// // //
// // // pubspec.yaml dependencies needed:
// // //   get, firebase_core, firebase_auth, cloud_firestore,
// // //   firebase_storage, file_picker
// // //
// // // Firestore collection : quote_requests/{requestId}
// // // Storage path         : quote_requests/{uid}/{requestId}/{file}
// // // =============================================================
// // import 'dart:typed_data';

// // import 'package:cloud_firestore/cloud_firestore.dart';
// // import 'package:file_picker/file_picker.dart';
// // import 'package:firebase_auth/firebase_auth.dart';
// // import 'package:firebase_storage/firebase_storage.dart';
// // import 'package:flutter/material.dart';
// // import 'package:get/get.dart';

// // // ---------------------------------------------------------
// // // THEME
// // // ---------------------------------------------------------
// // class _T {
// //   static const orange = Color(0xFFFF7A00);
// //   static const orangeDark = Color(0xFFE55F00);
// //   static const ink = Color(0xFF1F2430);
// //   static const bg = Color(0xFFF6F7FB);
// //   static const muted = Color(0xFF7A8194);
// //   static const green = Color(0xFF22B573);
// // }

// // // ---------------------------------------------------------
// // // STATUS VALUES (admin updates the `status` field)
// // // ---------------------------------------------------------
// // class QuoteStatus {
// //   static const pending = 'pending';
// //   static const reviewing = 'reviewing';
// //   static const quoted = 'quoted';
// //   static const accepted = 'accepted';
// //   static const scheduled = 'scheduled';
// //   static const completed = 'completed';
// //   static const rejected = 'rejected';
// //   static const cancelled = 'cancelled';
// //   static const all = [
// //     pending,
// //     reviewing,
// //     quoted,
// //     accepted,
// //     scheduled,
// //     completed,
// //     rejected,
// //     cancelled,
// //   ];
// // }

// // // ---------------------------------------------------------
// // // MODELS
// // // ---------------------------------------------------------
// // class ServiceItem {
// //   final String name;
// //   final IconData icon;
// //   final Color color;
// //   const ServiceItem(this.name, this.icon, this.color);
// // }

// // const kServiceItems = <ServiceItem>[
// //   ServiceItem('Plumbing', Icons.plumbing, Color(0xFF2D9CDB)),
// //   ServiceItem('Electrical', Icons.electrical_services, Color(0xFFF2C94C)),
// //   ServiceItem('Painting', Icons.format_paint, Color(0xFFEB5757)),
// //   ServiceItem('Cleaning', Icons.cleaning_services, Color(0xFF27AE60)),
// //   ServiceItem('AC Repair', Icons.ac_unit, Color(0xFF56CCF2)),
// //   ServiceItem('Carpentry', Icons.carpenter, Color(0xFF9B51E0)),
// //   ServiceItem('Roofing', Icons.roofing, Color(0xFFF2994A)),
// //   ServiceItem('Landscaping', Icons.yard, Color(0xFF6FCF97)),
// //   ServiceItem('Moving', Icons.local_shipping, Color(0xFF4F5D75)),
// //   ServiceItem('Other', Icons.more_horiz, Color(0xFF828282)),
// // ];

// // class PickedFile {
// //   final String name;
// //   final Uint8List bytes;
// //   final String kind; // image | video | document
// //   PickedFile(this.name, this.bytes, this.kind);
// //   double get mb => bytes.lengthInBytes / (1024 * 1024);
// // }

// // // ---------------------------------------------------------
// // // CONTROLLER (state + Firebase logic)
// // // ---------------------------------------------------------
// // class RequestController extends GetxController {
// //   final _auth = FirebaseAuth.instance;
// //   final _db = FirebaseFirestore.instance;

// //   final service = Rxn<ServiceItem>();
// //   final urgency = 'Flexible'.obs;
// //   final date = Rxn<DateTime>();
// //   final slot = 'Morning'.obs;
// //   final files = <PickedFile>[].obs;
// //   final loading = false.obs;
// //   final status = ''.obs;

// //   static const maxFileMb = 20.0;
// //   static const urgencies = ['Flexible', 'Soon', 'Urgent'];
// //   static const slots = {
// //     'Morning': '8 AM – 12 PM',
// //     'Afternoon': '12 – 4 PM',
// //     'Evening': '4 – 8 PM',
// //   };

// //   void toast(String msg, {bool error = true}) => Get.snackbar(
// //     error ? 'Oops' : 'Done',
// //     msg,
// //     snackPosition: SnackPosition.BOTTOM,
// //     margin: const EdgeInsets.all(16),
// //     borderRadius: 14,
// //     backgroundColor: error ? const Color(0xFFEB5757) : _T.green,
// //     colorText: Colors.white,
// //   );

// //   Future<void> pick(String kind) async {
// //     try {
// //       final res = await FilePicker.platform.pickFiles(
// //         allowMultiple: true,
// //         withData: true,
// //         type: kind == 'image'
// //             ? FileType.image
// //             : kind == 'video'
// //                 ? FileType.video
// //                 : FileType.custom,
// //         allowedExtensions:
// //             kind == 'document' ? ['pdf', 'doc', 'docx', 'txt'] : null,
// //       );
// //       if (res == null) return;
// //       for (final f in res.files) {
// //         if (f.bytes == null) continue;
// //         final p = PickedFile(f.name, f.bytes!, kind);
// //         if (p.mb > maxFileMb) {
// //           toast('${f.name} is larger than ${maxFileMb.toInt()} MB');
// //           continue;
// //         }
// //         if (files.length >= 8) {
// //           toast('You can attach up to 8 files');
// //           break;
// //         }
// //         files.add(p);
// //       }
// //     } catch (_) {
// //       toast('Could not open file picker');
// //     }
// //   }

// //   /// Creates quote_requests/{id}. Returns the request number or null.
// //   Future<String?> submit({
// //     required String name,
// //     required String phone,
// //     required String email,
// //     required String address,
// //     required String description,
// //     required String budget,
// //   }) async {
// //     final user = _auth.currentUser;
// //     if (user == null) {
// //       toast('Please log in first');
// //       return null;
// //     }
// //     try {
// //       loading.value = true;
// //       final ref = _db.collection('quote_requests').doc();
// //       final number = 'QR-${DateTime.now().millisecondsSinceEpoch % 1000000}';

// //       // 1) upload attachments
// //       final uploaded = <Map<String, dynamic>>[];
// //       for (var i = 0; i < files.length; i++) {
// //         status.value = 'Uploading file ${i + 1} of ${files.length}…';
// //         final f = files[i];
// //         final sref = FirebaseStorage.instance.ref(
// //           'quote_requests/${user.uid}/${ref.id}/${i}_${f.name}',
// //         );
// //         await sref.putData(f.bytes);
// //         uploaded.add({
// //           'name': f.name,
// //           'type': f.kind,
// //           'url': await sref.getDownloadURL(),
// //         });
// //       }

// //       // 2) save request
// //       status.value = 'Sending your request…';
// //       await ref.set({
// //         'id': ref.id,
// //         'requestNumber': number,
// //         'userId': user.uid,
// //         'service': service.value!.name,
// //         'description': description.trim(),
// //         'budget': double.tryParse(budget.trim()) ?? 0,
// //         'customerName': name.trim(),
// //         'phone': phone.trim(),
// //         'email': email.trim().toLowerCase(),
// //         'address': address.trim(),
// //         'urgency': urgency.value,
// //         'preferredDate': Timestamp.fromDate(date.value!),
// //         'preferredSlot': '${slot.value} (${slots[slot.value]})',
// //         // 'attachments': uploaded,
// //         // ----- admin-managed fields -----
// //         'status': QuoteStatus.pending,
// //         'quoteAmount': null,
// //         'adminNote': '',
// //         'assignedTo': null,
// //         'statusHistory': [
// //           {
// //             'status': QuoteStatus.pending,
// //             'at': Timestamp.now(),
// //             'by': 'customer',
// //           },
// //         ],
// //         'createdAt': FieldValue.serverTimestamp(),
// //         'updatedAt': FieldValue.serverTimestamp(),
// //       });
// //       return number;
// //     } on FirebaseException catch (e) {
// //       toast(e.message ?? 'Could not submit request');
// //     } catch (_) {
// //       toast('Something went wrong. Please try again.');
// //     } finally {
// //       loading.value = false;
// //       status.value = '';
// //     }
// //     return null;
// //   }

// //   void reset() {
// //     service.value = null;
// //     urgency.value = 'Flexible';
// //     date.value = null;
// //     slot.value = 'Morning';
// //     files.clear();
// //   }
// // }

// // // ---------------------------------------------------------
// // // REQUEST PAGE
// // // ---------------------------------------------------------
// // class RequestView extends StatefulWidget {
// //   /// Optional: called when user taps "Track this request" on success page.
// //   final VoidCallback? onTrack;
// //   const RequestView({super.key, this.onTrack});

// //   @override
// //   State<RequestView> createState() => _RequestViewState();
// // }

// // class _RequestViewState extends State<RequestView> {
// //   final c = Get.put(RequestController());
// //   final _form = GlobalKey<FormState>();
// //   final _desc = TextEditingController();
// //   final _budget = TextEditingController();
// //   final _name = TextEditingController();
// //   final _phone = TextEditingController();
// //   final _email = TextEditingController();
// //   final _address = TextEditingController();

// //   @override
// //   void initState() {
// //     super.initState();
// //     _prefill();
// //   }

// //   Future<void> _prefill() async {
// //     final u = FirebaseAuth.instance.currentUser;
// //     if (u == null) return;
// //     _name.text = u.displayName ?? '';
// //     _email.text = u.email ?? '';
// //     try {
// //       final doc = await FirebaseFirestore.instance
// //           .collection('users')
// //           .doc(u.uid)
// //           .get();
// //       final d = doc.data();
// //       if (d != null && mounted) {
// //         if (_name.text.isEmpty) _name.text = d['name'] ?? '';
// //         _phone.text = d['phone'] ?? '';
// //       }
// //     } catch (_) {}
// //   }

// //   @override
// //   void dispose() {
// //     for (final t in [_desc, _budget, _name, _phone, _email, _address]) {
// //       t.dispose();
// //     }
// //     Get.delete<RequestController>();
// //     super.dispose();
// //   }

// //   String? _req(String? v) =>
// //       (v == null || v.trim().isEmpty) ? 'This field is required' : null;

// //   InputDecoration _dec(
// //     String label,
// //     IconData icon, {
// //     String? hint,
// //     String? prefixText,
// //   }) => InputDecoration(
// //     labelText: label,
// //     hintText: hint,
// //     prefixText: prefixText,
// //     prefixIcon: Icon(icon, color: _T.orange, size: 22),
// //     filled: true,
// //     fillColor: const Color(0xFFF8F9FC),
// //     contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
// //     border: _border(Colors.transparent),
// //     enabledBorder: _border(const Color(0xFFE6E9F2)),
// //     focusedBorder: _border(_T.orange, w: 1.6),
// //     errorBorder: _border(const Color(0xFFEB5757)),
// //     focusedErrorBorder: _border(const Color(0xFFEB5757), w: 1.6),
// //   );

// //   OutlineInputBorder _border(Color col, {double w = 1}) => OutlineInputBorder(
// //     borderRadius: BorderRadius.circular(14),
// //     borderSide: BorderSide(color: col, width: w),
// //   );

// //   // ---------- service bottom sheet ----------
// //   Future<void> _pickService() async {
// //     FocusScope.of(context).unfocus();
// //     final picked = await showModalBottomSheet<ServiceItem>(
// //       context: context,
// //       isScrollControlled: true,
// //       backgroundColor: Colors.transparent,
// //       builder: (_) => _ServiceSheet(selected: c.service.value),
// //     );
// //     if (picked != null) c.service.value = picked;
// //   }

// //   Future<void> _pickDate() async {
// //     final now = DateTime.now();
// //     final d = await showDatePicker(
// //       context: context,
// //       initialDate: c.date.value ?? now.add(const Duration(days: 2)),
// //       firstDate: now,
// //       lastDate: now.add(const Duration(days: 365)),
// //       builder: (ctx, child) => Theme(
// //         data: Theme.of(
// //           ctx,
// //         ).copyWith(colorScheme: const ColorScheme.light(primary: _T.orange)),
// //         child: child!,
// //       ),
// //     );
// //     if (d != null) c.date.value = d;
// //   }

// //   Future<void> _submit() async {
// //     if (c.service.value == null) {
// //       c.toast('Please choose a service');
// //       return;
// //     }
// //     if (!_form.currentState!.validate()) return;
// //     if (c.date.value == null) {
// //       c.toast('Please pick a preferred date');
// //       return;
// //     }
// //     final number = await c.submit(
// //       name: _name.text,
// //       phone: _phone.text,
// //       email: _email.text,
// //       address: _address.text,
// //       description: _desc.text,
// //       budget: _budget.text,
// //     );
// //     if (number == null) return;
// //     final svc = c.service.value!;
// //     c.reset();
// //     _desc.clear();
// //     _budget.clear();
// //     _address.clear();
// //     Get.to(
// //       () => _SuccessPage(number: number, service: svc, onTrack: widget.onTrack),
// //     );
// //   }

// //   // ---------- build ----------
// //   @override
// //   Widget build(BuildContext context) {
// //     return Scaffold(
// //       backgroundColor: _T.bg,
// //       body: Stack(
// //         children: [
// //           LayoutBuilder(
// //             builder: (context, box) {
// //               final wide = box.maxWidth > 640;
// //               return CustomScrollView(
// //                 slivers: [
// //                   SliverToBoxAdapter(child: _header(wide)),
// //                   SliverToBoxAdapter(
// //                     child: Center(
// //                       child: ConstrainedBox(
// //                         constraints: const BoxConstraints(maxWidth: 760),
// //                         child: Padding(
// //                           padding: EdgeInsets.fromLTRB(
// //                             wide ? 24 : 16,
// //                             0,
// //                             wide ? 24 : 16,
// //                             40,
// //                           ),
// //                           child: Form(
// //                             key: _form,
// //                             child: Column(
// //                               children: [
// //                                 _serviceCard(),
// //                                 _detailsCard(),
// //                                 _contactCard(wide),
// //                                 _whenWhereCard(wide),
// //                                 _attachCard(),
// //                                 const SizedBox(height: 22),
// //                                 _submitButton(),
// //                               ],
// //                             ),
// //                           ),
// //                         ),
// //                       ),
// //                     ),
// //                   ),
// //                 ],
// //               );
// //             },
// //           ),
// //           Obx(() => c.loading.value ? _loadingOverlay() : const SizedBox()),
// //         ],
// //       ),
// //     );
// //   }

// //   Widget _header(bool wide) => Container(
// //     padding: EdgeInsets.fromLTRB(
// //       24,
// //       MediaQuery.of(context).padding.top + 22,
// //       24,
// //       56,
// //     ),
// //     decoration: const BoxDecoration(
// //       gradient: LinearGradient(
// //         colors: [_T.orange, _T.orangeDark],
// //         begin: Alignment.topLeft,
// //         end: Alignment.bottomRight,
// //       ),
// //       borderRadius: BorderRadius.vertical(bottom: Radius.circular(32)),
// //     ),
// //     child: Center(
// //       child: ConstrainedBox(
// //         constraints: const BoxConstraints(maxWidth: 760),
// //         child: Row(
// //           children: [
// //             Expanded(
// //               child: Column(
// //                 crossAxisAlignment: CrossAxisAlignment.start,
// //                 children: [
// //                   const Text(
// //                     'Request a quote',
// //                     style: TextStyle(
// //                       color: Colors.white,
// //                       fontSize: 26,
// //                       fontWeight: FontWeight.w800,
// //                     ),
// //                   ),
// //                   const SizedBox(height: 6),
// //                   Text(
// //                     'Tell us about the job — we will get back with a price.',
// //                     style: TextStyle(
// //                       color: Colors.white.withValues(alpha: .9),
// //                       fontSize: 14,
// //                     ),
// //                   ),
// //                 ],
// //               ),
// //             ),
// //             const SizedBox(width: 12),
// //             Container(
// //               padding: const EdgeInsets.all(14),
// //               decoration: BoxDecoration(
// //                 color: Colors.white.withValues(alpha: .2),
// //                 shape: BoxShape.circle,
// //               ),
// //               child: const Icon(
// //                 Icons.request_quote_rounded,
// //                 color: Colors.white,
// //                 size: 34,
// //               ),
// //             ),
// //           ],
// //         ),
// //       ),
// //     ),
// //   );

// //   // ---------- section card ----------
// //   Widget _card(String title, IconData icon, int step, Widget child) =>
// //       Container(
// //         margin: const EdgeInsets.only(top: 16),
// //         padding: const EdgeInsets.all(18),
// //         decoration: BoxDecoration(
// //           color: Colors.white,
// //           borderRadius: BorderRadius.circular(22),
// //           boxShadow: [
// //             BoxShadow(
// //               color: _T.ink.withValues(alpha: .06),
// //               blurRadius: 24,
// //               offset: const Offset(0, 8),
// //             ),
// //           ],
// //         ),
// //         child: Column(
// //           crossAxisAlignment: CrossAxisAlignment.start,
// //           children: [
// //             Row(
// //               children: [
// //                 Container(
// //                   width: 34,
// //                   height: 34,
// //                   alignment: Alignment.center,
// //                   decoration: BoxDecoration(
// //                     color: _T.orange.withValues(alpha: .12),
// //                     borderRadius: BorderRadius.circular(11),
// //                   ),
// //                   child: Icon(icon, color: _T.orange, size: 19),
// //                 ),
// //                 const SizedBox(width: 10),
// //                 Expanded(
// //                   child: Text(
// //                     title,
// //                     style: const TextStyle(
// //                       fontSize: 16,
// //                       fontWeight: FontWeight.w800,
// //                       color: _T.ink,
// //                     ),
// //                   ),
// //                 ),
// //                 Text(
// //                   '$step/5',
// //                   style: const TextStyle(
// //                     color: _T.muted,
// //                     fontWeight: FontWeight.w600,
// //                     fontSize: 12,
// //                   ),
// //                 ),
// //               ],
// //             ),
// //             const SizedBox(height: 16),
// //             child,
// //           ],
// //         ),
// //       );

// //   // ---------- 1. service ----------
// //   Widget _serviceCard() => Transform.translate(
// //     offset: const Offset(0, -34),
// //     child: _card(
// //       'What do you need?',
// //       Icons.handyman_rounded,
// //       1,
// //       Obx(() {
// //         final s = c.service.value;
// //         return InkWell(
// //           borderRadius: BorderRadius.circular(16),
// //           onTap: _pickService,
// //           child: AnimatedContainer(
// //             duration: const Duration(milliseconds: 250),
// //             padding: const EdgeInsets.all(14),
// //             decoration: BoxDecoration(
// //               color: (s?.color ?? _T.orange).withValues(alpha: .08),
// //               borderRadius: BorderRadius.circular(16),
// //               border: Border.all(
// //                 color: (s?.color ?? _T.orange).withValues(alpha: .5),
// //                 width: 1.4,
// //               ),
// //             ),
// //             child: Row(
// //               children: [
// //                 Container(
// //                   width: 48,
// //                   height: 48,
// //                   decoration: BoxDecoration(
// //                     color: s?.color ?? _T.orange,
// //                     borderRadius: BorderRadius.circular(14),
// //                   ),
// //                   child: Icon(
// //                     s?.icon ?? Icons.add_rounded,
// //                     color: Colors.white,
// //                     size: 26,
// //                   ),
// //                 ),
// //                 const SizedBox(width: 14),
// //                 Expanded(
// //                   child: Column(
// //                     crossAxisAlignment: CrossAxisAlignment.start,
// //                     children: [
// //                       Text(
// //                         s?.name ?? 'Choose a service',
// //                         style: const TextStyle(
// //                           fontSize: 16,
// //                           fontWeight: FontWeight.w800,
// //                           color: _T.ink,
// //                         ),
// //                       ),
// //                       const SizedBox(height: 2),
// //                       Text(
// //                         s == null ? 'Tap to see all services' : 'Tap to change',
// //                         style: const TextStyle(color: _T.muted, fontSize: 12.5),
// //                       ),
// //                     ],
// //                   ),
// //                 ),
// //                 const Icon(
// //                   Icons.keyboard_arrow_down_rounded,
// //                   color: _T.ink,
// //                   size: 28,
// //                 ),
// //               ],
// //             ),
// //           ),
// //         );
// //       }),
// //     ),
// //   );

// //   // ---------- 2. details ----------
// //   Widget _detailsCard() => Transform.translate(
// //     offset: const Offset(0, -34),
// //     child: _card(
// //       'Job details',
// //       Icons.edit_note_rounded,
// //       2,
// //       Column(
// //         children: [
// //           TextFormField(
// //             controller: _desc,
// //             maxLines: 4,
// //             maxLength: 500,
// //             textCapitalization: TextCapitalization.sentences,
// //             validator: (v) => (v == null || v.trim().length < 10)
// //                 ? 'Please describe the work (min 10 characters)'
// //                 : null,
// //             decoration: _dec(
// //               'Description of work',
// //               Icons.notes_rounded,
// //               hint: 'e.g. Kitchen sink is leaking underneath…',
// //             ),
// //           ),
// //           const SizedBox(height: 6),
// //           TextFormField(
// //             controller: _budget,
// //             keyboardType: const TextInputType.numberWithOptions(decimal: true),
// //             validator: (v) {
// //               if (_req(v) != null) return 'This field is required';
// //               if (double.tryParse(v!.trim()) == null) return 'Enter a number';
// //               return null;
// //             },
// //             decoration: _dec(
// //               'Estimated budget',
// //               Icons.payments_outlined,
// //               prefixText: '\$ ',
// //             ),
// //           ),
// //           const SizedBox(height: 16),
// //           Align(
// //             alignment: Alignment.centerLeft,
// //             child: Text(
// //               'How soon?',
// //               style: TextStyle(
// //                 fontWeight: FontWeight.w700,
// //                 color: _T.ink.withValues(alpha: .8),
// //               ),
// //             ),
// //           ),
// //           const SizedBox(height: 8),
// //           Obx(
// //             () => Row(
// //               children: [
// //                 for (final u in RequestController.urgencies)
// //                   Expanded(
// //                     child: Padding(
// //                       padding: EdgeInsets.only(
// //                         right: u == RequestController.urgencies.last ? 0 : 8,
// //                       ),
// //                       child: _pill(
// //                         u,
// //                         u == 'Urgent'
// //                             ? Icons.bolt_rounded
// //                             : u == 'Soon'
// //                             ? Icons.timelapse_rounded
// //                             : Icons.event_available_rounded,
// //                         c.urgency.value == u,
// //                         () => c.urgency.value = u,
// //                       ),
// //                     ),
// //                   ),
// //               ],
// //             ),
// //           ),
// //         ],
// //       ),
// //     ),
// //   );

// //   Widget _pill(
// //     String label,
// //     IconData icon,
// //     bool on,
// //     VoidCallback tap, {
// //     String? sub,
// //   }) => InkWell(
// //     borderRadius: BorderRadius.circular(14),
// //     onTap: tap,
// //     child: AnimatedContainer(
// //       duration: const Duration(milliseconds: 200),
// //       padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 6),
// //       decoration: BoxDecoration(
// //         color: on ? _T.orange : const Color(0xFFF8F9FC),
// //         borderRadius: BorderRadius.circular(14),
// //         border: Border.all(color: on ? _T.orange : const Color(0xFFE6E9F2)),
// //       ),
// //       child: Column(
// //         mainAxisSize: MainAxisSize.min,
// //         children: [
// //           Icon(icon, size: 20, color: on ? Colors.white : _T.muted),
// //           const SizedBox(height: 4),
// //           Text(
// //             label,
// //             style: TextStyle(
// //               fontWeight: FontWeight.w700,
// //               fontSize: 13,
// //               color: on ? Colors.white : _T.ink,
// //             ),
// //           ),
// //           if (sub != null)
// //             Text(
// //               sub,
// //               style: TextStyle(
// //                 fontSize: 10.5,
// //                 color: on ? Colors.white70 : _T.muted,
// //               ),
// //             ),
// //         ],
// //       ),
// //     ),
// //   );

// //   // ---------- 3. contact ----------
// //   Widget _contactCard(bool wide) {
// //     final phone = TextFormField(
// //       controller: _phone,
// //       keyboardType: TextInputType.phone,
// //       validator: _req,
// //       decoration: _dec('Phone', Icons.call_outlined),
// //     );
// //     final email = TextFormField(
// //       controller: _email,
// //       keyboardType: TextInputType.emailAddress,
// //       validator: (v) =>
// //           GetUtils.isEmail((v ?? '').trim()) ? null : 'Enter a valid email',
// //       decoration: _dec('Email', Icons.mail_outline_rounded),
// //     );
// //     return Transform.translate(
// //       offset: const Offset(0, -34),
// //       child: _card(
// //         'Your contact info',
// //         Icons.person_rounded,
// //         3,
// //         Column(
// //           children: [
// //             TextFormField(
// //               controller: _name,
// //               textCapitalization: TextCapitalization.words,
// //               validator: _req,
// //               decoration: _dec('Full name', Icons.person_outline_rounded),
// //             ),
// //             const SizedBox(height: 14),
// //             wide
// //                 ? Row(
// //                     children: [
// //                       Expanded(child: phone),
// //                       const SizedBox(width: 12),
// //                       Expanded(child: email),
// //                     ],
// //                   )
// //                 : Column(children: [phone, const SizedBox(height: 14), email]),
// //           ],
// //         ),
// //       ),
// //     );
// //   }

// //   // ---------- 4. when & where ----------
// //   Widget _whenWhereCard(bool wide) => Transform.translate(
// //     offset: const Offset(0, -34),
// //     child: _card(
// //       'When & where',
// //       Icons.place_rounded,
// //       4,
// //       Column(
// //         children: [
// //           TextFormField(
// //             controller: _address,
// //             maxLines: 2,
// //             minLines: 1,
// //             validator: _req,
// //             textCapitalization: TextCapitalization.words,
// //             decoration: _dec(
// //               'Property address',
// //               Icons.home_outlined,
// //               hint: 'Street, city, ZIP',
// //             ),
// //           ),
// //           const SizedBox(height: 14),
// //           Obx(() {
// //             final d = c.date.value;
// //             return InkWell(
// //               borderRadius: BorderRadius.circular(14),
// //               onTap: _pickDate,
// //               child: InputDecorator(
// //                 decoration: _dec('Preferred date', Icons.calendar_month_rounded)
// //                     .copyWith(
// //                       suffixIcon: const Icon(Icons.arrow_drop_down_rounded),
// //                     ),
// //                 child: Text(
// //                   d == null
// //                       ? 'Select a date'
// //                       : '${_months[d.month - 1]} ${d.day}, ${d.year}',
// //                   style: TextStyle(
// //                     color: d == null ? _T.muted : _T.ink,
// //                     fontWeight: FontWeight.w600,
// //                   ),
// //                 ),
// //               ),
// //             );
// //           }),
// //           const SizedBox(height: 14),
// //           Obx(
// //             () => Row(
// //               children: [
// //                 for (final e in RequestController.slots.entries)
// //                   Expanded(
// //                     child: Padding(
// //                       padding: EdgeInsets.only(
// //                         right: e.key == 'Evening' ? 0 : 8,
// //                       ),
// //                       child: _pill(
// //                         e.key,
// //                         e.key == 'Morning'
// //                             ? Icons.wb_sunny_outlined
// //                             : e.key == 'Afternoon'
// //                             ? Icons.wb_twilight_rounded
// //                             : Icons.nights_stay_outlined,
// //                         c.slot.value == e.key,
// //                         () => c.slot.value = e.key,
// //                         sub: e.value,
// //                       ),
// //                     ),
// //                   ),
// //               ],
// //             ),
// //           ),
// //         ],
// //       ),
// //     ),
// //   );

// //   static const _months = [
// //     'Jan',
// //     'Feb',
// //     'Mar',
// //     'Apr',
// //     'May',
// //     'Jun',
// //     'Jul',
// //     'Aug',
// //     'Sep',
// //     'Oct',
// //     'Nov',
// //     'Dec',
// //   ];

// //   // ---------- 5. attachments ----------
// //   Widget _attachCard() => Transform.translate(
// //     offset: const Offset(0, -34),
// //     child: _card(
// //       'Photos, videos & documents',
// //       Icons.attach_file_rounded,
// //       5,
// //       Column(
// //         crossAxisAlignment: CrossAxisAlignment.start,
// //         children: [
// //           Row(
// //             children: [
// //               _attachBtn(Icons.photo_camera_back_outlined, 'Photo', 'image'),
// //               const SizedBox(width: 10),
// //               _attachBtn(Icons.videocam_outlined, 'Video', 'video'),
// //               const SizedBox(width: 10),
// //               _attachBtn(Icons.description_outlined, 'Document', 'document'),
// //             ],
// //           ),
// //           const SizedBox(height: 6),
// //           Text(
// //             'Optional • up to 8 files • max 20 MB each',
// //             style: TextStyle(color: _T.muted, fontSize: 12),
// //           ),
// //           Obx(
// //             () => c.files.isEmpty
// //                 ? const SizedBox()
// //                 : Padding(
// //                     padding: const EdgeInsets.only(top: 12),
// //                     child: Column(
// //                       children: [
// //                         for (var i = 0; i < c.files.length; i++)
// //                           _fileTile(c.files[i], i),
// //                       ],
// //                     ),
// //                   ),
// //           ),
// //         ],
// //       ),
// //     ),
// //   );

// //   Widget _attachBtn(IconData icon, String label, String kind) => Expanded(
// //     child: InkWell(
// //       borderRadius: BorderRadius.circular(14),
// //       // onTap: () => c.pick(kind),
// //       child: Container(
// //         padding: const EdgeInsets.symmetric(vertical: 14),
// //         decoration: BoxDecoration(
// //           color: _T.orange.withValues(alpha: .06),
// //           borderRadius: BorderRadius.circular(14),
// //           border: Border.all(color: _T.orange.withValues(alpha: .35)),
// //         ),
// //         child: Column(
// //           children: [
// //             Icon(icon, color: _T.orange),
// //             const SizedBox(height: 4),
// //             Text(
// //               label,
// //               style: const TextStyle(
// //                 fontSize: 12.5,
// //                 fontWeight: FontWeight.w700,
// //                 color: _T.ink,
// //               ),
// //             ),
// //           ],
// //         ),
// //       ),
// //     ),
// //   );

// //   Widget _fileTile(PickedFile f, int i) => Container(
// //     margin: const EdgeInsets.only(bottom: 8),
// //     padding: const EdgeInsets.fromLTRB(8, 8, 4, 8),
// //     decoration: BoxDecoration(
// //       color: const Color(0xFFF8F9FC),
// //       borderRadius: BorderRadius.circular(14),
// //     ),
// //     child: Row(
// //       children: [
// //         ClipRRect(
// //           borderRadius: BorderRadius.circular(10),
// //           child: SizedBox(
// //             width: 44,
// //             height: 44,
// //             child: f.kind == 'image'
// //                 ? Image.memory(f.bytes, fit: BoxFit.cover)
// //                 : Container(
// //                     color: _T.orange.withValues(alpha: .12),
// //                     child: Icon(
// //                       f.kind == 'video'
// //                           ? Icons.play_circle_outline_rounded
// //                           : Icons.insert_drive_file_outlined,
// //                       color: _T.orange,
// //                     ),
// //                   ),
// //           ),
// //         ),
// //         const SizedBox(width: 12),
// //         Expanded(
// //           child: Column(
// //             crossAxisAlignment: CrossAxisAlignment.start,
// //             children: [
// //               Text(
// //                 f.name,
// //                 maxLines: 1,
// //                 overflow: TextOverflow.ellipsis,
// //                 style: const TextStyle(
// //                   fontWeight: FontWeight.w700,
// //                   fontSize: 13.5,
// //                 ),
// //               ),
// //               Text(
// //                 '${f.mb.toStringAsFixed(1)} MB',
// //                 style: const TextStyle(color: _T.muted, fontSize: 12),
// //               ),
// //             ],
// //           ),
// //         ),
// //         IconButton(
// //           onPressed: () => c.files.removeAt(i),
// //           icon: const Icon(Icons.close_rounded, size: 20),
// //         ),
// //       ],
// //     ),
// //   );

// //   // ---------- submit ----------
// //   Widget _submitButton() => Transform.translate(
// //     offset: const Offset(0, -34),
// //     child: SizedBox(
// //       width: double.infinity,
// //       height: 56,
// //       child: ElevatedButton.icon(
// //         onPressed: _submit,
// //         icon: const Icon(Icons.send_rounded),
// //         label: const Text(
// //           'Submit request',
// //           style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
// //         ),
// //         style: ElevatedButton.styleFrom(
// //           backgroundColor: _T.orange,
// //           foregroundColor: Colors.white,
// //           elevation: 6,
// //           shadowColor: _T.orange.withValues(alpha: .5),
// //           shape: RoundedRectangleBorder(
// //             borderRadius: BorderRadius.circular(18),
// //           ),
// //         ),
// //       ),
// //     ),
// //   );

// //   Widget _loadingOverlay() => Container(
// //     color: Colors.black.withValues(alpha: .45),
// //     alignment: Alignment.center,
// //     child: Container(
// //       padding: const EdgeInsets.all(24),
// //       decoration: BoxDecoration(
// //         color: Colors.white,
// //         borderRadius: BorderRadius.circular(20),
// //       ),
// //       child: Column(
// //         mainAxisSize: MainAxisSize.min,
// //         children: [
// //           const CircularProgressIndicator(color: _T.orange),
// //           const SizedBox(height: 16),
// //           Obx(
// //             () => Text(
// //               c.status.value.isEmpty ? 'Please wait…' : c.status.value,
// //               style: const TextStyle(fontWeight: FontWeight.w600),
// //             ),
// //           ),
// //         ],
// //       ),
// //     ),
// //   );
// // }

// // // ---------------------------------------------------------
// // // SERVICE PICKER BOTTOM SHEET (creative dropdown)
// // // ---------------------------------------------------------
// // class _ServiceSheet extends StatelessWidget {
// //   final ServiceItem? selected;
// //   const _ServiceSheet({this.selected});

// //   @override
// //   Widget build(BuildContext context) {
// //     final w = MediaQuery.of(context).size.width;
// //     final cols = w > 700 ? 5 : (w > 420 ? 3 : 2);
// //     return Container(
// //       constraints: BoxConstraints(
// //         maxHeight: MediaQuery.of(context).size.height * .8,
// //       ),
// //       padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
// //       decoration: const BoxDecoration(
// //         color: Colors.white,
// //         borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
// //       ),
// //       child: SafeArea(
// //         top: false,
// //         child: Column(
// //           mainAxisSize: MainAxisSize.min,
// //           children: [
// //             Container(
// //               width: 44,
// //               height: 5,
// //               decoration: BoxDecoration(
// //                 color: const Color(0xFFDDE1EA),
// //                 borderRadius: BorderRadius.circular(8),
// //               ),
// //             ),
// //             const SizedBox(height: 16),
// //             const Align(
// //               alignment: Alignment.centerLeft,
// //               child: Text(
// //                 'Select a service',
// //                 style: TextStyle(
// //                   fontSize: 20,
// //                   fontWeight: FontWeight.w800,
// //                   color: _T.ink,
// //                 ),
// //               ),
// //             ),
// //             const SizedBox(height: 14),
// //             Flexible(
// //               child: GridView.builder(
// //                 shrinkWrap: true,
// //                 itemCount: kServiceItems.length,
// //                 gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
// //                   crossAxisCount: cols,
// //                   mainAxisSpacing: 12,
// //                   crossAxisSpacing: 12,
// //                   childAspectRatio: 1.15,
// //                 ),
// //                 itemBuilder: (_, i) {
// //                   final s = kServiceItems[i];
// //                   final on = selected?.name == s.name;
// //                   return TweenAnimationBuilder<double>(
// //                     tween: Tween(begin: 0, end: 1),
// //                     duration: Duration(milliseconds: 250 + i * 40),
// //                     curve: Curves.easeOutBack,
// //                     builder: (_, v, child) => Transform.scale(
// //                       scale: v.clamp(0.0, 1.2),
// //                       child: Opacity(opacity: v.clamp(0.0, 1.0), child: child),
// //                     ),
// //                     child: InkWell(
// //                       borderRadius: BorderRadius.circular(18),
// //                       onTap: () => Navigator.pop(context, s),
// //                       child: Container(
// //                         decoration: BoxDecoration(
// //                           color: on ? s.color : s.color.withValues(alpha: .1),
// //                           borderRadius: BorderRadius.circular(18),
// //                           border: Border.all(
// //                             color: s.color.withValues(alpha: on ? 1 : .35),
// //                             width: on ? 2 : 1,
// //                           ),
// //                         ),
// //                         child: Stack(
// //                           children: [
// //                             Center(
// //                               child: Column(
// //                                 mainAxisAlignment: MainAxisAlignment.center,
// //                                 children: [
// //                                   Icon(
// //                                     s.icon,
// //                                     size: 32,
// //                                     color: on ? Colors.white : s.color,
// //                                   ),
// //                                   const SizedBox(height: 8),
// //                                   Text(
// //                                     s.name,
// //                                     style: TextStyle(
// //                                       fontWeight: FontWeight.w800,
// //                                       fontSize: 13.5,
// //                                       color: on ? Colors.white : _T.ink,
// //                                     ),
// //                                   ),
// //                                 ],
// //                               ),
// //                             ),
// //                             if (on)
// //                               const Positioned(
// //                                 top: 8,
// //                                 right: 8,
// //                                 child: Icon(
// //                                   Icons.check_circle,
// //                                   color: Colors.white,
// //                                   size: 20,
// //                                 ),
// //                               ),
// //                           ],
// //                         ),
// //                       ),
// //                     ),
// //                   );
// //                 },
// //               ),
// //             ),
// //           ],
// //         ),
// //       ),
// //     );
// //   }
// // }

// // // ---------------------------------------------------------
// // // SUCCESS PAGE
// // // ---------------------------------------------------------
// // class _SuccessPage extends StatelessWidget {
// //   final String number;
// //   final ServiceItem service;
// //   final VoidCallback? onTrack;
// //   const _SuccessPage({
// //     required this.number,
// //     required this.service,
// //     this.onTrack,
// //   });

// //   @override
// //   Widget build(BuildContext context) {
// //     return Scaffold(
// //       backgroundColor: _T.bg,
// //       body: SafeArea(
// //         child: Center(
// //           child: ConstrainedBox(
// //             constraints: const BoxConstraints(maxWidth: 460),
// //             child: Padding(
// //               padding: const EdgeInsets.all(28),
// //               child: Column(
// //                 mainAxisAlignment: MainAxisAlignment.center,
// //                 children: [
// //                   TweenAnimationBuilder<double>(
// //                     tween: Tween(begin: 0, end: 1),
// //                     duration: const Duration(milliseconds: 700),
// //                     curve: Curves.elasticOut,
// //                     builder: (_, v, child) =>
// //                         Transform.scale(scale: v, child: child),
// //                     child: Container(
// //                       padding: const EdgeInsets.all(26),
// //                       decoration: BoxDecoration(
// //                         color: _T.green.withValues(alpha: .12),
// //                         shape: BoxShape.circle,
// //                       ),
// //                       child: const Icon(
// //                         Icons.check_circle_rounded,
// //                         color: _T.green,
// //                         size: 84,
// //                       ),
// //                     ),
// //                   ),
// //                   const SizedBox(height: 24),
// //                   const Text(
// //                     'Request submitted!',
// //                     style: TextStyle(
// //                       fontSize: 24,
// //                       fontWeight: FontWeight.w800,
// //                       color: _T.ink,
// //                     ),
// //                   ),
// //                   const SizedBox(height: 10),
// //                   Text(
// //                     'We received your ${service.name} request. You will get a quote and a notification shortly.',
// //                     textAlign: TextAlign.center,
// //                     style: const TextStyle(color: _T.muted, height: 1.4),
// //                   ),
// //                   const SizedBox(height: 20),
// //                   Container(
// //                     padding: const EdgeInsets.symmetric(
// //                       horizontal: 18,
// //                       vertical: 12,
// //                     ),
// //                     decoration: BoxDecoration(
// //                       color: Colors.white,
// //                       borderRadius: BorderRadius.circular(14),
// //                     ),
// //                     child: Row(
// //                       mainAxisSize: MainAxisSize.min,
// //                       children: [
// //                         Icon(service.icon, color: service.color),
// //                         const SizedBox(width: 10),
// //                         Text(
// //                           number,
// //                           style: const TextStyle(
// //                             fontWeight: FontWeight.w800,
// //                             letterSpacing: 1,
// //                             color: _T.ink,
// //                           ),
// //                         ),
// //                       ],
// //                     ),
// //                   ),
// //                   const SizedBox(height: 28),
// //                   SizedBox(
// //                     width: double.infinity,
// //                     height: 52,
// //                     child: ElevatedButton(
// //                       onPressed: () {
// //                         Get.back();
// //                         onTrack?.call();
// //                       },
// //                       style: ElevatedButton.styleFrom(
// //                         backgroundColor: _T.orange,
// //                         foregroundColor: Colors.white,
// //                         shape: RoundedRectangleBorder(
// //                           borderRadius: BorderRadius.circular(16),
// //                         ),
// //                       ),
// //                       child: const Text(
// //                         'Track this request',
// //                         style: TextStyle(fontWeight: FontWeight.w800),
// //                       ),
// //                     ),
// //                   ),
// //                   TextButton(
// //                     onPressed: Get.back,
// //                     child: const Text(
// //                       'Back to home',
// //                       style: TextStyle(color: _T.muted),
// //                     ),
// //                   ),
// //                 ],
// //               ),
// //             ),
// //           ),
// //         ),
// //       ),
// //     );
// //   }
// // }

// // // import 'package:flutter/material.dart';
// // // import 'package:get/get.dart';
// // // import '../controllers/app_controller.dart';
// // // import '../core/theme.dart';
// // // import '../core/widgets.dart';
// // // import '../data/models.dart';

// // // class RequestController extends GetxController {
// // //   final service = ''.obs, addr = kAddresses.first.obs, files = <String>[].obs;
// // //   final date = DateTime.now().add(const Duration(days: 3)).obs;
// // //   final time = const TimeOfDay(hour: 10, minute: 0).obs;
// // //   final desc = TextEditingController(), budget = TextEditingController();
// // //   final name = TextEditingController(text: 'Sarah Malik'), phone = TextEditingController(text: '(201) 555-0148');
// // //   final email = TextEditingController(text: 'sarah.malik@email.com');
// // //   final key = GlobalKey<FormState>();
// // // }

// // // class RequestView extends StatelessWidget {
// // //   RequestView({super.key});
// // //   final r = Get.put(RequestController());
// // //   final c = Get.find<AppController>();
// // //   String? _req(String? v) => (v == null || v.trim().isEmpty) ? 'Required' : null;

// // //   @override
// // //   Widget build(BuildContext context) => Body(Form(
// // //         key: r.key,
// // //         child: ListView(padding: const EdgeInsets.all(20), children: [
// // //           h('Request a quote', size: 22), gap(4), sub('Tell us about the job and we will send a quote.'), gap(16),
// // //           h('Service', size: 15), gap(8),
// // //           Obx(() => Wrap(spacing: 8, runSpacing: 8, children: [
// // //                 for (final s in kServices)
// // //                   ChoiceChip(
// // //                       avatar: Icon(s.$2, size: 16), label: Text(s.$1), selected: r.service.value == s.$1,
// // //                       selectedColor: C.orange.withValues(alpha: .18), onSelected: (_) => r.service.value = s.$1),
// // //               ])),
// // //           gap(16),
// // //           TextFormField(controller: r.desc, maxLines: 4, validator: _req, decoration: const InputDecoration(labelText: 'Description of work')),
// // //           gap(),
// // //           TextFormField(controller: r.budget, keyboardType: TextInputType.number, validator: _req,
// // //               decoration: const InputDecoration(labelText: 'Budget', prefixText: '\$ ')),
// // //           gap(),
// // //           TextFormField(controller: r.name, validator: _req, decoration: const InputDecoration(labelText: 'Full name')),
// // //           gap(),
// // //           LayoutBuilder(builder: (_, b) {
// // //             final f1 = TextFormField(controller: r.phone, validator: _req, keyboardType: TextInputType.phone, decoration: const InputDecoration(labelText: 'Phone'));
// // //             final f2 = TextFormField(controller: r.email, validator: _req, keyboardType: TextInputType.emailAddress, decoration: const InputDecoration(labelText: 'Email'));
// // //             return b.maxWidth > 560
// // //                 ? Row(children: [Expanded(child: f1), const SizedBox(width: 12), Expanded(child: f2)])
// // //                 : Column(children: [f1, gap(), f2]);
// // //           }),
// // //           gap(),
// // //           Obx(() => DropdownButtonFormField<String>(
// // //               initialValue: r.addr.value, decoration: const InputDecoration(labelText: 'Property address'),
// // //               items: [for (final a in kAddresses) DropdownMenuItem(value: a, child: Text(a, overflow: TextOverflow.ellipsis))],
// // //               onChanged: (v) => r.addr.value = v!)),
// // //           gap(),
// // //           Row(children: [
// // //             Expanded(child: Obx(() => OutlinedButton.icon(
// // //                 icon: const Icon(Icons.calendar_today, size: 16),
// // //                 label: Text('${r.date.value.month}/${r.date.value.day}/${r.date.value.year}'),
// // //                 onPressed: () async {
// // //                   final d = await showDatePicker(context: context, initialDate: r.date.value, firstDate: DateTime.now(), lastDate: DateTime.now().add(const Duration(days: 365)));
// // //                   if (d != null) r.date.value = d;
// // //                 }))),
// // //             const SizedBox(width: 12),
// // //             Expanded(child: Obx(() => OutlinedButton.icon(
// // //                 icon: const Icon(Icons.schedule, size: 16), label: Text(r.time.value.format(context)),
// // //                 onPressed: () async {
// // //                   final t = await showTimePicker(context: context, initialTime: r.time.value);
// // //                   if (t != null) r.time.value = t;
// // //                 }))),
// // //           ]),
// // //           gap(16), h('Photos, videos & documents', size: 15), gap(8),
// // //           Obx(() => Wrap(spacing: 8, runSpacing: 8, children: [
// // //                 for (final f in r.files) Chip(label: Text(f), onDeleted: () => r.files.remove(f)),
// // //                 ActionChip(avatar: const Icon(Icons.image_outlined, size: 16), label: const Text('Photo'), onPressed: () => r.files.add('photo_${r.files.length + 1}.jpg')),
// // //                 ActionChip(avatar: const Icon(Icons.videocam_outlined, size: 16), label: const Text('Video'), onPressed: () => r.files.add('video_${r.files.length + 1}.mp4')),
// // //                 ActionChip(avatar: const Icon(Icons.description_outlined, size: 16), label: const Text('Document'), onPressed: () => r.files.add('doc_${r.files.length + 1}.pdf')),
// // //               ])),
// // //           gap(24),
// // //           cta('Submit request', () {
// // //             if (r.service.value.isEmpty) return toast('Please select a service');
// // //             if (!r.key.currentState!.validate()) return;
// // //             c.submitRequest(r.service.value, r.addr.value, '${r.date.value.month}/${r.date.value.day}/${r.date.value.year}');
// // //             final s = r.service.value;
// // //             r.service.value = ''; r.desc.clear(); r.budget.clear(); r.files.clear();
// // //             Get.to(() => _Done(s));
// // //           }),
// // //         ]),
// // //       ));
// // // }

// // // class _Done extends StatelessWidget {
// // //   final String service;
// // //   const _Done(this.service);
// // //   @override
// // //   Widget build(BuildContext context) => Scaffold(
// // //       body: SafeArea(child: Body(Padding(padding: const EdgeInsets.all(28), child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
// // //         const Icon(Icons.check_circle, color: C.green, size: 72), gap(),
// // //         h('Request submitted!', size: 22), gap(8),
// // //         Text('We received your $service request. You will get a quote and a notification shortly.', textAlign: TextAlign.center),
// // //         gap(24),
// // //         cta('Track this request', () { Get.back(); Get.find<AppController>().tab.value = 3; }),
// // //         TextButton(onPressed: () { Get.back(); Get.find<AppController>().tab.value = 0; }, child: const Text('Back to home')),
// // //       ])))));
// // // }
