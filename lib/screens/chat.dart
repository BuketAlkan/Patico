import 'package:flutter/material.dart';

class ChatPage extends StatelessWidget {
  const ChatPage({Key? key}) : super(key: key); // <- const constructor korundu

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Sohbetler')),
      body: ListView.builder(
        itemCount: 10,
        itemBuilder: (context, index) => ListTile(
          title: Text('Sohbet ${index + 1}'),
          subtitle: const Text('Son mesaj...'),
          leading: const CircleAvatar(child: Icon(Icons.person)),
        ),
      ),
    );
  }
}