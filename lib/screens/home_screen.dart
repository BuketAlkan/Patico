
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/material.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter/widgets.dart';
import 'package:geocoding/geocoding.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:patico/screens/forum_page.dart';
import 'package:patico/screens/login.dart';
import 'package:patico/screens/pet_detailpage.dart';
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
import 'package:smooth_page_indicator/smooth_page_indicator.dart';
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
  late Future<List<Map<String, dynamic>>> petsFuture;

  @override
  void initState() {
    super.initState();
    _setupFCM();
    saveDeviceToken();

    _pages = [
      _HomeContent(
        userCity: userCity,
        notifications: notifications,
        notifiedCount: notifiedCount,
      ),
      ChatPage(), // const kaldırıldı
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
  void _setupFCM() async {
    await FirebaseMessaging.instance.requestPermission();

    // Bildirim geldiğinde foreground'da gösterilecek
    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      if (message.notification != null) {
        print("Bildirim Başlığı: ${message.notification!.title}");
        print("Bildirim İçeriği: ${message.notification!.body}");

        // Uygulama içi bildirim kutusu gösterilebilir (Snackbar, Alert vs.)
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(message.notification!.body ?? "Yeni bildirim")),
        );
      }
    });
  }
  void saveDeviceToken() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    final token = await FirebaseMessaging.instance.getToken();
    if (token != null) {
      await FirebaseFirestore.instance.collection('users').doc(user.uid).update({
        'fcmToken': token,
      });
      print('📲 Token Firestore\'a kaydedildi: $token');
    }
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
  void _saveUserToken(String userId) async {
    String? token = await FirebaseMessaging.instance.getToken();
    if (token != null) {
      await FirebaseFirestore.instance.collection('users').doc(userId).set({
        'fcmToken': token,
      }, SetOptions(merge: true)); // merge: true, var olan verileri silmeden günceller
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
    final currentUser = FirebaseAuth.instance.currentUser;

    return Drawer(
      child: StreamBuilder<DocumentSnapshot>(
        stream: FirebaseFirestore.instance.collection('users').doc(currentUser!.uid).snapshots(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          final userData = snapshot.data!.data() as Map<String, dynamic>?;

          final userName = userData?['name'] ?? 'Kullanıcı';
          final userEmail = currentUser.email ?? 'E-posta yok';

          // photoURL alanını kullan
          String? profileUrl = userData?['photoURL'];

          // Eğer yoksa varsayılan avatar URL'si
          profileUrl ??= 'https://example.com/default-avatar.png';

          return Column(
            children: [
              UserAccountsDrawerHeader(
                currentAccountPicture: CircleAvatar(
                  backgroundImage: NetworkImage(profileUrl),
                  onBackgroundImageError: (_, __) {},
                  child: profileUrl.isEmpty
                      ? const Icon(Icons.person, size: 40)
                      : null,
                ),
                accountName: Text(userName),
                accountEmail: Text(userEmail),
              ),
              _buildDrawerItem(Icons.person, "Profilim", () {
                Navigator.push(context, MaterialPageRoute(builder: (context) => const ProfilePage()));
              }),
              _buildDrawerItem(Icons.favorite, "Favorilerim", () {
                Navigator.push(context, MaterialPageRoute(builder: (context) => FavoritesPage()));
              }),
              _buildDrawerItem(Icons.mode_comment_rounded, "Forum", () {
                Navigator.push(context, MaterialPageRoute(builder: (context) => ForumPage()));
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
          );
        },
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
      padding: const EdgeInsets.symmetric(vertical: 10.0, horizontal: 16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(Icons.place_outlined, color: AppColor.labelColor,
                      size: 20),
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
          StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance
                .collection('notifications')
                .where(
                'toUserId', isEqualTo: FirebaseAuth.instance.currentUser?.uid)
                .where('isRead', isEqualTo: false)
                .snapshots(),
            builder: (context, snapshot) {
              int unreadCount = snapshot.data?.docs.length ?? 0;

              return GestureDetector(
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (context) => const NotificationBox()),
                  );
                },
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    const Icon(Icons.notifications_none, size: 28,
                        color: Colors.black),
                    if (unreadCount > 0)
                      Positioned(
                        right: 0,
                        top: 5,
                        child: Container(
                          padding: const EdgeInsets.all(4),
                          decoration: const BoxDecoration(
                            color: Colors.red,
                            shape: BoxShape.circle,
                          ),
                          child: Text(
                            unreadCount.toString(),
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              );
            },
          ),
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
            _buildSectionWithPets(
                "Sahiplendirme İlanları", "Sahiplenme", context),
            const SizedBox(height: 20),
            _buildSectionWithPets("Bakım İlanları", "Bakım", context),
          ],
        ),
      ),
    );
  }

  Future<List<Map<String, dynamic>>> fetchLatestPets(String type) async {
    final snapshot = await FirebaseFirestore.instance
        .collection(type)
        .orderBy('createdAt', descending: true)
        .limit(5)
        .get();

    if (snapshot.docs.isEmpty) {
      print("No pets found in $type"); // Debug için
    }

    return snapshot.docs.map((doc) => doc.data()).toList();
  }

  void _toggleFavorite(Map<String, dynamic> petData) async {
    final userId = FirebaseAuth.instance.currentUser?.uid;
    if (userId == null) return;

    final petId = petData['adId'];

    final favoritesRef = FirebaseFirestore.instance.collection('Favorites').doc(
        userId);
    final favoriteDoc = await favoritesRef.get();

    if (favoriteDoc.exists) {
      final favoriteList = List.from(favoriteDoc['petIds'] ?? []);
      if (favoriteList.contains(petId)) {
        favoriteList.remove(petId);
      } else {
        favoriteList.add(petId);
      }

      await favoritesRef.update({'petIds': favoriteList});
    } else {
      await favoritesRef.set({'petIds': [petId]});
    }
  }


  Widget _buildSectionWithPets(String title, String type, BuildContext context) {
    final collectionName = type == 'Sahiplenme' ? 'Sahiplenme' : 'Bakım';
    final pageController = PageController(viewportFraction: 0.8);
    final currentPage = ValueNotifier<int>(0);
    final userId = FirebaseAuth.instance.currentUser?.uid;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Başlık ve "Daha Fazla" butonu aynen kaldı
        Padding(
          padding: const EdgeInsets.fromLTRB(15, 0, 15, 15),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(title,
                  style: TextStyle(
                    color: AppColor.textColor,
                    fontWeight: FontWeight.w700,
                    fontSize: 24,
                  )),
              ElevatedButton(
                onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => MorePetsPage(type: type)),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColor.primary,
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20),
                  ),
                ),
                child: const Text("Daha Fazla",
                    style: TextStyle(color: Colors.white, fontSize: 16)),
              ),
            ],
          ),
        ),

        // İlanları çeken StreamBuilder
        StreamBuilder<QuerySnapshot>(
          stream: FirebaseFirestore.instance
              .collection(collectionName)
              .orderBy('createdAt', descending: true)
              .limit(5)
              .snapshots(),
          builder: (context, snap) {
            if (snap.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }
            final docs = snap.data?.docs ?? [];
            if (docs.isEmpty) {
              return const Padding(
                padding: EdgeInsets.all(20),
                child: Center(child: Text('Hiç ilan bulunamadı.')),
              );
            }

            // Her dokümandan bir Map çıkar ve adId olarak ID'yi set et
            final pets = docs.map((doc) {
              final data = doc.data()! as Map<String, dynamic>;
              data['adId'] = doc.id;
              return data;
            }).toList();

            return SizedBox(
              height: 400,
              child: Column(
                children: [
                  Expanded(
                    child: PageView.builder(
                      controller: pageController,
                      itemCount: pets.length,
                      onPageChanged: (i) => currentPage.value = i,
                      itemBuilder: (context, index) {
                        final pet = pets[index];
                        final adId = pet['adId'];

                        // Favori listesini dinleyen StreamBuilder
                        return StreamBuilder<DocumentSnapshot>(
                          stream: FirebaseFirestore.instance
                              .collection('Favorites')
                              .doc(userId)
                              .snapshots(),
                          builder: (context, favSnap) {
                            bool isFav = false;
                            if (favSnap.hasData && favSnap.data!.exists) {
                              final favList = List<String>.from(
                                  favSnap.data!['petIds'] ?? []);
                              isFav = favList.contains(adId);
                            }

                            return Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 8.0),
                              child: PetItem(
                                data: pet,
                                width: MediaQuery.of(context).size.width * 0.8,
                                isFavorite: isFav,
                                onTap: () => Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                      builder: (_) =>
                                          PetDetailPage(adData: pet)),
                                ),
                                onFavoriteTap: () => _toggleFavorite(pet),
                              ),
                            );
                          },
                        );
                      },
                    ),
                  ),
                  const SizedBox(height: 16),
                  ValueListenableBuilder<int>(
                    valueListenable: currentPage,
                    builder: (context, value, _) => AnimatedSmoothIndicator(
                      activeIndex: value,
                      count: pets.length,
                      effect: const WormEffect(
                        dotHeight: 8,
                        dotWidth: 8,
                        activeDotColor: Colors.blue,
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      ],
    );
  }

}