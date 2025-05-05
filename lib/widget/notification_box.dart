import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:patico/screens/forum_page.dart';

class NotificationBox extends StatefulWidget {
  const NotificationBox({super.key});

  @override
  State<NotificationBox> createState() => _NotificationBoxState();
}

class _NotificationBoxState extends State<NotificationBox> {
  final userId = FirebaseAuth.instance.currentUser?.uid;
  final notificationsRef = FirebaseFirestore.instance.collection(
      'notifications');

  void _handleNotificationTap(Map<String, dynamic> data) {
    final type = data['type'];
    final relatedId = data['relatedId'];

    if (type == 'comment') {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (ctx) => ForumPage(postId: relatedId),
        ),
      );
    }

    if (!(data['isRead'] ?? false)) {
      _markAsRead(data['docId']);
    }
  }

  Future<void> _markAsRead(String docId) async {
    await notificationsRef.doc(docId).update({'isRead': true});
  }

  Future<void> _deleteNotification(String docId) async {
    await notificationsRef.doc(docId).delete();
  }

  Future<void> _clearAllNotifications() async {
    final snapshot = await notificationsRef.where('toUserId', isEqualTo: userId)
        .get();
    for (var doc in snapshot.docs) {
      await doc.reference.delete();
    }
  }

  String _getNotificationMessage(Map<String, dynamic> data) {
    return '${data['senderName']} gönderine yorum yaptı: ${data['content']}';
  }

  @override
  @override
  Widget build(BuildContext context) {
    if (userId == null) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Bildirimler'),
        actions: [
          IconButton(
            icon: const Icon(Icons.cleaning_services),
            onPressed: () async {
              final confirm = await showDialog(
                context: context,
                builder: (ctx) =>
                    AlertDialog(
                      title: const Text("Tümünü sil"),
                      content: const Text(
                          "Tüm bildirimleri silmek istediğine emin misin?"),
                      actions: [
                        TextButton(onPressed: () => Navigator.pop(ctx, false),
                            child: const Text("İptal")),
                        TextButton(onPressed: () => Navigator.pop(ctx, true),
                            child: const Text("Sil")),
                      ],
                    ),
              );
              if (confirm == true) {
                await _clearAllNotifications();
              }
            },
          )
        ],
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: notificationsRef
            .where('toUserId', isEqualTo: userId)
            .orderBy('timestamp', descending: true)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return const Center(child: Text("Hiç bildirimin yok 🐾"));
          }

          final notifications = snapshot.data!.docs;

          return ListView.builder(
            itemCount: notifications.length,
            itemBuilder: (context, index) {
              final doc = notifications[index];
              final data = doc.data() as Map<String, dynamic>;
              final isRead = data['isRead'] ?? false;

              return ListTile(
                leading: Icon(
                    Icons.comment, color: isRead ? Colors.grey : Colors.pink),
                title: Text(_getNotificationMessage(data)),
                subtitle: Text(
                  (data['timestamp'] as Timestamp?)?.toDate()
                      .toLocal()
                      .toString()
                      .substring(0, 16) ?? '',
                ),
                tileColor: isRead ? Colors.grey[200] : Colors.pink[50],
                onTap: () => _handleNotificationTap({...data, 'docId': doc.id}),
                trailing: IconButton(
                  icon: const Icon(Icons.delete, color: Colors.redAccent),
                  onPressed: () => _deleteNotification(doc.id),
                ),
              );
            },
          );
        },
      ),
    );
  }
}
