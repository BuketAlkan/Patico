import 'package:carousel_slider/carousel_slider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:geocoding/geocoding.dart';
import 'package:patico/screens/login.dart';
import 'package:patico/screens/profile_page.dart';
import 'package:patico/services/setup_notification_chanel.dart';
import 'package:patico/theme/colors.dart';
import 'package:patico/utils/data.dart';
import 'package:patico/widget/category_item.dart';
import 'package:patico/widget/notification_box.dart';
import 'package:patico/widget/pet_item.dart';
import 'package:patico/widget/bottombar_item.dart';
import 'package:patico/widget/notification_modal.dart';
import 'package:patico/services/notification_services.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:patico/screens/ad_page.dart';
import 'package:patico/screens/morepetspage.dart';
import 'package:patico/screens/favorites_page.dart';

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
  String userLocation = '';
  String userName = "Kullanıcı Adı"; // Başlangıç değeri
  String userEmail = "kullanici@mail.com"; // Başlangıç değeri
  String userCity='';

  @override
  void initState() {
    super.initState();
    initializeServices();
    setupNotificationChannel();
    setupFirebaseMessaging();
    fetchUserLocation();
    fetchUserDetails();
  }

  Future<void> fetchUserDetails() async {
    String? userId = FirebaseAuth.instance.currentUser?.uid;

    if (userId != null) {
      try {
        DocumentSnapshot userDoc = await FirebaseFirestore.instance
            .collection('users')
            .doc(userId)
            .get();

        if (userDoc.exists) {
          setState(() {
            userName = userDoc['name'] ?? "Kullanıcı Adı Yok"; // name alanı firestore'dan çekilecek
            userEmail = userDoc['email'] ?? "kullanici@mail.com"; // email alanı firestore'dan çekilecek
          });
        }
      } catch (e) {
        print("Kullanıcı bilgileri alınamadı: $e");
      }
    }
  }

  Future<void> fetchUserLocation() async {
    String? userId = FirebaseAuth.instance.currentUser?.uid;
    if (userId != null) {
      try {
        // Firestore'dan kullanıcı verisini çek
        DocumentSnapshot userDoc = await FirebaseFirestore.instance.collection('users').doc(userId).get();

        if (userDoc.exists) {
          // Konum bilgisini al
          var location = userDoc['location'];
          if (location != null && location['latitude'] != null && location['longitude'] != null) {
            setState(() {
              // Konumu düzgün formatta yazdırıyoruz
              userLocation =
              'Konum: ${location['latitude']}, ${location['longitude']}';
            });
          } else {
            setState(() {
              userLocation = "Konum verisi eksik.";
            });
          }
        } else {
          setState(() {
            userLocation = "Kullanıcı verisi bulunamadı.";
          });
        }
      } catch (e) {
        setState(() {
          userLocation = "Konum alınamadı: $e";
        });
        print("Konum alınamadı: $e");
      }
    }
  }

  Future<String> getCityFromCoordinates(double latitude, double longitude) async {
    try {
      List<Placemark>? placemarks = await GeocodingPlatform.instance?.placemarkFromCoordinates(latitude, longitude);

      if (placemarks!.isNotEmpty) {
        Placemark place = placemarks[0];
        return place.locality ?? "Bilinmeyen Şehir";
      } else {
        return "Şehir Bulunamadı";
      }
    } catch (e) {
      return "Konum alınamıyor";
    }
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
      drawer: _buildDrawer(context),
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
                leading: IconButton(
                  icon: Icon(Icons.menu, color: Colors.white), // Menü butonu
                  onPressed: () => Scaffold.of(context).openDrawer(),
                ),
              ),
              SliverList(
                delegate: SliverChildBuilderDelegate(
                      (context, index) => _buildBody(),
                  childCount: 1,
                ),
              ),
            ],
          ),
          _buildFloatingActionButton(),
        ],
      ),
      bottomNavigationBar: _buildBottomBar(),
    );
  }

  /// 🔹 **Yan Menü (Drawer)**
  Widget _buildDrawer(BuildContext context) {
    return Drawer(
      child: Column(
        children: [
          UserAccountsDrawerHeader(
            currentAccountPicture: CircleAvatar(
              backgroundImage: NetworkImage(
                FirebaseAuth.instance.currentUser?.photoURL ??
                    'https://example.com/default-avatar.png',
              ),
            ),
            accountName: Text(userName), // Firestore'dan alınan kullanıcı adı
            accountEmail: Text(userEmail), // Firestore'dan alınan kullanıcı email
          ),
          _buildDrawerItem(Icons.person, "Profilim", () {
             Navigator.push(context, MaterialPageRoute(builder: (context) => ProfilePage()));
          }),
          _buildDrawerItem(Icons.favorite, "Favorilerim", () {
            Navigator.push(context, MaterialPageRoute(builder: (context) => FavoritesPage()));
          }),
          _buildDrawerItem(Icons.forum, "Forum", () {
            // Navigator.push(context, MaterialPageRoute(builder: (context) => ForumPage()));
          }),
          Spacer(),
          Divider(),
          _buildDrawerItem(Icons.logout, "Çıkış Yap", () async {
            try {
              await FirebaseAuth.instance.signOut(); // Kullanıcıyı çıkış yap
              Navigator.pushAndRemoveUntil(
    context,
    MaterialPageRoute(builder: (context) => LoginScreen()), // Replace with your login screen widget
    (Route<dynamic> route) => false, // This removes all previous routes
    );
    } catch (e) {
    print("Çıkış yaparken hata oluştu: $e");
    }
    }),

        ],
      ),
    );
  }

  Widget _buildDrawerItem(IconData icon, String title, VoidCallback onTap) {
    return ListTile(
      leading: Icon(icon, color: AppColor.primary),
      title: Text(title, style: TextStyle(fontSize: 16)),
      onTap: onTap,
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
                userCity.isEmpty ? "Konum yükleniyor..." : userCity,
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
              notifiedNumber: notificationService
                  .getNotificationList()
                  .length
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
            //_buildCategories(),
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
    // Firestore'daki koleksiyon adları ile eşleşen formatta bir değişken oluşturalım
    String collectionName = title.contains("Bakım") ? "Bakım" : "Sahiplenme";

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
                onPressed: () {
                  print("Seçilen koleksiyon: $collectionName"); // Debugging için
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => MorePetsPage(type: collectionName),
                    ),
                  );
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColor.primary,
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
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

        // Carousel Slider buraya düzgün şekilde yerleştirildi
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
      ], // children listesi burada düzgün kapanıyor
    );
  }


  /// Kategori seçimi için widget
  /*Widget _buildCategories() {
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
  }*/

  /// Alt Buton
  Widget _buildFloatingActionButton() {
    return Positioned(
      bottom: 20,
      right: 20,
      child: FloatingActionButton(
        backgroundColor: AppColor.primary,
        onPressed: () {
          // Yeni ilan ekleme ekranına yönlendirme

          Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => CreateAdPage()),
          );
        },
        child: Icon(Icons.add, size: 30, color: Colors.white),
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


