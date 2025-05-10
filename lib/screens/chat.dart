import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:patico/screens/Chat_detail_page.dart';

class ChatPage extends StatelessWidget {
  const ChatPage({Key? key}) : super(key: key);

  // Karşı tarafın userId'sini bul
  String getOtherUserId(List users, String currentUserId) {
    return users.firstWhere((id) => id != currentUserId);
  }

  Future<String> getUserName(String userId) async {
    final doc = await FirebaseFirestore.instance.collection('users').doc(userId).get();
    return doc.exists ? (doc.data()?['name'] ?? 'Bilinmeyen') : 'Bilinmeyen';
  }

  Future<String?> getUserPhotoUrl(String userId) async {
    final doc = await FirebaseFirestore.instance.collection('users').doc(userId).get();
    if (doc.exists && doc.data() != null) {
      return doc.data()!['photoUrl'];
    } else {
      return null;
    }
  }
  @override
  Widget build(BuildContext context) {
    final currentUser = FirebaseAuth.instance.currentUser;

    return Scaffold(
      appBar: AppBar(title: const Text('Sohbetler')),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('chats')
            .where('users', arrayContains: currentUser!.uid)
            .snapshots(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());

          final chats = snapshot.data!.docs;

          if (chats.isEmpty) {
            return const Center(child: Text("Hiç sohbetiniz yok."));
          }

          return ListView.builder(
            itemCount: chats.length,
            itemBuilder: (context, index) {
              final chat = chats[index];
              final users = chat['users'] as List;
              final otherUserId = getOtherUserId(users, currentUser.uid);

              return FutureBuilder(
                future: Future.wait([
                  getUserName(otherUserId),
                  getUserPhotoUrl(otherUserId),
                ]),
                builder: (context, AsyncSnapshot<List<dynamic>> snapshot) {
                  if (!snapshot.hasData) return const ListTile(title: Text("Yükleniyor..."));

                  final userName = snapshot.data![0] as String;
                  final userPhotoUrl = snapshot.data![1] as String?;

                  return ListTile(
                    leading: CircleAvatar(
                      backgroundImage: userPhotoUrl != null
                          ? NetworkImage(userPhotoUrl)
                          : null,
                      child: userPhotoUrl == null ? const Icon(Icons.person) : null,
                    ),
                    title: Text(userName),
                    subtitle: const Text('Sohbete dokunarak devam et'),
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => ChatDetailPage(chatId: chat.id),
                        ),
                      );
                    },
                  );
                },
              );
            },
          );
        },
      ),
    );
  }
}
