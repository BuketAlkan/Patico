import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:image_picker/image_picker.dart';
import 'package:firebase_storage/firebase_storage.dart';
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

  // Kullanıcı resmini değiştirmek için
  Future<void> _changeProfilePicture() async {
    // Resim seçme işlemi
    final pickedFile = await _picker.pickImage(source: ImageSource.gallery);
    if (pickedFile == null) {
      print("Resim seçilmedi");
      return;
    }

    // Seçilen dosya yolunu al
    File file = File(pickedFile.path);

    try {
      // Firebase Storage'a dosya yüklemek için referans oluştur
      final storageRef = FirebaseStorage.instance
          .ref()
          .child("profile_pictures")
          .child('${FirebaseAuth.instance.currentUser!.uid}.jpg');

      // Dosyayı Firebase Storage'a yükle
      await storageRef.putFile(file);

      // Yükleme tamamlandıktan sonra dosyanın URL'sini al
      String downloadUrl = await storageRef.getDownloadURL();

      // Firestore'da kullanıcı resmini güncelle
      await FirebaseFirestore.instance.collection('users').doc(FirebaseAuth.instance.currentUser!.uid).update({
        'photoURL': downloadUrl,
      });

      // Resmi sayfada güncelle
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
        backgroundColor: Color(0xFFBB86FC), // Purple theme
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
              String city = userData['city'] ?? 'Bilinmiyor'; // Şehir adı Firestore'dan alınır

              return Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.start,
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    // Profil Resmi
                    GestureDetector(
                      onTap: _changeProfilePicture, // Resme tıklandığında resim değiştirilir
                      child: CircleAvatar(
                        radius: 70,
                        backgroundImage: _imageUrl != null
                            ? NetworkImage(_imageUrl!)
                            : user.photoURL != null
                            ? NetworkImage(user.photoURL!)
                            : AssetImage("assets/default_avatar.png") as ImageProvider,
                      ),
                    ),
                    SizedBox(height: 16),

                    // Kullanıcı Adı (Firestore'dan alınır)
                    Text(
                      name,
                      style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.purple),
                    ),
                    SizedBox(height: 8),

                    // Şehir Adı
                    Text(
                      "Şehir: $city",
                      style: TextStyle(fontSize: 18, color: Colors.grey[700]),
                    ),
                    SizedBox(height: 20),

                    // "İlanlarım" adlı card
                    Card(
                      color: Color(0xFFF1E6FF), // Light purple card color
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
                            // İçerik eklemek için yer bırakılmış
                            Text("Buraya ilanlar eklenecek...", style: TextStyle(color: Colors.grey[500])),
                          ],
                        ),
                      ),
                    ),
                    SizedBox(height: 20),



                  ],
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
