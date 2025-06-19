import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

class NotificationService {
  static final FirebaseMessaging _messaging = FirebaseMessaging.instance;

  // Arka plan handler'ı
  @pragma('vm:entry-point')
  static Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
    await Firebase.initializeApp();
    await _processNotification(message.data);
  }

  static Future<void> _processNotification(Map<String, dynamic> data) async {
    debugPrint('📬 Bildirim Verisi: $data');

    // Tüm bildirim türleri için ortak işleme
    final toUserId = data['toUserId'];
    if (toUserId == null || toUserId.isEmpty) return;

    try {
      final notificationRef = FirebaseFirestore.instance.collection('notifications').doc();

      // Tüm bildirim türleri için ortak alanlar
      final notificationData = {
        'id': notificationRef.id,
        'toUserId': toUserId,
        'isRead': false,
        'timestamp': FieldValue.serverTimestamp(),
      };

      // Bildirim tipine göre özelleştirme
      switch (data['type']) {
        case 'chat':
          notificationData.addAll({
            'senderName': data['senderName'] ?? 'Bilinmiyor',
            'content': data['content'] ?? '',
            'chatId': data['chatId'] ?? '',
            'type': 'chat',
          });
          break;

        case 'forum_comment':
          notificationData.addAll({
            'senderName': data['senderName'] ?? 'Bilinmiyor',
            'content': data['content'] ?? '',
            'postId': data['postId'] ?? '',
            'type': 'forum_comment',
          });
          break;

        case 'comment':
          notificationData.addAll({
            'senderName': data['senderName'] ?? 'Bilinmiyor',
            'content': data['content'] ?? '',
            'relatedId': data['relatedId'] ?? '',
            'type': 'comment',
          });
          break;

        case 'request_sent':
        case 'request_accepted':
        case 'request_rejected':
          notificationData.addAll({
            'senderName': data['senderName'] ?? 'Bilinmiyor',
            'content': data['content'] ?? '',
            'relatedId': data['relatedId'] ?? '',
            'status': data['status'] ?? '',
            'type': data['type'],
          });
          break;

        default:
          debugPrint('⚠️ Bilinmeyen bildirim tipi: ${data['type']}');
          return;
      }

      await notificationRef.set(notificationData);
      debugPrint('✅ Firestore kaydı başarılı! ID: ${notificationRef.id}');
    } catch (e) {
      debugPrint('🔥 Firestore kayıt hatası: $e');
    }
  }

  static Future<void> initialize() async {
    try {
      final token = await _messaging.getToken();
      debugPrint('🆕 FCM Token: $token');

      final user = FirebaseAuth.instance.currentUser;
      if (user != null && token != null) {
        await FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .set({'fcmToken': token}, SetOptions(merge: true));
      }

      // İzin ve dinleyiciler
      await _messaging.requestPermission(alert: true, badge: true, sound: true);
      FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);
      FirebaseMessaging.onMessage.listen((m) => _processNotification(m.data));
      FirebaseMessaging.onMessageOpenedApp.listen((m) => _processNotification(m.data));

      final initialMessage = await _messaging.getInitialMessage();
      if (initialMessage != null) _processNotification(initialMessage.data);

    } catch (e) {
      debugPrint('🔥 Bildirim servisi başlatma hatası: $e');
    }
  }

  // Tüm bildirim türleri için ortak gönderim fonksiyonu
  static Future<void> _sendNotification({
    required String toUserId,
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
          'toUserId': toUserId,
          'type': type,
        }
      };

      const url = 'https://fcm-notification-server-sku2.onrender.com/sendNotification';
      final response = await http.post(
        Uri.parse(url),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(payload),
      );

      if (response.statusCode != 200) {
        debugPrint('❌ Sunucu hatası: ${response.statusCode} - ${response.body}');
      }
    } catch (e) {
      debugPrint('🌐 Bildirim gönderme hatası: $e');
    }
  }

  // 1. Mesaj bildirimi
  static Future<void> sendMessageNotification({
    required String toUserId,
    required String chatId,
    required String senderName,
    required String messageContent,
  }) async {
    await _sendNotification(
      toUserId: toUserId,
      type: 'chat',
      data: {
        'senderName': senderName,
        'content': messageContent,
        'chatId': chatId,
      },
    );
  }

  // 2. Forum yorumu bildirimi
  static Future<void> sendForumReplyNotification({
    required String toUserId,
    required String postId,
    required String replierName,
    required String question,
  }) async {
    await _sendNotification(
      toUserId: toUserId,
      type: 'forum_comment',
      data: {
        'senderName': replierName,
        'content': question,
        'postId': postId,
      },
    );
  }

  // 3. Genel yorum bildirimi
  static Future<void> sendCommentNotification({
    required String toUserId,
    required String relatedId,
    required String commenterName,
    required String commentText,
  }) async {
    await _sendNotification(
      toUserId: toUserId,
      type: 'comment',
      data: {
        'senderName': commenterName,
        'content': commentText,
        'relatedId': relatedId,
      },
    );
  }

  // 4. Talep durum bildirimi
  static Future<void> sendRequestStatusNotification({
    required String toUserId,
    required String senderName,
    required String relatedId,
    required String status,
  }) async {
    String content;
    switch (status) {
      case 'sent':
        content = '$senderName ilanınıza talep gönderdi';
        break;
      case 'accepted':
        content = '$senderName talebinizi kabul etti';
        break;
      case 'rejected':
        content = '$senderName talebinizi reddetti';
        break;
      default:
        content = 'Talep durumu güncellendi';
    }

    await _sendNotification(
      toUserId: toUserId,
      type: 'request_$status', // request_sent, request_accepted, request_rejected
      data: {
        'senderName': senderName,
        'content': content,
        'relatedId': relatedId,
        'status': status,
      },
    );
  }
}