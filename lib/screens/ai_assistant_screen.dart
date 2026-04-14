// lib/screens/ai_assistant_screen.dart

import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import '../utils/app_data.dart';
import '../utils/auth_provider.dart';
import '../utils/theme.dart';
import '../models/models.dart';

// ─────────────────────────────────────────────
// MESSAGE MODEL
// ─────────────────────────────────────────────
class ChatMessage {
  final String text;
  final bool isUser;
  final DateTime timestamp;
  final bool isLoading;

  ChatMessage({
    required this.text,
    required this.isUser,
    required this.timestamp,
    this.isLoading = false,
  });
}

// ─────────────────────────────────────────────
// AI ASSISTANT SCREEN
// ─────────────────────────────────────────────
class AiAssistantScreen extends StatefulWidget {
  const AiAssistantScreen({super.key});

  @override
  State<AiAssistantScreen> createState() => _AiAssistantScreenState();
}

class _AiAssistantScreenState extends State<AiAssistantScreen> {
  final _msgCtrl = TextEditingController();
  final _scrollCtrl = ScrollController();
  final List<ChatMessage> _messages = [];
  bool _isSending = false;

  // ── Gemini API — paste your key here ─────────
  // Free key at: https://aistudio.google.com/app/apikey
  // WORKING model: gemini-2.0-flash (NOT gemini-1.5-flash on v1beta)
  static const String _apiKey = 'AIzaSyBlB_AKdeYfw_uGHsx2lRDmvr6xKP8M9C8';
  static const String _model  = 'gemini-2.0-flash';
  static String get _url =>
      'https://generativelanguage.googleapis.com/v1beta/models/$_model:generateContent?key=$_apiKey';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _sendAutoReminder());
  }

  @override
  void dispose() {
    _msgCtrl.dispose();
    _scrollCtrl.dispose();
    super.dispose();
  }

  // ── Build system context from live clinic data ─
  String _buildContext(AppData data, AuthProvider auth) {
    final user = auth.currentUser!;
    final now = DateTime.now();
    final expired = data.expiredItems.map((i) =>
        '- ${i.name} (Batch: ${i.batchNumber}, expired ${i.daysUntilExpiry.abs()} days ago)').join('\n');
    final expiring = data.expiringItems.map((i) =>
        '- ${i.name} (Batch: ${i.batchNumber}, expires in ${i.daysUntilExpiry} days on ${i.expiryDate.toIso8601String().split('T')[0]})').join('\n');
    final appts = data.patients.asMap().entries.map((e) =>
        '- ${e.value.name}, Age ${e.value.age}: ${e.value.procedure} — Next visit: ${e.value.nextVisit}').join('\n');
    final totalInv = data.inventory.length;
    final okCount = data.inventory.where((i) => i.status == ExpiryStatus.ok).length;

    return '''
You are DentaBot, the intelligent AI assistant for DentaLogic Dental Clinic Management System.
You are speaking with ${user.displayName} (Role: ${user.roleLabel}).
Today's date: ${now.year}-${now.month.toString().padLeft(2,'0')}-${now.day.toString().padLeft(2,'0')}.

Your responsibilities:
1. Proactively remind about expired/expiring inventory and suggest action
2. Remind about upcoming patient appointments and preparation needed
3. Answer questions about clinic operations, patients, and inventory
4. Be concise, professional, warm. Use bullet points for lists.
5. Always prioritize safety — expired materials must NEVER be used on patients.

=== LIVE CLINIC DATA ===
INVENTORY ($totalInv items, $okCount OK):
${expired.isNotEmpty ? 'EXPIRED — discard immediately:\n$expired' : 'No expired items.'}
${expiring.isNotEmpty ? '\nEXPIRING SOON (≤30 days):\n$expiring' : '\nNo items expiring soon.'}

PATIENTS / APPOINTMENTS:
$appts
=== END CLINIC DATA ===

Response rules:
- Flag expired items with 🚫, expiring with ⚠️, appointments with 📅
- Keep responses focused and actionable
- If unrelated to dentistry/clinic, gently redirect
''';
  }

  // ── Send a message ─────────────────────────────
  Future<void> _sendMessage(String text, AppData data, AuthProvider auth) async {
    if (text.trim().isEmpty || _isSending) return;

    final userText = text.trim();
    _msgCtrl.clear();

    setState(() {
      _messages.add(ChatMessage(text: userText, isUser: true, timestamp: DateTime.now()));
      _messages.add(ChatMessage(text: '', isUser: false, timestamp: DateTime.now(), isLoading: true));
      _isSending = true;
    });
    _scrollToBottom();

    final reply = await _callGemini(
      '${_buildContext(data, auth)}\n\nUser: $userText',
      data, auth,
    );

    setState(() {
      _messages.removeLast();
      _messages.add(ChatMessage(text: reply, isUser: false, timestamp: DateTime.now()));
      _isSending = false;
    });
    _scrollToBottom();
  }

  // ── Auto morning briefing ──────────────────────
  Future<void> _sendAutoReminder() async {
    final data = context.read<AppData>();
    final auth = context.read<AuthProvider>();

    // Step 1: Show offline briefing immediately — no waiting
    final offlineText = _buildOfflineBriefing(data, auth);
    setState(() {
      _messages.add(ChatMessage(
        text: offlineText,
        isUser: false,
        timestamp: DateTime.now(),
      ));
    });
    _scrollToBottom();

    // Step 2: If API key is set, enhance with AI in background
    if (_apiKey == 'YOUR_GEMINI_API_KEY' || _apiKey.isEmpty) return;

    setState(() {
      _messages.add(ChatMessage(text: '', isUser: false, timestamp: DateTime.now(), isLoading: true));
      _isSending = true;
    });

    final prompt =
        '${_buildContext(data, auth)}\n\nAction: Based on the clinic data above, give me a concise '
        'AI-enhanced daily briefing. Add specific preparation advice for each appointment today, '
        'urgency ranking for inventory issues, and 2-3 actionable recommendations. Keep it brief.';

    final reply = await _callGemini(prompt, data, auth);

    if (mounted) {
      setState(() {
        _messages.removeLast(); // remove loading
        // Only add AI reply if it's not an error
        if (!reply.startsWith('⏳') && !reply.startsWith('🔑')) {
          _messages.add(ChatMessage(
            text: '🤖 AI Enhanced Briefing:\n\n$reply',
            isUser: false,
            timestamp: DateTime.now(),
          ));
        }
        _isSending = false;
      });
      _scrollToBottom();
    }
  }

  // ── Core Gemini API call ───────────────────────
  Future<String> _callGemini(String prompt, AppData data, AuthProvider auth) async {
    try {
      final response = await http.post(
        Uri.parse(_url),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'contents': [
            {
              'parts': [
                {'text': prompt}
              ]
            }
          ],
          'generationConfig': {
            'temperature': 0.7,
            'maxOutputTokens': 1024,
          },
          'safetySettings': [
            {'category': 'HARM_CATEGORY_HARASSMENT', 'threshold': 'BLOCK_NONE'},
            {'category': 'HARM_CATEGORY_HATE_SPEECH', 'threshold': 'BLOCK_NONE'},
            {'category': 'HARM_CATEGORY_SEXUALLY_EXPLICIT', 'threshold': 'BLOCK_NONE'},
            {'category': 'HARM_CATEGORY_DANGEROUS_CONTENT', 'threshold': 'BLOCK_NONE'},
          ],
        }),
      ).timeout(const Duration(seconds: 20));

      if (response.statusCode == 200) {
        final body = jsonDecode(response.body);
        final candidates = body['candidates'] as List?;
        if (candidates != null && candidates.isNotEmpty) {
          final parts = candidates[0]['content']?['parts'] as List?;
          if (parts != null && parts.isNotEmpty) {
            return parts[0]['text'] as String? ?? 'No response from DentaBot.';
          }
        }
        return '⚠️ Empty response from Gemini. Try again.';
      } else {
        final err = jsonDecode(response.body);
        final msg = err['error']?['message'] ?? 'HTTP ${response.statusCode}';
        // Friendly error hints
        if (msg.contains('not found') || msg.contains('not supported')) {
          return '⚠️ Model error: Gemini model "$_model" is not available.\n\nTry changing _model to "gemini-1.5-flash" or "gemini-pro" in ai_assistant_screen.dart\n\nFull error: $msg';
        }
        if (msg.contains('API_KEY') || msg.contains('key') || response.statusCode == 400) {
          return '🔑 Invalid API key. Get a free key at:\nhttps://aistudio.google.com/app/apikey\n\nThen paste it in ai_assistant_screen.dart line 49 → _apiKey';
        }
        if (msg.contains('quota') || msg.contains('RESOURCE_EXHAUSTED') || response.statusCode == 429) {
          return '⏳ Gemini free quota reached for today.\n\nOptions:\n  1. Wait until tomorrow (quota resets daily)\n  2. Upgrade at https://aistudio.google.com\n  3. The offline briefing above still works without internet.\n\nError: $msg';
        }
        return '⚠️ Gemini error (${response.statusCode}): $msg';
      }
    } catch (e) {
      // Fallback to offline briefing on network error
      return _buildOfflineBriefing(context.read<AppData>(), context.read<AuthProvider>());
    }
  }

  // ── Offline fallback ───────────────────────────
  String _buildOfflineBriefing(AppData data, AuthProvider auth) {
    final user = auth.currentUser!;
    final buf = StringBuffer();
    buf.writeln('Good morning, ${user.displayName}! 👋 (Offline mode — no internet)\n');

    final expired = data.expiredItems;
    final expiring = data.expiringItems;

    if (expired.isNotEmpty) {
      buf.writeln('🚫 EXPIRED — Discard Immediately:');
      for (final i in expired) {
        buf.writeln('  • ${i.name} (${i.batchNumber}) — expired ${i.daysUntilExpiry.abs()} day(s) ago');
      }
      buf.writeln();
    }
    if (expiring.isNotEmpty) {
      buf.writeln('⚠️ Expiring Soon (≤30 days):');
      for (final i in expiring) {
        buf.writeln('  • ${i.name} — ${i.expiryLabel}');
      }
      buf.writeln();
    }
    if (expired.isEmpty && expiring.isEmpty) {
      buf.writeln('✅ All inventory is within safe expiration windows.\n');
    }

    buf.writeln('📅 Today\'s Appointments:');
    final times = ['9:00 AM', '10:30 AM', '2:00 PM', '4:00 PM'];
    for (int i = 0; i < data.patients.length && i < 4; i++) {
      buf.writeln('  • ${times[i]} — ${data.patients[i].name} (${data.patients[i].procedure})');
    }
    return buf.toString();
  }

  void _scrollToBottom() {
    Future.delayed(const Duration(milliseconds: 120), () {
      if (_scrollCtrl.hasClients) {
        _scrollCtrl.animateTo(
          _scrollCtrl.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final data = context.watch<AppData>();
    final auth = context.watch<AuthProvider>();

    return Scaffold(
      backgroundColor: AppTheme.shellTop,
      appBar: AppBar(
        title: Row(
          children: [
            Container(
              width: 32, height: 32,
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.2),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Center(child: Text('🤖', style: TextStyle(fontSize: 16))),
            ),
            const SizedBox(width: 10),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('DentaBot', style: GoogleFonts.dmSans(
                    fontSize: 16, fontWeight: FontWeight.w700, color: Colors.white)),
                Text('Gemini 2.0 Flash', style: GoogleFonts.dmSans(
                    fontSize: 10, color: Colors.white.withOpacity(0.7))),
              ],
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded, color: Colors.white),
            tooltip: 'New briefing',
            onPressed: _isSending ? null : () {
              setState(() => _messages.clear());
              _sendAutoReminder();
            },
          ),
        ],
      ),
      body: Container(
        decoration: const BoxDecoration(gradient: AppTheme.appBackground),
        child: Column(
        children: [
          _QuickActionsBar(
            onTap: (p) => _sendMessage(p, data, auth),
            enabled: !_isSending,
          ),
          Expanded(
            child: _messages.isEmpty
                ? const _EmptyState()
                : ListView.builder(
                    controller: _scrollCtrl,
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
                    itemCount: _messages.length,
                    itemBuilder: (_, i) => _MessageBubble(
                      message: _messages[i],
                      userName: auth.currentUser?.displayName ?? 'You',
                    ),
                  ),
          ),
          _ChatInputBar(
            controller: _msgCtrl,
            isSending: _isSending,
            onSend: () => _sendMessage(_msgCtrl.text, data, auth),
          ),
        ],
      ),
      ),
    );
  }
}

