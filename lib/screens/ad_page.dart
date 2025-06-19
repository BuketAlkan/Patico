import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
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
  String userCity = '';

  // Tür (species) için state
  final List<String> _speciesOptions = ['Köpek', 'Kedi', 'Kuş', 'Diğer'];
  String _selectedSpecies = 'Köpek';

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

  Future<String?> _uploadToImgbb(File imageFile) async {
    const String imgbbApiKey = '984d720ca4875a9e9aede1fbb12b0ccb';
    final url = Uri.parse("https://api.imgbb.com/1/upload?key=$imgbbApiKey");

    final base64Image = base64Encode(await imageFile.readAsBytes());
    final response = await http.post(url, body: {'image': base64Image});

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      return data['data']['url'];
    } else {
      print("❌ imgbb yükleme hatası: ${response.body}");
      return null;
    }
  }

  Future<void> _createAd() async {
    if (_titleController.text.isEmpty || _descriptionController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Lütfen tüm alanları doldurun!')),
      );
      return;
    }

    String? imageUrl;

    if (_isImagePicked && _image != null) {
      imageUrl = await _uploadToImgbb(File(_image!.path));
      if (imageUrl == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Fotoğraf yüklenemedi.')),
        );
        return;
      }
    }

    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    final userId = user.uid;
    final adType = ref.read(adTypeProvider);

    DocumentSnapshot userDoc = await FirebaseFirestore.instance
        .collection('users')
        .doc(userId)
        .get();
    String userName = userDoc.exists ? userDoc['name'] : 'Anonim';
    String userCity = userDoc.exists ? userDoc['city'] ?? '' : '';

    DocumentReference adRef = await FirebaseFirestore.instance
        .collection(adType)
        .add({
      'title': _titleController.text,
      'description': _descriptionController.text,
      'price': adType == 'Bakım' ? _priceController.text : null,
      'userId': userId,
      'userName': userName,
      'imageUrl': imageUrl,
      'createdAt': Timestamp.now(),
      'species': _selectedSpecies,
      'city': userCity,
      'type': adType, //

    });


    await adRef.update({'adId': adRef.id});

    setState(() {
      _titleController.clear();
      _descriptionController.clear();
      _priceController.clear();
      _image = null;
      _isImagePicked = false;
      _selectedSpecies = _speciesOptions.first;
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('İlan başarıyla oluşturuldu!')),
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
            // Tür seçimi butonları
            Text('Tür Seçimi', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            SizedBox(height: 8),
            Wrap(
              spacing: 8,
              children: _speciesOptions.map((s) {
                final isSelected = s == _selectedSpecies;
                return ChoiceChip(
                  label: Text(s),
                  selected: isSelected,
                  selectedColor: Colors.blue.shade200,
                  onSelected: (_) => setState(() => _selectedSpecies = s),
                );
              }).toList(),
            ),
            SizedBox(height: 16),
            GestureDetector(
              onTap: _pickImage,
              child: Container(
                height: 200,
                width: double.infinity,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(15),
                  boxShadow: [
                    BoxShadow(color: Colors.purple.shade100, blurRadius: 10, spreadRadius: 2),
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
                    Text('Resim Seç', style: TextStyle(color: Colors.grey.shade600)),
                  ],
                ),
              ),
            ),
            SizedBox(height: 16),
            _buildTextField(_titleController, 'İlan Başlığı'),
            SizedBox(height: 12),
            _buildTextField(_descriptionController, 'İlan Açıklaması', maxLines: 3),
            if (adType == 'Bakım') ...[
              SizedBox(height: 12),
              _buildTextField(_priceController, 'Ücret (₺)', isNumber: true),
            ],
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
                onPressed: _createAd,
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
