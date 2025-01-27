import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:patico/widget/notification_modal.dart';

class NotificationBox extends StatefulWidget {
  const NotificationBox({
    Key? key,
    required this.notifications, // Bildirim listesi
    this.onTap,
    this.notifiedNumber = 0,
  }) : super(key: key);

  final GestureTapCallback? onTap;
  final int notifiedNumber;
  final List<String> notifications; // Bildirim listesi

  @override
  _NotificationBoxState createState() => _NotificationBoxState();
}

class _NotificationBoxState extends State<NotificationBox> {
  late int _notifiedNumber;

  @override
  void initState() {
    super.initState();
    // Bildirim sayısını widget.notifiedNumber'dan başlatıyoruz
    _notifiedNumber = widget.notifiedNumber > 0 ? widget.notifiedNumber : widget.notifications.length;
  }

  // Alttan kayan modalı açan fonksiyon
  void _showNotificationModal(BuildContext context) {
    showModalBottomSheet(
      context: context,
      builder: (BuildContext context) {
        return NotificationModal(
          notifications: widget.notifications,
          onNotificationRemoved: _removeNotification, // Bildirim silme fonksiyonu ekledik
        );
      },
    );
  }

  // Bildirim sayısını sıfırlama
  void _resetNotificationCount() {
    setState(() {
      _notifiedNumber = widget.notifications.length;
    });
  }

  // Bildirim silme işlemi
  void _removeNotification(int index) {
    setState(() {
      widget.notifications.removeAt(index); // Listeden bildirimi sil
      _notifiedNumber = widget.notifications.length; // Bildirim sayısını güncelle
    });
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        // Bildirim kutusuna tıklandığında sadece alttan kayan modal'ı aç
        _showNotificationModal(context);

        // Bildirim sayısını sıfırlama işlemi
        _resetNotificationCount();

        // Ekstra onTap fonksiyonu varsa çalıştır
        widget.onTap?.call(); // null kontrolü ile onTap fonksiyonunu çağırma
      },
      child: Container(
        padding: EdgeInsets.all(5),
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: Colors.white, // AppColor.appBarColor
          border: Border.all(color: Colors.grey.withOpacity(.3)),
        ),
        child: Stack(
          alignment: Alignment.center, // Stack öğelerini merkeze hizalar
          children: [
            SvgPicture.asset(
              "assets/bell.svg", // Bildirim simgesi
              width: 25,
              height: 25,
            ),
            // Eğer bildirim varsa, bildirim sayısını gösterecek yuvarlak bir kutu
            if (_notifiedNumber > 0) // 0'dan büyükse göster
              Positioned(
                right: -5, // Konumu ayarlayın, böylece simgenin dışına taşar
                top: -5, // Bildirim sayısı simgenin üstünde biraz taşsın
                child: Container(
                  padding: EdgeInsets.all(6),  // Padding'i artırarak sayı görünürlüğünü kontrol et
                  decoration: BoxDecoration(
                    color: Colors.red,
                    shape: BoxShape.circle,
                  ),
                  child: Text(
                    _notifiedNumber.toString(),
                    style: TextStyle(color: Colors.white, fontSize: 14),  // Font boyutunu biraz artır
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}