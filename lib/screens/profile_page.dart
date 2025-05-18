import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:image_picker/image_picker.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:io';

import '../services/auth_provider.dart';
import 'package:patico/screens/pet_detailpage.dart';

class ProfilePage extends ConsumerStatefulWidget {
  const ProfilePage({super.key});

  @override
  _ProfilePageState createState() => _ProfilePageState();
}

class _ProfilePageState extends ConsumerState<ProfilePage> {
  final ImagePicker _picker = ImagePicker();
  String? _imageUrl;

  Future<void> _changeProfilePicture() async {
    final source = await showDialog<ImageSource>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Fotoğraf Seç'),
        content: const Text('Profil fotoğrafınızı nereden seçmek istersiniz?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, ImageSource.camera),
            child: const Text('Kamera'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, ImageSource.gallery),
            child: const Text('Galeri'),
          ),
        ],
      ),
    );

    if (source == null) return;

    final pickedFile = await _picker.pickImage(source: source);
    if (pickedFile == null) return;

    try {
      final imageBytes = await File(pickedFile.path).readAsBytes();
      final base64Image = base64Encode(imageBytes);

      final response = await http.post(
        Uri.parse('https://api.imgbb.com/1/upload?key=984d720ca4875a9e9aede1fbb12b0ccb'),
        body: {'image': base64Image},
      );

      final responseData = json.decode(response.body);
      if (response.statusCode == 200 && responseData['data']['url'] != null) {
        final imageUrl = responseData['data']['url'];
        final user = FirebaseAuth.instance.currentUser!;
        final uid = user.uid;

        // Firestore'da kullanıcı belgesi varsa güncelle, yoksa oluştur
        final userDocRef = FirebaseFirestore.instance.collection('users').doc(uid);
        await userDocRef.set({'photoURL': imageUrl}, SetOptions(merge: true));

        // Firebase Authentication profilini güncelle
        await user.updatePhotoURL(imageUrl);

        setState(() {
          _imageUrl = imageUrl;
        });

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Profil fotoğrafı başarıyla güncellendi")),
        );
      } else {
        throw Exception("ImgBB yükleme hatası: ${response.body}");
      }
    } catch (e) {
      print("Profil fotoğrafı yüklenirken hata: $e");
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Profil fotoğrafı güncellenirken bir hata oluştu")),
      );
    }
  }

  Future<void> _deleteAdAndRemoveFromFavorites(String collection, String adId) async {
    try {
      final batch = FirebaseFirestore.instance.batch();

      final allUsers = await FirebaseFirestore.instance.collection('Favorites').get();
      for (var userDoc in allUsers.docs) {
        final userFavorites = await FirebaseFirestore.instance
            .collection('Favorites')
            .doc(userDoc.id)
            .collection('UserFavorites')
            .where('adId', isEqualTo: adId)
            .get();

        for (var favDoc in userFavorites.docs) {
          batch.delete(favDoc.reference);
        }
      }

      batch.delete(FirebaseFirestore.instance.collection(collection).doc(adId));
      await batch.commit();

      print("İlan ve favoriler başarıyla silindi!");
    } catch (e) {
      print("HATA: ${e.toString()}");
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("İlan silinirken bir hata oluştu")),
      );
    }
  }

  Widget _buildAdList(String collection) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection(collection)
          .where('userId', isEqualTo: FirebaseAuth.instance.currentUser!.uid)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return Padding(
            padding: const EdgeInsets.all(16.0),
            child: Text(
              "$collection ilanı bulunamadı",
              style: const TextStyle(color: Colors.grey),
            ),
          );
        }

        return ListView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: snapshot.data!.docs.length,
          itemBuilder: (context, index) {
            final doc = snapshot.data!.docs[index];
            final data = doc.data() as Map<String, dynamic>;

            return Card(
              margin: const EdgeInsets.symmetric(vertical: 8),
              elevation: 3,
              child: ListTile(
                contentPadding: const EdgeInsets.all(12),
                leading: CircleAvatar(
                  backgroundColor: Colors.purple[100],
                  child: const Icon(Icons.pets, color: Colors.purple),
                ),
                title: Text(
                  data['title'] ?? 'Başlıksız',
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                subtitle: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(data['description'] ?? 'Açıklama yok'),
                    if (data['petType'] != null)
                      Padding(
                        padding: const EdgeInsets.only(top: 4.0),
                        child: Chip(
                          label: Text(data['petType']),
                          backgroundColor: Colors.purple[50],
                        ),
                      ),
                  ],
                ),
                trailing: IconButton(
                  icon: const Icon(Icons.delete, color: Colors.red),
                  onPressed: () => _showDeleteDialog(collection, doc.id),
                ),
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => PetDetailPage(adData: data),
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  Future<void> _showDeleteDialog(String collection, String adId) async {
    return showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("İlanı Sil"),
        content: const Text("Bu ilanı silmek istediğinize emin misiniz? Bu işlem geri alınamaz."),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("İptal"),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(context);
              await _deleteAdAndRemoveFromFavorites(collection, adId);
            },
            child: const Text("Sil", style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Profilim"),
        centerTitle: true,
        backgroundColor: const Color(0xFFBB86FC),
      ),
      body: ref.watch(authStateProvider).when(
        data: (user) => user == null
            ? const Center(child: Text("Lütfen giriş yapın"))
            : _buildProfileContent(user),
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (_, __) => const Center(child: Text("Hata oluştu")),
      ),
    );
  }

  Widget _buildProfileContent(User user) {
    return FutureBuilder<DocumentSnapshot>(
      future: FirebaseFirestore.instance.collection('users').doc(user.uid).get(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (!snapshot.hasData || !snapshot.data!.exists) {
          return const Center(child: Text("Kullanıcı bilgileri bulunamadı"));
        }

        final userData = snapshot.data!.data() as Map<String, dynamic>;

        return SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              _buildProfileHeader(user, userData),
              const SizedBox(height: 24),
              _buildAdSection(),
            ],
          ),
        );
      },
    );
  }

  Widget _buildProfileHeader(User user, Map<String, dynamic> userData) {
    final profileImageUrl = _imageUrl?.isNotEmpty == true
        ? _imageUrl!
        : (userData['photoURL']?.isNotEmpty == true
        ? userData['photoURL']
        : (user.photoURL?.isNotEmpty == true
        ? user.photoURL!
        : 'https://via.placeholder.com/150'));
    return Column(
      children: [
        Stack(
          alignment: Alignment.bottomRight,
          children: [
            CircleAvatar(
              radius: 60,
              backgroundImage: NetworkImage(profileImageUrl),
            ),
            Container(
              decoration: BoxDecoration(
                color: Colors.purple,
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white, width: 2),
              ),
              child: IconButton(
                icon: const Icon(Icons.camera_alt, color: Colors.white),
                onPressed: _changeProfilePicture,
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        Text(
          userData['name'] ?? 'İsimsiz',
          style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 4),
        Text(
          userData['city'] ?? 'Şehir belirtilmemiş',
          style: TextStyle(color: Colors.grey[600], fontSize: 16),
        ),
      ],
    );
  }

  Widget _buildAdSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(
          padding: EdgeInsets.symmetric(vertical: 8.0),
          child: Text(
            "İlanlarım",
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
          ),
        ),
        _buildAdList('Bakım'),
        const SizedBox(height: 16),
        _buildAdList('Sahiplenme'),
      ],
    );
  }
}
