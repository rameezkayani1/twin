// // =============================================================
// // jobs_view.dart — Customer "Your jobs" (LIVE Firebase, responsive)
// //
// // Jobs are read from the SAME collection as quotes_view.dart:
// //   quote_requests  where userId == current user
// // A request becomes a "job" once the deposit is paid / it is scheduled:
// //   status 'accepted' + depositPaid == true   -> stage 0 "Deposit paid"
// //   status 'scheduled'                        -> stage 1 "Scheduled"
// //   status 'completed'                        -> last stage "Completed"
// // Admin/crew can move the job forward with an optional int field `jobStage`
// // (0..7, see kStages). When jobStage changes the customer gets a live banner.
// //
// // Optional fields the admin may write on quote_requests/{id}:
// //   scheduledDate Timestamp   (falls back to preferredDate)
// //   scheduledTime String      (falls back to preferredSlot)
// //   crew          String | List<String>
// //   jobStage      int
// //
// // pubspec: get, firebase_auth, cloud_firestore
// // Usage:   Get.to(() => JobsView());    // or use as a tab body
// // Works standalone next to quotes_view.dart (no shared private names).
// // =============================================================
// import 'dart:async';

// import 'package:cloud_firestore/cloud_firestore.dart';
// import 'package:firebase_auth/firebase_auth.dart';
// import 'package:flutter/material.dart';
// import 'package:get/get.dart';

// // ---------------------------------------------------------
// // CONFIG
// // ---------------------------------------------------------
// const kJobsCollection = 'quote_requests';

// /// Index in this list == `jobStage` value stored in Firebase.
// const kStages = [
//   'Deposit paid',
//   'Scheduled',
//   'Crew assigned',
//   'On the way',
//   'Arrived',
//   'Work in progress',
//   'Final check',
//   'Completed',
// ];

// /// Stage at/after which a job moves to the "Past" tab.
// const kDoneStage = 7;

// // ---------------------------------------------------------
// // THEME + HELPERS
// // ---------------------------------------------------------
// class _C {
//   static const orange = Color(0xFFFF7A00);
//   static const ink = Color(0xFF1B1F2A);
//   static const bg = Color(0xFFF5F3EF);
//   static const surface = Colors.white;
//   static const muted = Color(0xFF787F90);
//   static const line = Color(0xFFE9E5DD);
//   static const green = Color(0xFF1FAE6B);
//   static const red = Color(0xFFE4513F);
//   static const blue = Color(0xFF2D8CDB);
// }

// const _months = [
//   'Jan',
//   'Feb',
//   'Mar',
//   'Apr',
//   'May',
//   'Jun',
//   'Jul',
//   'Aug',
//   'Sep',
//   'Oct',
//   'Nov',
//   'Dec',
// ];
// String _date(DateTime? d) =>
//     d == null ? '—' : '${_months[d.month - 1]} ${d.day}, ${d.year}';

// String _money(num v) {
//   final p = v.toStringAsFixed(2).split('.');
//   final w = p[0].replaceAllMapped(RegExp(r'\B(?=(\d{3})+(?!\d))'), (_) => ',');
//   return '\$$w.${p[1]}';
// }

// IconData _icon(String s) {
//   switch (s) {
//     case 'Plumbing':
//       return Icons.plumbing;
//     case 'Electrical':
//       return Icons.electrical_services;
//     case 'Painting':
//       return Icons.format_paint_rounded;
//     case 'Cleaning':
//       return Icons.cleaning_services_rounded;
//     case 'Pressure Washing':
//       return Icons.water_drop_rounded;
//     case 'Assembly':
//       return Icons.construction_rounded;
//     case 'Waste Disposal':
//       return Icons.delete_outline_rounded;
//     case 'Lawn Services':
//     case 'Landscaping':
//       return Icons.yard_rounded;
//     case 'AC Repair':
//       return Icons.ac_unit;
//     case 'Carpentry':
//       return Icons.carpenter;
//     case 'Roofing':
//       return Icons.roofing;
//     case 'Moving':
//       return Icons.local_shipping_rounded;
//     default:
//       return Icons.handyman_rounded;
//   }
// }

// String _stageLabel(int s) => kStages[s.clamp(0, kStages.length - 1)];

