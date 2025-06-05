import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'pet_detailpage.dart';

class FavoritesPage extends StatelessWidget {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

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
      body: StreamBuilder<QuerySnapshot>(
        stream: _firestore
            .collection("Favorites")
            .doc(user.uid)
            .collection("UserFavorites")
            .orderBy('timestamp', descending: true)
            .snapshots(),
        builder: (context, favSnap) {
          if (favSnap.connectionState == ConnectionState.waiting) {
            return Center(child: CircularProgressIndicator());
          }

          final favDocs = favSnap.data?.docs ?? [];
          if (favDocs.isEmpty) {
            return Center(child: Text("Hiç favori ilanınız yok."));
          }

          return ListView.builder(
            itemCount: favDocs.length,
            itemBuilder: (context, index) {
              final favDoc = favDocs[index];
              final String adId = favDoc.id;
              final String? collection =
              favDoc.data().toString().contains('collection')
                  ? favDoc.get('collection') as String
                  : null;

              return FutureBuilder<Map<String, dynamic>?>(
                future: _fetchAdData(adId, collection: collection),
                builder: (context, adSnap) {
                  if (adSnap.connectionState == ConnectionState.waiting) {
                    return ListTile(title: Text("Yükleniyor..."));
                  }

                  final adData = adSnap.data;
                  if (adData == null) {
                    return ListTile(title: Text("İlan bulunamadı"));
                  }

                  final title = adData['title'] as String? ?? 'Başlık yok';
                  final imageUrl = adData['imageUrl'] as String? ?? '';

                  return ListTile(
                    leading: imageUrl.isNotEmpty
                        ? Image.network(imageUrl, width: 50, height: 50, fit: BoxFit.cover)
                        : Icon(Icons.pets),
                    title: Text(title),
                    trailing: IconButton(
                      icon: Icon(Icons.favorite, color: Colors.red),
                      onPressed: () => _toggleFavorite(adId, user.uid),
                    ),
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => PetDetailPage(adData: adData),
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

  /// Belirtilen koleksiyona göre ya da her iki koleksiyonu kontrol ederek ilan verisini getirir
  Future<Map<String, dynamic>?> _fetchAdData(String adId, {String? collection}) async {
    if (collection != null) {
      final doc = await _firestore.collection(collection).doc(adId).get();
      if (doc.exists && doc.data() != null) {
        final data = Map<String, dynamic>.from(doc.data()!);
        data['adId'] = adId;
        return data;
      }
    } else {
      // Koleksiyon belirtilmediyse her iki koleksiyonda ara
      final sahDoc = await _firestore.collection('Sahiplenme').doc(adId).get();
      if (sahDoc.exists && sahDoc.data() != null) {
        final data = Map<String, dynamic>.from(sahDoc.data()!);
        data['adId'] = adId;
        return data;
      }

      final bakDoc = await _firestore.collection('Bakım').doc(adId).get();
      if (bakDoc.exists && bakDoc.data() != null) {
        final data = Map<String, dynamic>.from(bakDoc.data()!);
        data['adId'] = adId;
        return data;
      }
    }

    return null;
  }

  /// Favori ekleme/silme işlemi
  Future<void> _toggleFavorite(String adId, String userId) async {
    final favRef = _firestore
        .collection("Favorites")
        .doc(userId)
        .collection("UserFavorites")
        .doc(adId);

    final snapshot = await favRef.get();
    if (snapshot.exists) {
      await favRef.delete();
    } else {
      await favRef.set({
        'timestamp': FieldValue.serverTimestamp(),
        // İsteğe bağlı: hangi koleksiyona ait olduğunu da kaydedebilirsin
        // 'collection': 'Sahiplenme' veya 'Bakim'
      });
    }
  }
}
