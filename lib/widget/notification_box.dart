import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

class NotificationBox extends StatefulWidget {
  const NotificationBox({super.key});

  @override
  State<NotificationBox> createState() => _NotificationBoxState();
}

class _NotificationBoxState extends State<NotificationBox> {
  final userId = FirebaseAuth.instance.currentUser?.uid;
  final notificationsRef = FirebaseFirestore.instance.collection('notifications');

  Future<void> _markAsRead(String docId) async {
    await notificationsRef.doc(docId).update({'isRead': true});
  }

  Future<void> _deleteNotification(String docId) async {
    await notificationsRef.doc(docId).delete();
  }

  Future<void> _clearAllNotifications() async {
    final snapshot = await notificationsRef.where('toUserId', isEqualTo: userId).get();
    for (var doc in snapshot.docs) {
      await doc.reference.delete();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Bildirimler'),
        actions: [
          IconButton(
            icon: const Icon(Icons.cleaning_services),
            onPressed: () async {
              final confirm = await showDialog(
                context: context,
                builder: (ctx) => AlertDialog(
                  title: const Text("Tümünü sil"),
                  content: const Text("Tüm bildirimleri silmek istediğine emin misin?"),
                  actions: [
                    TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text("İptal")),
                    TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text("Sil")),
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
          if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());

          final notifications = snapshot.data!.docs;

          if (notifications.isEmpty) {
            return const Center(child: Text("Hiç bildirimin yok 🐾"));
          }

          return ListView.builder(
            itemCount: notifications.length,
            itemBuilder: (context, index) {
              final data = notifications[index].data() as Map<String, dynamic>;
              final docId = notifications[index].id;
              final isRead = data['isRead'] ?? false;

              return ListTile(
                leading: Icon(Icons.notifications, color: isRead ? Colors.grey : Colors.pink),
                title: Text(data['message'] ?? 'Yeni bildirim'),
                subtitle: Text(
                  (data['timestamp'] as Timestamp?)?.toDate().toLocal().toString().substring(0, 16) ?? '',
                ),
                tileColor: isRead ? Colors.grey[200] : Colors.pink[50],
                onTap: () => _markAsRead(docId),
                trailing: IconButton(
                  icon: const Icon(Icons.delete, color: Colors.redAccent),
                  onPressed: () => _deleteNotification(docId),
                ),
              );
            },
          );
        },
      ),
    );
  }
}
