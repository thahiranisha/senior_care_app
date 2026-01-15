import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

class GuardianChatScreen extends StatefulWidget {
  final String requestId;
  const GuardianChatScreen({super.key, required this.requestId});

  @override
  State<GuardianChatScreen> createState() => _GuardianChatScreenState();
}

class _GuardianChatScreenState extends State<GuardianChatScreen> {
  final _msgController = TextEditingController();

  DocumentReference<Map<String, dynamic>> get _requestRef =>
      FirebaseFirestore.instance.collection('care_requests').doc(widget.requestId);

  DocumentReference<Map<String, dynamic>> get _chatRef =>
      FirebaseFirestore.instance.collection('chats').doc(widget.requestId);

  CollectionReference<Map<String, dynamic>> get _messagesRef =>
      _chatRef.collection('messages');

  @override
  void dispose() {
    _msgController.dispose();
    super.dispose();
  }

  Future<void> _sendMessage({
    required String caregiverId,
    required String guardianId,
  }) async {
    final text = _msgController.text.trim();
    if (text.isEmpty) return;

    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;

    _msgController.clear();

    final msgDoc = _messagesRef.doc();
    final batch = FirebaseFirestore.instance.batch();

    batch.set(msgDoc, {
      'senderId': uid,
      'text': text,
      'sentAt': FieldValue.serverTimestamp(),
    });

    batch.set(
      _chatRef,
      {
        'requestId': widget.requestId,
        'caregiverId': caregiverId,
        'guardianId': guardianId,
        'participants': [caregiverId, guardianId],
        'lastMessage': text,
        'lastMessageAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      },
      SetOptions(merge: true),
    );

    await batch.commit();
  }

  Widget _bubble({required bool mine, required String text}) {
    return Align(
      alignment: mine ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 4),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        constraints: const BoxConstraints(maxWidth: 320),
        decoration: BoxDecoration(
          color: mine ? Colors.teal.withOpacity(0.12) : Colors.grey.shade200,
          borderRadius: BorderRadius.circular(14),
        ),
        child: Text(text),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return const Scaffold(body: Center(child: Text('Not logged in')));

    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: _requestRef.snapshots(),
      builder: (context, reqSnap) {
        if (reqSnap.hasError) return Scaffold(body: Center(child: Text('Error: ${reqSnap.error}')));
        if (!reqSnap.hasData) return const Scaffold(body: Center(child: CircularProgressIndicator()));

        final req = reqSnap.data!.data();
        if (req == null) return const Scaffold(body: Center(child: Text('Request not found')));

        final caregiverId = (req['caregiverId'] as String?) ?? '';
        final guardianId = (req['guardianId'] as String?) ?? '';
        final patientName = (req['patientName'] as String?) ?? 'Patient';

        if (uid != caregiverId && uid != guardianId) {
          return const Scaffold(body: Center(child: Text('Access denied')));
        }

        return Scaffold(
          appBar: AppBar(
            backgroundColor: Colors.teal,
            foregroundColor: Colors.white,
            title: Text('Chat • $patientName'),
          ),
          body: Column(
            children: [
              Expanded(
                child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                  stream: _messagesRef.orderBy('sentAt').snapshots(),
                  builder: (context, msgSnap) {
                    if (msgSnap.hasError) return Center(child: Text('Error: ${msgSnap.error}'));
                    if (!msgSnap.hasData) return const Center(child: CircularProgressIndicator());

                    final msgs = msgSnap.data!.docs;
                    if (msgs.isEmpty) return const Center(child: Text('No messages yet.'));

                    return ListView.builder(
                      padding: const EdgeInsets.all(12),
                      itemCount: msgs.length,
                      itemBuilder: (_, i) {
                        final m = msgs[i].data();
                        final senderId = (m['senderId'] as String?) ?? '';
                        final text = (m['text'] as String?) ?? '';
                        return _bubble(mine: senderId == uid, text: text);
                      },
                    );
                  },
                ),
              ),
              SafeArea(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
                  child: Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _msgController,
                          minLines: 1,
                          maxLines: 4,
                          decoration: const InputDecoration(
                            hintText: 'Type a message…',
                            border: OutlineInputBorder(),
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      IconButton.filled(
                        onPressed: caregiverId.isEmpty || guardianId.isEmpty
                            ? null
                            : () => _sendMessage(caregiverId: caregiverId, guardianId: guardianId),
                        icon: const Icon(Icons.send),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
