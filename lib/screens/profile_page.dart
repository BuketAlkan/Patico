import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:image_picker/image_picker.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:patico/screens/pet_detailpage.dart';
import 'dart:io'; // File sınıfını kullanabilmek için gerekli

import '../services/auth_provider.dart';

class ProfilePage extends ConsumerStatefulWidget {
  const ProfilePage({super.key});

  @override
  _ProfilePageState createState() => _ProfilePageState();
}

class _ProfilePageState extends ConsumerState<ProfilePage> {
  final ImagePicker _picker = ImagePicker();
  String? _imageUrl;

  Future<void> _changeProfilePicture() async {
    final pickedFile = await _picker.pickImage(source: ImageSource.gallery);
    if (pickedFile == null) {
      print("Resim seçilmedi");
      return;
    }

    File file = File(pickedFile.path);

    try {
      final storageRef = FirebaseStorage.instance
          .ref()
          .child("profile_pictures")
          .child('${FirebaseAuth.instance.currentUser!.uid}.jpg');

      await storageRef.putFile(file);

      String downloadUrl = await storageRef.getDownloadURL();

      await FirebaseFirestore.instance.collection('users').doc(FirebaseAuth.instance.currentUser!.uid).update({
        'photoURL': downloadUrl,
      });

      setState(() {
        _imageUrl = downloadUrl;
      });
    } catch (e) {
      print("Resim yüklenirken hata oluştu: $e");
    }
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authStateProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text("Profilim"),
        centerTitle: true,
        backgroundColor: Color(0xFFBB86FC),
      ),
      body: authState.when(
        data: (user) {
          if (user == null) {
            return Center(child: Text("Giriş yapmamış kullanıcı"));
          }

          return FutureBuilder<DocumentSnapshot>(
            future: FirebaseFirestore.instance.collection('users').doc(user.uid).get(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return Center(child: CircularProgressIndicator());
              }

              if (snapshot.hasError) {
                return Center(child: Text("Hata: ${snapshot.error}"));
              }

              if (!snapshot.hasData || !snapshot.data!.exists) {
                return Center(child: Text("Kullanıcı bilgileri bulunamadı"));
              }

              var userData = snapshot.data!.data() as Map<String, dynamic>;
              String name = userData['name'] ?? "Bilinmeyen Kullanıcı";
              String city = userData['city'] ?? 'Bilinmiyor';

              return SingleChildScrollView(  // Sayfayı kaydırılabilir yapıyoruz
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Align(
                        alignment: Alignment.center,
                        child: GestureDetector(
                          onTap: _changeProfilePicture,
                          child: CircleAvatar(
                            radius: 70,
                            backgroundImage: _imageUrl != null
                                ? NetworkImage(_imageUrl!)
                                : user.photoURL != null
                                ? NetworkImage(user.photoURL!)
                                : AssetImage("assets/default_avatar.png") as ImageProvider,
                          ),
                        ),
                      ),
                      SizedBox(height: 16),
                      Text(name, style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.purple)),
                      SizedBox(height: 8),
                      Text("Şehir: $city", style: TextStyle(fontSize: 18, color: Colors.grey[700])),
                      SizedBox(height: 20),
                      // İlanlarım Card
                      Card(
                        color: Color(0xFFF1E6FF),
                        elevation: 4,
                        child: Padding(
                          padding: const EdgeInsets.all(16.0),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                "İlanlarım",
                                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.purple),
                              ),
                              SizedBox(height: 12),
                              // Bakım ilanlarını listele
                              StreamBuilder<QuerySnapshot>(
                                stream: FirebaseFirestore.instance
                                    .collection('Bakım') // Bakım koleksiyonunu kullan
                                    .where('userId', isEqualTo: user.uid) // Kullanıcı ID'sine göre filtrele
                                    .snapshots(),
                                builder: (context, adSnapshot) {
                                  if (adSnapshot.connectionState == ConnectionState.waiting) {
                                    return Center(child: CircularProgressIndicator());
                                  }
                                  if (adSnapshot.hasError) {
                                    return Center(child: Text("Error: ${adSnapshot.error}"));
                                  }

                                  if (!adSnapshot.hasData || adSnapshot.data!.docs.isEmpty) {
                                    return Center(child: Text("İlan bulunamadı"));
                                  }

                                  var ads = adSnapshot.data!.docs;

                                  return ListView.builder(
                                    shrinkWrap: true,
                                    physics: NeverScrollableScrollPhysics(), // ListView'un scroll olmasını engelle
                                    itemCount: ads.length,
                                    itemBuilder: (context, index) {
                                      var adData = ads[index].data() as Map<String, dynamic>;
                                      return Card(
                                        elevation: 5,
                                        margin: EdgeInsets.symmetric(vertical: 10),
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(15),
                                        ),
                                        child: ListTile(
                                          contentPadding: EdgeInsets.all(16),
                                          title: Text(adData['title'] ?? 'Başlık yok', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
                                          subtitle: Text(adData['description'] ?? 'Açıklama yok', style: TextStyle(fontSize: 14)),
                                          leading: Icon(Icons.pets, size: 40, color: Colors.purple),
                                          trailing: Icon(Icons.arrow_forward_ios, color: Colors.purple),
                                          onTap: () {
                                            Navigator.push(
                                              context,
                                              MaterialPageRoute(
                                                builder: (context) => PetDetailPage(adData: adData),
                                              ),
                                            );
                                          },
                                        ),
                                      );
                                    },
                                  );
                                },
                              ),
                              SizedBox(height: 12),
                              // Sahiplenme ilanlarını listele
                              StreamBuilder<QuerySnapshot>(
                                stream: FirebaseFirestore.instance
                                    .collection('Sahiplenme') // Sahiplenme koleksiyonunu kullan
                                    .where('userId', isEqualTo: user.uid) // Kullanıcı ID'sine göre filtrele
                                    .snapshots(),
                                builder: (context, adSnapshot) {
                                  if (adSnapshot.connectionState == ConnectionState.waiting) {
                                    return Center(child: CircularProgressIndicator());
                                  }
                                  if (adSnapshot.hasError) {
                                    return Center(child: Text("Error: ${adSnapshot.error}"));
                                  }

                                  if (!adSnapshot.hasData || adSnapshot.data!.docs.isEmpty) {
                                    return Center(child: Text("İlan bulunamadı"));
                                  }

                                  var ads = adSnapshot.data!.docs;

                                  return ListView.builder(
                                    shrinkWrap: true,
                                    physics: NeverScrollableScrollPhysics(), // ListView'un scroll olmasını engelle
                                    itemCount: ads.length,
                                    itemBuilder: (context, index) {
                                      var adData = ads[index].data() as Map<String, dynamic>;
                                      return Card(
                                        elevation: 5,
                                        margin: EdgeInsets.symmetric(vertical: 10),
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(15),
                                        ),
                                        child: ListTile(
                                          contentPadding: EdgeInsets.all(16),
                                          title: Text(adData['title'] ?? 'Başlık yok', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
                                          subtitle: Text(adData['description'] ?? 'Açıklama yok', style: TextStyle(fontSize: 14)),
                                          leading: Icon(Icons.pets, size: 40, color: Colors.purple),
                                          trailing: Icon(Icons.arrow_forward_ios, color: Colors.purple),
                                          onTap: () {
                                            Navigator.push(
                                              context,
                                              MaterialPageRoute(
                                                builder: (context) => PetDetailPage(adData: adData),
                                              ),
                                            );
                                          },
                                        ),
                                      );
                                    },
                                  );
                                },
                              ),
                            ],
                          ),
                        ),
                      ),
                      SizedBox(height: 20),
                    ],
                  ),
                ),
              );
            },
          );
        },
        loading: () => Center(child: CircularProgressIndicator()),
        error: (err, stack) => Center(child: Text("Hata: $err")),
      ),
    );
  }
}
