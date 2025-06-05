import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class NotificationModal extends StatelessWidget {
  final Function() onNotificationsChanged;

  NotificationModal({required this.onNotificationsChanged});

  @override
  Widget build(BuildContext context) {
    final currentUserId = FirebaseAuth.instance.currentUser?.uid;
    if (currentUserId == null) {
      return Center(child: Text('Giriş yapmalısınız.'));
    }

    return Container(
      height: 400, // Modal yüksekliği
      padding: EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            "Bildirimler",
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
          ),
          SizedBox(height: 10),
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('notifications')
                  .where('toUserId', isEqualTo: currentUserId)
                  .orderBy('timestamp', descending: true)
                  .snapshots(),
              builder: (context, snapshot) {
                if (snapshot.hasError) return Text('Hata: ${snapshot.error}');
                if (!snapshot.hasData) return Center(child: CircularProgressIndicator());

                final docs = snapshot.data!.docs;

                if (docs.isEmpty) {
                  return Center(child: Text("Henüz bildirim yok.", style: TextStyle(color: Colors.grey)));
                }

                return ListView.builder(
                  itemCount: docs.length,
                  itemBuilder: (context, index) {
                    final data = docs[index].data()! as Map<String, dynamic>;

                    return ListTile(
                      title: Text(data['senderName'] ?? 'Bilinmeyen'),
                      subtitle: Text(data['content'] ?? ''),
                      trailing: IconButton(
                        icon: Icon(Icons.delete, color: Colors.red),
                        onPressed: () async {
                          await docs[index].reference.delete();
                          onNotificationsChanged(); // Dışarıya bildirim durumu güncellendi diye haber ver
                        },
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
