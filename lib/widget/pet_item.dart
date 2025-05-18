import 'package:flutter/material.dart';

class PetItem extends StatelessWidget {
  final Map<String, dynamic> data;
  final double width;
  final VoidCallback? onTap;
  final VoidCallback? onFavoriteTap;
  final bool isFavorite;  // Favori durumu için ekledik

  const PetItem({
    super.key,
    required this.data,
    required this.width,
    this.onTap,
    this.onFavoriteTap,
    this.isFavorite = false,   // default false
  });

  @override
  Widget build(BuildContext context) {
    final imageUrl = data['imageUrl'] ?? '';
    final title = data['title'] ?? 'İsimsiz İlan';

    // Burada kullanıcı adını 'username' veya 'name' alanlarından alıyoruz.
    // Senin veritabanında username olarak geçiyorsa onu tercih edebilirsin.
    final username = data['username'] ?? data['name'] ?? 'Kullanıcı';

    final description = data['description'] ?? 'Açıklama yok';
    final petId = data['petId'];

    return GestureDetector(
      onTap: onTap,
      child: Card(
        margin: const EdgeInsets.symmetric(horizontal: 8),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        elevation: 4,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ClipRRect(
              borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
              child: imageUrl.isNotEmpty
                  ? Image.network(imageUrl, width: width, height: 200, fit: BoxFit.cover)
                  : Container(
                width: width,
                height: 200,
                color: Colors.grey[300],
                child: const Icon(Icons.image_not_supported, size: 60, color: Colors.grey),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title,
                      style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 4),
                  Text(description, maxLines: 2, overflow: TextOverflow.ellipsis),
                  const SizedBox(height: 8),
                  //Text("İlan sahibi: $username",
                    //  style: const TextStyle(fontSize: 12, color: Colors.grey)),
                  Align(
                    alignment: Alignment.bottomRight,
                    child: IconButton(
                      icon: Icon(
                        isFavorite ? Icons.favorite : Icons.favorite_border,
                        color: Colors.red,
                      ),
                      onPressed: () {
                        onFavoriteTap?.call();
                      },
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
