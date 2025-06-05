
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/widgets.dart';
import 'package:geocoding/geocoding.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:geolocator/geolocator.dart';
import 'package:patico/screens/forum_page.dart';
import 'package:patico/screens/login.dart';
import 'package:patico/screens/pet_detailpage.dart';
import 'package:patico/screens/profile_page.dart';
import 'package:patico/screens/reminder_list_page.dart';
import 'package:patico/screens/settings_page.dart';
import 'package:patico/theme/colors.dart';
import 'package:patico/widget/notification_box.dart';
import 'package:patico/widget/pet_item.dart';
import 'package:patico/screens/ad_page.dart';
import 'package:patico/screens/morepetspage.dart';
import 'package:patico/screens/favorites_page.dart';
import 'package:patico/screens/chat.dart';
import 'package:patico/widget/custom_bottom_navbar.dart';
import 'package:smooth_page_indicator/smooth_page_indicator.dart';

import '../widget/VetMapWidget.dart';

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
    updateUserCityFromCoordinates();

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
    if (token == null) return;

    final firestore = FirebaseFirestore.instance;

    // 1. Bu token başka kullanıcıda varsa, sil
    final query = await firestore
        .collection('users')
        .where('fcmToken', isEqualTo: token)
        .get();

    for (var doc in query.docs) {
      if (doc.id != user.uid) {
        await firestore.collection('users').doc(doc.id).update({'fcmToken': FieldValue.delete()});
        print('❌ $token diğer kullanıcıdan silindi: ${doc.id}');
      }
    }

    // 2. Kendi kullanıcı tokenını güncelle
    await firestore.collection('users').doc(user.uid).set({'fcmToken': token}, SetOptions(merge: true));
    print('📲 Token güncellendi: $token');
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


// İzinleri kontrol eden ve isteyen fonksiyon
  Future<bool> _handleLocationPermission() async {
    LocationPermission permission;

    permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        print('Konum izni reddedildi');
        return false;
      }
    }

    if (permission == LocationPermission.deniedForever) {
      print('Konum izni kalıcı olarak reddedildi. Ayarlardan açmalısın.');
      return false;
    }

    return true;
  }

