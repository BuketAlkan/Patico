import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'pet_detailpage.dart';

class FavoritesPage extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      return Scaffold(
        appBar: AppBar(title: Text("Favorilerim")),
        body: Center(child: Text("Favorileri görmek için giriş yapmalısınız!")),
      );
    }

    return Scaffold(
      appBar: AppBar(title: Text("Favorilerim")),
      body: StreamBuilder(
        stream: FirebaseFirestore.instance
            .collection("Favorites")
            .doc(user.uid)
            .collection("UserFavorites")
            .snapshots(),
        builder: (context, AsyncSnapshot<QuerySnapshot> snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return Center(child: CircularProgressIndicator());
          }
          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return Center(child: Text("Favori ilanınız yok."));
          }

          return ListView.builder(
            itemCount: snapshot.data!.docs.length,
            itemBuilder: (context, index) {
              var doc = snapshot.data!.docs[index];
              var favData = doc.data() as Map<String, dynamic>;
              String adId = doc.id;

              return ListTile(
                title: Text(favData["title"] ?? "İlan Başlığı Yok"),
                leading: Image.network(
                  favData["imageUrl"] ?? "https://cdn.pixabay.com/photo/2017/09/25/13/12/dog-2785074_1280.jpg",
                  width: 50,
                  height: 50,
                  fit: BoxFit.cover,
                ),
                trailing: IconButton(
                  icon: Icon(Icons.favorite, color: Colors.red),
                  onPressed: () => _toggleFavorite(adId, user.uid, favData),
                ),
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => PetDetailPage(adData: favData)),
                ),
              );
            },
          );
        },
      ),
    );
  }

  void _toggleFavorite(String adId, String userId, Map<String, dynamic> adData) async {
    final favRef = FirebaseFirestore.instance
        .collection("Favorites")
        .doc(userId)
        .collection("UserFavorites")
        .doc(adId);

    final docSnapshot = await favRef.get();
    if (docSnapshot.exists) {
      await favRef.delete(); // Favoriden çıkar
    } else {
      await favRef.set(adData); // Favorilere ekle
    }
  }
}
