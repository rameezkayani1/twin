import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../core/theme.dart';
import '../core/widgets.dart';

// =========================================================
// FIRESTORE STRUCTURE
//   chats/{customerUid}                -> chat summary (one chat per customer)
//   chats/{customerUid}/messages/{id}  -> every message
// =========================================================

class ChatPage extends StatelessWidget {
  const ChatPage({super.key});
  @override
  Widget build(BuildContext context) => Scaffold(
    // appBar: AppBar(title: const Text('Customer Support')),
    appBar: AppBar(
      backgroundColor: Colors.white,
      elevation: 0,
      surfaceTintColor: Colors.transparent,
      titleSpacing: 0,
      iconTheme: const IconThemeData(color: Color(0xFF10233A)),
      title: Row(
        children: [
          Stack(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: const BoxDecoration(
                  color: Color(0xFFEAF0F6),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.support_agent_rounded,
                  color: Color(0xFF10233A),
                  size: 25,
                ),
              ),
              Positioned(
                right: 0,
                bottom: 0,
                child: Container(
                  width: 11,
                  height: 11,
                  decoration: BoxDecoration(
                    color: Colors.green,
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white, width: 2),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(width: 12),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Customer Support',
                  style: TextStyle(
                    color: Color(0xFF10233A),
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                SizedBox(height: 3),
                Text(
                  'We’re here to help',
                  style: TextStyle(
                    color: Color(0xFF16A36A),
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    ),

    body: Body(const ChatView()),
  );
}

class ChatView extends StatefulWidget {
  const ChatView({super.key});
  @override
  State<ChatView> createState() => _ChatViewState();
}

class _ChatViewState extends State<ChatView> {
  final _tc = TextEditingController();
  final _db = FirebaseFirestore.instance;
  final User? _user = FirebaseAuth.instance.currentUser;
  String? _lastReadId;

  DocumentReference<Map<String, dynamic>> get _chatRef =>
      _db.collection('chats').doc(_user!.uid);
  CollectionReference<Map<String, dynamic>> get _msgs =>
      _chatRef.collection('messages');

  @override
  void initState() {
    super.initState();
    if (_user != null) _markRead();
  }

  @override
  void dispose() {
    _tc.dispose();
    super.dispose();
  }

  /// Customer has seen everything -> reset customer unread counter
  Future<void> _markRead() async {
    try {
      await _chatRef.set({'unreadForCustomer': 0}, SetOptions(merge: true));
    } catch (_) {}
  }

  Future<void> _send([String? preset]) async {
    final text = (preset ?? _tc.text).trim();
    if (text.isEmpty || _user == null) return;
    _tc.clear();

    final batch = _db.batch();
    // 1) the message
    batch.set(_msgs.doc(), {
      'text': text,
      'senderId': _user.uid,
      'senderRole': 'customer',
      'createdAt': FieldValue.serverTimestamp(),
    });
    // 2) chat summary (admin inbox reads this)
    batch.set(_chatRef, {
      'customerUid': _user.uid,
      'customerName': _user.displayName ?? 'Customer',
      'customerEmail': _user.email ?? '',
      'lastMessage': text,
      'lastMessageAt': FieldValue.serverTimestamp(),
      'unreadForAdmin': FieldValue.increment(1),
    }, SetOptions(merge: true));
    try {
      await batch.commit();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Message not sent. Try again.')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_user == null) {
      return const Center(child: Text('Please log in to chat with support.'));
    }
    return Column(
      children: [
        Expanded(
          child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
            stream: _msgs
                .orderBy('createdAt', descending: true)
                .limit(100)
                .snapshots(),
            builder: (context, snap) {
              if (snap.hasError) {
                return const Center(child: Text('Could not load messages.'));
              }
              final docs = snap.data?.docs ?? [];

              // New admin message arrived while chat is open -> mark as read
              if (docs.isNotEmpty &&
                  docs.first.data()['senderRole'] == 'admin' &&
                  _lastReadId != docs.first.id) {
                _lastReadId = docs.first.id;
                WidgetsBinding.instance.addPostFrameCallback(
                  (_) => _markRead(),
                );
              }

              return ListView.builder(
                reverse: true, // newest at bottom, auto-stays at bottom
                padding: const EdgeInsets.all(16),
                itemCount: docs.length + 1,
                itemBuilder: (_, i) {
                  // last item (top of screen) = welcome message
                  if (i == docs.length) {
                    return _bubble(
                      false,
                      'Hi! This is Twins Handyman. How can we help?',
                      null,
                    );
                  }
                  final m = docs[i].data();
                  return _bubble(
                    m['senderRole'] == 'customer',
                    (m['text'] ?? '').toString(),
                    (m['createdAt'] as Timestamp?)?.toDate(),
                  );
                },
              );
            },
          ),
        ),
        Padding(
          padding: const EdgeInsets.all(10),
          child: Row(
            children: [
              IconButton(
                icon: const Icon(Icons.attach_file),
                onPressed: () => ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Attachments coming soon')),
                ),
              ),
              Expanded(
                child: TextField(
                  controller: _tc,
                  textInputAction: TextInputAction.send,
                  onSubmitted: _send,
                  decoration: const InputDecoration(
                    hintText: 'Message…',
                    isDense: true,
                  ),
                ),
              ),
              IconButton.filled(
                style: IconButton.styleFrom(backgroundColor: C.orange),
                onPressed: _send,
                icon: const Icon(Icons.send, size: 18),
              ),
            ],
          ),
        ),
        SizedBox(height: 50, child: Container(color: Colors.grey[200])),
      ],
    );
  }

  Widget _bubble(bool mine, String text, DateTime? time) => Align(
    alignment: mine ? Alignment.centerRight : Alignment.centerLeft,
    child: Container(
      margin: const EdgeInsets.symmetric(vertical: 4),
      padding: const EdgeInsets.all(12),
      constraints: const BoxConstraints(maxWidth: 300),
      decoration: BoxDecoration(
        color: mine ? C.orange : Colors.white,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.end,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(text, style: TextStyle(color: mine ? Colors.white : C.ink)),
          if (time != null) ...[
            const SizedBox(height: 4),
            Text(
              _fmt(time),
              style: TextStyle(
                fontSize: 10,
                color: mine ? Colors.white70 : Colors.black45,
              ),
            ),
          ],
        ],
      ),
    ),
  );

  String _fmt(DateTime d) {
    final h = d.hour % 12 == 0 ? 12 : d.hour % 12;
    final m = d.minute.toString().padLeft(2, '0');
    return '$h:$m ${d.hour >= 12 ? 'PM' : 'AM'}';
  }
}
// import 'package:flutter/material.dart';
// import 'package:get/get.dart';
// import '../core/theme.dart';
// import '../core/widgets.dart';

// class ChatPage extends StatelessWidget {
//   const ChatPage({super.key});
//   @override
//   Widget build(BuildContext context) => Scaffold(appBar: AppBar(title: const Text('Twins Handyman')), body: Body(ChatView()));
// }

// class ChatView extends StatelessWidget {
//   ChatView({super.key});
//   final msgs = <(bool, String)>[(false, 'Hi! This is Twins Handyman. How can we help?')].obs;
//   final tc = TextEditingController();
//   void _send([String? t]) {
//     final s = t ?? tc.text.trim();
//     if (s.isEmpty) return;
//     msgs.add((true, s));
//     tc.clear();
//   }

//   @override
//   Widget build(BuildContext context) => Column(children: [
//         Expanded(child: Obx(() => ListView(padding: const EdgeInsets.all(16), children: [
//               for (final m in msgs)
//                 Align(
//                     alignment: m.$1 ? Alignment.centerRight : Alignment.centerLeft,
//                     child: Container(
//                         margin: const EdgeInsets.symmetric(vertical: 4), padding: const EdgeInsets.all(12),
//                         constraints: const BoxConstraints(maxWidth: 300),
//                         decoration: BoxDecoration(color: m.$1 ? C.orange : Colors.white, borderRadius: BorderRadius.circular(14)),
//                         child: Text(m.$2, style: TextStyle(color: m.$1 ? Colors.white : C.ink)))),
//             ]))),
//         Padding(padding: const EdgeInsets.all(10), child: Row(children: [
//           PopupMenuButton<String>(icon: const Icon(Icons.attach_file), onSelected: (v) => _send('📎 $v attached'),
//               itemBuilder: (_) => const [PopupMenuItem(value: 'Photo', child: Text('Photo')), PopupMenuItem(value: 'Video', child: Text('Video')), PopupMenuItem(value: 'Document', child: Text('Document'))]),
//           Expanded(child: TextField(controller: tc, onSubmitted: _send, decoration: const InputDecoration(hintText: 'Message…', isDense: true))),
//           IconButton.filled(style: IconButton.styleFrom(backgroundColor: C.orange), onPressed: _send, icon: const Icon(Icons.send, size: 18)),
//         ])),
//       ]);
// }
