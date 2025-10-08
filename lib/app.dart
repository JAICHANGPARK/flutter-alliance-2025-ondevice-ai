import 'package:flutter/material.dart';
import 'package:flutter_alliance_2025_on_device_ai/ui/cactus/basic_completion.dart';
import 'package:flutter_alliance_2025_on_device_ai/ui/cactus/streaming_completion.dart';

import 'ui/chat_screen.dart';

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Chat App',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
        useMaterial3: true,
      ),
      home: const StreamingCompletionPage(),
    );
  }
}
