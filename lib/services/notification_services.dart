import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

class NotificationService {
  static final FirebaseMessaging _messaging = FirebaseMessaging.instance;

  // 1. Arka plan handler'ı @pragma ile işaretle
  @pragma('vm:entry-point')
  static Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
    // 2. Firebase'i mutlaka başlat
    await Firebase.initializeApp();
    await _processNotification(message.data);
  }

  static Future<void> _processNotification(Map<String, dynamic> data) async {
    debugPrint('📬 Bildirim Verisi: $data');

    // 3. Eksik veri kontrolü
    final toUserId = data['toUserId'];
    if (toUserId == null || toUserId.isEmpty) {
      debugPrint('❌ Hata: toUserId eksik!');
      return;
    }

    try {
      // 4. Firestore kaydı için doküman referansı oluştur
      final notificationRef = FirebaseFirestore.instance
          .collection('notifications')
          .doc();

      // 5. Firestore'a kaydet
      await notificationRef.set({
        'id': notificationRef.id,
        'toUserId': toUserId,
        'senderName': data['senderName'] ?? 'Bilinmiyor',
        'content': data['content'] ?? data['body'] ?? '',
        'relatedId': data['chatId'] ?? data['postId'] ?? data['relatedId'] ?? '',
        'type': data['type'] ?? 'genel',
        'isRead': false,
        'timestamp': FieldValue.serverTimestamp(),
      });

      debugPrint('✅ Firestore kaydı başarılı! ID: ${notificationRef.id}');
    } catch (e) {
      debugPrint('🔥 Firestore kayıt hatası: $e');
    }
  }

  static Future<void> initialize() async {
    try {
      // 6. FCM Token'ını güncelle
      final token = await _messaging.getToken();
      debugPrint('🆕 FCM Token: $token');

      final user = FirebaseAuth.instance.currentUser;
      if (user != null && token != null) {
        await FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .set({'fcmToken': token}, SetOptions(merge: true));
      }

      // 7. İzin iste
      final settings = await _messaging.requestPermission(
        alert: true,
        badge: true,
        sound: true,
        provisional: true,
      );

      debugPrint('🔔 Bildirim izni durumu: ${settings.authorizationStatus}');

      // 8. Arka plan handler'ını ayarla
      FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);

      // 9. Ön plan dinleyicisi
      FirebaseMessaging.onMessage.listen((RemoteMessage message) async {
        debugPrint('📥 Ön Planda Bildirim: ${message.data}');
        await _processNotification(message.data);
      });

      // 10. Uygulama kapalıyken açılan bildirimler
      FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
        debugPrint('🚀 Kapalıyken açılan bildirim: ${message.data}');
        _processNotification(message.data);
      });

      // 11. İlk açılışta gelen bildirimi yakala
      final initialMessage = await _messaging.getInitialMessage();
      if (initialMessage != null) {
        debugPrint('🚀 İlk açılış bildirimi: ${initialMessage.data}');
        _processNotification(initialMessage.data);
      }

    } catch (e) {
      debugPrint('🔥 Bildirim servisi başlatma hatası: $e');
    }
  }

  static Future<void> _sendToServer(Map<String, dynamic> data) async {
    const url = 'https://fcm-notification-server-sku2.onrender.com/sendNotification';
    try {
      final response = await http.post(
        Uri.parse(url),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(data),
      );

      if (response.statusCode == 200) {
        debugPrint('✅ Bildirim sunucuya gönderildi');
      } else {
        debugPrint('❌ Sunucu hatası: ${response.statusCode} - ${response.body}');
      }
    } catch (e) {
      debugPrint('🌐 Ağ hatası: $e');
    }
  }

  static Future<void> _sendToServerWithTokenLookup({
    required String toUserId,
    required String title,
    required String body,
    required String type,
    required Map<String, dynamic> data,
  }) async {
    try {
      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(toUserId)
          .get();

      final token = userDoc.data()?['fcmToken'] as String?;

      if (token == null || token.isEmpty) {
        debugPrint('📭 Kullanıcının FCM token\'ı bulunamadı: $toUserId');
        return;
      }

      final payload = {
        'token': token,
        'data': {
          ...data,
          'title': title,
          'body': body,
          'toUserId': toUserId,
          'type': type,
        }
      };

      debugPrint('📤 Gönderilen payload: ${jsonEncode(payload)}');
      await _sendToServer(payload);
    } catch (e) {
      debugPrint('🔑 Token alma hatası: $e');
    }
  }

// Mesaj bildirimi gönder
  static Future<void> sendMessageNotification({
    required String toUserId,
    required String chatId,
    required String senderName,
    required String messageContent,
  }) async {
    await _sendToServerWithTokenLookup(
      toUserId: toUserId,
      title: senderName,
      body: messageContent,
      type: 'chat',
      data: {
        'senderName': senderName,
        'content': messageContent,
        'chatId': chatId,
        // Ek bilgiler
        'notificationType': 'message',
      },
    );
  }

// Forum yorumu bildirimi gönder
  static Future<void> sendForumReplyNotification({
    required String toUserId,
    required String postId,
    required String replierName,
    required String commentText,
  }) async {
    await _sendToServerWithTokenLookup(
      toUserId: toUserId,
      title: '$replierName gönderine yorum yaptı',
      body: commentText,
      type: 'forum_comment',
      data: {
        'senderName': replierName,
        'content': commentText,
        'postId': postId,
        // Ek bilgiler
        'notificationType': 'forum_reply',
      },
    );
  }

// Genel yorum bildirimi gönder
  static Future<void> sendCommentNotification({
    required String toUserId,
    required String relatedId,
    required String commenterName,
    required String commentText,
  }) async {
    await _sendToServerWithTokenLookup(
      toUserId: toUserId,
      title: '$commenterName yorum yaptı',
      body: commentText,
      type: 'comment',
      data: {
        'senderName': commenterName,
        'content': commentText,
        'relatedId': relatedId,
        // Ek bilgiler
        'notificationType': 'comment',
      },
    );
  }
}