import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:provider/provider.dart';

import '../../core/localization/app_localizations.dart';
import '../../core/providers/navigation_provider.dart';
import '../../core/providers/theme_provider.dart';
import '../../core/providers/user_provider.dart';
import '../../core/services/ai/ai_chat_history_service.dart';
import '../../core/services/ai/ai_chat_service.dart';
import '../../core/services/ai_credit_service.dart';
import '../../core/services/feature_gate_service.dart';
import '../../core/theme/app_palette.dart';
import '../../core/theme/app_typography.dart';
import '../../core/widgets/ds/app_snackbar.dart';
import '../ai/widgets/ai_credit_badge.dart';

class AIChatScreen extends StatefulWidget {
  /// Optional message auto-sent when the screen opens (from voice transcript).
  final String? initialMessage;

  const AIChatScreen({super.key, this.initialMessage});

  @override
  State<AIChatScreen> createState() => _AIChatScreenState();
}

class _AIChatScreenState extends State<AIChatScreen> {
  final AIChatService _chatService = AIChatService();
  final AIChatHistoryService _history = AIChatHistoryService();
  final TextEditingController _inputController = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  // Local reference to the singleton list — same object, reactive via setState.
  late final List<AIChatMessage> _messages;

  bool _isTyping = false;

  @override
  void initState() {
    super.initState();
    _messages = _history.messages;
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

    final uid = user.uid;
    final isPremium = user.subscriptionTier.isPremiumOrAbove;

    final canUse = await AiCreditService().checkAndConsume(uid, isPremium);
    if (!canUse) {
      if (!mounted) return;
      AppSnackBar.warning(
        context,
        'AI limit reached. Upgrade to Premium for unlimited access.',
      );
      unawaited(FeatureGateService().showPaywall(context));
      return;
    }

    _inputController.clear();

    final userMsg = AIChatMessage(role: 'user', content: trimmed);
    _history.add(userMsg);
    setState(() => _isTyping = true);
    _scrollToBottom();

    try {
      final reply = await _chatService.sendMessage(
        user: user,
        history: List.from(_messages),
        userMessage: trimmed,
      );
      if (!mounted) return;
      _history.add(AIChatMessage(role: 'assistant', content: reply));
      setState(() => _isTyping = false);
    } catch (e) {
      if (!mounted) return;
      _history.add(const AIChatMessage(
        role: 'assistant',
        content: 'Sorry, something went wrong. Please try again.',
      ));
      setState(() => _isTyping = false);
    }
    _scrollToBottom();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final palette = AppPalette.of(context);
    final appText = AppText.of(context);
    final primary = context.watch<ThemeProvider>().primaryColor;

    return Scaffold(
      backgroundColor: palette.background,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios_new,
              size: 20.sp,
              color: palette.textPrimary),
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
            Flexible(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    l10n.translate('ai_chat.title'),
                    style: appText.titleM.copyWith(
                      fontSize: 15.sp,
                      fontWeight: FontWeight.bold,
                      color: palette.textPrimary,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                  Text(
                    l10n.translate('ai_chat.subtitle'),
                    style: appText.labelS.copyWith(
                      fontSize: 11.sp,
                      color: palette.textTertiary,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          // AI credit usage indicator
          Builder(
            builder: (context) {
              final user = context.read<UserProvider>().user;
              if (user == null) return const SizedBox.shrink();
              return Padding(
                padding: EdgeInsets.only(right: 4.w),
                child: Center(
                  child: AiCreditBadge(
                    uid: user.uid,
                    isPremium: user.subscriptionTier.isPremiumOrAbove,
                  ),
                ),
              );
            },
          ),
          // Switch to voice mode
          GestureDetector(
            onTap: () {
              Navigator.pop(context);
              context.read<NavigationProvider>().toggleVoiceAssistant(true);
            },
            child: Container(
              margin: EdgeInsets.only(right: 16.w),
              padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 6.h),
              decoration: BoxDecoration(
                color: primary.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(20.r),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.mic_rounded, size: 16.sp, color: primary),
                  SizedBox(width: 4.w),
                  Text(
                    l10n.translate('ai_chat.voice_mode'),
                    style: TextStyle(
                      fontFamily: 'Poppins',
                      fontSize: 12.sp,
                      fontWeight: FontWeight.w600,
                      color: primary,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: _messages.isEmpty
                ? _buildEmptyState(l10n, palette, appText, primary)
                : _buildMessageList(palette, primary),
          ),
          if (_isTyping) _buildTypingIndicator(l10n, palette, primary),
          _buildInputBar(l10n, palette, appText, primary),
        ],
      ),
    );
  }

  Widget _buildEmptyState(
      AppLocalizations l10n, AppPalette palette, AppText appText, Color primary) {
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
          style: appText.headlineS.copyWith(
            fontSize: 20.sp,
            fontWeight: FontWeight.bold,
          ),
        ),
        SizedBox(height: 8.h),
        Text(
          l10n.translate('ai_chat.subtitle'),
          textAlign: TextAlign.center,
          style: appText.bodyM.copyWith(
            fontSize: 13.sp,
            color: palette.textSecondary,
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
                  color: palette.surface,
                  borderRadius: BorderRadius.circular(14.r),
                  border: Border.all(
                    color: primary.withValues(alpha: 0.25),
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: palette.shadow.withValues(alpha: 0.06),
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
                        style: appText.bodyM.copyWith(
                          fontSize: 13.sp,
                          color: palette.textPrimary,
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

  Widget _buildMessageList(AppPalette palette, Color primary) {
    return ListView.builder(
      controller: _scrollController,
      padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 16.h),
      itemCount: _messages.length,
      itemBuilder: (context, i) {
        final msg = _messages[i];
        return _buildBubble(msg, palette, primary);
      },
    );
  }

  Widget _buildBubble(AIChatMessage msg, AppPalette palette, Color primary) {
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
                color: isUser ? primary : palette.surfaceVariant,
                borderRadius: BorderRadius.only(
                  topLeft: Radius.circular(16.r),
                  topRight: Radius.circular(16.r),
                  bottomLeft: Radius.circular(isUser ? 16.r : 4.r),
                  bottomRight: Radius.circular(isUser ? 4.r : 16.r),
                ),
                boxShadow: [
                  BoxShadow(
                    color: palette.shadow.withValues(alpha: 0.08),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Text(
                msg.content,
                style: TextStyle(
                  fontFamily: 'Poppins',
                  fontSize: 14.sp,
                  color: isUser ? Colors.white : palette.textPrimary,
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
      AppLocalizations l10n, AppPalette palette, Color primary) {
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
              color: palette.surfaceVariant,
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
      AppLocalizations l10n, AppPalette palette, AppText appText, Color primary) {
    return SafeArea(
      child: Container(
        color: palette.background,
        padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 10.h),
        child: Row(
          children: [
            Expanded(
              child: Container(
                decoration: BoxDecoration(
                  color: palette.surface,
                  borderRadius: BorderRadius.circular(24.r),
                  boxShadow: [
                    BoxShadow(
                      color: palette.shadow.withValues(alpha: 0.06),
                      blurRadius: 8,
                    ),
                  ],
                ),
                child: TextField(
                  controller: _inputController,
                  style: appText.bodyM.copyWith(
                    fontSize: 14.sp,
                    color: palette.textPrimary,
                  ),
                  decoration: InputDecoration(
                    hintText: l10n.translate('ai_chat.input_hint'),
                    hintStyle: appText.bodyM.copyWith(
                      fontSize: 13.sp,
                      color: palette.textTertiary,
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