// ─────────────────────────────────────────────
// QUICK ACTIONS BAR
// ─────────────────────────────────────────────
class _QuickActionsBar extends StatelessWidget {
  final void Function(String) onTap;
  final bool enabled;
  const _QuickActionsBar({required this.onTap, required this.enabled});

  @override
  Widget build(BuildContext context) {
    final prompts = [
      ('📦 Inventory Check', 'List all expired or expiring inventory items and tell me what action to take for each.'),
      ('📅 Today\'s Appts', 'List today\'s appointments with times and what materials/preparation is needed per procedure.'),
      ('⚠️ Urgent Alerts', 'What are the most urgent issues I need to address right now in the clinic?'),
      ('🔁 Reorder List', 'Which items should I reorder today? Give a prioritized list.'),
      ('🧹 Safety Check', 'Do a full safety check — are there any expired materials that could harm patients?'),
    ];

    return Container(
      height: 44,
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Colors.white, Color(0xFFF3F8FF)],
        ),
        border: Border(bottom: BorderSide(color: Colors.grey[200]!)),
      ),
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        itemCount: prompts.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (_, i) => GestureDetector(
          onTap: enabled ? () => onTap(prompts[i].$2) : null,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
            decoration: BoxDecoration(
              color: enabled ? AppTheme.primaryContainer : Colors.grey[100],
              borderRadius: BorderRadius.circular(100),
              border: Border.all(
                color: enabled ? AppTheme.primary.withOpacity(0.3) : Colors.grey[300]!,
              ),
            ),
            child: Text(
              prompts[i].$1,
              style: GoogleFonts.dmSans(
                fontSize: 12, fontWeight: FontWeight.w600,
                color: enabled ? AppTheme.onPrimaryContainer : Colors.grey[400],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────
// MESSAGE BUBBLE
// ─────────────────────────────────────────────
class _MessageBubble extends StatelessWidget {
  final ChatMessage message;
  final String userName;
  const _MessageBubble({required this.message, required this.userName});

  @override
  Widget build(BuildContext context) {
    if (message.isLoading) {
      return Align(
        alignment: Alignment.centerLeft,
        child: Container(
          margin: const EdgeInsets.only(bottom: 12, right: 60),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          decoration: AppTheme.glassCard(
            radius: const BorderRadius.only(
              topLeft: Radius.circular(4), topRight: Radius.circular(16),
              bottomLeft: Radius.circular(16), bottomRight: Radius.circular(16),
            ),
            tint: Colors.white,
          ).copyWith(
            borderRadius: const BorderRadius.only(
              topLeft: Radius.circular(4), topRight: Radius.circular(16),
              bottomLeft: Radius.circular(16), bottomRight: Radius.circular(16),
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('🤖', style: TextStyle(fontSize: 14)),
              const SizedBox(width: 8),
              _TypingIndicator(),
            ],
          ),
        ),
      );
    }

    final isUser = message.isUser;
    return Align(
      alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: EdgeInsets.only(bottom: 12, left: isUser ? 52 : 0, right: isUser ? 0 : 52),
        child: Column(
          crossAxisAlignment: isUser ? CrossAxisAlignment.end : CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.only(bottom: 4, left: 4, right: 4),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (!isUser) ...[
                    const Text('🤖', style: TextStyle(fontSize: 12)),
                    const SizedBox(width: 4),
                  ],
                  Text(
                    isUser ? userName : 'DentaBot',
                    style: GoogleFonts.dmSans(fontSize: 11, fontWeight: FontWeight.w600, color: Colors.grey[500]),
                  ),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                gradient: isUser
                    ? const LinearGradient(
                        colors: [Color(0xFF2A8CFF), AppTheme.primary],
                      )
                    : const LinearGradient(
                        colors: [Colors.white, Color(0xFFF4F8FF)],
                      ),
                borderRadius: BorderRadius.only(
                  topLeft: Radius.circular(isUser ? 16 : 4),
                  topRight: Radius.circular(isUser ? 4 : 16),
                  bottomLeft: const Radius.circular(16),
                  bottomRight: const Radius.circular(16),
                ),
                boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.06), blurRadius: 6, offset: const Offset(0, 2))],
              ),
              child: Text(
                message.text,
                style: GoogleFonts.dmSans(
                  fontSize: 14,
                  color: isUser ? Colors.white : const Color(0xFF1A1A2E),
                  height: 1.55,
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.only(top: 3, left: 4, right: 4),
              child: Text(_formatTime(message.timestamp),
                  style: GoogleFonts.dmSans(fontSize: 10, color: Colors.grey[400])),
            ),
          ],
        ),
      ),
    );
  }

  String _formatTime(DateTime dt) {
    final h = dt.hour > 12 ? dt.hour - 12 : dt.hour == 0 ? 12 : dt.hour;
    final m = dt.minute.toString().padLeft(2, '0');
    final ampm = dt.hour >= 12 ? 'PM' : 'AM';
    return '$h:$m $ampm';
  }
}

