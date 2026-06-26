import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:provider/provider.dart';

import '../../core/localization/app_localizations.dart';
import '../../core/providers/theme_provider.dart';
import '../../core/providers/user_provider.dart';
import '../../core/services/ai/ai_chat_service.dart';

class AIChatScreen extends StatefulWidget {
  /// Optional message auto-sent when the screen opens (from voice transcript).
  final String? initialMessage;

  const AIChatScreen({super.key, this.initialMessage});

  @override
  State<AIChatScreen> createState() => _AIChatScreenState();
}

class _AIChatScreenState extends State<AIChatScreen> {
  final AIChatService _chatService = AIChatService();
  final TextEditingController _inputController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final List<AIChatMessage> _messages = [];
  bool _isTyping = false;

  @override
  void initState() {
    super.initState();
    final initial = widget.initialMessage;
    if (initial != null && initial.isNotEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _sendMessage(initial));
    }
  }

  @override
  void dispose() {
    _inputController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  Future<void> _sendMessage(String text) async {
    final trimmed = text.trim();
    if (trimmed.isEmpty || _isTyping) return;

    final user = context.read<UserProvider>().user;
    if (user == null) return;

    _inputController.clear();

    setState(() {
      _messages.add(AIChatMessage(role: 'user', content: trimmed));
      _isTyping = true;
    });
    _scrollToBottom();

    try {
      final reply = await _chatService.sendMessage(
        user: user,
        history: List.from(_messages),
        userMessage: trimmed,
      );
      if (!mounted) return;
      setState(() {
        _messages.add(AIChatMessage(role: 'assistant', content: reply));
        _isTyping = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _messages.add(AIChatMessage(
          role: 'assistant',
          content: 'Sorry, something went wrong. Please try again.',
        ));
        _isTyping = false;
      });
    }
    _scrollToBottom();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primary = context.watch<ThemeProvider>().primaryColor;

    return Scaffold(
      backgroundColor:
          isDark ? const Color(0xFF0D1117) : const Color(0xFFF5F5F5),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios_new,
              size: 20.sp,
              color: isDark ? Colors.white : const Color(0xFF2E3A59)),
          onPressed: () => Navigator.pop(context),
        ),
        title: Row(
          children: [
            CircleAvatar(
              radius: 16.r,
              backgroundColor: primary.withValues(alpha: 0.15),
              child: Icon(Icons.smart_toy_outlined, size: 18.sp, color: primary),
            ),
            SizedBox(width: 10.w),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  l10n.translate('ai_chat.title'),
                  style: TextStyle(
                    fontSize: 15.sp,
                    fontWeight: FontWeight.bold,
                    color: isDark ? Colors.white : const Color(0xFF2E3A59),
                  ),
                ),
                Text(
                  l10n.translate('ai_chat.subtitle'),
                  style: TextStyle(
                    fontSize: 11.sp,
                    color: isDark
                        ? Colors.white54
                        : const Color(0xFF2E3A59).withAlpha(140),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
      body: Column(
        children: [
          Expanded(
            child: _messages.isEmpty
                ? _buildEmptyState(l10n, isDark, primary)
                : _buildMessageList(isDark, primary),
          ),
          if (_isTyping) _buildTypingIndicator(l10n, isDark, primary),
          _buildInputBar(l10n, isDark, primary),
        ],
      ),
    );
  }

  Widget _buildEmptyState(
      AppLocalizations l10n, bool isDark, Color primary) {
    final suggestions = l10n.translateArray('ai_chat.suggestions');
    return ListView(
      padding: EdgeInsets.symmetric(horizontal: 20.w, vertical: 24.h),
      children: [
        Center(
          child: Container(
            width: 80.w,
            height: 80.w,
            decoration: BoxDecoration(
              color: primary.withValues(alpha: 0.12),
              shape: BoxShape.circle,
            ),
            child: Icon(Icons.smart_toy_outlined, size: 40.sp, color: primary),
          ),
        ),
        SizedBox(height: 16.h),
        Text(
          l10n.translate('ai_chat.title'),
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 20.sp,
            fontWeight: FontWeight.bold,
            color: isDark ? Colors.white : const Color(0xFF2E3A59),
          ),
        ),
        SizedBox(height: 8.h),
        Text(
          l10n.translate('ai_chat.subtitle'),
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 13.sp,
            color: isDark
                ? Colors.white54
                : const Color(0xFF2E3A59).withAlpha(140),
          ),
        ),
        SizedBox(height: 32.h),
        ...suggestions.map(
          (s) => Padding(
            padding: EdgeInsets.only(bottom: 10.h),
            child: GestureDetector(
              onTap: () => _sendMessage(s),
              child: Container(
                padding:
                    EdgeInsets.symmetric(horizontal: 16.w, vertical: 12.h),
                decoration: BoxDecoration(
                  color: isDark
                      ? const Color(0xFF1C2333)
                      : Colors.white,
                  borderRadius: BorderRadius.circular(14.r),
                  border: Border.all(
                    color: primary.withValues(alpha: 0.25),
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.04),
                      blurRadius: 8,
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    Icon(Icons.lightbulb_outline,
                        size: 16.sp, color: primary),
                    SizedBox(width: 10.w),
                    Expanded(
                      child: Text(
                        s,
                        style: TextStyle(
                          fontSize: 13.sp,
                          color:
                              isDark ? Colors.white : const Color(0xFF2E3A59),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildMessageList(bool isDark, Color primary) {
    return ListView.builder(
      controller: _scrollController,
      padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 16.h),
      itemCount: _messages.length,
      itemBuilder: (context, i) {
        final msg = _messages[i];
        return _buildBubble(msg, isDark, primary);
      },
    );
  }

  Widget _buildBubble(AIChatMessage msg, bool isDark, Color primary) {
    final isUser = msg.role == 'user';
    return Padding(
      padding: EdgeInsets.only(bottom: 12.h),
      child: Row(
        mainAxisAlignment:
            isUser ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          if (!isUser) ...[
            CircleAvatar(
              radius: 14.r,
              backgroundColor: primary.withValues(alpha: 0.15),
              child:
                  Icon(Icons.smart_toy_outlined, size: 15.sp, color: primary),
            ),
            SizedBox(width: 8.w),
          ],
          Flexible(
            child: Container(
              constraints: BoxConstraints(maxWidth: 0.72.sw),
              padding:
                  EdgeInsets.symmetric(horizontal: 14.w, vertical: 10.h),
              decoration: BoxDecoration(
                color: isUser
                    ? primary
                    : (isDark ? const Color(0xFF1C2333) : Colors.white),
                borderRadius: BorderRadius.only(
                  topLeft: Radius.circular(16.r),
                  topRight: Radius.circular(16.r),
                  bottomLeft: Radius.circular(isUser ? 16.r : 4.r),
                  bottomRight: Radius.circular(isUser ? 4.r : 16.r),
                ),
                boxShadow: [
                  BoxShadow(
                    color:
                        Colors.black.withValues(alpha: isDark ? 0.3 : 0.06),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Text(
                msg.content,
                style: TextStyle(
                  fontSize: 14.sp,
                  color: isUser
                      ? Colors.white
                      : (isDark ? Colors.white : const Color(0xFF2E3A59)),
                  height: 1.45,
                ),
              ),
            ),
          ),
          if (isUser) SizedBox(width: 8.w),
        ],
      ),
    );
  }

  Widget _buildTypingIndicator(
      AppLocalizations l10n, bool isDark, Color primary) {
    return Padding(
      padding: EdgeInsets.fromLTRB(16.w, 0, 16.w, 4.h),
      child: Row(
        children: [
          CircleAvatar(
            radius: 14.r,
            backgroundColor: primary.withValues(alpha: 0.15),
            child: Icon(Icons.smart_toy_outlined, size: 15.sp, color: primary),
          ),
          SizedBox(width: 8.w),
          Container(
            padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 10.h),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF1C2333) : Colors.white,
              borderRadius: BorderRadius.circular(16.r),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                _DotIndicator(color: primary, delay: 0),
                SizedBox(width: 4.w),
                _DotIndicator(color: primary, delay: 200),
                SizedBox(width: 4.w),
                _DotIndicator(color: primary, delay: 400),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInputBar(
      AppLocalizations l10n, bool isDark, Color primary) {
    return SafeArea(
      child: Container(
        color: isDark ? const Color(0xFF0D1117) : const Color(0xFFF5F5F5),
        padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 10.h),
        child: Row(
          children: [
            Expanded(
              child: Container(
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF1C2333) : Colors.white,
                  borderRadius: BorderRadius.circular(24.r),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: isDark ? 0.3 : 0.06),
                      blurRadius: 8,
                    ),
                  ],
                ),
                child: TextField(
                  controller: _inputController,
                  style: TextStyle(
                    fontSize: 14.sp,
                    color: isDark ? Colors.white : const Color(0xFF2E3A59),
                  ),
                  decoration: InputDecoration(
                    hintText: l10n.translate('ai_chat.input_hint'),
                    hintStyle: TextStyle(
                      fontSize: 13.sp,
                      color: isDark
                          ? Colors.white38
                          : const Color(0xFF2E3A59).withAlpha(100),
                    ),
                    border: InputBorder.none,
                    contentPadding: EdgeInsets.symmetric(
                        horizontal: 16.w, vertical: 12.h),
                  ),
                  maxLines: 4,
                  minLines: 1,
                  textInputAction: TextInputAction.send,
                  onSubmitted: _sendMessage,
                ),
              ),
            ),
            SizedBox(width: 10.w),
            GestureDetector(
              onTap: () => _sendMessage(_inputController.text),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                width: 46.w,
                height: 46.w,
                decoration: BoxDecoration(
                  color: _isTyping ? primary.withValues(alpha: 0.5) : primary,
                  shape: BoxShape.circle,
                ),
                child: Icon(Icons.send_rounded,
                    color: Colors.white, size: 20.sp),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DotIndicator extends StatefulWidget {
  final Color color;
  final int delay;

  const _DotIndicator({required this.color, required this.delay});

  @override
  State<_DotIndicator> createState() => _DotIndicatorState();
}

class _DotIndicatorState extends State<_DotIndicator>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _anim;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _anim = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut),
    );
    Future.delayed(Duration(milliseconds: widget.delay), () {
      if (mounted) _ctrl.repeat(reverse: true);
    });
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _anim,
      builder: (_, __) => Opacity(
        opacity: 0.3 + _anim.value * 0.7,
        child: Container(
          width: 7,
          height: 7,
          decoration:
              BoxDecoration(color: widget.color, shape: BoxShape.circle),
        ),
      ),
    );
  }
}