// Color _stageColor(int s) {
//   if (s >= kDoneStage) return _C.green;
//   if (s >= 3) return _C.blue; // on the way / working
//   return _C.orange;
// }

// // ---------------------------------------------------------
// // MODEL
// // ---------------------------------------------------------
// class JobModel {
//   final String id, number, service, time, crew, address, notes, status;
//   final int stage;
//   final double amount;
//   final DateTime? date, updatedAt;

//   JobModel({
//     required this.id,
//     required this.number,
//     required this.service,
//     required this.time,
//     required this.crew,
//     required this.address,
//     required this.notes,
//     required this.status,
//     required this.stage,
//     required this.amount,
//     this.date,
//     this.updatedAt,
//   });

//   /// Only paid / scheduled / completed requests count as jobs.
//   static bool isJob(Map<String, dynamic> d) {
//     final st = (d['status'] ?? '').toString();
//     return (st == 'accepted' && d['depositPaid'] == true) ||
//         st == 'scheduled' ||
//         st == 'completed';
//   }

//   factory JobModel.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
//     final d = doc.data() ?? {};
//     DateTime? dt(dynamic v) {
//       if (v is Timestamp) return v.toDate();
//       if (v is String) return DateTime.tryParse(v);
//       return null;
//     }

//     final crewRaw = d['crew'];
//     final crew = crewRaw is List
//         ? crewRaw.map((e) => '$e').join(', ')
//         : (crewRaw ?? '').toString();

//     final status = (d['status'] ?? '').toString();
//     final js = d['jobStage'];
//     int stage = js is num ? js.toInt() : (int.tryParse('$js') ?? -1);
//     if (stage < 0) {
//       stage = status == 'completed'
//           ? kDoneStage
//           : (status == 'scheduled' ? 1 : 0);
//     }
//     if (status == 'completed') stage = kDoneStage;

//     final q = d['quote'];
//     final amount = q is Map && q['total'] is num
//         ? (q['total'] as num).toDouble()
//         : (d['quoteAmount'] is num
//               ? (d['quoteAmount'] as num).toDouble()
//               : 0.0);

//     return JobModel(
//       id: doc.id,
//       number: (d['requestNumber'] ?? doc.id.substring(0, 6).toUpperCase())
//           .toString(),
//       service: (d['service'] ?? 'Service').toString(),
//       time: (d['scheduledTime'] ?? d['preferredSlot'] ?? '').toString(),
//       crew: crew,
//       address: (d['address'] ?? '').toString(),
//       notes: (d['adminNote'] ?? '').toString(),
//       status: status,
//       stage: stage,
//       amount: amount,
//       date: dt(d['scheduledDate']) ?? dt(d['preferredDate']),
//       updatedAt: dt(d['updatedAt']),
//     );
//   }

//   bool get isPast => stage >= kDoneStage;
//   double get progress =>
//       (stage.clamp(0, kStages.length - 1) + 1) / kStages.length;

//   /// "May 3, 2026 · 10:00 AM · Crew A"
//   String get summary => [
//     if (date != null) _date(date),
//     if (time.isNotEmpty) time,
//     if (crew.isNotEmpty) crew,
//   ].join(' · ');
// }

// // ---------------------------------------------------------
// // CONTROLLER (live stream)
// // ---------------------------------------------------------
// class JobsController extends GetxController {
//   final jobs = <JobModel>[].obs;
//   final seg = 0.obs; // 0 upcoming, 1 past
//   final loading = true.obs;
//   final error = ''.obs;
//   StreamSubscription? _sub;

//   Query<Map<String, dynamic>>? get _query {
//     final u = FirebaseAuth.instance.currentUser;
//     if (u == null) return null;
//     return FirebaseFirestore.instance
//         .collection(kJobsCollection)
//         .where('userId', isEqualTo: u.uid); // no composite index needed
//   }

//   @override
//   void onInit() {
//     super.onInit();
//     _listen();
//   }

//   final _lastStage = <String, int>{};
//   bool _firstLoad = true;

