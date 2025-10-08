import 'package:cactus/cactus.dart';
import 'package:flutter/material.dart';

class BasicCompletionPage extends StatefulWidget {
  const BasicCompletionPage({super.key});

  @override
  State<BasicCompletionPage> createState() => _BasicCompletionPageState();
}

class ChatMessageModel {
  final String text;
  final bool isUser;
  final DateTime timestamp;
  final double? tokensPerSecond;

  ChatMessageModel({
    required this.text,
    required this.isUser,
    required this.timestamp,
    this.tokensPerSecond,
  });
}

class _BasicCompletionPageState extends State<BasicCompletionPage> {
  final lm = CactusLM();
  final TextEditingController _textController = TextEditingController();
  final List<ChatMessageModel> _messages = [];
  final List<ChatMessage> _conversationHistory = [];

  bool isModelDownloaded = false;
  bool isModelLoaded = false;
  bool isDownloading = false;
  bool isInitializing = false;
  bool isGenerating = false;
  String _modelStatus = 'Ready to start. Click "Download Model" to begin.';
  List<CactusModel> availableModels = [];

  @override
  void initState() {
    super.initState();
    getAvailableModels();
  }

  @override
  void dispose() {
    _textController.dispose();
    lm.unload();
    super.dispose();
  }

  Future<void> getAvailableModels() async {
    try {
      final models = await lm.getModels();
      print("Available models: ${models.map((m) => "${m.slug}: ${m.sizeMb}MB").join(", ")}");
    } catch (e) {
      print("Error fetching models: $e");
    }
  }

  Future<void> downloadModel() async {
    setState(() {
      isDownloading = true;
      _modelStatus = 'Downloading model...';
    });

    try {
      await lm.downloadModel(
        downloadProcessCallback: (progress, status, isError) {
          setState(() {
            if (isError) {
              _modelStatus = 'Error: $status';
            } else {
              _modelStatus = status;
              if (progress != null) {
                _modelStatus += ' (${(progress * 100).toStringAsFixed(1)}%)';
              }
            }
          });
        },
      );
      setState(() {
        isModelDownloaded = true;
        _modelStatus = 'Model downloaded successfully! Click "Initialize Model" to load it.';
      });
    } catch (e) {
      setState(() {
        _modelStatus = 'Error downloading model: $e';
      });
    } finally {
      setState(() {
        isDownloading = false;
      });
    }
  }

  Future<void> initializeModel() async {
    setState(() {
      isInitializing = true;
      _modelStatus = 'Initializing model...';
    });

    try {
      await lm.initializeModel();
      setState(() {
        isModelLoaded = true;
        _modelStatus = 'Model ready - Start chatting!';
      });
    } catch (e) {
      setState(() {
        _modelStatus = 'Error initializing model: $e';
      });
    } finally {
      setState(() {
        isInitializing = false;
      });
    }
  }

