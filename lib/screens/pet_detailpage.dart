import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'Chat_detail_page.dart';

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
    final bool isBakimIlan = adData["type"] == "Bakım";
    final String adId = adData["adId"] ?? ""; // adId'yi alıyoruz

    return Scaffold(
      appBar: AppBar(
        title: Text(adData["title"] ?? "İlan Detayı"),
        backgroundColor: Colors.pink[200],
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: SingleChildScrollView(
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

              // Kullanıcı bilgileri ve butonlar
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  // Kullanıcı bilgileri
                  Expanded(
                    child: StreamBuilder<DocumentSnapshot>(
                      stream: FirebaseFirestore.instance
                          .collection("users")
                          .doc(ownerId)
                          .snapshots(),
                      builder: (context, snapshot) {
                        if (snapshot.connectionState == ConnectionState.waiting) {
                          return const CircularProgressIndicator();
                        }

                        if (!snapshot.hasData || snapshot.data == null) {
                          return const Text("Kullanıcı bilgisi yüklenemedi");
                        }

                        final userData = snapshot.data!.data() as Map<String, dynamic>?;

                        return Row(
                          children: [
                            CircleAvatar(
                              radius: 30,
                              backgroundImage: (userData?["photoURL"] != null &&
                                  userData!["photoURL"].isNotEmpty)
                                  ? NetworkImage(userData["photoURL"])
                                  : const AssetImage('assets/images/default_profile.png')
                              as ImageProvider,
                            ),
                            const SizedBox(width: 10),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  userData?["name"] ?? "Bilinmeyen Kullanıcı",
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
                        );
                      },
                    ),
                  ),

                  // Mesaj butonu (HER ZAMAN GÖRÜNÜR)
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
              ),

              // Kabul edilmiş talep kontrolü
              const SizedBox(height: 20),
              StreamBuilder<QuerySnapshot>(
                stream: FirebaseFirestore.instance
                    .collection('requests')
                    .where('adId', isEqualTo: adId)
                    .where('status', isEqualTo: 'accepted')
                    .snapshots(),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  }

                  final hasAcceptedRequest = snapshot.hasData && snapshot.data!.docs.isNotEmpty;

                  return Column(
                    children: [
                      // TALEP BUTONU (SADECE BAKIM İLANLARINDA VE KABUL EDİLMEMİŞSE)
                      if (currentUser != null &&
                          currentUser.uid != ownerId &&
                          isBakimIlan &&
                          !hasAcceptedRequest)
                        _buildRequestButton(context, adId, currentUser.uid),

                      // Kabul edilmiş talep uyarısı
                      if (hasAcceptedRequest)
                        Padding(
                          padding: const EdgeInsets.only(top: 20),
                          child: Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: Colors.orange[50],
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: Colors.orange),
                            ),
                            child: Row(
                              children: [
                                Icon(Icons.warning, color: Colors.orange[800]),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Text(
                                    "Bu ilan için kabul edilmiş talep bulunmaktadır. Yeni talep gönderemezsiniz.",
                                    style: TextStyle(
                                        color: Colors.orange[800],
                                        fontWeight: FontWeight.w500
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                    ],
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildRequestButton(BuildContext context, String adId, String userId) {
    // Talep gönderme işlemini yapan fonksiyon
    Future<void> sendRequest() async {
      final requestsRef = FirebaseFirestore.instance.collection('requests');

      // Aynı talebin daha önce gönderilip gönderilmediğini kontrol et
      final existingRequests = await requestsRef
          .where('adId', isEqualTo: adId)
          .where('providerId', isEqualTo: userId)
          .get();

      if (existingRequests.docs.isNotEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("Bu ilana zaten talep gönderdiniz."),
            duration: Duration(seconds: 2),
          ),
        );
        return;
      }

      // Yeni talep oluştur
      await requestsRef.add({
        'adId': adId,
        'clientId': adData["userId"], // İlan sahibi
        'providerId': userId, // Talep gönderen
        'status': 'pending', // Beklemede
        'createdAt': Timestamp.now(),
        'petName': adData['title'] ?? '',
        'price': adData['price'] ?? 0,
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Talebiniz başarıyla gönderildi!"),
          duration: Duration(seconds: 2),
          backgroundColor: Colors.green,
        ),
      );
    }

    // Talep onay dialogu göster
    void showRequestConfirmation() {
      showDialog(
        context: context,
        builder: (BuildContext context) {
          return AlertDialog(
            title: const Text("Talep Onayı"),
            content: const Text("Bu ilana talep göndermek istediğinize emin misiniz?"),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text("Hayır", style: TextStyle(color: Colors.red)),
              ),
              ElevatedButton(
                onPressed: () {
                  Navigator.pop(context);
                  sendRequest();
                },
                style: ElevatedButton.styleFrom(backgroundColor: Colors.pink[300]),
                child: const Text("Evet"),
              ),
            ],
          );
        },
      );
    }

    return Padding(
      padding: const EdgeInsets.only(top: 30),
      child: ElevatedButton.icon(
        icon: const Icon(Icons.send),
        label: const Text("Talep Gönder"),
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.pink[300],
          minimumSize: const Size(double.infinity, 50),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
        onPressed: showRequestConfirmation,
      ),
    );
  }
}