//   void _apply(QuerySnapshot<Map<String, dynamic>> s) {
//     final list = s.docs
//         .where((d) => JobModel.isJob(d.data()))
//         .map(JobModel.fromDoc)
//         .toList();
//     jobs.assignAll(list);
//     loading.value = false;
//     error.value = '';
//     _notifyProgress(list);
//   }

//   /// Live banner when a job moves to a new stage (not on first load).
//   void _notifyProgress(List<JobModel> list) {
//     for (final j in list) {
//       final prev = _lastStage[j.id];
//       _lastStage[j.id] = j.stage;
//       if (_firstLoad || prev == null || prev == j.stage) continue;
//       Get.snackbar(
//         '',
//         '',
//         titleText: Text(
//           j.service,
//           style: const TextStyle(
//             color: Colors.white,
//             fontWeight: FontWeight.w800,
//             fontSize: 15,
//           ),
//         ),
//         messageText: Text(
//           'Update: ${_stageLabel(j.stage)}',
//           style: TextStyle(color: Colors.white.withValues(alpha: .92)),
//         ),
//         snackPosition: SnackPosition.TOP,
//         margin: const EdgeInsets.all(16),
//         maxWidth: 560,
//         borderRadius: 16,
//         backgroundColor: _stageColor(j.stage),
//         duration: const Duration(seconds: 5),
//         icon: const Icon(
//           Icons.notifications_active_rounded,
//           color: Colors.white,
//         ),
//         onTap: (_) {
//           Get.closeCurrentSnackbar();
//           Get.to(() => JobDetailView(job: j));
//         },
//       );
//     }
//     _firstLoad = false;
//   }

//   void _listen() {
//     final q = _query;
//     if (q == null) {
//       loading.value = false;
//       error.value = 'Please log in to see your jobs.';
//       return;
//     }
//     _sub?.cancel();
//     _sub = q.snapshots().listen(
//       _apply,
//       onError: (_) {
//         loading.value = false;
//         error.value = 'Could not load jobs. Pull down to retry.';
//       },
//     );
//   }

//   Future<void> refreshData() async {
//     final q = _query;
//     if (q == null) return;
//     try {
//       _apply(await q.get(const GetOptions(source: Source.server)));
//     } catch (_) {
//       error.value = 'You appear to be offline.';
//       Get.snackbar(
//         'Oops',
//         'Could not refresh. Check your connection.',
//         snackPosition: SnackPosition.BOTTOM,
//         margin: const EdgeInsets.all(16),
//         maxWidth: 560,
//         backgroundColor: _C.red,
//         colorText: Colors.white,
//       );
//     }
//     _listen();
//   }

//   List<JobModel> get visible {
//     final past = seg.value == 1;
//     final l = jobs.where((j) => j.isPast == past).toList();
//     final far = DateTime(2100);
//     l.sort(
//       (a, b) => past
//           ? (b.date ?? far).compareTo(a.date ?? far) // newest first
//           : (a.date ?? far).compareTo(b.date ?? far),
//     ); // soonest first
//     return l;
//   }

//   int count(bool past) => jobs.where((j) => j.isPast == past).length;

//   @override
//   void onClose() {
//     _sub?.cancel();
//     super.onClose();
//   }
// }

// // ---------------------------------------------------------
// // LAYOUT HELPERS
// // ---------------------------------------------------------
// int _cols(double w) => w >= 960 ? 3 : (w >= 600 ? 2 : 1);
// double _pad(double w) => w >= 600 ? 24 : 16;

// class _Page extends StatelessWidget {
//   final Widget child;
//   final double max;
//   const _Page({required this.child, this.max = 1100});
//   @override
//   Widget build(BuildContext context) => Center(
//     child: ConstrainedBox(
//       constraints: BoxConstraints(maxWidth: max),
//       child: child,
//     ),
//   );
// }

// class _Tag extends StatelessWidget {
//   final String text;
//   final Color color;
//   const _Tag(this.text, this.color);
//   @override
//   Widget build(BuildContext context) => Container(
//     padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
//     decoration: BoxDecoration(
//       color: color.withValues(alpha: .13),
//       borderRadius: BorderRadius.circular(20),
//     ),
//     child: Text(
//       text,
//       maxLines: 1,
//       overflow: TextOverflow.ellipsis,
//       style: TextStyle(color: color, fontWeight: FontWeight.w800, fontSize: 12),
//     ),
//   );
// }

