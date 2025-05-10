import 'package:flutter/material.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import '../theme/colors.dart'; // Tema renkleri

final adTypeProvider = StateProvider<String>((ref) => 'Bakım');

class CreateAdPage extends ConsumerStatefulWidget {
  @override
  _CreateAdPageState createState() => _CreateAdPageState();
}

class _CreateAdPageState extends ConsumerState<CreateAdPage> {
  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _priceController = TextEditingController();
  XFile? _image;
  bool _isImagePicked = false;

  Future<void> _pickImage() async {
    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(source: ImageSource.gallery);
    setState(() {
      if (pickedFile != null) {
        _image = pickedFile;
        _isImagePicked = true;
      }
    });
  }

  Future<void> _createAd() async {
    if (_titleController.text.isEmpty || _descriptionController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Lütfen tüm alanları doldurun!')),
      );
      return;
    }

    String? imageUrl;
    if (_isImagePicked) {
      try {
        final storageRef = FirebaseStorage.instance
            .ref()
            .child('ads/${DateTime.now().millisecondsSinceEpoch}.jpg');

        final uploadTask = await storageRef.putFile(File(_image!.path));
        print("📸 Seçilen dosya yolu: ${_image!.path}");
        // Hatalıysa burada yakalanacak
        if (uploadTask.state == TaskState.success) {
          imageUrl = await storageRef.getDownloadURL();
        } else {
          throw Exception('Görsel yüklenemedi.');
    ;
        }
      } catch (e) {
        print("❌ Fotoğraf yükleme hatası: $e");
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Fotoğraf yüklenirken hata oluştu. Lütfen tekrar deneyin.')),
        );
        return; // Hata varsa ilan oluşturmayı iptal et
      }
    }

    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    final userId = user.uid;
    final adType = ref.read(adTypeProvider);

    DocumentSnapshot userDoc =
    await FirebaseFirestore.instance.collection('users').doc(userId).get();
    String userName = userDoc.exists ? userDoc['name'] : 'Anonim';

// Firestore'da yeni ilan eklerken, otomatik ID'yi alıp 'adId' olarak kaydediyoruz
    DocumentReference adRef = await FirebaseFirestore.instance.collection(adType).add({
      'title': _titleController.text,
      'description': _descriptionController.text,
      'price': adType == 'Bakım' ? _priceController.text : null,
      'userId': userId,
      'userName': userName,
      'imageUrl': imageUrl,
      'createdAt': Timestamp.now(),
    });

// Burada yeni eklenen ilan için Firestore tarafından otomatik oluşturulan ID'yi 'adId' olarak kullanıyoruz
    String adId = adRef.id;

// Şimdi bu 'adId'yi, favorilere ve diğer işlemlerde kullanabilirsin
    await adRef.update({
      'adId': adId, // ID'yi veriye ekliyoruz
    });
    print("✅ Firestore'a ilan başarıyla eklendi!");

setState(() {
    _titleController.clear();
    _descriptionController.clear();
    _priceController.clear();

      _isImagePicked = false;
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('İlan Başarıyla Oluşturuldu!')),
    );
  }

  @override
  Widget build(BuildContext context) {
    final adType = ref.watch(adTypeProvider);

    return Scaffold(
      backgroundColor: Colors.pink.shade50,
      appBar: AppBar(
        title: Text('İlan Oluştur', style: TextStyle(color: Colors.white)),
        backgroundColor: AppColor.primary,
        centerTitle: true,
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: EdgeInsets.symmetric(horizontal: 20, vertical: 10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            GestureDetector(
              onTap: _pickImage,
              child: Container(
                height: 200,
                width: double.infinity,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(15),
                  boxShadow: [
                    BoxShadow(color: Colors.purple.shade100, blurRadius: 10, spreadRadius: 2)
                  ],
                ),
                child: _isImagePicked
                    ? ClipRRect(
                  borderRadius: BorderRadius.circular(15),
                  child: Image.file(File(_image!.path), fit: BoxFit.cover),
                )
                    : Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.add_a_photo, size: 60, color: Colors.purple.shade300),
                    SizedBox(height: 8),
                    Text('Resim Seç', style: TextStyle(color: Colors.grey.shade600))
                  ],
                ),
              ),
            ),
            SizedBox(height: 16),
            _buildTextField(_titleController, 'İlan Başlığı'),
            SizedBox(height: 12),
            _buildTextField(_descriptionController, 'İlan Açıklaması', maxLines: 3),
            if (adType == 'Bakım') SizedBox(height: 12),
            if (adType == 'Bakım') _buildTextField(_priceController, 'Ücret (₺)', isNumber: true),
            SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _buildAdTypeButton('Bakım', adType == 'Bakım'),
                _buildAdTypeButton('Sahiplenme', adType == 'Sahiplenme'),
              ],
            ),
            SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton(
                onPressed:(){ _createAd();
    print("📌 İlanı Paylaş butonuna basıldı!"); },
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColor.primary,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                  shadowColor: Colors.purple.shade100,
                  elevation: 6,
                ),
                child: Text(
                  'İlanı Paylaş',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTextField(TextEditingController controller, String hintText, {bool isNumber = false, int maxLines = 1}) {
    return TextField(
      controller: controller,
      keyboardType: isNumber ? TextInputType.number : TextInputType.text,
      maxLines: maxLines,
      decoration: InputDecoration(
        hintText: hintText,
        filled: true,
        fillColor: Colors.white,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
        contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.purple.shade100, width: 1.5),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: AppColor.primary, width: 2),
        ),
      ),
    );
  }

  Widget _buildAdTypeButton(String label, bool isSelected) {
    return GestureDetector(
      onTap: () {
        ref.read(adTypeProvider.notifier).state = label;
      },
      child: AnimatedContainer(
        duration: Duration(milliseconds: 300),
        padding: EdgeInsets.symmetric(horizontal: 24, vertical: 12),
        decoration: BoxDecoration(
          color: isSelected ? AppColor.primary : Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: AppColor.primary, width: 2),
          boxShadow: isSelected ? [BoxShadow(color: Colors.purple.shade200, blurRadius: 8)] : [],
        ),
        child: Text(
          label,
          style: TextStyle(color: isSelected ? Colors.white : AppColor.primary, fontWeight: FontWeight.bold),
        ),
      ),
    );
  }
}
