import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../core/theme.dart';
import '../core/widgets.dart';

class ChatPage extends StatelessWidget {
  const ChatPage({super.key});
  @override
  Widget build(BuildContext context) => Scaffold(appBar: AppBar(title: const Text('Twins Handyman')), body: Body(ChatView()));
}

class ChatView extends StatelessWidget {
  ChatView({super.key});
  final msgs = <(bool, String)>[(false, 'Hi! This is Twins Handyman. How can we help?')].obs;
  final tc = TextEditingController();
  void _send([String? t]) {
    final s = t ?? tc.text.trim();
    if (s.isEmpty) return;
    msgs.add((true, s));
    tc.clear();
  }

  @override
  Widget build(BuildContext context) => Column(children: [
        Expanded(child: Obx(() => ListView(padding: const EdgeInsets.all(16), children: [
              for (final m in msgs)
                Align(
                    alignment: m.$1 ? Alignment.centerRight : Alignment.centerLeft,
                    child: Container(
                        margin: const EdgeInsets.symmetric(vertical: 4), padding: const EdgeInsets.all(12),
                        constraints: const BoxConstraints(maxWidth: 300),
                        decoration: BoxDecoration(color: m.$1 ? C.orange : Colors.white, borderRadius: BorderRadius.circular(14)),
                        child: Text(m.$2, style: TextStyle(color: m.$1 ? Colors.white : C.ink)))),
            ]))),
        Padding(padding: const EdgeInsets.all(10), child: Row(children: [
          PopupMenuButton<String>(icon: const Icon(Icons.attach_file), onSelected: (v) => _send('📎 $v attached'),
              itemBuilder: (_) => const [PopupMenuItem(value: 'Photo', child: Text('Photo')), PopupMenuItem(value: 'Video', child: Text('Video')), PopupMenuItem(value: 'Document', child: Text('Document'))]),
          Expanded(child: TextField(controller: tc, onSubmitted: _send, decoration: const InputDecoration(hintText: 'Message…', isDense: true))),
          IconButton.filled(style: IconButton.styleFrom(backgroundColor: C.orange), onPressed: _send, icon: const Icon(Icons.send, size: 18)),
        ])),
      ]);
}
