import 'package:flutter/material.dart';
import 'ai_engine.dart';
import 'voice_service.dart';
import '../shell/main_shell.dart';

class AIScreen extends StatefulWidget {
  final int companyId;
  const AIScreen({super.key, required this.companyId});

  @override
  State<AIScreen> createState() => _AIScreenState();
}

class _ChatMessage {
  final String text;
  final bool isUser;
  final DateTime time;
  final AIIntent? pendingIntent;
  final Map<String, dynamic>? params;
  bool isActionTaken = false;

  _ChatMessage({
    required this.text,
    required this.isUser,
    required this.time,
    this.pendingIntent,
    this.params,
  });
}

class _AIScreenState extends State<AIScreen> {
  final List<_ChatMessage> _messages = [];
  final TextEditingController _controller = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  late AIEngine _engine;
  final VoiceService _voice = VoiceService();
  bool _isListening = false;
  bool _isVoiceReady = false;

  @override
  void initState() {
    super.initState();
    // Default to Urdu, but will be updated by voice/locale settings
    _engine = AIEngine(widget.companyId, locale: 'ur');

    // Initialize voice service
    _voice.init().then((_) {
      if (mounted) {
        setState(() {
          _isVoiceReady = true;
          _engine = AIEngine(widget.companyId,
              locale: _voice.isUrduMode ? 'ur' : 'en');
        });
      }
    });

    // Initialize TFLite model for AI intent classification
    _initializeTFLite();

    _addSystemMessage(
        "Asalam-o-Alaikum! Main BizManager AI hoon. Main aapke business data ko samajhne mein aapki madad kar sakta hoon.");
  }

  /// Initialize TFLite intent classifier
  Future<void> _initializeTFLite() async {
    try {
      await _engine.initializeTFLite();
      print('✅ TFLite AI initialized successfully');
    } catch (e) {
      print('⚠️  TFLite initialization failed: $e');
      print('   App will use keyword-based intent matching as fallback');
      // No error shown to user - app continues with keyword matching
    }
  }

  void _addSystemMessage(String text,
      {AIIntent? pendingIntent, Map<String, dynamic>? params}) {
    setState(() {
      _messages.add(_ChatMessage(
        text: text,
        isUser: false,
        time: DateTime.now(),
        pendingIntent: pendingIntent,
        params: params,
      ));
    });
    _scrollToBottom();
  }

  Future<void> _handleSend(String text) async {
    if (text.trim().isEmpty) return;

    setState(() {
      _messages
          .add(_ChatMessage(text: text, isUser: true, time: DateTime.now()));
      _controller.clear();
    });
    _scrollToBottom();

    // AI Processing
    final response = await _engine.processQuery(text);

    if (mounted) {
      _addSystemMessage(
        response.text,
        pendingIntent: response.pendingIntent,
        params: response.params,
      );
      if (!_isListening) {
        _voice.speak(response.text);
      }
    }
  }

  Future<void> _handleAction(int messageIndex, bool confirm) async {
    final msg = _messages[messageIndex];
    if (msg.pendingIntent == null || msg.params == null) return;

    setState(() {
      msg.isActionTaken = true;
    });

    if (confirm) {
      final result =
          await _engine.executeConfirmedAction(msg.pendingIntent!, msg.params!);
      _addSystemMessage(result);
      _voice.speak(result);
    } else {
      _addSystemMessage("Action cancel kar diya gaya.");
    }
  }

