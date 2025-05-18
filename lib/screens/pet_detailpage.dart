import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'Chat_detail_page.dart';

// ✅ Sohbet varsa getir, yoksa oluştur
Future<String> createChatIfNotExists(String user1Id, String user2Id) async {
  final chats = await FirebaseFirestore.instance
      .collection('chats')
      .where('users', arrayContains: user1Id)
      .get();

  for (var doc in chats.docs) {
    List users = List<String>.from(doc['users']);
    if (users.contains(user2Id)) return doc.id;
  }

  final newChat = await FirebaseFirestore.instance.collection('chats').add({
    'users': [user1Id, user2Id],
    'createdAt': Timestamp.now(),
  });

  return newChat.id;
}

class PetDetailPage extends StatelessWidget {
  final Map<String, dynamic> adData;

  const PetDetailPage({Key? key, required this.adData}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final currentUser = FirebaseAuth.instance.currentUser;
    final String ownerId = adData["userId"];

    return Scaffold(
      appBar: AppBar(
        title: Text(adData["title"] ?? "İlan Detayı"),
        backgroundColor: Colors.pink[200],
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // İlan resmi
            ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: Image.network(
                adData["imageUrl"] ?? "https://via.placeholder.com/150",
                height: 250,
                width: double.infinity,
                fit: BoxFit.cover,
              ),
            ),
            const SizedBox(height: 15),

            // Başlık
            Text(
              adData["title"] ?? "İlan Başlığı",
              style: const TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 10),

            // Açıklama
            Text(
              adData["description"] ?? "Açıklama mevcut değil",
              style: const TextStyle(fontSize: 16),
            ),
            const SizedBox(height: 10),

            if (adData.containsKey("price"))
              Text(
                "Fiyat: ${adData["price"]} TL",
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.red,
                ),
              ),

            const SizedBox(height: 20),

            // 👤 Kullanıcı bilgileri (Gerçek zamanlı)
            StreamBuilder<DocumentSnapshot>(
              stream: FirebaseFirestore.instance
                  .collection("users")
                  .doc(ownerId)
                  .snapshots(),
              builder: (context, snapshot) {
                if (!snapshot.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }

                final userData =
                snapshot.data!.data() as Map<String, dynamic>?;

                if (userData == null) {
                  return const Text("Kullanıcı bilgisi bulunamadı");
                }

                return Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    // Profil resmi ve isim
                    Row(
                      children: [
                        CircleAvatar(
                          radius: 30,
                          backgroundImage: userData["photoURL"] != null &&
                              userData["photoURL"].toString().isNotEmpty
                              ? NetworkImage(userData["photoURL"])
                              : const AssetImage('assets/images/default_profile.png')
                          as ImageProvider,
                        ),
                        const SizedBox(width: 10),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              userData["name"] ?? "Bilinmeyen Kullanıcı",
                              style: const TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const Text(
                              "İlan Sahibi",
                              style: TextStyle(fontSize: 14, color: Colors.grey),
                            ),
                          ],
                        ),
                      ],
                    ),

                    // Mesaj gönder butonu
                    if (currentUser != null && currentUser.uid != ownerId)
                      ElevatedButton(
                        onPressed: () async {
                          String chatId = await createChatIfNotExists(
                              currentUser.uid, ownerId);
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => ChatDetailPage(chatId: chatId),
                            ),
                          );
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.pink[300],
                        ),
                        child: const Text("Mesaj Gönder"),
                      ),
                  ],
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}
