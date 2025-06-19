import 'dart:convert';
import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:http/http.dart' as http;

import 'my_forum_posts.dart';

class ForumPage extends StatefulWidget {
  const ForumPage({Key? key}) : super(key: key);

  @override
  State<ForumPage> createState() => _ForumPageState();
}

class _ForumPageState extends State<ForumPage> {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final TextEditingController _questionController = TextEditingController();
  File? _selectedImage;
  final ImagePicker _picker = ImagePicker();

  final String _imgbbApiKey = '984d720ca4875a9e9aede1fbb12b0ccb';

  Future<void> _pickImage() async {
    final XFile? pickedFile = await _picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 75,
    );
    if (pickedFile != null) {
      setState(() {
        _selectedImage = File(pickedFile.path);
      });
    }
  }

  Future<String?> _uploadImageToImgbb(File imageFile) async {
    try {
      final bytes = await imageFile.readAsBytes();
      final base64Image = base64Encode(bytes);

      final response = await http.post(
        Uri.parse('https://api.imgbb.com/1/upload?key=$_imgbbApiKey'),
        body: {'image': base64Image},
      );

      final data = jsonDecode(response.body);
      if (data['success'] == true) {
        return data['data']['url'] as String?;
      }
    } catch (e) {
      debugPrint('Fotoğraf yükleme hatası: $e');
    }
    return null;
  }

  Future<void> _sendQuestion() async {
    final user = _auth.currentUser;
    if (user == null) return;

    final questionText = _questionController.text.trim();
    if (questionText.isEmpty) return;

    String? uploadedImageUrl;
    if (_selectedImage != null) {
      uploadedImageUrl = await _uploadImageToImgbb(_selectedImage!);
    }

    final newPostRef = await _firestore.collection('forumPosts').add({
      'question': questionText,
      'userId': user.uid,
      'imageUrl': uploadedImageUrl ?? '',
      'timestamp': FieldValue.serverTimestamp(),
    });

    await newPostRef.update({'postId': newPostRef.id});

    _questionController.clear();
    setState(() => _selectedImage = null);
  }

  String _formatTimestamp(Timestamp? timestamp) {
    if (timestamp == null) return '';
    final dt = timestamp.toDate();
    return '${dt.day.toString().padLeft(2, '0')}.${dt.month.toString().padLeft(2, '0')}.${dt.year} ${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFFF0F5),
      appBar: AppBar(
        backgroundColor: const Color(0xFFFFC0CB),
        title: const Text(
          '🐾 Patili Forum',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
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
            ),
            ),
            IconButton(

              icon: const Icon(Icons.photo, color: Color(0xFFFF69B4)),
              // Pembe ikon
              onPressed: _pickImage,
            ),
            ElevatedButton.icon(
              onPressed: _sendQuestion,
              icon: const Icon(Icons.pets),
              label: const Text('Paylaş'),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFFFB6C1),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                ),
              ),
            ),
            ],
          ),
          if (_selectedImage != null)
            Padding(
              padding: const EdgeInsets.only(top: 8.0),
              child: Image.file(_selectedImage!, height: 100),
            ),
        ],
      ),
    ),
    const Divider(),
    Padding(
    padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 4),
    child: Align(
    alignment: Alignment.centerLeft,
    child: ElevatedButton.icon(
    style: ElevatedButton.styleFrom(
    backgroundColor: const Color(0xFFFFC0CB),
    foregroundColor: Colors.white,
    shape: RoundedRectangleBorder(
    borderRadius: BorderRadius.circular(20),
    ),
    ),
    icon: const Icon(Icons.person),
    label: const Text("Gönderilerim"),
    onPressed: () => Navigator.push(
    context,
    MaterialPageRoute(builder: (context) => const MyForumPostsPage()),
    ),
    ),
    ),
    ),
    Expanded(
    child: StreamBuilder<QuerySnapshot>(
    stream: _firestore
        .collection('forumPosts')
        .orderBy('timestamp', descending: true)
        .snapshots(),
    builder: (context, snapshot) {
    if (snapshot.hasError) {
    return Center(child: Text('Hata: ${snapshot.error}'));
    }

    if (snapshot.connectionState == ConnectionState.waiting) {
    return const Center(child: CircularProgressIndicator());
    }

    final posts = snapshot.data!.docs;
    if (posts.isEmpty) {
    return const Center(
    child: Text(
    'Henüz soru yok.',
    style: TextStyle(color: Colors.grey)),
    );
    }

    return ListView.builder(
    itemCount: posts.length,
    itemBuilder: (context, index) {
    final postDoc = posts[index];
    final postData = postDoc.data() as Map<String, dynamic>;
    final String userId = postData['userId'] ?? '';
    final String question = postData['question'] ?? '';
    final String imageUrl = postData['imageUrl'] ?? '';
    final Timestamp? timestamp = postData['timestamp'];

    return FutureBuilder<DocumentSnapshot>(
    future: _firestore.collection('users').doc(userId).get(),
    builder: (context, userSnapshot) {
    if (userSnapshot.connectionState == ConnectionState.waiting) {
    return const ListTile(
    leading: CircleAvatar(child: CircularProgressIndicator()),
    title: Text('Yükleniyor...'),
    );
    }

    if (userSnapshot.hasError) {
    return ListTile(
    leading: const CircleAvatar(child: Icon(Icons.error)),
    title: Text('Hata: ${userSnapshot.error}'),
    );
    }

    if (!userSnapshot.hasData || !userSnapshot.data!.exists) {
    return ListTile(
    leading: const CircleAvatar(child: Icon(Icons.person)),
    title: const Text('Kullanıcı bilgisi bulunamadı'),
    subtitle: Text(question),
    );
    }

    final userData = userSnapshot.data!.data() as Map<String, dynamic>;
    final String username = userData['name'] ?? 'Kullanıcı';
    final String photoUrl = userData['photoURL'] ?? '';

    return Card(
    color: Colors.white,
    elevation: 2,
    margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
    shape: RoundedRectangleBorder(
    borderRadius: BorderRadius.circular(16),
    side: const BorderSide(color: Color(0xFFFFC0CB), width: 1),
    ),
    child: Padding(
    padding: const EdgeInsets.all(12),
    child: Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
    Row(
    children: [
    CircleAvatar(
    backgroundImage: photoUrl.isNotEmpty ? NetworkImage(photoUrl) : null,
    child: photoUrl.isEmpty ? const Icon(Icons.person) : null,
    ),
    const SizedBox(width: 8),
    Text( username,
      style: const TextStyle(
        fontWeight: FontWeight.w600,
        color: Colors.black87,
        fontSize: 16,
      ),),
    const Spacer(),
    Text(
    _formatTimestamp(timestamp),
    style: const TextStyle(fontSize: 12, color: Colors.grey),
    ),
    ],
    ),
    const SizedBox(height: 8),
    Text(question, style: const TextStyle(fontSize: 15)),
    if (imageUrl.isNotEmpty)
    Padding(
    padding: const EdgeInsets.only(top: 8.0),
    child: ClipRRect(
    borderRadius: BorderRadius.circular(10),
    child: Image.network(imageUrl),
    ),
    ),
    const SizedBox(height: 8),
    CommentSection(postId: postDoc.id),
    ],
    ),
    ),
    );
    },
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
}

class CommentSection extends StatefulWidget {
  final String postId;

  const CommentSection({Key? key, required this.postId}) : super(key: key);

  @override
  State<CommentSection> createState() => _CommentSectionState();
}

class _CommentSectionState extends State<CommentSection> {
  final TextEditingController _commentController = TextEditingController();
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  String? _replyingToCommentId;

  Future<void> _sendComment() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    final commentText = _commentController.text.trim();
    if (commentText.isEmpty) return;

    try {
      await _firestore
          .collection('forumPosts')
          .doc(widget.postId)
          .collection('comments')
          .add({
        'userId': user.uid,
        'comment': commentText,
        'timestamp': Timestamp.now(),
        'parentId': _replyingToCommentId,
      });

      _commentController.clear();
      setState(() => _replyingToCommentId = null);
    } catch (e) {
      debugPrint('Yorum gönderme hatası: $e');
    }
  }

  Stream<QuerySnapshot> getTopLevelComments() {
    return _firestore
        .collection('forumPosts')
        .doc(widget.postId)
        .collection('comments')
        .where('parentId', isNull: true)
        .orderBy('timestamp', descending: true)
        .snapshots();
  }

  Stream<QuerySnapshot> getReplies(String commentId) {
    return _firestore
        .collection('forumPosts')
        .doc(widget.postId)
        .collection('comments')
        .where('parentId', isEqualTo: commentId)
        .orderBy('timestamp')
        .snapshots();
  }

  String _formatTimestamp(Timestamp? timestamp) {
    if (timestamp == null) return '';
    final dt = timestamp.toDate();
    return '${dt.day.toString().padLeft(2, '0')}.${dt.month.toString().padLeft(2, '0')}.${dt.year} ${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
  }

  Widget _buildCommentTile(Map<String, dynamic> commentData, String commentId, {int depth = 0}) {
    final userId = commentData['userId'] ?? '';
    final comment = commentData['comment'] ?? '';
    final Timestamp? timestamp = commentData['timestamp'];

    return FutureBuilder<DocumentSnapshot>(
      future: _firestore.collection('users').doc(userId).get(),
      builder: (context, userSnapshot) {
        if (userSnapshot.connectionState == ConnectionState.waiting) {
          return Padding(
            padding: EdgeInsets.only(left: 16.0 * depth),
            child: const ListTile(
              leading: CircleAvatar(child: CircularProgressIndicator()),
              title: Text('Yükleniyor...'),
            ),
          );
        }

        if (userSnapshot.hasError) {
          return Padding(
            padding: EdgeInsets.only(left: 16.0 * depth),
            child: ListTile(
              leading: const CircleAvatar(child: Icon(Icons.error)),
              title: Text('Hata: ${userSnapshot.error}'),
            ),
          );
        }

        if (!userSnapshot.hasData || !userSnapshot.data!.exists) {
          return Padding(
            padding: EdgeInsets.only(left: 16.0 * depth),
            child: ListTile(
              leading: const CircleAvatar(child: Icon(Icons.person)),
              title: Text(comment),
              subtitle: timestamp != null ? Text(_formatTimestamp(timestamp)) : null,
            ),
          );
        }

        final userData = userSnapshot.data!.data() as Map<String, dynamic>;
        final String username = userData['name'] ?? 'Kullanıcı';
        final String photoUrl = userData['photoURL'] ?? '';

        return Padding(
          padding: EdgeInsets.only(left: 16.0 * depth),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ListTile(
                leading: CircleAvatar(
                  backgroundImage: photoUrl.isNotEmpty ? NetworkImage(photoUrl) : null,
                  child: photoUrl.isEmpty ? const Icon(Icons.person) : null,
                ),
                title: Text(username,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Colors.black87,
                  ),),
                subtitle: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(comment),
                    if (timestamp != null)
                      Text(
                        _formatTimestamp(timestamp),
                        style: const TextStyle(fontSize: 10, color: Colors.grey),
                      ),
                    TextButton(
                      onPressed: () => setState(() {
                        _replyingToCommentId = _replyingToCommentId == commentId ? null : commentId;
                      }),
                      child: const Text('Yanıtla', style: TextStyle(color: Color(0xFFFF69B4))),
                    ),
                  ],
                ),
              ),
              if (_replyingToCommentId == commentId)
                Padding(
                  padding: const EdgeInsets.only(left: 40, right: 16),
                  child: Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _commentController,
                          decoration: const InputDecoration(
                            hintText: 'Yanıt yaz...',
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.all(Radius.circular(20)),
                            ),
                            filled: true,
                            fillColor: Colors.white,
                          ),
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.send, color: Color(0xFFFF69B4)),
                        onPressed: _sendComment,
                      ),
                    ],
                  ),
                ),
              StreamBuilder<QuerySnapshot>(
                stream: getReplies(commentId),
                builder: (context, replySnapshot) {
                  if (replySnapshot.hasError) {
                    return Padding(
                      padding: EdgeInsets.only(left: 16.0 * (depth + 1)),
                      child: Text('Hata: ${replySnapshot.error}'),
                    );
                  }

                  if (replySnapshot.connectionState == ConnectionState.waiting) {
                    return const Padding(
                      padding: EdgeInsets.only(left: 40),
                      child: CircularProgressIndicator(),
                    );
                  }

                  final replies = replySnapshot.data!.docs;
                  return Column(
                    children: replies.map((replyDoc) {
                      final replyData = replyDoc.data() as Map<String, dynamic>;
                      return _buildCommentTile(replyData, replyDoc.id, depth: depth + 1);
                    }).toList(),
                  );
                },
              ),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        StreamBuilder<QuerySnapshot>(
          stream: getTopLevelComments(),
          builder: (context, snapshot) {
            if (snapshot.hasError) {
              return Padding(
                padding: const EdgeInsets.all(8.0),
                child: Text('Hata: ${snapshot.error}'),
              );
            }

            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }

            final comments = snapshot.data!.docs;
            if (comments.isEmpty) {
              return const Padding(
                padding: EdgeInsets.all(8.0),
                child: Text('Henüz yorum yok.', style: TextStyle(color: Colors.grey)),
              );
            }

            return ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: comments.length,
              itemBuilder: (context, index) {
                final commentDoc = comments[index];
                final commentData = commentDoc.data() as Map<String, dynamic>;
                return _buildCommentTile(commentData, commentDoc.id);
              },
            );
          },
        ),
        const SizedBox(height: 8),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8.0),
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _commentController,
                  decoration: const InputDecoration(
                    hintText: 'Yorum yaz...',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.all(Radius.circular(20)),
                    ),
                    filled: true,
                    fillColor: Colors.white,
                  ),
                ),
              ),
              IconButton(
                icon: const Icon(Icons.send, color: Color(0xFFFF69B4)),
                onPressed: () {
                  setState(() => _replyingToCommentId = null);
                  _sendComment();
                },
              ),
            ],
          ),
        ),
      ],
    );
  }
}