  void _scrollToBottom() {
    Future.delayed(const Duration(milliseconds: 100), () {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  Future<void> _toggleVoice() async {
    if (_voice.isListening) {
      await _voice.stop();
      setState(() => _isListening = false);
    } else {
      setState(() => _isListening = true);
      await _voice.listen(onResult: (text) {
        setState(() => _isListening = false);
        _handleSend(text);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        leading: MainShell.getMenuButton(context),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('BizManager AI',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
            Text('Your private business assistant',
                style: TextStyle(
                    fontSize: 11, color: Colors.white.withOpacity(0.7))),
          ],
        ),
        actions: [
          if (_isVoiceReady && _voice.canUrdu)
            Padding(
              padding: const EdgeInsets.only(right: 8.0),
              child: ChoiceChip(
                label: Text(_voice.isUrduMode ? 'Urdu' : 'English',
                    style: const TextStyle(fontSize: 12)),
                selected: _voice.isUrduMode,
                onSelected: (val) {
                  setState(() {
                    _voice.setLocale(val);
                    _engine =
                        AIEngine(widget.companyId, locale: val ? 'ur' : 'en');
                  });
                },
                selectedColor: Colors.white,
                labelStyle: TextStyle(
                    color: _voice.isUrduMode
                        ? theme.colorScheme.primary
                        : Colors.white),
                backgroundColor: Colors.transparent,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20),
                    side: const BorderSide(color: Colors.white)),
              ),
            ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: _messages.isEmpty
                ? _buildSuggestions()
                : ListView.builder(
                    controller: _scrollController,
                    padding: const EdgeInsets.all(16),
                    itemCount: _messages.length,
                    itemBuilder: (ctx, i) =>
                        _buildMessageBubble(_messages[i], i),
                  ),
          ),
          _buildInputArea(),
        ],
      ),
    );
  }

  Widget _buildSuggestions() {
    final theme = Theme.of(context);
    final suggestions = [
      "Aaj ki sales kitni hain?",
      "Low stock products dikhao",
      "Kitna udhaar lena hai?",
      "Add expense of 500",
      "Total kitne products hain?",
    ];

    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.auto_awesome, size: 64, color: Color(0xFF2563EB)),
            const SizedBox(height: 16),
            const Text(
              'Aap ye pooch sakte hain:',
              style: TextStyle(fontWeight: FontWeight.bold, color: Colors.grey),
            ),
            const SizedBox(height: 16),
            ...suggestions.map((s) => Padding(
                  padding: const EdgeInsets.only(bottom: 8.0),
                  child: ActionChip(
                    label: Text(s),
                    onPressed: () => _handleSend(s),
                    backgroundColor:
                        theme.colorScheme.primary.withOpacity(0.05),
                  ),
                )),
          ],
        ),
      ),
    );
  }

  Widget _buildMessageBubble(_ChatMessage msg, int index) {
    return Align(
      alignment: msg.isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: Column(
        crossAxisAlignment:
            msg.isUser ? CrossAxisAlignment.end : CrossAxisAlignment.start,
        children: [
          Container(
            margin: const EdgeInsets.only(bottom: 4),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            constraints: BoxConstraints(
                maxWidth: MediaQuery.of(context).size.width * 0.75),
            decoration: BoxDecoration(
              color:
                  msg.isUser ? const Color(0xFF2563EB) : Colors.grey.shade200,
              borderRadius: BorderRadius.only(
                topLeft: const Radius.circular(16),
                topRight: const Radius.circular(16),
                bottomLeft: Radius.circular(msg.isUser ? 16 : 0),
                bottomRight: Radius.circular(msg.isUser ? 0 : 16),
              ),
            ),
            child: Text(
              msg.text,
              style: TextStyle(
                color: msg.isUser ? Colors.white : Colors.black87,
                fontSize: 14,
              ),
            ),
          ),
          if (!msg.isUser && msg.pendingIntent != null && !msg.isActionTaken)
            Padding(
              padding: const EdgeInsets.only(bottom: 12.0, left: 4),
              child: Row(
                children: [
                  ElevatedButton(
                    onPressed: () => _handleAction(index, true),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green,
                      foregroundColor: Colors.white,
                      visualDensity: VisualDensity.compact,
                    ),
                    child: const Text('Haan (Confirm)'),
                  ),
                  const SizedBox(width: 8),
                  OutlinedButton(
                    onPressed: () => _handleAction(index, false),
                    style: OutlinedButton.styleFrom(
                      visualDensity: VisualDensity.compact,
                    ),
                    child: const Text('Nahi (Cancel)'),
                  ),
                ],
              ),
            )
          else
            const SizedBox(height: 8),
        ],
      ),
    );
  }

  Widget _buildInputArea() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 10,
              offset: const Offset(0, -2)),
        ],
      ),
      child: SafeArea(
        child: Row(
          children: [
            IconButton(
              icon: Icon(_isListening ? Icons.mic : Icons.mic_none,
                  color: _isListening ? Colors.red : const Color(0xFF2563EB)),
              onPressed: _toggleVoice,
            ),
            Expanded(
              child: TextField(
                controller: _controller,
                decoration: const InputDecoration(
                  hintText: 'Yahan likhein...',
                  border: InputBorder.none,
                  filled: false,
                ),
                onSubmitted: _handleSend,
              ),
            ),
            IconButton(
              icon: const Icon(Icons.send, color: Color(0xFF2563EB)),
              onPressed: () => _handleSend(_controller.text),
            ),
          ],
        ),
      ),
    );
  }
}
