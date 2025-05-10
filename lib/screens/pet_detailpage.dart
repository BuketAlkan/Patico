import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import 'Chat_detail_page.dart';

// ✅ Bu fonksiyonu ekle: Sohbet varsa getirir, yoksa oluşturur
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

// ✅ Ana sayfa
class PetDetailPage extends StatefulWidget {
  final Map<String, dynamic> adData;

  const PetDetailPage({Key? key, required this.adData}) : super(key: key);

  @override
  _PetDetailPageState createState() => _PetDetailPageState();
}

class _PetDetailPageState extends State<PetDetailPage> {
  Map<String, dynamic>? userData;

  @override
  void initState() {
    super.initState();
    fetchUserData();
  }

  void fetchUserData() async {
    if (widget.adData["userId"] != null) {
      DocumentSnapshot userDoc = await FirebaseFirestore.instance
          .collection("users")
          .doc(widget.adData["userId"])
          .get();

      if (userDoc.exists) {
        setState(() {
          userData = userDoc.data() as Map<String, dynamic>?;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final currentUser = FirebaseAuth.instance.currentUser;

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.adData["title"] ?? "İlan Detayı"),
        backgroundColor: Colors.pink[200],
        iconTheme: IconThemeData(color: Colors.white),
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
                widget.adData["imageUrl"] ?? "https://via.placeholder.com/150",
                height: 250,
                width: double.infinity,
                fit: BoxFit.cover,
              ),
            ),
            SizedBox(height: 15),

            // İlan başlığı
            Text(
              widget.adData["title"] ?? "İlan Başlığı",
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
                color: Colors.black,
              ),
            ),
            SizedBox(height: 10),

            // Açıklama
            Text(
              widget.adData["description"] ?? "Açıklama mevcut değil",
              style: TextStyle(fontSize: 16, color: Colors.black87),
            ),
            SizedBox(height: 10),

            if (widget.adData.containsKey("price"))
              Text(
                "Fiyat: ${widget.adData["price"]} TL",
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.red),
              ),

            SizedBox(height: 20),

            userData != null
                ? Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    CircleAvatar(
                      radius: 30,
                      backgroundImage: userData!["profileImageUrl"] != null && userData!["profileImageUrl"].toString().isNotEmpty
                          ? NetworkImage(userData!["profileImageUrl"])
                          : const AssetImage('assets/images/default_profile.png') as ImageProvider,
                    ),
                    SizedBox(width: 10),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          userData!["name"] ?? "Bilinmeyen Kullanıcı",
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text(
                          "İlan Sahibi",
                          style: TextStyle(fontSize: 14, color: Colors.grey),
                        ),
                      ],
                    ),
                  ],
                ),

                // ✅ Mesaj Gönder Butonu (kendi ilanı değilse göster)
                if (currentUser != null &&
                    currentUser.uid != widget.adData["userId"])
                  ElevatedButton(
                    onPressed: () async {
                      String chatId = await createChatIfNotExists(
                          currentUser.uid, widget.adData["userId"]);
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) =>
                              ChatDetailPage(chatId: chatId), // Bu sayfayı senin oluşturman gerek
                        ),
                      );
                    },
                    child: Text("Mesaj Gönder"),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.pink[300],
                    ),
                  ),
              ],
            )
                : Center(child: CircularProgressIndicator()),
          ],
        ),
      ),
    );
  }
}

//
