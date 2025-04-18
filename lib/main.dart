import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'screens/root_app.dart';
import 'screens/login.dart'; // LoginScreen'i import ettik
import 'theme/colors.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart'; // Riverpod importu

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();
  runApp(ProviderScope(  // ProviderScope ekledik
    child: MyApp(),
  ));
}

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Patico', // Uygulamanın başlığı
      theme: ThemeData(
        primaryColor: AppColor.primary, // Tema rengini ayarlayın
      ),
      home: const LoginScreen(), // İlk ekran olarak LoginScreen belirlenir
    );
  }
}
