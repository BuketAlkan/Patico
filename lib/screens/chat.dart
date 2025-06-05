import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:patico/screens/Chat_detail_page.dart';

class ChatPage extends StatelessWidget {
  const ChatPage({Key? key}) : super(key: key);

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
      return doc.data()!['photoURL'];
    } else {
      return null;
    }
  }

  Future<void> deleteChat(String chatId) async {
    final chatDoc = FirebaseFirestore.instance.collection('chats').doc(chatId);

    // Alt koleksiyon 'messages' içindeki tüm mesajları sil
    final messagesSnapshot = await chatDoc.collection('messages').get();
    for (final doc in messagesSnapshot.docs) {
      await doc.reference.delete();
    }

    // Sohbet dokümanını sil
    await chatDoc.delete();
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
                    trailing: IconButton(
                      icon: const Icon(Icons.delete, color: Colors.red),
                      onPressed: () async {
                        final confirm = await showDialog<bool>(
                          context: context,
                          builder: (ctx) => AlertDialog(
                            title: const Text('Sohbeti sil'),
                            content: const Text('Bu sohbeti silmek istediğinize emin misiniz?'),
                            actions: [
                              TextButton(
                                onPressed: () => Navigator.of(ctx).pop(false),
                                child: const Text('İptal'),
                              ),
                              TextButton(
                                onPressed: () => Navigator.of(ctx).pop(true),
                                child: const Text('Sil'),
                              ),
                            ],
                          ),
                        );

                        if (confirm == true) {
                          await deleteChat(chat.id);
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Sohbet silindi')),
                          );
                        }
                      },
                    ),
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
