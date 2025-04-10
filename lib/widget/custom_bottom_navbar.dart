import 'package:flutter/material.dart';

class CustomBottomNavBar extends StatelessWidget {
  final int currentIndex;
  final Function(int) onTap;

  const CustomBottomNavBar({
    Key? key,
    required this.currentIndex,
    required this.onTap,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return BottomNavigationBar(
      currentIndex: currentIndex,
      onTap: onTap,
      items: const [
        BottomNavigationBarItem(icon: Icon(Icons.home), label: 'Ana Sayfa'),
        BottomNavigationBarItem(icon: Icon(Icons.chat), label: 'Sohbet'),
        BottomNavigationBarItem(icon: Icon(Icons.settings), label: 'Ayarlar'),
      ],
    );
  }
}