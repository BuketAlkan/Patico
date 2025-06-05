import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'screens/root_app.dart';
import 'screens/login.dart';
import 'theme/colors.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_app_check/firebase_app_check.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'services/notification_services.dart'; // Tek servis dosyasını kullanıyoruz
import 'package:intl/date_symbol_data_local.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:timezone/data/latest.dart' as tz;
/// 🔄 Arka planda/uygulama kapalıyken gelen bildirim handler'ı
@pragma('vm:entry-point') // Bu satır önemli!
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp();
  print('🔔 [Background] Bildirim başlığı: ${message.notification?.title}');
  // Firestore'a bildirim ekleme vs. yapılabilir

}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  tz.initializeTimeZones();
  await Firebase.initializeApp();

  await initializeDateFormatting('tr_TR', null);
  await FirebaseAppCheck.instance.activate(
    // androidProvider: AndroidProvider.debug, // test için açılabilir
    // iosProvider: IOSProvider.debug,
  );

  await FirebaseMessaging.instance.requestPermission(); // iOS izin

  // Arka plan bildirimleri için
  FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);

  runApp(const ProviderScope(child: MyApp()));
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  @override
  void initState() {
    super.initState();

    // Bildirim servisini başlat, context'i parametre olarak veriyoruz
   // NotificationService.initialize(context);

    // FCM token'ı al ve Firestore'a kaydet (giriş yapan kullanıcıyla bağla)
    FirebaseMessaging.instance.getToken().then((token) {
      print("📱 FCM Token: $token");
      final currentUser = FirebaseAuth.instance.currentUser;
      if (currentUser != null && token != null) {

      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Patico',
      theme: ThemeData(
        primaryColor: AppColor.primary,
      ),
      home: const LoginScreen(),
    );
  }
}