// Konumu çekip Firestore'dan veriyi güncelleyen veya okuyan fonksiyon
  Future<void> _fetchUserLocation() async {
    bool hasPermission = await _handleLocationPermission();
    if (!hasPermission) return;

    // Konumu alıyoruz
    Position position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high);

    String? userId = FirebaseAuth.instance.currentUser?.uid;
    if (userId != null) {
      try {
        // Koordinatları Firestore'a kaydet (opsiyonel, eğer kaydetmek istiyorsan)
        await FirebaseFirestore.instance.collection('users').doc(userId).set({
          'location': {
            'latitude': position.latitude,
            'longitude': position.longitude,
          }
        }, SetOptions(merge: true));

        // Firestore'dan konumu tekrar okuyup şehir ismini al
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
              print("Firestore’dan gelen şehir: $city");

              _pages[0] = _HomeContent(
                userCity: userCity,
                notifications: notifications,
                notifiedCount: notifiedCount,
              );
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
      if (placemarks.isNotEmpty) {
        Placemark place = placemarks.first;

        print("Placemark detayları:");
        print("name: ${place.name}");
        print("locality: ${place.locality}");
        print("subAdministrativeArea: ${place.subAdministrativeArea}");
        print("administrativeArea: ${place.administrativeArea}");
        print("country: ${place.country}");
        print("postalCode: ${place.postalCode}");

        String? city = place.locality?.trim().isNotEmpty == true
            ? place.locality
            : place.subAdministrativeArea?.trim().isNotEmpty == true
            ? place.subAdministrativeArea
            : place.administrativeArea?.trim().isNotEmpty == true
            ? place.administrativeArea
            : null;

        return city ?? "Bilinmeyen Şehir";
      } else {
        return "Bilinmeyen Şehir";
      }
    } catch (e) {
      print("Şehir alınırken hata oluştu: $e");
      return "Şehir Bulunamadı";
    }
  }
  Future<void> updateUserCityFromCoordinates() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    final userDoc = await FirebaseFirestore.instance.collection('users').doc(user.uid).get();

    if (!userDoc.exists) return;

    final data = userDoc.data();
    if (data == null) return;

    final lat = data['location']?['latitude'];
    final lng = data['location']?['longitude'];

    if (lat == null || lng == null) return;

    String city = await getCityFromCoordinates(lat, lng);

    await FirebaseFirestore.instance.collection('users').doc(user.uid).update({
      'city': city,
    });

    print("Kullanıcının şehri Firestore'da güncellendi: $city");
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
        heroTag: 'uniqueTag1',
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
              _buildDrawerItem(Icons.access_alarm_rounded, "Hatırlatıcı", () {
                Navigator.push(context, MaterialPageRoute(builder: (context) => ReminderListPage()));
              }),
              const Spacer(),
              const Divider(),
              _buildDrawerItem(Icons.logout, "Çıkış Yap", () async {
                await FirebaseAuth.instance.signOut();
                await removeDeviceTokenOnSignOut();
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
  Future<void> removeDeviceTokenOnSignOut() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    await FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .update({'fcmToken': FieldValue.delete()});

    print('📲 Kullanıcı çıkış yaptı, token silindi.');

    await FirebaseAuth.instance.signOut();
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
                (userCity == null || userCity!.isEmpty) ? "Konum yükleniyor..." : userCity!,
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
            _buildSectionWithPets("Sahiplendirme İlanları", "Sahiplenme", context),
            const SizedBox(height: 20),
            _buildSectionWithPets("Bakım İlanları", "Bakım", context),

            // Yeni eklenen Veteriner Haritası Bölümü
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    "Yakındaki Veterinerler",
                    style: TextStyle(
                      color: AppColor.textColor,
                      fontWeight: FontWeight.w700,
                      fontSize: 24,
                    ),
                  ),
                  const SizedBox(height: 15),
                  Container(
                    height: 300,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(15),
                      boxShadow: [
                        BoxShadow(
                            color: Colors.black12,
                            blurRadius: 6,
                            spreadRadius: 2
                        )
                      ],
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(15),
                      child: VetMapWidget(),
                    ),
                  ),
                ],
              ),
            ),
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

  Future<void> _toggleFavorite(String adId) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    final favDocRef = FirebaseFirestore.instance
        .collection('Favorites')
        .doc(user.uid)
        .collection('UserFavorites')
        .doc(adId);

    final snapshot = await favDocRef.get();
    if (snapshot.exists) {
      // Zaten favoride, kaldır
      await favDocRef.delete();
    } else {
      // Favoriye ekle
      await favDocRef.set({
        'adId': adId,
        'timestamp': FieldValue.serverTimestamp(),
      });
    }
  }

  Stream<bool> _isFavoriteStream(String adId) {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return  Stream.value(false);

    return FirebaseFirestore.instance
        .collection('Favorites')
        .doc(user.uid)
        .collection('UserFavorites')
        .doc(adId)
        .snapshots()
        .map((snap) => snap.exists);
  }


  Widget _buildSectionWithPets(String title, String type, BuildContext context) {
    final collectionName = type == 'Sahiplenme' ? 'Sahiplenme' : 'Bakım';
    final pageController = PageController(viewportFraction: 0.8);
    final currentPage = ValueNotifier<int>(0);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Başlık ve "Daha Fazla" butonu
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
                  MaterialPageRoute(builder: (_) => MorePetsPage(type: type)),
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
                  style: TextStyle(color: Colors.white, fontSize: 16),
                ),
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
                        final adId = pet['adId'] as String;
                        final city = pet['city'] as String? ?? '';

                        return Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 8.0),
                          child: Container(
                            decoration: BoxDecoration(
                              color: const Color(0xFFF3E5F5),
                              borderRadius: BorderRadius.circular(15),
                              boxShadow: [
                                BoxShadow(
                                    color: Colors.black12,
                                    blurRadius: 6,
                                    spreadRadius: 2)
                              ],
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                // İlan Görseli
                                ClipRRect(
                                  borderRadius: const BorderRadius.vertical(
                                      top: Radius.circular(15)),
                                  child: Image.network(
                                    pet['imageUrl'] ??
                                        'https://cdn.pixabay.com/photo/2017/09/25/13/12/dog-2785074_1280.jpg',
                                    height: 150,
                                    width: double.infinity,
                                    fit: BoxFit.cover,
                                    errorBuilder: (_, __, ___) => Container(
                                      height: 150,
                                      color: Colors.grey[200],
                                      child: const Icon(Icons.pets,
                                          size: 50, color: Colors.grey),
                                    ),
                                  ),
                                ),

                                // Kart içeriği - GestureDetector ile sarmalayıp tıklamayı ekledik
                                Padding(
                                  padding: const EdgeInsets.all(12.0),
                                  child: GestureDetector(
                                    onTap: () {
                                      Navigator.push(
                                        context,
                                        MaterialPageRoute(
                                          builder: (context) =>
                                              PetDetailPage(adData: pet),
                                        ),
                                      );
                                    },
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        // Başlık
                                        Text(
                                          pet['title'] ?? 'Başlıksız',
                                          style: const TextStyle(
                                              fontSize: 18,
                                              fontWeight: FontWeight.w600),
                                        ),
                                        const SizedBox(height: 6),
                                        // Açıklama
                                        Text(
                                          pet['description'] ?? '',
                                          maxLines: 2,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                        const SizedBox(height: 6),
                                        // Şehir bilgisi
                                        if (city.isNotEmpty)
                                          Row(
                                            children: [
                                              Icon(Icons.location_on,
                                                  size: 14,
                                                  color: Colors.grey[600]),
                                              const SizedBox(width: 4),
                                              Flexible(
                                                child: Text(
                                                  city,
                                                  style: TextStyle(
                                                      fontSize: 12,
                                                      color: Colors.grey[600]),
                                                  overflow: TextOverflow.ellipsis,
                                                ),
                                              ),
                                            ],
                                          ),
                                        const SizedBox(height: 8),
                                        // Favori butonu
                                        Align(
                                          alignment: Alignment.centerRight,
                                          child: StreamBuilder<bool>(
                                            stream: _isFavoriteStream(adId),
                                            initialData: false,
                                            builder: (context, favSnap) {
                                              final isFav = favSnap.data ?? false;
                                              return IconButton(
                                                icon: Icon(
                                                  isFav
                                                      ? Icons.favorite
                                                      : Icons.favorite_border,
                                                  color:
                                                  isFav ? Colors.red : Colors.grey,
                                                ),
                                                onPressed: () => _toggleFavorite(adId),
                                              );
                                            },
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
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