// // ---------------------------------------------------------
// // JOBS LIST
// // ---------------------------------------------------------
// class JobsView extends StatelessWidget {
//   JobsView({super.key});
//   final c = Get.put(JobsController());

//   @override
//   Widget build(BuildContext context) {
//     return Scaffold(
//       backgroundColor: _C.bg,
//       body: RefreshIndicator(
//         color: _C.orange,
//         onRefresh: c.refreshData,
//         child: LayoutBuilder(
//           builder: (context, box) {
//             final w = box.maxWidth;
//             final pad = _pad(w);
//             final contentW = (w < 1100 ? w : 1100.0) - pad * 2;
//             final cols = _cols(w);
//             const gap = 14.0;
//             final itemW = (contentW - gap * (cols - 1)) / cols;
//             final top = MediaQuery.of(context).padding.top;

//             return CustomScrollView(
//               physics: const AlwaysScrollableScrollPhysics(),
//               slivers: [
//                 SliverToBoxAdapter(
//                   child: _Page(
//                     child: Padding(
//                       padding: EdgeInsets.fromLTRB(pad, top + 18, pad, 0),
//                       child: Row(
//                         children: [
//                           Expanded(
//                             child: Column(
//                               crossAxisAlignment: CrossAxisAlignment.start,
//                               children: [
//                                 const Text(
//                                   'Your jobs',
//                                   style: TextStyle(
//                                     fontSize: 30,
//                                     height: 1.1,
//                                     fontWeight: FontWeight.w900,
//                                     color: _C.ink,
//                                     letterSpacing: -.5,
//                                   ),
//                                 ),
//                                 const SizedBox(height: 6),
//                                 Obx(
//                                   () => Text(
//                                     c.jobs.isEmpty
//                                         ? 'Booked jobs will appear here.'
//                                         : '${c.jobs.length} job${c.jobs.length == 1 ? '' : 's'} · tracked live',
//                                     style: const TextStyle(color: _C.muted),
//                                   ),
//                                 ),
//                               ],
//                             ),
//                           ),
//                           Material(
//                             color: _C.surface,
//                             shape: const CircleBorder(
//                               side: BorderSide(color: _C.line),
//                             ),
//                             child: IconButton(
//                               tooltip: 'Refresh',
//                               onPressed: c.refreshData,
//                               icon: const Icon(
//                                 Icons.refresh_rounded,
//                                 color: _C.ink,
//                               ),
//                             ),
//                           ),
//                         ],
//                       ),
//                     ),
//                   ),
//                 ),

//                 // Upcoming / Past switch
//                 SliverToBoxAdapter(
//                   child: _Page(
//                     child: Padding(
//                       padding: EdgeInsets.fromLTRB(pad, 16, pad, 16),
//                       child: Obx(
//                         () => Container(
//                           padding: const EdgeInsets.all(4),
//                           decoration: BoxDecoration(
//                             color: _C.surface,
//                             borderRadius: BorderRadius.circular(16),
//                             border: Border.all(color: _C.line),
//                           ),
//                           child: Row(
//                             children: [
//                               _segBtn('Upcoming', 0, c.count(false)),
//                               _segBtn('Past', 1, c.count(true)),
//                             ],
//                           ),
//                         ),
//                       ),
//                     ),
//                   ),
//                 ),

//                 Obx(() {
//                   if (c.loading.value) {
//                     return const SliverFillRemaining(
//                       hasScrollBody: false,
//                       child: Center(
//                         child: CircularProgressIndicator(color: _C.orange),
//                       ),
//                     );
//                   }
//                   final list = c.visible;
//                   if (list.isEmpty) {
//                     return SliverFillRemaining(
//                       hasScrollBody: false,
//                       child: _Empty(
//                         message: c.error.value.isNotEmpty
//                             ? c.error.value
//                             : (c.seg.value == 0
//                                   ? 'No upcoming jobs.'
//                                   : 'No past jobs yet.'),
//                       ),
//                     );
//                   }
//                   return SliverToBoxAdapter(
//                     child: _Page(
//                       child: Padding(
//                         padding: EdgeInsets.fromLTRB(pad, 0, pad, 40),
//                         child: Wrap(
//                           spacing: gap,
//                           runSpacing: gap,
//                           children: [
//                             for (var i = 0; i < list.length; i++)
//                               SizedBox(
//                                 width: itemW,
//                                 child: _JobCard(j: list[i], index: i),
//                               ),
//                           ],
//                         ),
//                       ),
//                     ),
//                   );
//                 }),
//               ],
//             );
//           },
//         ),
//       ),
//     );
//   }

