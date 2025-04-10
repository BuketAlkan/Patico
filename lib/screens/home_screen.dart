import 'package:carousel_slider/carousel_slider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:geocoding/geocoding.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:patico/screens/login.dart';
import 'package:patico/screens/profile_page.dart';
import 'package:patico/screens/settings_page.dart';
import 'package:patico/theme/colors.dart';
import 'package:patico/utils/data.dart';
import 'package:patico/widget/notification_box.dart';
import 'package:patico/widget/pet_item.dart';
import 'package:patico/screens/ad_page.dart';
import 'package:patico/screens/morepetspage.dart';
import 'package:patico/screens/favorites_page.dart';
import 'package:patico/screens/chat.dart';
import 'package:patico/widget/custom_bottom_navbar.dart';

class HomePage extends StatefulWidget {
  const HomePage({Key? key}) : super(key: key);

  @override
  _HomePageState createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  int _currentIndex = 0;
  int notifiedCount = 0;
  List<String> notifications = [];
  String userName = "Kullanıcı Adı";
  String userEmail = "kullanici@mail.com";
  String userCity = '';

  late List<Widget> _pages;

  @override
  void initState() {
    super.initState();
    _pages = [
      _HomeContent(
        userCity: userCity,
        notifications: notifications,
        notifiedCount: notifiedCount,
      ),
     const ChatPage(), // const kaldırıldı
      SettingsPage(), // const kaldırıldı
    ];
    _initializeServices();
    _setupFirebaseMessaging();
    _fetchUserLocation();
    _fetchUserDetails();
  }

  void _updatePages() {
    setState(() {
      _pages = [
        _HomeContent(
          userCity: userCity,
          notifications: notifications,
          notifiedCount: notifiedCount,
        ),
        ChatPage(),
        SettingsPage(),
      ];
    });
  }

  Future<void> _initializeServices() async {
    // Servis başlatma işlemleri
  }

  void _setupFirebaseMessaging() {
    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      setState(() {
        notifications.add("${message.notification?.title}: ${message.notification?.body}");
        notifiedCount++;
      });
      _updatePages();
    });
  }

  Future<void> _fetchUserLocation() async {
    String? userId = FirebaseAuth.instance.currentUser?.uid;
    if (userId != null) {
      try {
        DocumentSnapshot userDoc = await FirebaseFirestore.instance
            .collection('users')
            .doc(userId)
            .get();

        if (userDoc.exists) {
          var location = userDoc['location'];
          if (location != null &&
              location['latitude'] != null &&
              location['longitude'] != null) {
            String city = await getCityFromCoordinates(
                location['latitude'], location['longitude']);
            setState(() {
              userCity = city;
              _updatePages();
            });
          }
        }
      } catch (e) {
        print("Konum alınamadı: $e");
      }
    }
  }

  Future<String> getCityFromCoordinates(double lat, double lng) async {
    try {
      List<Placemark> placemarks = await placemarkFromCoordinates(lat, lng);
      return placemarks.first.locality ?? "Bilinmeyen Şehir";
    } catch (e) {
      return "Şehir Bulunamadı";
    }
  }

  Future<void> _fetchUserDetails() async {
    String? userId = FirebaseAuth.instance.currentUser?.uid;
    if (userId != null) {
      try {
        DocumentSnapshot userDoc = await FirebaseFirestore.instance
            .collection('users')
            .doc(userId)
            .get();

        if (userDoc.exists) {
          setState(() {
            userName = userDoc['name'] ?? "İsim Yok";
            userEmail = userDoc['email'] ?? "Email Yok";
          });
        }
      } catch (e) {
        print("Kullanıcı bilgileri alınamadı: $e");
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColor.appBgColor,
      drawer: _buildDrawer(),
      body: IndexedStack(
        index: _currentIndex,
        children: _pages,
      ),
      bottomNavigationBar: CustomBottomNavBar(
        currentIndex: _currentIndex,
        onTap: (index) => setState(() => _currentIndex = index),
      ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: AppColor.primary,
        onPressed: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (context) =>  CreateAdPage()),
        ),
        child: const Icon(Icons.add, size: 30, color: Colors.white), // child doğru parametre
      ),
    );
  }

  Widget _buildDrawer() {
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
            accountName: Text(userName),
            accountEmail: Text(userEmail),
          ),
          _buildDrawerItem(Icons.person, "Profilim", () {
            Navigator.push(context, MaterialPageRoute(builder: (context) => const ProfilePage()));
          }),
          _buildDrawerItem(Icons.favorite, "Favorilerim", () {
            Navigator.push(context, MaterialPageRoute(builder: (context) =>  FavoritesPage()));
          }),
          const Spacer(),
          const Divider(),
          _buildDrawerItem(Icons.logout, "Çıkış Yap", () async {
            await FirebaseAuth.instance.signOut();
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(builder: (context) => const LoginScreen()),
            );
          }),
        ],
      ),
    );
  }

  ListTile _buildDrawerItem(IconData icon, String title, VoidCallback onTap) {
    return ListTile(
      leading: Icon(icon, color: AppColor.primary),
      title: Text(title, style: const TextStyle(fontSize: 16)),
      onTap: onTap,
    );
  }
}

class _HomeContent extends StatelessWidget {
  final String userCity;
  final List<String> notifications;
  final int notifiedCount;

  const _HomeContent({
    Key? key,
    required this.userCity,
    required this.notifications,
    required this.notifiedCount,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return CustomScrollView(
      slivers: [
        SliverAppBar(
          backgroundColor: AppColor.appBarColor,
          pinned: true,
          snap: true,
          floating: true,
          title: _buildAppBar(),
        ),
        SliverList(
          delegate: SliverChildListDelegate([
            _buildBody(context),
          ]),
        ),
      ],
    );
  }

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
                  const Icon(Icons.place_outlined, color: AppColor.labelColor, size: 20),
                  const SizedBox(width: 5),
                  Text(
                    "Konum",
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
            notifications: notifications,
            notifiedNumber: notifiedCount,
          )
        ],
      ),
    );
  }

  Widget _buildBody(BuildContext context) {
    return SingleChildScrollView(
      child: Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 25),
            _buildSectionWithPets("Sahiplendirme İlanları", context),
            const SizedBox(height: 20),
            _buildSectionWithPets("Bakım İlanları", context),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionWithPets(String title, BuildContext context) {
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
                onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => MorePetsPage(type: collectionName),
                  ),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColor.primary,
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20),
                  ),
                ),
                child: const Text(
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
              onFavoriteTap: () {},
            ),
          ),
        ),
      ],
    );
  }
}