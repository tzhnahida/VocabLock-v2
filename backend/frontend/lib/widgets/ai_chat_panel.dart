import 'package:flutter/material.dart';
import '../providers/app_state.dart';
import '../theme/app_theme.dart';

class AIChatPanel extends StatefulWidget {
  final AppState state;
  const AIChatPanel({super.key, required this.state});

  @override
  State<AIChatPanel> createState() => _AIChatPanelState();
}

class _AIChatPanelState extends State<AIChatPanel> {
  final _msgCtrl = TextEditingController();
  final _scrollCtrl = ScrollController();
  final List<({String role, String content})> _messages = [];
  bool _sending = false;

  Future<void> _send() async {
    final text = _msgCtrl.text.trim();
    if (text.isEmpty) return;
    setState(() {
      _messages.add((role: 'user', content: text));
      _sending = true;
    });
    _msgCtrl.clear();

    final aiApi = widget.state.aiApi;
    if (aiApi != null) {
      try {
        final result = await aiApi.chat(text);
        if (mounted) {
          setState(() {
            _messages.add((role: 'assistant', content: result['reply'] ?? '(no response)'));
            _sending = false;
          });
        }
      } catch (_) {
        if (mounted) {
          setState(() {
            _messages.add((role: 'assistant', content: 'Sorry, AI is not available right now.'));
            _sending = false;
          });
        }
      }
    } else {
      setState(() {
        _messages.add((role: 'assistant', content: 'AI chat is not configured. Start the Go backend without --mock to enable it.'));
        _sending = false;
      });
    }

    Future.delayed(const Duration(milliseconds: 100), () {
      if (_scrollCtrl.hasClients) {
        _scrollCtrl.animateTo(_scrollCtrl.position.maxScrollExtent, duration: const Duration(milliseconds: 300), curve: Curves.easeOut);
      }
    });
  }

  @override
  void dispose() {
    _msgCtrl.dispose();
    _scrollCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(28),
      child: Column(
        children: [
          Row(
            children: [
              Text('AI Chat', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w700, color: AppTheme.textPrimary)),
            ],
          ),
          const SizedBox(height: 16),
          Expanded(
            child: _messages.isEmpty
                ? Center(
                    child: Text('Ask me anything about your vocabulary!', style: TextStyle(color: AppTheme.textHint, fontSize: 15)),
                  )
                : ListView.builder(
                    controller: _scrollCtrl,
                    itemCount: _messages.length,
                    itemBuilder: (_, i) {
                      final msg = _messages[i];
                      final isUser = msg.role == 'user';
                      return Align(
                        alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
                        child: Container(
                          margin: const EdgeInsets.only(bottom: 10),
                          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
                          constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.55),
                          decoration: BoxDecoration(
                            color: isUser ? AppTheme.primary : Colors.white,
                            borderRadius: BorderRadius.only(
                              topLeft: const Radius.circular(16),
                              topRight: const Radius.circular(16),
                              bottomLeft: isUser ? const Radius.circular(16) : Radius.zero,
                              bottomRight: isUser ? Radius.zero : const Radius.circular(16),
                            ),
                          ),
                          child: Text(
                            msg.content,
                            style: TextStyle(fontSize: 14, color: isUser ? Colors.white : AppTheme.textPrimary, height: 1.4),
                          ),
                        ),
                      );
                    },
                  ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _msgCtrl,
                  onSubmitted: (_) => _send(),
                  decoration: InputDecoration(
                    hintText: 'Type a message...',
                    filled: true,
                    fillColor: AppTheme.cardBg,
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              _sending
                  ? const SizedBox(width: 44, height: 44, child: Padding(padding: EdgeInsets.all(10), child: CircularProgressIndicator(strokeWidth: 2)))
                  : GestureDetector(
                      onTap: _send,
                      child: Container(
                        width: 44,
                        height: 44,
                        decoration: BoxDecoration(
                          color: AppTheme.primary,
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: const Icon(Icons.send, color: Colors.white, size: 20),
                      ),
                    ),
            ],
          ),
        ],
      ),
    );
  }
}