//   Widget _segBtn(String label, int v, int n) {
//     final on = c.seg.value == v;
//     return Expanded(
//       child: GestureDetector(
//         onTap: () => c.seg.value = v,
//         child: AnimatedContainer(
//           duration: const Duration(milliseconds: 180),
//           padding: const EdgeInsets.symmetric(vertical: 11),
//           decoration: BoxDecoration(
//             color: on ? _C.ink : Colors.transparent,
//             borderRadius: BorderRadius.circular(12),
//           ),
//           child: Row(
//             mainAxisAlignment: MainAxisAlignment.center,
//             children: [
//               Text(
//                 label,
//                 style: TextStyle(
//                   fontWeight: FontWeight.w800,
//                   color: on ? Colors.white : _C.ink,
//                 ),
//               ),
//               const SizedBox(width: 8),
//               Container(
//                 padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
//                 decoration: BoxDecoration(
//                   color: on ? _C.orange : _C.bg,
//                   borderRadius: BorderRadius.circular(10),
//                 ),
//                 child: Text(
//                   '$n',
//                   style: TextStyle(
//                     fontSize: 11.5,
//                     fontWeight: FontWeight.w800,
//                     color: on ? Colors.white : _C.muted,
//                   ),
//                 ),
//               ),
//             ],
//           ),
//         ),
//       ),
//     );
//   }
// }

// class _Empty extends StatelessWidget {
//   final String message;
//   const _Empty({required this.message});
//   @override
//   Widget build(BuildContext context) => Padding(
//     padding: const EdgeInsets.all(32),
//     child: Column(
//       mainAxisAlignment: MainAxisAlignment.center,
//       children: [
//         Container(
//           padding: const EdgeInsets.all(22),
//           decoration: BoxDecoration(
//             color: _C.orange.withValues(alpha: .1),
//             shape: BoxShape.circle,
//           ),
//           child: const Icon(
//             Icons.event_busy_rounded,
//             color: _C.orange,
//             size: 44,
//           ),
//         ),
//         const SizedBox(height: 16),
//         Text(
//           message,
//           textAlign: TextAlign.center,
//           style: const TextStyle(color: _C.muted, height: 1.4),
//         ),
//       ],
//     ),
//   );
// }

// class _JobCard extends StatelessWidget {
//   final JobModel j;
//   final int index;
//   const _JobCard({required this.j, required this.index});

