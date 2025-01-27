import 'package:carousel_slider/carousel_slider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:patico/theme/colors.dart';
import 'package:patico/utils/data.dart';
import 'package:patico/widget/category_item.dart';
import 'package:patico/widget/notification_box.dart';
import 'package:patico/widget/pet_item.dart';
import 'package:patico/widget/bottombar_item.dart';
import 'package:patico/widget/notification_modal.dart';
import 'package:patico/services/notification_services.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:patico/services/setup_notification_chanel.dart';
import 'package:firebase_messaging/firebase_messaging.dart';

class HomePage extends StatefulWidget {
  const HomePage({Key? key}) : super(key: key);

  @override
  _HomePageState createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  int _selectedCategory = 0;
  int notifiedCount = 0;
  List<String> notifications = [];
  final NotificationService notificationService = NotificationService();

  @override
  void initState() {
    super.initState();
    initializeServices();
    setupNotificationChannel();
    setupFirebaseMessaging();
  }

  /// Firebase ve bildirim servisini başlatan fonksiyon
  Future<void> initializeServices() async {
    try {
      await notificationService.initialize(context, (count) {
        setState(() {
          notifiedCount = count; // Bildirim sayısını güncelle
        });
      });
      print("Firebase ve Bildirim Servisi Başlatıldı");
    } catch (e) {
      print("Servis Başlatılamadı: $e");
    }
  }

  /// Firebase Messaging ile bildirimleri almak için gerekli fonksiyon
  void setupFirebaseMessaging() {
    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      print("Foreground Message Received: ${message.notification?.title}");

      if (message.notification != null) {
        setState(() {
          notifications.add(
              "${message.notification?.title}: ${message.notification?.body}");
        });
      }
    });

    FirebaseMessaging.onBackgroundMessage(_firebaseBackgroundMessageHandler);
  }

  /// Arka planda gelen bildirimleri işleme fonksiyonu
  static Future<void> _firebaseBackgroundMessageHandler(
      RemoteMessage message) async {
    print("Background Message Received: ${message.notification?.title}");
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColor.appBgColor,
      body: Stack(
        children: [
          CustomScrollView(
            slivers: [
              SliverAppBar(
                backgroundColor: AppColor.appBarColor,
                pinned: true,
                snap: true,
                floating: true,
                title: _buildAppBar(),
              ),
              SliverList(
                delegate: SliverChildBuilderDelegate(
                      (context, index) => _buildBody(),
                  childCount: 1,
                ),
              ),
            ],
          ),
          _buildBottomButton(),
        ],
      ),
      bottomNavigationBar: _buildBottomBar(),
    );
  }

  /// AppBar Widget
  Widget _buildAppBar() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.place_outlined,
                      color: AppColor.labelColor, size: 20),
                  const SizedBox(width: 5),
                  Text(
                    "Location",
                    style: TextStyle(
                      color: AppColor.labelColor,
                      fontSize: 13,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 3),
              Text(
                "konum",
                style: TextStyle(
                  color: AppColor.textColor,
                  fontWeight: FontWeight.w500,
                  fontSize: 14,
                ),
              ),
            ],
          ),
          NotificationBox(
            notifications: notificationService.getNotificationList(),
              notifiedNumber: notificationService.getNotificationList().length
          )
        ],
      ),
    );
  }

  /// Body İçeriği
  Widget _buildBody() {
    return SingleChildScrollView(
      child: Padding(
        padding: const EdgeInsets.only(top: 0, bottom: 10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 25),
            _buildCategories(),
            const SizedBox(height: 25),
            _buildSectionWithPets("Sahiplendirme İlanları"),
            const SizedBox(height: 20),
            _buildSectionWithPets("Bakım İlanları"),
          ],
        ),
      ),
    );
  }

  /// Hayvanların olduğu bölümü oluşturur
  Widget _buildSectionWithPets(String title) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(15, 0, 15, 15),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                title,
                style: TextStyle(
                  color: AppColor.textColor,
                  fontWeight: FontWeight.w700,
                  fontSize: 24,
                ),
              ),
              ElevatedButton(
                onPressed: () {},
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColor.primary,
                  padding:
                  const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20),
                  ),
                ),
                child: Text(
                  "Daha Fazla",
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                  ),
                ),
              ),
            ],
          ),
        ),
        CarouselSlider(
          options: CarouselOptions(
            height: 400,
            enlargeCenterPage: true,
            disableCenter: true,
            viewportFraction: .8,
          ),
          items: List.generate(
            pets.length,
                (index) => PetItem(
              data: pets[index],
              width: MediaQuery.of(context).size.width * .8,
              onTap: null,
              onFavoriteTap: () {
                setState(() {
                  pets[index]["is_favorited"] = !pets[index]["is_favorited"];
                });
              },
            ),
          ),
        ),
      ],
    );
  }

  /// Kategori seçimi için widget
  Widget _buildCategories() {
    List<Widget> lists = List.generate(
      categories.length,
          (index) => CategoryItem(
        data: categories[index],
        selected: index == _selectedCategory,
        onTap: () {
          setState(() {
            _selectedCategory = index;
          });
        },
      ),
    );
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: EdgeInsets.only(bottom: 5, left: 15),
      child: Row(children: lists),
    );
  }

  /// Alt Buton
  Widget _buildBottomButton() {
    return Positioned(
      bottom: 20,
      left: 20,
      right: 20,
      child: ElevatedButton(
        onPressed: () {
          Navigator.pushNamed(context, '/forumPage');
        },
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColor.primary,
          padding: EdgeInsets.symmetric(horizontal: 40, vertical: 15),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(30),
          ),
        ),
        child: Text(
          "Forum Sayfası",
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            fontSize: 16,
          ),
        ),
      ),
    );
  }

  /// Alt Navigasyon Barı
  Widget _buildBottomBar() {
    return BottomNavigationBar(
      items: [
        BottomNavigationBarItem(
          icon: BottomBarItem('assets/home.svg'),
          label: 'Home',
        ),
        BottomNavigationBarItem(
          icon: BottomBarItem('assets/chat.svg'),
          label: 'Chat',
        ),
        BottomNavigationBarItem(
          icon: BottomBarItem('assets/setting.svg'),
          label: 'Settings',
        ),
      ],
    );
  }
}
