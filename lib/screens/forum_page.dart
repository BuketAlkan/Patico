import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

class ForumPage extends StatefulWidget {
  final String? postId;
  const ForumPage({super.key,this.postId});

  @override
  State<ForumPage> createState() => _ForumPageState();
}

class _ForumPageState extends State<ForumPage> {
  final TextEditingController _questionController = TextEditingController();
  File? _selectedImage;

  final _auth = FirebaseAuth.instance;
  final _firestore = FirebaseFirestore.instance;
  final picker = ImagePicker();

  Future<void> _pickImage() async {
    final picked = await picker.pickImage(source: ImageSource.gallery);
    if (picked != null) {
      setState(() => _selectedImage = File(picked.path));
    }
  }

  Future<String?> _uploadImage(File file) async {
    final fileName = '${DateTime.now().millisecondsSinceEpoch}.jpg';
    final ref = FirebaseStorage.instance.ref().child('forumImages').child(fileName);
    await ref.putFile(file);
    return await ref.getDownloadURL();
  }

  Future<void> _postQuestion() async {
    final user = _auth.currentUser;
    if (user == null || _questionController.text.trim().isEmpty) return;

    final userDoc = await _firestore.collection('users').doc(user.uid).get();
    final userData = userDoc.data();
    String? imageUrl;

    if (_selectedImage != null) {
      imageUrl = await _uploadImage(_selectedImage!);
    }

    await _firestore.collection('forumPosts').add({
      'question': _questionController.text.trim(),
      'userId': user.uid,
      'username': userData?['name'] ?? 'Bilinmeyen',
      'profilePicture': userData?['profilePicture'] ?? '',
      'imageUrl': imageUrl ?? '',
      'timestamp': FieldValue.serverTimestamp(),
    });

    _questionController.clear();
    setState(() => _selectedImage = null);
  }

