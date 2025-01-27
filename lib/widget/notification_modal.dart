import 'package:flutter/material.dart';

class NotificationModal extends StatelessWidget {
  final List<String> notifications;
  final Function(int) onNotificationRemoved; // Bildirim silme fonksiyonu

  NotificationModal({required this.notifications, required this.onNotificationRemoved});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            "Bildirimler",
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
          ),
          SizedBox(height: 10),
          notifications.isEmpty
              ? Text("Henüz bildirim yok.", style: TextStyle(color: Colors.grey))
              : Expanded(
            child: ListView.builder(
              itemCount: notifications.length,
              itemBuilder: (context, index) {
                return ListTile(
                  title: Text(notifications[index]),
                  trailing: IconButton(
                    icon: Icon(Icons.delete, color: Colors.red),
                    onPressed: () {
                      onNotificationRemoved(index); // Bildirim silme
                      Navigator.pop(context); // Modal'ı kapat
                    },
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}