import 'dart:io';  // Dosya işlemleri için
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';

final firebaseAuthProvider = Provider<FirebaseAuth>((ref) {
  return FirebaseAuth.instance;
});

final authStateProvider = StreamProvider<User?>((ref) {
  return ref.watch(firebaseAuthProvider).authStateChanges();
});

// Firestore provider
final firestoreProvider = Provider<FirebaseFirestore>((ref) {
  return FirebaseFirestore.instance;
});

// Firebase Storage provider
final firebaseStorageProvider = Provider<FirebaseStorage>((ref) {
  return FirebaseStorage.instance;
});

// Profil resmi URL'sini almak için provider
final profilePicUrlProvider = FutureProvider.family<String, String>((ref, userId) async {
  final firestore = ref.watch(firestoreProvider);
  final snapshot = await firestore.collection('users').doc(userId).get();

  // Veri olup olmadığını kontrol et
  if (!snapshot.exists) {
    throw Exception('User not found in Firestore');
  }

  final data = snapshot.data();  // Burada data null olursa kontrol edilmelidir
  String profilePicUrl = data?['profilePicUrl'] ?? '';  // 'profilePicUrl' null olursa boş değer dön

  // Eğer profil resmi URL'si yoksa, varsayılan bir URL ver
  if (profilePicUrl.isEmpty) {
    profilePicUrl = 'https://example.com/default-avatar.png';  // Varsayılan resim URL'si
  }

  return profilePicUrl;
});

// Profil resmi yüklemek ve Firestore'a kaydetmek için provider
final uploadProfilePicProvider = FutureProvider.family<void, String>((ref, filePath) async {
  final authState = ref.watch(authStateProvider);

  // Kullanıcı durumu kontrolü
  return authState.when(
    data: (user) async {
      if (user == null) {
        throw Exception("User not authenticated");
      }

      final storage = ref.watch(firebaseStorageProvider);
      final storageRef = storage.ref().child('profile_pics/${user.uid}');

      // Dosya yükleme
      final file = File(filePath);  // Dosya yolu üzerinden File nesnesi oluşturuluyor
      if (!await file.exists()) {
        throw Exception("File does not exist at path: $filePath");
      }

      final uploadTask = await storageRef.putFile(file);
      final downloadUrl = await uploadTask.ref.getDownloadURL();

      final firestore = ref.watch(firestoreProvider);
      await firestore.collection('users').doc(user.uid).update({
        'profilePicUrl': downloadUrl,
      });
    },
    loading: () {
      throw Exception("Loading user state...");
    },
    error: (error, stack) {
      throw Exception("Error loading user state: $error");
    },
  );
});
