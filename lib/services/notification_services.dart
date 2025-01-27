import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';

class NotificationService {
  List<String> notifications = [];
  final FirebaseMessaging _firebaseMessaging = FirebaseMessaging.instance;
  int notifiedCount = 0;  // Bildirim sayısı

  // Bildirim servisini başlatma
  Future<void> initialize(BuildContext context, Function(int) onNotificationUpdate) async {
    await _firebaseMessaging.requestPermission();

    // Foreground'da gelen bildirimleri dinle
    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      if (message.notification != null) {
        // Bildirimi listeye ekle
        notifications.add(message.notification!.title ?? 'Yeni Bildirim');

        // Bildirim sayısını güncelle
        notifiedCount++;
        onNotificationUpdate(notifiedCount);  // Bildirim sayısını güncellemek için callback çağır

        print("Foreground Bildirim: ${message.notification!.title}");
      }
    });

    // Arka planda gelen bildirimler için handler
    FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);
  }

  // Arka planda bildirim geldiğinde yapılacak işlem
  static Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
    print("Arka planda bildirim alındı: ${message.notification?.title}");
  }

  // Bildirimleri almak için getter
  List<String> getNotificationList() {
    return notifications;
  }

  int getNotifiedCount() {
    return notifiedCount;
  }
}