//   @override
//   Widget build(BuildContext context) {
//     final col = _stageColor(j.stage);
//     return TweenAnimationBuilder<double>(
//       tween: Tween(begin: 0, end: 1),
//       duration: Duration(milliseconds: 280 + index.clamp(0, 6) * 60),
//       curve: Curves.easeOut,
//       builder: (_, v, child) => Opacity(
//         opacity: v,
//         child: Transform.translate(
//           offset: Offset(0, 14 * (1 - v)),
//           child: child,
//         ),
//       ),
//       child: Material(
//         color: _C.surface,
//         clipBehavior: Clip.antiAlias,
//         shape: RoundedRectangleBorder(
//           borderRadius: BorderRadius.circular(20),
//           side: const BorderSide(color: _C.line),
//         ),
//         child: InkWell(
//           onTap: () => Get.to(() => JobDetailView(job: j)),
//           child: Padding(
//             padding: const EdgeInsets.all(16),
//             child: Column(
//               crossAxisAlignment: CrossAxisAlignment.start,
//               children: [
//                 Row(
//                   children: [
//                     Container(
//                       width: 42,
//                       height: 42,
//                       decoration: BoxDecoration(
//                         color: col.withValues(alpha: .12),
//                         borderRadius: BorderRadius.circular(13),
//                       ),
//                       child: Icon(_icon(j.service), color: col, size: 22),
//                     ),
//                     const SizedBox(width: 12),
//                     Expanded(
//                       child: Text(
//                         j.service,
//                         maxLines: 1,
//                         overflow: TextOverflow.ellipsis,
//                         style: const TextStyle(
//                           fontSize: 16,
//                           fontWeight: FontWeight.w800,
//                           color: _C.ink,
//                         ),
//                       ),
//                     ),
//                     const SizedBox(width: 8),
//                     Flexible(child: _Tag(_stageLabel(j.stage), col)),
//                   ],
//                 ),
//                 if (j.summary.isNotEmpty) ...[
//                   const SizedBox(height: 10),
//                   Text(
//                     j.summary,
//                     maxLines: 2,
//                     overflow: TextOverflow.ellipsis,
//                     style: const TextStyle(
//                       color: _C.muted,
//                       height: 1.35,
//                       fontSize: 13,
//                     ),
//                   ),
//                 ],
//                 const SizedBox(height: 14),
//                 ClipRRect(
//                   borderRadius: BorderRadius.circular(4),
//                   child: LinearProgressIndicator(
//                     value: j.progress,
//                     color: col,
//                     backgroundColor: _C.line,
//                     minHeight: 6,
//                   ),
//                 ),
//                 const SizedBox(height: 8),
//                 Row(
//                   children: [
//                     Text(
//                       'Step ${j.stage.clamp(0, kStages.length - 1) + 1} of ${kStages.length}',
//                       style: const TextStyle(color: _C.muted, fontSize: 12),
//                     ),
//                     const Spacer(),
//                     const Icon(Icons.chevron_right_rounded, color: _C.muted),
//                   ],
//                 ),
//               ],
//             ),
//           ),
//         ),
//       ),
//     );
//   }
// }

// // ---------------------------------------------------------
// // JOB DETAIL (live document stream)
// // ---------------------------------------------------------
// class JobDetailView extends StatelessWidget {
//   final JobModel job;
//   const JobDetailView({super.key, required this.job});

//   @override
//   Widget build(BuildContext context) {
//     return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
//       stream: FirebaseFirestore.instance
//           .collection(kJobsCollection)
//           .doc(job.id)
//           .snapshots(),
//       builder: (context, snap) {
//         final j = (snap.hasData && snap.data!.exists)
//             ? JobModel.fromDoc(snap.data!)
//             : job;
//         return Scaffold(
//           backgroundColor: _C.bg,
//           appBar: AppBar(
//             backgroundColor: _C.bg,
//             surfaceTintColor: Colors.transparent,
//             elevation: 0,
//             foregroundColor: _C.ink,
//             centerTitle: false,
//             title: Text(
//               j.number,
//               style: const TextStyle(fontWeight: FontWeight.w900),
//             ),
//           ),
//           body: RefreshIndicator(
//             color: _C.orange,
//             onRefresh: () async {
//               await FirebaseFirestore.instance
//                   .collection(kJobsCollection)
//                   .doc(job.id)
//                   .get(const GetOptions(source: Source.server));
//             },
//             child: LayoutBuilder(
//               builder: (context, box) {
//                 final wide = box.maxWidth > 860;
//                 final pad = _pad(box.maxWidth);
//                 final left = [_hero(j), _info(j)];
//                 final right = [_timeline(j)];
//                 return ListView(
//                   physics: const AlwaysScrollableScrollPhysics(),
//                   padding: EdgeInsets.fromLTRB(pad, 4, pad, 32),
//                   children: [
//                     _Page(
//                       max: wide ? 1080 : 640,
//                       child: wide
//                           ? Row(
//                               crossAxisAlignment: CrossAxisAlignment.start,
//                               children: [
//                                 Expanded(child: Column(children: left)),
//                                 const SizedBox(width: 16),
//                                 Expanded(child: Column(children: right)),
//                               ],
//                             )
//                           : Column(children: [...left, ...right]),
//                     ),
//                   ],
//                 );
//               },
//             ),
//           ),
//         );
//       },
//     );
//   }

