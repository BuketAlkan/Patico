import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class PetDetailPage extends StatefulWidget {
  final Map<String, dynamic> adData;

  const PetDetailPage({Key? key, required this.adData}) : super(key: key);

  @override
  _PetDetailPageState createState() => _PetDetailPageState();
}

class _PetDetailPageState extends State<PetDetailPage> {
  Map<String, dynamic>? userData; // Kullanıcı bilgilerini burada saklayacağız.

  @override
  void initState() {
    super.initState();
    fetchUserData();
  }

  // Kullanıcı bilgilerini Firestore'dan çek
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

            // Eğer bakım ilanıysa fiyatı göster
            if (widget.adData.containsKey("price"))
              Text(
                "Fiyat: ${widget.adData["price"]} TL",
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.red),
              ),

            SizedBox(height: 20),

            // Kullanıcı bilgileri (Eğer veriler yüklendiyse göster)
            userData != null
                ? Row(
              children: [
                // Profil Resmi
                CircleAvatar(
                  radius: 30,
                  backgroundImage: NetworkImage(
                    userData!["profileImageUrl"] ??
                        "https://via.placeholder.com/100", // Varsayılan profil resmi
                  ),
                ),
                SizedBox(width: 10),

                // Kullanıcı Adı
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
            )
                : Center(child: CircularProgressIndicator()), // Kullanıcı bilgileri yüklenene kadar gösterilir
          ],
        ),
      ),
    );
  }
}
