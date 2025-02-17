import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/cupertino.dart';
import 'package:geolocator/geolocator.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'dart:convert';

class AuthMethod {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final ImagePicker _picker = ImagePicker();

  // Konum bilgisi almak için fonksiyon
  Future<Position> getCurrentLocation() async {
    bool serviceEnabled;
    LocationPermission permission;

    // Konum servislerinin etkin olup olmadığını kontrol et
    serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      return Future.error('Location services are disabled.');
    }

    // Konum izni olup olmadığını kontrol et
    permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        return Future.error('Location permissions are denied');
      }
    }

    // Konum bilgisini al
    return await Geolocator.getCurrentPosition(desiredAccuracy: LocationAccuracy.high);
  }

  // OpenCage API kullanarak enlem ve boylamdan şehir bilgisi alma
  Future<String> getCityFromCoordinates(double latitude, double longitude) async {
    final apiKey = '837dfb141a814026a1e86a65579fdf35';  // OpenCage API anahtarınızı buraya ekleyin
    final url = 'https://api.opencagedata.com/geocode/v1/json?q=$latitude+$longitude&key=$apiKey';

    final response = await http.get(Uri.parse(url));
    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      final city = data['results'][0]['components']['city'] ?? 'Bilinmeyen Şehir';
      return city;
    } else {
      throw Exception('Geocoding failed');
    }
  }

  // Kullanıcıyı kaydetme fonksiyonu
  Future<String> signupUser({
    required String email,
    required String password,
    required String name,
    required String phone,
  }) async {
    String res = "Some error occurred";
    try {
      if (email.isNotEmpty && password.isNotEmpty && name.isNotEmpty) {
        // Auth ile kullanıcıyı kaydet
        UserCredential cred = await _auth.createUserWithEmailAndPassword(
          email: email,
          password: password,
        );

        // Konum bilgisini al
        Position position = await getCurrentLocation();

        // Konumdan şehir bilgisini al
        String city = await getCityFromCoordinates(position.latitude, position.longitude);
 //String photoURL= await uploadProfilePicture(cred.user!.uid) ;
        // Kullanıcıyı Firestore'a ekle
        await _firestore.collection("users").doc(cred.user!.uid).set({
          'name': name,
          'password':password,
          'uid': cred.user!.uid,
          'email': email,
          'phone': phone,
          'createdAt': Timestamp.now(),
          'lastLogin': Timestamp.now(),
          'location': {'latitude': position.latitude, 'longitude': position.longitude},
          'city': city,


        });

        res = "success"; // Başarılı kayıt
      } else {
        res = "Please fill in all fields"; // Eksik bilgilerle form gönderildi
      }
    } catch (err) {
      res = err.toString(); // Hata mesajı döndür
    }
    return res;
  }

  // Kullanıcı giriş fonksiyonu
  Future<String> loginUser({
    required String email,
    required String password,
  }) async {
    String res = "Some error occurred";
    try {
      if (email.isNotEmpty && password.isNotEmpty) {
        UserCredential cred = await _auth.signInWithEmailAndPassword(
          email: email,
          password: password,
        );

        // Son giriş tarihini güncelle
        await _firestore.collection('users').doc(cred.user!.uid).update({
          'lastLogin': Timestamp.now(),
        });

        res = "success"; // Giriş başarılı
      } else {
        res = "Please fill in all fields"; // Giriş bilgileri eksikse uyarı
      }
    } on FirebaseAuthException catch (e) {
      res = "Error: ${e.message}"; // Firebase hatası
    } catch (err) {
      res = "Error: ${err.toString()}"; // Diğer hatalar
    }
    return res;
  }

  // Kullanıcı çıkışı yapma fonksiyonu
  Future<void> signOut() async {
    await _auth.signOut();
  }

  // Profil resmi değiştirme fonksiyonu
  Future<String> uploadProfilePicture(String uid) async {
    try {
      final pickedFile = await _picker.pickImage(source: ImageSource.gallery);
      if (pickedFile == null) {
        return "No image selected";
      }

      File file = File(pickedFile.path);

      final storageRef = FirebaseStorage.instance
          .ref()
          .child("profile_pictures")
          .child('$uid.jpg');

      // Fotoğrafı Firebase Storage'a yükle
      await storageRef.putFile(file);

      // Yükleme tamamlandıktan sonra URL'yi al
      String photoUrl = await storageRef.getDownloadURL();

      // Firestore'da kullanıcı profil fotoğrafını güncelle
      await _firestore.collection("users").doc(uid).update({
        'photoURL': photoUrl,
      });

      return photoUrl; // URL'yi döndür
    } catch (e) {
      return e.toString(); // Hata mesajını döndür
    }
  }
}