//   Widget _card(String? title, Widget child, {Color? color, Color? border}) =>
//       Container(
//         width: double.infinity,
//         margin: const EdgeInsets.only(bottom: 14),
//         padding: const EdgeInsets.all(18),
//         decoration: BoxDecoration(
//           color: color ?? _C.surface,
//           borderRadius: BorderRadius.circular(22),
//           border: Border.all(color: border ?? _C.line),
//         ),
//         child: Column(
//           crossAxisAlignment: CrossAxisAlignment.start,
//           children: [
//             if (title != null) ...[
//               Text(
//                 title,
//                 style: const TextStyle(
//                   fontSize: 15.5,
//                   fontWeight: FontWeight.w800,
//                   color: _C.ink,
//                 ),
//               ),
//               const SizedBox(height: 14),
//             ],
//             child,
//           ],
//         ),
//       );

//   Widget _hero(JobModel j) {
//     final col = _stageColor(j.stage);
//     return _card(
//       null,
//       color: col.withValues(alpha: .07),
//       border: col.withValues(alpha: .25),
//       Column(
//         crossAxisAlignment: CrossAxisAlignment.start,
//         children: [
//           Row(
//             children: [
//               Container(
//                 width: 52,
//                 height: 52,
//                 decoration: BoxDecoration(
//                   color: col,
//                   borderRadius: BorderRadius.circular(16),
//                 ),
//                 child: Icon(
//                   j.isPast ? Icons.verified_rounded : _icon(j.service),
//                   color: Colors.white,
//                   size: 26,
//                 ),
//               ),
//               const SizedBox(width: 14),
//               Expanded(
//                 child: Column(
//                   crossAxisAlignment: CrossAxisAlignment.start,
//                   children: [
//                     Text(
//                       j.service,
//                       maxLines: 2,
//                       overflow: TextOverflow.ellipsis,
//                       style: const TextStyle(
//                         fontSize: 20,
//                         fontWeight: FontWeight.w900,
//                         color: _C.ink,
//                       ),
//                     ),
//                     const SizedBox(height: 2),
//                     Text(
//                       _stageLabel(j.stage),
//                       style: TextStyle(color: col, fontWeight: FontWeight.w800),
//                     ),
//                   ],
//                 ),
//               ),
//             ],
//           ),
//           const SizedBox(height: 16),
//           ClipRRect(
//             borderRadius: BorderRadius.circular(4),
//             child: LinearProgressIndicator(
//               value: j.progress,
//               color: col,
//               backgroundColor: _C.line,
//               minHeight: 8,
//             ),
//           ),
//           const SizedBox(height: 8),
//           Text(
//             'Step ${j.stage.clamp(0, kStages.length - 1) + 1} of ${kStages.length}',
//             style: const TextStyle(color: _C.muted, fontSize: 12),
//           ),
//         ],
//       ),
//     );
//   }

//   Widget _row(IconData i, String k, String v) => v.isEmpty
//       ? const SizedBox.shrink()
//       : Padding(
//           padding: const EdgeInsets.symmetric(vertical: 7),
//           child: Row(
//             crossAxisAlignment: CrossAxisAlignment.start,
//             children: [
//               Icon(i, size: 18, color: _C.orange),
//               const SizedBox(width: 10),
//               Expanded(
//                 flex: 4,
//                 child: Text(k, style: const TextStyle(color: _C.muted)),
//               ),
//               Expanded(
//                 flex: 6,
//                 child: Text(
//                   v,
//                   textAlign: TextAlign.right,
//                   style: const TextStyle(
//                     color: _C.ink,
//                     fontWeight: FontWeight.w700,
//                     height: 1.3,
//                   ),
//                 ),
//               ),
//             ],
//           ),
//         );

//   Widget _info(JobModel j) => _card(
//     'Job details',
//     Column(
//       children: [
//         _row(Icons.event_rounded, 'Date', j.date == null ? '' : _date(j.date)),
//         _row(Icons.schedule_rounded, 'Time', j.time),
//         _row(Icons.groups_rounded, 'Crew', j.crew),
//         _row(Icons.location_on_outlined, 'Address', j.address),
//         _row(Icons.tag_rounded, 'Request', j.number),
//         _row(
//           Icons.payments_rounded,
//           'Amount',
//           j.amount > 0 ? _money(j.amount) : '',
//         ),
//         _row(
//           Icons.update_rounded,
//           'Last update',
//           j.updatedAt == null ? '' : _date(j.updatedAt),
//         ),
//         if (j.notes.isNotEmpty) ...[
//           const Divider(height: 24),
//           Align(
//             alignment: Alignment.centerLeft,
//             child: Text(
//               j.notes,
//               style: const TextStyle(color: _C.ink, height: 1.4),
//             ),
//           ),
//         ],
//       ],
//     ),
//   );

