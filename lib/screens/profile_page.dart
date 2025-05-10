import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:image_picker/image_picker.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:patico/screens/pet_detailpage.dart';
import 'dart:io';

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
    if (pickedFile == null) return;

    try {
      final uid = FirebaseAuth.instance.currentUser!.uid;
      final storageRef = FirebaseStorage.instance
          .ref()
          .child("profile_pictures/$uid.jpg");

      await storageRef.putFile(File(pickedFile.path));
      String downloadUrl = await storageRef.getDownloadURL();

      // Firestore ve Auth güncelle
      await FirebaseFirestore.instance.collection('users').doc(uid).update({'photoURL': downloadUrl});
      await FirebaseAuth.instance.currentUser!.updatePhotoURL(downloadUrl);

      setState(() => _imageUrl = downloadUrl);
    } catch (e) {
      print("Resim yükleme hatası: $e");
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Profil resmi güncellenirken hata oluştu")),
      );
    }
  }

  Future<void> _deleteAdAndRemoveFromFavorites(String collection, String adId) async {
    try {
      final batch = FirebaseFirestore.instance.batch();

      // Tüm kullanıcıların favorilerinde ilanı sil
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

      // İlanı sil
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
        : (user.photoURL?.isNotEmpty == true
        ? user.photoURL!
        : 'https://via.placeholder.com/150');

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
