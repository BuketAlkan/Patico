import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:patico/screens/forum_page.dart';

import '../screens/Chat_detail_page.dart';

class NotificationBox extends StatefulWidget {
  const NotificationBox({super.key});

  @override
  State<NotificationBox> createState() => _NotificationBoxState();
}

class _NotificationBoxState extends State<NotificationBox> {
  final userId = FirebaseAuth.instance.currentUser?.uid;
  final notificationsRef = FirebaseFirestore.instance.collection('notifications');

  // 1. State için anahtar eklendi
  final GlobalKey<_NotificationBoxState> _key = GlobalKey();

  void _handleNotificationTap( Map<String, dynamic> data) {
    final type = data['type'] ?? '';
    final chatId = data['chatId'] ?? data['relatedId'] ?? '';
    final postId = data['postId'] ?? data['relatedId'] ?? '';

    if (type == 'chat' && chatId.isNotEmpty) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (ctx) => ChatDetailPage(chatId: chatId),
        ),
      );
    }
    else if (type == 'forum_comment' || type == 'comment') {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (ctx) => ForumPage(),
        ),
      );
    }
    else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("İlgili içeriğe ulaşılamadı.")),
      );
    }

    // 2. Okunmamışsa işaretle (doküman ID kontrolü)
    final docId = data['id'] ?? '';
    if (docId.isNotEmpty && !(data['isRead'] ?? false)) {
      _markAsRead(docId);
    }
  }

  Future<void> _markAsRead(String docId) async {
    try {
      await notificationsRef.doc(docId).update({'isRead': true});
    } catch (e) {
      debugPrint('Okunma durumu güncellenemedi: $e');
    }
  }

  Future<void> _deleteNotification(String docId) async {
    try {
      await notificationsRef.doc(docId).delete();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Bildirim silindi')),
      );
    } catch (e) {
      debugPrint('Bildirim silinemedi: $e');
    }
  }

  Future<void> _clearAllNotifications() async {
    try {
      final snapshot = await notificationsRef
          .where('toUserId', isEqualTo: userId)
          .get();

      final batch = FirebaseFirestore.instance.batch();
      for (var doc in snapshot.docs) {
        batch.delete(doc.reference);
      }
      await batch.commit();

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Tüm bildirimler silindi')),
      );
    } catch (e) {
      debugPrint('Tüm bildirimler silinemedi: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Hata: ${e.toString()}')),
      );
    }
  }

  String _getNotificationMessage(Map<String, dynamic> data) {
    final senderName = data['senderName'] ?? 'Birisi';
    final content = data['content'] ?? '';
    final type = data['type'] ?? '';

    switch (type) {
      case 'chat': return '$senderName: $content';
      case 'forum_comment': return '$senderName gönderine yorum yaptı';
      case 'comment': return '$senderName yorum yaptı: $content';
      default: return 'Yeni bildirim';
    }
  }

  String _formatTimestamp(Timestamp? timestamp) {
    if (timestamp == null) return '';
    final date = timestamp.toDate();
    return '${date.day}/${date.month}/${date.year} ${date.hour}:${date.minute}';
  }

  @override
  Widget build(BuildContext context) {
    if (userId == null || userId!.isEmpty) {
      return Scaffold(
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const CircularProgressIndicator(),
              const SizedBox(height: 20),
              const Text('Kullanıcı bilgileri yükleniyor'),
              TextButton(
                onPressed: () => setState(() {}),
                child: const Text('Yenile'),
              )
            ],
          ),
        ),
      );
    }

    return Scaffold(
      key: _key, // 3. State key eklendi
      appBar: AppBar(
        title: const Text('Bildirimler'),
        actions: [
          IconButton(
            icon: const Icon(Icons.delete_sweep),
            onPressed: _clearAllNotifications,
          )
        ],
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: notificationsRef
            .where('toUserId', isEqualTo: userId)
            .orderBy('timestamp', descending: true)
            .snapshots(),
        builder: (context, snapshot) {
          // 5. Hata durumunda bilgilendirme
          if (snapshot.hasError) {
            debugPrint('Bildirim hatası: ${snapshot.error}');
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.error, size: 50, color: Colors.red),
                  const SizedBox(height: 20),
                  Text(
                    'Bildirimler yüklenemedi',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const SizedBox(height: 10),
                  Text(
                    'Hata: ${snapshot.error}',
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 20),
                  ElevatedButton(
                    onPressed: () => setState(() {}),
                    child: const Text('Yeniden Dene'),
                  )
                ],
              ),
            );
          }

          // 6. Yükleme durumu
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          // 7. Veri yoksa
          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.notifications_off,
                      size: 64,
                      color: Theme.of(context).colorScheme.secondary),
                  const SizedBox(height: 16),
                  Text(
                    'Hiç bildirimin yok',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 8),
                  const Text('Yeni etkileşimler burada görünecek'),
                ],
              ),
            );
          }

          final notifications = snapshot.data!.docs;

          // 8. Dokümanları logla
          debugPrint('Toplam bildirim: ${notifications.length}');
          for (final doc in notifications) {
            debugPrint('Bildirim: ${doc.data()}');
          }

          return ListView.builder(
            itemCount: notifications.length,
            itemBuilder: (context, index) {
              final doc = notifications[index];
              final data = doc.data() as Map<String, dynamic>;
              final isRead = data['isRead'] ?? false;
              final type = data['type'] ?? '';

              // 9. Bildirim türüne göre ikon
              IconData icon = Icons.notifications;
              Color color = Colors.blue;

              if (type == 'chat') {
                icon = Icons.message;
                color = Colors.blue;
              } else if (type.contains('comment')) {
                icon = Icons.comment;
                color = Colors.green;
              }

              return Card(
                margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                elevation: 2,
                child: ListTile(
                  leading: Icon(icon, color: isRead ? Colors.grey : color),
                  title: Text(
                    _getNotificationMessage(data),
                    style: TextStyle(
                      fontWeight: isRead ? FontWeight.normal : FontWeight.bold,
                      color: isRead ? Colors.grey : Colors.black,
                    ),
                  ),
                  subtitle: Text(_formatTimestamp(data['timestamp'] as Timestamp?)),
                  trailing: IconButton(
                    icon: const Icon(Icons.close, size: 20),
                    onPressed: () => _deleteNotification(doc.id),
                  ),
                  onTap: () => _handleNotificationTap({
                    ...data,
                    'docId': doc.id, // 10. Doküman ID ekledik1
                    'id': doc.id, // Firestore doküman ID
                  }),
                ),
              );
            },
          );
        },
      ),
    );
  }
}