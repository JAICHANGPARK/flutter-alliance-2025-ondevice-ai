class ChatMessage {
  final String text;
  final String? imagePath;
  final bool isUser;
  final DateTime timestamp;

  ChatMessage({
    required this.text,
    this.imagePath,
    required this.isUser,
    required this.timestamp,
  });
}