//   Widget _timeline(JobModel j) {
//     final cur = j.stage.clamp(0, kStages.length - 1);
//     return _card(
//       'Progress',
//       Column(
//         children: [
//           for (var i = 0; i < kStages.length; i++)
//             IntrinsicHeight(
//               child: Row(
//                 crossAxisAlignment: CrossAxisAlignment.stretch,
//                 children: [
//                   SizedBox(
//                     width: 30,
//                     child: Column(
//                       children: [
//                         Container(
//                           width: 22,
//                           height: 22,
//                           decoration: BoxDecoration(
//                             shape: BoxShape.circle,
//                             color: i < cur
//                                 ? _C.green
//                                 : (i == cur ? _stageColor(cur) : _C.line),
//                           ),
//                           child: i < cur
//                               ? const Icon(
//                                   Icons.check_rounded,
//                                   size: 14,
//                                   color: Colors.white,
//                                 )
//                               : (i == cur
//                                     ? const Icon(
//                                         Icons.circle,
//                                         size: 8,
//                                         color: Colors.white,
//                                       )
//                                     : null),
//                         ),
//                         if (i != kStages.length - 1)
//                           Expanded(
//                             child: Container(
//                               width: 2,
//                               color: i < cur ? _C.green : _C.line,
//                             ),
//                           ),
//                       ],
//                     ),
//                   ),
//                   const SizedBox(width: 10),
//                   Expanded(
//                     child: Padding(
//                       padding: const EdgeInsets.only(bottom: 14),
//                       child: Text(
//                         kStages[i],
//                         style: TextStyle(
//                           fontWeight: i == cur
//                               ? FontWeight.w800
//                               : FontWeight.w500,
//                           color: i > cur ? _C.muted : _C.ink,
//                         ),
//                       ),
//                     ),
//                   ),
//                 ],
//               ),
//             ),
//         ],
//       ),
//     );
//   }
// }

// // import 'package:flutter/material.dart';
// // import 'package:get/get.dart';
// // import '../controllers/app_controller.dart';
// // import '../core/theme.dart';
// // import '../core/widgets.dart';
// // import '../data/models.dart';
// // import 'job_detail_view.dart';

// // class JobsView extends StatelessWidget {
// //   JobsView({super.key});
// //   final seg = 0.obs;
// //   final c = Get.find<AppController>();
// //   @override
// //   Widget build(BuildContext context) => Body(Obx(() {
// //         final list = c.jobs.where((j) => seg.value == 0 ? j.stage.value < 11 : j.stage.value >= 11).toList();
// //         return ListView(padding: const EdgeInsets.all(20), children: [
// //           h('Your jobs', size: 22), gap(),
// //           SegmentedButton<int>(
// //               segments: const [ButtonSegment(value: 0, label: Text('Upcoming')), ButtonSegment(value: 1, label: Text('Past'))],
// //               selected: {seg.value}, onSelectionChanged: (s) => seg.value = s.first),
// //           gap(),
// //           if (list.isEmpty) const Center(child: Padding(padding: EdgeInsets.all(40), child: Text('Nothing here yet'))),
// //           for (final j in list)
// //             Box(onTap: () => Get.to(() => JobDetailView(job: j)), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
// //               Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [h(j.service, size: 15), Tag(stages[j.stage.value])]),
// //               gap(4), sub('${j.date} · ${j.time} · ${j.crew}'), gap(10),
// //               LinearProgressIndicator(value: (j.stage.value + 1) / stages.length, color: C.green, backgroundColor: C.line, minHeight: 5, borderRadius: BorderRadius.circular(4)),
// //             ])),
// //         ]);
// //       }));
// // }