  Future<void> _handleSubmit() async {
    final text = _textController.text.trim();
    if (text.isEmpty) return;
    if (!isModelLoaded) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please download and initialize model first.')),
      );
      return;
    }

    // 사용자 메시지 추가
    setState(() {
      _messages.insert(
        0,
        ChatMessageModel(
          text: text,
          isUser: true,
          timestamp: DateTime.now(),
        ),
      );
      _conversationHistory.add(ChatMessage(content: text, role: "user"));
      _textController.clear();
      isGenerating = true;
    });

    // AI 응답을 위한 빈 메시지 생성
    final aiMessageIndex = 0;
    setState(() {
      _messages.insert(
        0,
        ChatMessageModel(
          text: '',
          isUser: false,
          timestamp: DateTime.now(),
        ),
      );
    });

    try {
      // 시스템 메시지와 대화 히스토리 포함
      final messages = [
        ChatMessage(
          content: 'You are Cactus, a very capable AI assistant running offline on a smartphone',
          role: "system",
        ),
        ..._conversationHistory,
      ];

      final startTime = DateTime.now();
      String fullResponse = '';

      final resp = await lm.generateCompletion(
        messages: messages,
        params: CactusCompletionParams(maxTokens: 500),
      );

      if (resp.success) {
        fullResponse = resp.response ?? '';
        final elapsed = DateTime.now().difference(startTime).inMilliseconds;
        final tps = resp.tokensPerSecond;

        setState(() {
          _messages[aiMessageIndex] = ChatMessageModel(
            text: fullResponse,
            isUser: false,
            timestamp: _messages[aiMessageIndex].timestamp,
            tokensPerSecond: tps,
          );
          _conversationHistory.add(ChatMessage(content: fullResponse, role: "assistant"));
        });
      } else {
        setState(() {
          _messages[aiMessageIndex] = ChatMessageModel(
            text: 'Failed to generate response.',
            isUser: false,
            timestamp: _messages[aiMessageIndex].timestamp,
          );
        });
      }
    } catch (e) {
      setState(() {
        _messages[aiMessageIndex] = ChatMessageModel(
          text: 'Error: $e',
          isUser: false,
          timestamp: _messages[aiMessageIndex].timestamp,
        );
      });
    } finally {
      setState(() {
        isGenerating = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text('Cactus Chat'),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 1,
      ),
      body: Column(
        children: [
          // Status bar
          Container(
            padding: const EdgeInsets.all(12.0),
            color: isModelLoaded ? Colors.green[100] : Colors.orange[100],
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    _modelStatus,
                    style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.black),
                  ),
                ),
                if (!isModelDownloaded)
                  ElevatedButton(
                    onPressed: isDownloading ? null : downloadModel,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.black,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    ),
                    child: isDownloading
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                            ),
                          )
                        : const Text('Download'),
                  ),
                if (isModelDownloaded && !isModelLoaded)
                  ElevatedButton(
                    onPressed: isInitializing ? null : initializeModel,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.black,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    ),
                    child: isInitializing
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                            ),
                          )
                        : const Text('Initialize'),
                  ),
              ],
            ),
          ),
          // Chat messages
          Expanded(
            child: _messages.isEmpty
                ? const Center(
                    child: Text(
                      'Start chatting with AI',
                      style: TextStyle(color: Colors.grey, fontSize: 16),
                    ),
                  )
                : ListView.builder(
                    reverse: true,
                    padding: const EdgeInsets.all(16.0),
                    itemCount: _messages.length,
                    itemBuilder: (context, index) {
                      final message = _messages[index];
                      return _buildMessageBubble(message);
                    },
                  ),
          ),
          // Input area
          Container(
            decoration: BoxDecoration(
              color: Colors.white,
              boxShadow: [
                BoxShadow(
                  color: Colors.grey.withOpacity(0.3),
                  spreadRadius: 1,
                  blurRadius: 3,
                  offset: const Offset(0, -1),
                ),
              ],
            ),
            child: SafeArea(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 8.0),
                child: Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _textController,
                        decoration: InputDecoration(
                          hintText: 'Type a message...',
                          hintStyle: const TextStyle(color: Colors.grey),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(24.0),
                            borderSide: const BorderSide(color: Colors.black),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(24.0),
                            borderSide: const BorderSide(color: Colors.black),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(24.0),
                            borderSide: const BorderSide(color: Colors.black, width: 2),
                          ),
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 16.0,
                            vertical: 10.0,
                          ),
                        ),
                        maxLines: null,
                        textInputAction: TextInputAction.send,
                        onSubmitted: (_) => _handleSubmit(),
                        enabled: isModelLoaded && !isGenerating,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      decoration: const BoxDecoration(
                        color: Colors.black,
                        shape: BoxShape.circle,
                      ),
                      child: IconButton(
                        icon: isGenerating
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                                ),
                              )
                            : const Icon(Icons.send, color: Colors.white),
                        onPressed: (isModelLoaded && !isGenerating) ? _handleSubmit : null,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMessageBubble(ChatMessageModel message) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        mainAxisAlignment:
            message.isUser ? MainAxisAlignment.end : MainAxisAlignment.start,
        children: [
          Container(
            constraints: BoxConstraints(
              maxWidth: MediaQuery.of(context).size.width * 0.7,
            ),
            padding: const EdgeInsets.all(12.0),
            decoration: BoxDecoration(
              color: message.isUser ? Colors.black : Colors.grey[300],
              borderRadius: BorderRadius.circular(16.0),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (message.text.isNotEmpty)
                  Text(
                    message.text,
                    style: TextStyle(
                      color: message.isUser ? Colors.white : Colors.black87,
                      fontSize: 16.0,
                    ),
                  ),
                if (!message.isUser && message.tokensPerSecond != null) ...[
                  const SizedBox(height: 8.0),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8.0,
                      vertical: 4.0,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.blue[100],
                      borderRadius: BorderRadius.circular(8.0),
                    ),
                    child: Text(
                      '${message.tokensPerSecond!.toStringAsFixed(2)} tokens/s',
                      style: const TextStyle(
                        fontSize: 12.0,
                        fontWeight: FontWeight.bold,
                        color: Colors.blue,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}