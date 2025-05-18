import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'pet_detailpage.dart';
import 'package:http/http.dart' as http;



class MorePetsPage extends StatelessWidget {
  final String type;

  const MorePetsPage({Key? key, required this.type}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;

    return Scaffold(
      appBar: AppBar(
        title: Text(type, style: TextStyle(color: Colors.white)),
        backgroundColor: Colors.pink[200],
        iconTheme: IconThemeData(color: Colors.white),
      ),
      body: StreamBuilder(
        stream: FirebaseFirestore.instance.collection(type).snapshots(),
        builder: (context, AsyncSnapshot<QuerySnapshot> snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return Center(child: CircularProgressIndicator(color: Colors.pink));
          }
          if (snapshot.hasError) {
            return Center(child: Text("Hata: ${snapshot.error}"));
          }
          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return Center(child: Text("$type ilanı bulunamadı 🐾"));
          }

          return ListView.builder(
            padding: const EdgeInsets.all(15),
            itemCount: snapshot.data!.docs.length,
            itemBuilder: (context, index) {
              var adData = snapshot.data!.docs[index].data() as Map<
                  String,
                  dynamic>;
              String adId = snapshot.data!.docs[index].id;

              return _buildAdItem(context, adData, adId, user?.uid);
            },
          );
        },
      ),
    );
  }

  Widget _buildAdItem(BuildContext context, Map<String, dynamic> adData,
      String adId, String? userId) {
    bool isFavorited = false;

    return GestureDetector(
      onTap: () =>
          Navigator.push(
            context,
            MaterialPageRoute(
                builder: (context) => PetDetailPage(adData: adData)),
          ),
      child: Container(
        padding: EdgeInsets.all(10),
        margin: EdgeInsets.symmetric(vertical: 8),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(15),
          boxShadow: [
            BoxShadow(color: Colors.black12, blurRadius: 6, spreadRadius: 2)
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              adData["title"] ?? "İlansız Hayvan",
              style: TextStyle(fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: Colors.black),
            ),
            SizedBox(height: 8),
            ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: Image.network(
                adData["imageUrl"] ??
                    "https://cdn.pixabay.com/photo/2017/09/25/13/12/dog-2785074_1280.jpg",
                height: 150,
                width: double.infinity,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) =>
                    Container(
                      height: 150,
                      color: Colors.grey[200],
                      child: Icon(Icons.pets, size: 50, color: Colors.grey),
                    ),
              ),
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                IconButton(
                  icon: Icon(
                    isFavorited ? Icons.favorite : Icons.favorite_border,
                    color: isFavorited ? Colors.red : Colors.grey,
                  ),
                  onPressed: () {
                    if (userId != null) {
                      _toggleFavorite(adId, userId, adData);
                    } else {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text(
                            "Favorilere eklemek için giriş yapmalısınız!")),
                      );
                    }
                  },
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _toggleFavorite(String adId, String userId,
      Map<String, dynamic> adData) async {
    final favRef = FirebaseFirestore.instance
        .collection("Favorites")
        .doc(userId)
        .collection("UserFavorites")
        .doc(adId);

    final docSnapshot = await favRef.get();

    if (docSnapshot.exists) {
      // Zaten favorideyse: sil
      await favRef.delete();
      print("Favoriden kaldırıldı: $adId");
    } else {
      // Favoriye eklerken adData'ya adId bilgisini ekleyerek kaydediyoruz
      Map<String, dynamic> favoriteData = Map.from(adData);
      favoriteData["adId"] = adId;

      await favRef.set(favoriteData);
      print("Favoriye eklendi: $adId");

      // Favori ekledikten sonra bildirim gönder
      _sendFavoriteNotification(adData); // Bildirim gönderme fonksiyonu
    }
  }

// Favori ekledikten sonra bildirim gönderme
  void _sendFavoriteNotification(Map<String, dynamic> adData) async {
    final userToken = await _getUserToken(
        adData['userId']); // Kullanıcının FCM token'ını al

    if (userToken != null) {
      final message = {
        'to': userToken,
        'notification': {
          'title': 'Yeni Favoriniz',
          'body': 'Favorilerinize yeni bir ilan eklendi: ${adData["title"]}'
        },
        'data': {
          'type': 'favorite',
          'adId': adData["adId"]
        }
      };

      await _sendPushNotification(message);
    }
  }

// Kullanıcının FCM token'ını almak
  Future<String?> _getUserToken(String userId) async {
    final userDoc = await FirebaseFirestore.instance.collection('users').doc(
        userId).get();
    if (userDoc.exists) {
      return userDoc
          .data()?['fcmToken']; // FCM token'ı firestore'da saklı olmalı
    }
    return null;
  }

// Bildirim gönderme işlemi
  Future<void> _sendPushNotification(Map<String, dynamic> message) async {
    final url = Uri.parse('https://fcm.googleapis.com/fcm/send');
    final response = await http.post(url,
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'key=YOUR_FCM_SERVER_KEY', // FCM server key
        },
        body: json.encode(message));

    if (response.statusCode == 200) {
      print("Bildirim başarıyla gönderildi.");
    } else {
      print("Bildirim gönderme başarısız oldu.");
    }
  }
}





