import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'pet_detailpage.dart';
import 'package:http/http.dart' as http;

class MorePetsPage extends StatefulWidget {
  final String type;
  const MorePetsPage({Key? key, required this.type}) : super(key: key);

  @override
  State<MorePetsPage> createState() => _MorePetsPageState();
}

class _MorePetsPageState extends State<MorePetsPage> {
  bool _descending = true; // true = Yeni→Eski, false = Eski→Yeni

  // Tür filtresi
  final List<String> _speciesOptions = ['Hepsi', 'Köpek', 'Kedi', 'Kuş', 'Diğer'];
  String _filterSpecies = 'Hepsi';

  String userCity = '';
  @override
  void initState() {
    super.initState();
    _loadUserCity();  // burayı ekle
  }
  Future<void> _loadUserCity() async {
    final userId = FirebaseAuth.instance.currentUser?.uid;
    if (userId == null) return;
    final doc = await FirebaseFirestore.instance
        .collection('users')
        .doc(userId)
        .get();
    if (doc.exists && doc.data()!.containsKey('city')) {
      setState(() {
        userCity = doc['city'] as String;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.type, style: TextStyle(color: Colors.white)),
        backgroundColor: Colors.pink[200],
        iconTheme: IconThemeData(color: Colors.white),
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Sıralama ve türe göre filtre çipleri
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Wrap(
              spacing: 8,
              children: [
                // Sıralama çipi
                GestureDetector(
                  onTap: () => setState(() => _descending = !_descending),
                  child: Container(
                    padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: Colors.pink[50],
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: Colors.pink.shade200),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          _descending ? Icons.arrow_downward : Icons.arrow_upward,
                          size: 16,
                          color: Colors.pink,
                        ),
                        SizedBox(width: 4),
                        Text(
                          _descending ? 'Yeni → Eski' : 'Eski → Yeni',
                          style: TextStyle(color: Colors.pink, fontWeight: FontWeight.w600),
                        ),
                      ],
                    ),
                  ),
                ),
                // Tür filtre çipi
                GestureDetector(
                  onTap: () => _showSpeciesFilterSheet(context),
                  child: Container(
                    padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: Colors.blue[50],
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: Colors.blue.shade200),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.pets, size: 16, color: Colors.blue),
                        SizedBox(width: 4),
                        Text(
                          _filterSpecies,
                          style: TextStyle(color: Colors.blue, fontWeight: FontWeight.w600),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
          // Liste
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: _buildQuery().snapshots(),
              builder: (context, snap) {
                if (snap.connectionState == ConnectionState.waiting) {
                  return Center(child: CircularProgressIndicator(color: Colors.pink));
                }
                final docs = snap.data?.docs ?? [];
                if (docs.isEmpty) {
                  return Center(child: Text("${widget.type} ilanı bulunamadı 🐾"));
                }
                return ListView.builder(
                  padding: const EdgeInsets.all(15),
                  itemCount: docs.length,
                  itemBuilder: (context, index) {
                    final adDoc = docs[index];
                    final adData = adDoc.data()! as Map<String, dynamic>;
                    final adId = adDoc.id;
                    final userId = user?.uid;
                    return _buildAdItem(context, adData, adId, userId);
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  /// Filtre ve sıralamayı tek sorguda belirler
  Query _buildQuery() {
    Query q = FirebaseFirestore.instance.collection(widget.type);
    if (_filterSpecies != 'Hepsi') {
      q = q.where('species', isEqualTo: _filterSpecies);
    }
    q = q.orderBy('createdAt', descending: _descending);
    return q;
  }

  void _showSpeciesFilterSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) {
        String temp = _filterSpecies;
        return Padding(
          padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
          child: SingleChildScrollView(
            child: StatefulBuilder(
              builder: (context, setModalState) {
                return Padding(
                  padding: EdgeInsets.all(16),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text('Tür Seçimi', style: TextStyle(fontWeight: FontWeight.bold)),
                      SizedBox(height: 8),
                      ..._speciesOptions.map((s) => RadioListTile<String>(
                        title: Text(s),
                        value: s,
                        groupValue: temp,
                        onChanged: (v) => setModalState(() => temp = v!),
                      )),
                      SizedBox(height: 8),
                      ElevatedButton(
                        onPressed: () {
                          setState(() => _filterSpecies = temp);
                          Navigator.of(context).pop();
                        },
                        child: Text('Uygula'),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
        );
      },
    );
  }

  Widget _buildAdItem(
      BuildContext context,
      Map<String, dynamic> adData,
      String adId,
      String? currentUserId,
      ) {
    final ownerId = adData['userId'] as String?;  // Burada userId alanını kullanıyoruz

    return GestureDetector(
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => PetDetailPage(adData: adData)),
      ),
      child: Container(
        padding: EdgeInsets.all(10),
        margin: EdgeInsets.symmetric(vertical: 8),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(15),
          boxShadow: [
            BoxShadow(color: Colors.black12, blurRadius: 6, spreadRadius: 2)
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [

            // Başlık
            Text(
              adData['title'] ?? 'İlansız Hayvan',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: Colors.black,
              ),
            ),
            const SizedBox(height: 8),

            // Görsel
            ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: Image.network(
                adData['imageUrl'] ??
                    'https://cdn.pixabay.com/photo/2017/09/25/13/12/dog-2785074_1280.jpg',
                height: 150,
                width: double.infinity,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => Container(
                  height: 150,
                  color: Colors.grey[200],
                  child: Icon(Icons.pets, size: 50, color: Colors.grey),
                ),
              ),
            ),

            const SizedBox(height: 6),

            // İlan sahibinin şehri
            if (ownerId != null)
              FutureBuilder<DocumentSnapshot>(
                future: FirebaseFirestore.instance
                    .collection('users')
                    .doc(ownerId)
                    .get(),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return Row(
                      children: [
                        Icon(Icons.location_on, size: 14, color: Colors.grey[600]),
                        SizedBox(width: 4),
                        Text('Yükleniyor...', style: TextStyle(fontSize: 12, color: Colors.grey[600])),
                      ],
                    );
                  }
                  if (!snapshot.hasData || !snapshot.data!.exists) {
                    return SizedBox.shrink();
                  }
                  final userData = snapshot.data!.data() as Map<String, dynamic>?;
                  final city = userData?['city'] ?? 'Bilinmeyen Şehir';
                  return Row(
                    children: [
                      Icon(Icons.location_on, size: 14, color: Colors.grey[600]),
                      SizedBox(width: 4),
                      Text(city, style: TextStyle(fontSize: 12, color: Colors.grey[600])),
                    ],
                  );
                },
              ),

            // Favori butonu
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                if (currentUserId != null)
                  StreamBuilder<DocumentSnapshot>(
                    stream: FirebaseFirestore.instance
                        .collection('Favorites')
                        .doc(currentUserId)
                        .collection('UserFavorites')
                        .doc(adId)
                        .snapshots(),
                    builder: (context, favSnap) {
                      final isFav = favSnap.hasData && favSnap.data!.exists;
                      return IconButton(
                        icon: Icon(
                          isFav ? Icons.favorite : Icons.favorite_border,
                          color: isFav ? Colors.red : Colors.grey,
                        ),
                        onPressed: () => _toggleFavorite(adId, currentUserId),
                      );
                    },
                  )
                else
                  IconButton(
                    icon: Icon(Icons.favorite_border, color: Colors.grey),
                    onPressed: () => ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(
                          'Favorilere eklemek için giriş yapmalısınız!',
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }


  Future<void> _toggleFavorite(String adId, String userId) async {
    final favRef = FirebaseFirestore.instance
        .collection('Favorites')
        .doc(userId)
        .collection('UserFavorites')
        .doc(adId);

    final snap = await favRef.get();
    if (snap.exists) {
      await favRef.delete();
    } else {
      await favRef.set({
        'timestamp': FieldValue.serverTimestamp(),
        'collection': widget.type, // Örneğin: "Bakim" veya "Sahiplenme"
      });
    }
  }
}
