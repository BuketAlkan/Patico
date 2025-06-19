import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:patico/screens/login.dart';

import '../services/forum_service.dart';

class SettingsPage extends StatefulWidget {
  const SettingsPage({Key? key}) : super(key: key);

  @override
  _SettingsPageState createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  bool _notificationsEnabled = true;

  String _username = "";
  String _email = "";

  @override
  void initState() {
    super.initState();
    _loadUserData();
  }

  Future<void> _loadUserData() async {
    final user = _auth.currentUser;
    if (user != null) {
      final doc = await _firestore.collection('users').doc(user.uid).get();
      setState(() {
        _username = doc.data()?['name'] ?? '';
        _email = user.email ?? '';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Hesap Ayarları')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          ListTile(
            leading: const Icon(Icons.person),
            title: Text('Kullanıcı Adı: $_username'),
          ),
          ListTile(
            leading: const Icon(Icons.email),
            title: Text('E-posta: $_email'),
          ),
          const Divider(),
          _buildSettingItem(
            icon: Icons.lock,
            title: 'Şifre Değiştir',
            onTap: _changePassword,
          ),
          _buildSettingItem(
            icon: Icons.email,
            title: 'E-posta Değiştir',
            onTap: _changeEmail,
          ),
          _buildSettingItem(
            icon: Icons.person,
            title: 'Kullanıcı Adı Değiştir',
            onTap: _changeUsername,
          ),


          _buildSettingItem(
            icon: Icons.delete,
            title: 'Hesabı Sil',
            color: Colors.red,
            onTap: _deleteAccount,
          ),
        ],
      ),
    );
  }

  ListTile _buildSettingItem({
    required IconData icon,
    required String title,
    Color color = Colors.black,
    required VoidCallback onTap,
  }) {
    return ListTile(
      leading: Icon(icon, color: color),
      title: Text(title, style: TextStyle(color: color)),
      onTap: onTap,
    );
  }

  Future<void> _changePassword() async {
    final user = _auth.currentUser;
    if (user == null) return;

    final passwordController = TextEditingController();
    final newPasswordController = TextEditingController();

    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Şifre Değiştir'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: passwordController,
              obscureText: true,
              decoration: const InputDecoration(labelText: 'Mevcut Şifre'),
            ),
            TextField(
              controller: newPasswordController,
              obscureText: true,
              decoration: const InputDecoration(labelText: 'Yeni Şifre'),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('İptal'),
          ),
          ElevatedButton(
            onPressed: () async {
              final oldPass = passwordController.text.trim();
              final newPass = newPasswordController.text.trim();

              if (oldPass.isEmpty || newPass.isEmpty) {
                _showError('Lütfen tüm alanları doldurun');
                return;
              }

              try {
                await _reauthenticate(user, oldPass);
                await user.updatePassword(newPass);

                // NOT: Şifre Firestore'da saklanmamalı! Sadece test amaçlı ise izin ver.
                // await _firestore.collection('users').doc(user.uid).update({'password': newPass});

                Navigator.pop(context);
                _showSuccess('Şifre başarıyla değiştirildi');
              } catch (e) {
                _showError('Hata: ${e.toString()}');
              }
            },
            child: const Text('Kaydet'),
          ),
        ],
      ),
    );
  }

  Future<void> _changeEmail() async {
    final user = _auth.currentUser;
    if (user == null) return;

    final emailController = TextEditingController();
    final passwordController = TextEditingController();

    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('E-posta Değiştir'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: passwordController,
              obscureText: true,
              decoration: const InputDecoration(labelText: 'Mevcut Şifre'),
            ),
            TextField(
              controller: emailController,
              keyboardType: TextInputType.emailAddress,
              decoration: const InputDecoration(labelText: 'Yeni E-posta'),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('İptal'),
          ),
          ElevatedButton(
            onPressed: () async {
              final newEmail = emailController.text.trim();
              final password = passwordController.text.trim();

              if (newEmail.isEmpty || password.isEmpty) {
                _showError('Lütfen tüm alanları doldurun');
                return;
              }

              try {
                await _reauthenticate(user, password);

                await user.updateEmail(newEmail);
                await _firestore.collection('users').doc(user.uid).update({
                  'email': newEmail,
                });

                setState(() {
                  _email = newEmail;
                });

                Navigator.pop(context);
                _showSuccess('E-posta başarıyla güncellendi');
              } catch (e) {
                _showError('Hata: ${e.toString()}');
              }
            },
            child: const Text('Güncelle'),
          ),
        ],
      ),
    );
  }

  Future<void> _changeUsername() async {
    final user = _auth.currentUser;
    if (user == null) return;

    final usernameController = TextEditingController(text: _username);

    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Kullanıcı Adı Değiştir'),
        content: TextField(
          controller: usernameController,
          decoration: const InputDecoration(labelText: 'Yeni Kullanıcı Adı'),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('İptal')),
          ElevatedButton(
            onPressed: () async {
              final newUsername = usernameController.text.trim();
              if (newUsername.isEmpty) {
                _showError('Kullanıcı adı boş olamaz');
                return;
              }

              try {
                await _firestore.collection('users').doc(user.uid).update({
                  'name': newUsername,
                });

                setState(() {
                  _username = newUsername;
                });

                // Forum ve yorumlarda kullanıcı adını da güncelle
                await ForumService.updateUsernameEverywhere(newUsername);

                Navigator.pop(context);
                _showSuccess('Kullanıcı adı başarıyla güncellendi');
              } catch (e) {
                _showError('Hata: ${e.toString()}');
              }
            },
            child: const Text('Kaydet'),
          ),
        ],
      ),
    );
  }

  Future<void> _deleteAccount() async {
    final user = _auth.currentUser;
    if (user == null) return;

    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Hesabı Sil'),
        content: const Text('Bu işlem geri alınamaz! Emin misiniz?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('İptal')),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Sil', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirm == true) {
      try {
        await _firestore.collection('users').doc(user.uid).delete();
        await user.delete();

        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => const LoginScreen()),
        );
      } catch (e) {
        _showError('Hata: ${e.toString()}');
      }
    }
  }

  Future<void> _reauthenticate(User user, String password) async {
    final cred = EmailAuthProvider.credential(email: user.email!, password: password);
    await user.reauthenticateWithCredential(cred);
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: Colors.red),
    );
  }

  void _showSuccess(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: Colors.green),
    );
  }
}