// ─────────────────────────────────────────────
// TYPING INDICATOR
// ─────────────────────────────────────────────
class _TypingIndicator extends StatefulWidget {
  @override
  State<_TypingIndicator> createState() => _TypingIndicatorState();
}

class _TypingIndicatorState extends State<_TypingIndicator>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 1200))..repeat();
  }

  @override
  void dispose() { _ctrl.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _ctrl,
      builder: (_, __) => Row(
        mainAxisSize: MainAxisSize.min,
        children: List.generate(3, (i) {
          final t = (_ctrl.value - i * 0.33).clamp(0.0, 1.0);
          final opacity = (t < 0.5 ? t * 2 : (1 - t) * 2).clamp(0.3, 1.0);
          return Container(
            margin: const EdgeInsets.symmetric(horizontal: 2),
            width: 7, height: 7,
            decoration: BoxDecoration(
              color: Colors.grey[400]!.withOpacity(opacity),
              shape: BoxShape.circle,
            ),
          );
        }),
      ),
    );
  }
}

// ─────────────────────────────────────────────
// CHAT INPUT BAR
// ─────────────────────────────────────────────
class _ChatInputBar extends StatelessWidget {
  final TextEditingController controller;
  final bool isSending;
  final VoidCallback onSend;
  const _ChatInputBar({required this.controller, required this.isSending, required this.onSend});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.fromLTRB(12, 8, 12, MediaQuery.of(context).padding.bottom + 8),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Colors.white, Color(0xFFF4F8FF)],
        ),
        border: Border(top: BorderSide(color: Colors.grey[200]!)),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 8, offset: const Offset(0, -2))],
      ),
      child: Row(
        children: [
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFFF3F6FB), Color(0xFFEFF4FC)],
                ),
                borderRadius: BorderRadius.circular(24),
              ),
              child: TextField(
                controller: controller,
                maxLines: 3, minLines: 1,
                onSubmitted: isSending ? null : (_) => onSend(),
                decoration: InputDecoration(
                  hintText: 'Ask about inventory, appointments…',
                  hintStyle: GoogleFonts.dmSans(fontSize: 14, color: Colors.grey[400]),
                  border: InputBorder.none,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                ),
                style: GoogleFonts.dmSans(fontSize: 14),
              ),
            ),
          ),
          const SizedBox(width: 8),
          GestureDetector(
            onTap: isSending ? null : onSend,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              width: 44, height: 44,
              decoration: BoxDecoration(
                color: isSending ? Colors.grey[300] : AppTheme.primary,
                shape: BoxShape.circle,
              ),
              child: Icon(
                isSending ? Icons.hourglass_top_rounded : Icons.send_rounded,
                color: isSending ? Colors.grey[500] : Colors.white,
                size: 20,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────
// EMPTY STATE
// ─────────────────────────────────────────────
class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Text('🤖', style: TextStyle(fontSize: 56)),
          const SizedBox(height: 16),
          Text('DentaBot', style: GoogleFonts.dmSans(fontSize: 22, fontWeight: FontWeight.w700)),
          const SizedBox(height: 8),
          Text('Loading your daily briefing…', style: GoogleFonts.dmSans(fontSize: 14, color: Colors.grey[500])),
          const SizedBox(height: 16),
          const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 2)),
        ],
      ),
    );
  }
}
