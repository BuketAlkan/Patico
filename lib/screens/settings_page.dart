import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:patico/screens/login.dart';

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
        _username = doc['name'] ?? '';
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
          SwitchListTile(
            title: const Text('Bildirimlere İzin Ver'),
            value: _notificationsEnabled,
            onChanged: (value) => setState(() => _notificationsEnabled = value),
            secondary: const Icon(Icons.notifications),
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
              try {
                // Kimlik doğrulama
                await _reauthenticate(passwordController.text);

                // Firebase Authentication şifre güncelleme
                await user.updatePassword(newPasswordController.text);

                // Firestore'a düz metin şifreyi yazma (GÜVENLİ DEĞİL - sadece test için)
                await _firestore.collection('users').doc(user.uid).update({
                  'password': newPasswordController.text,
                });

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
              try {
                await _reauthenticate(passwordController.text);

                await user.verifyBeforeUpdateEmail(newEmail);

                // Firestore'u hemen güncellemiyoruz çünkü değişiklik henüz Auth'da onaylanmadı.
                // Eğer hemen değişmesini istiyorsan, kullanıcı doğruladıktan sonra uygulamayı yeniden başlatabiliriz.

                Navigator.pop(context);
                _showSuccess('Yeni e-posta için doğrulama gönderildi. Lütfen gelen kutunu kontrol et.');
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

    final usernameController = TextEditingController();

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
              try {
                await _firestore.collection('users').doc(user.uid).update({
                  'name': usernameController.text,
                });
                setState(() => _username = usernameController.text);
                Navigator.pop(context);
                _showSuccess('Kullanıcı adı güncellendi');
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
        content: const Text('Bu işlem geri alınamaz!'),
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

  Future<void> _reauthenticate(String password) async {
    final user = _auth.currentUser!;
    final cred = EmailAuthProvider.credential(
      email: user.email!,
      password: password,
    );
    await user.reauthenticateWithCredential(cred);
  }

  void _showSuccess(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: Colors.green),
    );
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: Colors.red),
    );
  }
}