  Future<void> _addComment(String postId, String postOwnerId, String commentText) async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null || commentText
          .trim()
          .isEmpty) return;

      final userDoc = await FirebaseFirestore.instance.collection('users').doc(
          user.uid).get();
      final username = userDoc.data()?['name'] ?? 'Kullanıcı';
      final profilePicture = userDoc.data()?['profilePicture'] ?? '';

      await FirebaseFirestore.instance
          .collection('forumPosts')
          .doc(postId)
          .collection('comments')
          .add({
        'userId': user.uid,
        'username': username,
        'profilePicture': profilePicture,
        'comment': commentText,
        'timestamp': Timestamp.now(),
      });

      if (postOwnerId != user.uid) {
        await _sendNotification(postOwnerId, user.uid, commentText,postId);
      }

    } catch (e) {
      print("Yorum eklenirken hata oluştu: $e");
    }
  }

  Future<void> _sendNotification(String postOwnerId, String senderId, String commentText, String postId) async {
    if (postOwnerId == senderId) return;

    final senderDoc = await FirebaseFirestore.instance.collection('users').doc(senderId).get();
    final senderName = senderDoc.data()?['name'] ?? 'Bilinmeyen';

    await FirebaseFirestore.instance.collection('notifications').add({
      'toUserId': postOwnerId,
      'senderId': senderId,
      'senderName': senderName,
      'type': 'comment',
      'content': commentText,
      'relatedId': postId,
      'timestamp': Timestamp.now(),
      'isRead': false,
    });
  }


  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFFF0F5),
      appBar: AppBar(
        backgroundColor: const Color(0xFFFFC0CB),
        title: const Text('🐾  Patili Forum', style: TextStyle(fontWeight: FontWeight.bold)),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              children: [
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _questionController,
                        decoration: const InputDecoration(
                          hintText: 'Bir soru sor...',
                          filled: true,
                          fillColor: Colors.white,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.all(Radius.circular(20)),
                          ),
                        ),
                      ), // TextField'ın kapanışı
                    ),
                    IconButton(
                      icon: const Icon(Icons.photo),
                      onPressed: _pickImage,
                    ),
                    ElevatedButton.icon(
                      onPressed: _postQuestion,
                      icon: const Icon(Icons.pets),
                      label: const Text('Paylaş'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFFFB6C1),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(20),
                        ),
                      ),
                    ), // ElevatedButton.icon kapanışı
                  ],
                ),

                if (_selectedImage != null)
                  Padding(
                    padding: const EdgeInsets.all(8.0),
                    child: Image.file(_selectedImage!, height: 100),
                  ),
              ],
            ),
          ),
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: _firestore.collection('forumPosts').orderBy('timestamp', descending: true).snapshots(),
              builder: (context, snapshot) {
                if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
                final posts = snapshot.data!.docs;

                return ListView.builder(
                  itemCount: posts.length,
                  itemBuilder: (context, index) {
                    final post = posts[index];
                    final data = post.data() as Map<String, dynamic>;

                    return Card(
                      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      child: Padding(
                        padding: const EdgeInsets.all(12),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                CircleAvatar(
                                  backgroundImage: data['profilePicture'] != ''
                                      ? NetworkImage(data['profilePicture'])
                                      : null,
                                  child: data['profilePicture'] == '' ? const Icon(Icons.person) : null,
                                ),
                                const SizedBox(width: 8),
                                Text(data['username'] ?? 'Kullanıcı', style: const TextStyle(fontWeight: FontWeight.bold)),
                                const Spacer(),
                                Text(
                                  (data['timestamp'] as Timestamp?)?.toDate().toLocal().toString().substring(0, 16) ?? '',
                                  style: const TextStyle(fontSize: 12, color: Colors.grey),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            Text(data['question'] ?? ''),
                            if (data['imageUrl'] != null && data['imageUrl'] != '')
                              Padding(
                                padding: const EdgeInsets.only(top: 8.0),
                                child: Image.network(data['imageUrl']),
                              ),
                            const SizedBox(height: 8),
                            _buildCommentSection(post.id, data['userId']),
                          ],
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCommentSection(String postId, String postOwnerId) {
    final commentController = TextEditingController();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        StreamBuilder<QuerySnapshot>(
          stream: FirebaseFirestore.instance
              .collection('forumPosts')
              .doc(postId)
              .collection('comments')
              .orderBy('timestamp', descending: true)
              .snapshots(),
          builder: (context, snapshot) {
            if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
            final comments = snapshot.data!.docs;

            return Column(
              children: comments.map((commentDoc) {
                final commentData = commentDoc.data() as Map<String, dynamic>;
                return ListTile(
                  leading: CircleAvatar(
                    backgroundImage: commentData['profilePicture'] != ''
                        ? NetworkImage(commentData['profilePicture'])
                        : null,
                    child: commentData['profilePicture'] == '' ? const Icon(Icons.person) : null,
                  ),
                  title: Text(commentData['username'] ?? 'Kullanıcı'),
                  subtitle: Text(commentData['comment'] ?? ''),
                  trailing: Text(
                    (commentData['timestamp'] as Timestamp?)?.toDate().toLocal().toString().substring(0, 16) ?? '',
                    style: const TextStyle(fontSize: 10, color: Colors.grey),
                  ),
                );
              }).toList(),
            );
          },
        ),
        const SizedBox(height: 6),
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: commentController,
                decoration: const InputDecoration(
                  hintText: 'Yorum yap...',
                  filled: true,
                  fillColor: Color(0xFFFFF5F5),
                  border: OutlineInputBorder(borderRadius: BorderRadius.all(Radius.circular(20))),
                ),
              ),
            ),
            IconButton(
              icon: const Icon(Icons.send, color: Color(0xFFFF69B4)),
              onPressed: () async {
                if (commentController.text.trim().isNotEmpty) {
                  await _addComment(
                    postId,
                    postOwnerId,
                    commentController.text.trim(),
                  );
                  commentController.clear();
                }
              },
            ),
          ],
        ),
      ],
    );
  }
}