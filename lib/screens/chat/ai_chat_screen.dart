import 'dart:async';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:provider/provider.dart';

import '../../core/localization/app_localizations.dart';
import '../../core/providers/navigation_provider.dart';
import '../../core/providers/theme_provider.dart';
import '../../core/providers/user_provider.dart';
import '../../core/services/ai/ai_chat_history_service.dart';
import '../../core/services/ai/ai_chat_service.dart';
import '../../core/services/ai/ai_service.dart';
import '../../core/services/ai_credit_service.dart';
import '../../core/widgets/ds/ds.dart';
import '../ai/widgets/ai_credit_badge.dart';
import '../ai/widgets/ai_credits_sheet.dart';

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
      WidgetsBinding.instance
          .addPostFrameCallback((_) => _sendMessage(initial));
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
      setState(() {
        _history.add(const AIChatMessage(
          role: '_limit',
          content: '__limit__',
        ));
      });
      _scrollToBottom();
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
      if (reply.isEmpty) {
        unawaited(AiCreditService().rollbackCredit(uid));
        _history.add(const AIChatMessage(
          role: 'assistant',
          content: 'Sorry, something went wrong. Please try again.',
        ));
      } else {
        _history.add(AIChatMessage(role: 'assistant', content: reply));
      }
      setState(() => _isTyping = false);
    } on AIQuotaExceededException {
      if (!mounted) return;
      setState(() {
        _isTyping = false;
        _history.add(const AIChatMessage(role: '_limit', content: '__limit__'));
      });
      unawaited(AiCreditsSheet.show(context, uid: uid, isPremium: isPremium));
    } catch (e) {
      unawaited(AiCreditService().rollbackCredit(uid));
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
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: palette.background,
      extendBodyBehindAppBar: true,
      // ── Glassmorphism v2 AppBar ──
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(kToolbarHeight),
        child: ClipRRect(
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
            child: Container(
              decoration: BoxDecoration(
                color: palette.surface.withValues(alpha: 0.80),
                border: Border(
                  bottom: BorderSide(color: palette.glassStroke, width: 0.5),
                ),
              ),
              child: Stack(
                children: [
                  // 2px brand→sunsetA gradient accent line at bottom
                  Positioned(
                    left: 0,
                    right: 0,
                    bottom: 0,
                    child: Container(
                      height: 2,
                      decoration: BoxDecoration(
                        gradient: AppGradients.brand(theme.primaryColor),
                      ),
                    ),
                  ),
                  AppBar(
                    backgroundColor: Colors.transparent,
                    elevation: 0,
                    leading: IconButton(
                      icon: Icon(Icons.arrow_back_ios_new,
                          size: 20.sp, color: palette.textPrimary),
                      onPressed: () => Navigator.pop(context),
                    ),
                    title: Row(
                      children: [
                        // AI avatar with brand glow
                        Container(
                          width: 32.r,
                          height: 32.r,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            gradient: AppGradients.brand(primary),
                            boxShadow: [
                              BoxShadow(
                                color: primary.withValues(alpha: 0.30),
                                blurRadius: 8,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                          child: Icon(Icons.smart_toy_outlined,
                              size: 17.sp, color: Colors.white),
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
                      // AI credit usage indicator — kept as-is with palette tokens
                      Builder(
                        builder: (context) {
                          final user = context.read<UserProvider>().user;
                          if (user == null) return const SizedBox.shrink();
                          return Padding(
                            padding: EdgeInsets.only(right: 4.w),
                            child: Center(
                              child: AiCreditBadge(
                                uid: user.uid,
                                isPremium:
                                    user.subscriptionTier.isPremiumOrAbove,
                              ),
                            ),
                          );
                        },
                      ),
                      // Switch to voice mode
                      GestureDetector(
                        onTap: () {
                          Navigator.pop(context);
                          context
                              .read<NavigationProvider>()
                              .toggleVoiceAssistant(true);
                        },
                        child: Container(
                          margin: EdgeInsets.only(right: 16.w),
                          padding: EdgeInsets.symmetric(
                              horizontal: 12.w, vertical: 6.h),
                          decoration: BoxDecoration(
                            color: primary.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(20.r),
                            border: Border.all(
                              color: primary.withValues(alpha: 0.20),
                              width: 0.5,
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.mic_rounded,
                                  size: 16.sp, color: primary),
                              SizedBox(width: 4.w),
                              Text(
                                l10n.translate('ai_chat.voice_mode'),
                                style: appText.labelM.copyWith(
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
                ],
              ),
            ),
          ),
        ),
      ),
      body: Stack(
        children: [
          // ── Ambient mesh-glow blobs (brand top-right + energy bottom-left) ──
          Positioned(
            top: -60,
            right: -80,
            child: IgnorePointer(
              child: Container(
                width: 280,
                height: 280,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: [
                      AppPalette.brand.withValues(alpha: 0.04),
                      AppPalette.brand.withValues(alpha: 0),
                    ],
                  ),
                ),
              ),
            ),
          ),
          Positioned(
            bottom: 80,
            left: -100,
            child: IgnorePointer(
              child: Container(
                width: 300,
                height: 300,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: [
                      palette.energy.withValues(alpha: 0.03),
                      palette.energy.withValues(alpha: 0),
                    ],
                  ),
                ),
              ),
            ),
          ),

          // ── Main content column ──
          Column(
            children: [
              Expanded(
                child: _messages.isEmpty
                    ? _buildEmptyState(l10n, palette, appText, primary)
                    : _buildMessageList(palette, primary, theme),
              ),
              if (_isTyping) _buildTypingIndicator(l10n, palette, primary),
              _buildInputBar(l10n, palette, appText, primary, theme),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState(AppLocalizations l10n, AppPalette palette,
      AppText appText, Color primary) {
    final suggestions = l10n.translateArray('ai_chat.suggestions');
    return ListView(
      padding: EdgeInsets.fromLTRB(20.w, kToolbarHeight + 24.h, 20.w, 24.h),
      children: [
        Center(
          // Brand gradient circle avatar with glow
          child: Container(
            width: 80.w,
            height: 80.w,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: AppGradients.brand(primary),
              boxShadow: [
                BoxShadow(
                  color: primary.withValues(alpha: 0.30),
                  blurRadius: 20,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Icon(Icons.smart_toy_outlined,
                size: 38.sp, color: Colors.white),
          ),
        ),
        SizedBox(height: 16.h),
        Text(
          l10n.translate('ai_chat.title'),
          textAlign: TextAlign.center,
          style: appText.headlineS.copyWith(
            fontSize: 20.sp,
            fontWeight: FontWeight.bold,
            color: palette.textPrimary,
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
        // Suggested prompt chips — glassFill + glassStroke + brand text
        ...suggestions.map(
          (s) => Padding(
            padding: EdgeInsets.only(bottom: 10.h),
            child: GestureDetector(
              onTap: () => _sendMessage(s),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(14.r),
                child: BackdropFilter(
                  filter: ImageFilter.blur(
                    sigmaX: AppPalette.glassBlurSubtle,
                    sigmaY: AppPalette.glassBlurSubtle,
                  ),
                  child: Container(
                    padding:
                        EdgeInsets.symmetric(horizontal: 16.w, vertical: 12.h),
                    decoration: BoxDecoration(
                      color: palette.glassFill,
                      borderRadius: BorderRadius.circular(14.r),
                      border: Border.all(
                        color: palette.glassStroke,
                        width: 0.5,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: palette.shadow.withValues(alpha: 0.05),
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
                              color: primary,
                            ),
                          ),
                        ),
                        Icon(Icons.arrow_forward_ios_rounded,
                            size: 12.sp,
                            color: primary.withValues(alpha: 0.50)),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildMessageList(AppPalette palette, Color primary, ThemeData theme) {
    final l10n = AppLocalizations.of(context);
    return ListView.builder(
      controller: _scrollController,
      padding: EdgeInsets.fromLTRB(16.w, kToolbarHeight + 16.h, 16.w, 16.h),
      itemCount: _messages.length,
      itemBuilder: (context, i) {
        final msg = _messages[i];
        if (msg.role == '_limit') {
          return _buildLimitBubble(context, l10n, palette, primary, theme);
        }
        return _buildBubble(msg, palette, primary, theme);
      },
    );
  }

  Widget _buildLimitBubble(
    BuildContext context,
    AppLocalizations l10n,
    AppPalette palette,
    Color primary,
    ThemeData theme,
  ) {
    final appText = AppText.of(context);
    final user = context.read<UserProvider>().user;
    return Padding(
      padding: EdgeInsets.only(bottom: 12.h),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          CircleAvatar(
            radius: 14.r,
            backgroundColor: palette.warning.withValues(alpha: 0.15),
            child:
                Icon(Icons.bolt_rounded, size: 15.sp, color: palette.warning),
          ),
          SizedBox(width: 8.w),
          Flexible(
            child: ClipRRect(
              borderRadius: BorderRadius.only(
                topLeft: Radius.circular(16.r),
                topRight: Radius.circular(16.r),
                bottomLeft: Radius.circular(4.r),
                bottomRight: Radius.circular(16.r),
              ),
              child: BackdropFilter(
                filter: ImageFilter.blur(
                  sigmaX: AppPalette.glassBlurSubtle,
                  sigmaY: AppPalette.glassBlurSubtle,
                ),
                child: Container(
                  constraints: BoxConstraints(maxWidth: 0.80.sw),
                  padding:
                      EdgeInsets.symmetric(horizontal: 14.w, vertical: 12.h),
                  decoration: BoxDecoration(
                    color: palette.warning.withValues(alpha: 0.10),
                    borderRadius: BorderRadius.only(
                      topLeft: Radius.circular(16.r),
                      topRight: Radius.circular(16.r),
                      bottomLeft: Radius.circular(4.r),
                      bottomRight: Radius.circular(16.r),
                    ),
                    border: Border.all(
                      color: palette.warning.withValues(alpha: 0.30),
                      width: 0.5,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: palette.shadow.withValues(alpha: 0.06),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        l10n.translate('ai.twin_limit_title'),
                        style: appText.labelL.copyWith(
                          color: palette.warning,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      SizedBox(height: 4.h),
                      Text(
                        l10n.translate('ai.twin_limit_msg'),
                        style: appText.bodyM.copyWith(
                          fontSize: 13.sp,
                          color: palette.textPrimary,
                          height: 1.45,
                        ),
                      ),
                      if (user != null) ...[
                        SizedBox(height: 10.h),
                        GestureDetector(
                          onTap: () => AiCreditsSheet.show(
                            context,
                            uid: user.uid,
                            isPremium: user.subscriptionTier.isPremiumOrAbove,
                          ),
                          child: Container(
                            padding: EdgeInsets.symmetric(
                                horizontal: 12.w, vertical: 6.h),
                            decoration: BoxDecoration(
                              gradient: AppGradients.brand(primary),
                              borderRadius: BorderRadius.circular(20.r),
                              boxShadow: [
                                BoxShadow(
                                  color: primary.withValues(alpha: 0.30),
                                  blurRadius: 6,
                                  offset: const Offset(0, 2),
                                ),
                              ],
                            ),
                            child: Text(
                              l10n.translate('settings.premium.upgrade_btn'),
                              style: appText.labelM.copyWith(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBubble(
      AIChatMessage msg, AppPalette palette, Color primary, ThemeData theme) {
    final isUser = msg.role == 'user';
    final br = BorderRadius.only(
      topLeft: Radius.circular(16.r),
      topRight: Radius.circular(16.r),
      bottomLeft: Radius.circular(isUser ? 16.r : 4.r),
      bottomRight: Radius.circular(isUser ? 4.r : 16.r),
    );

    return Padding(
      padding: EdgeInsets.only(bottom: 12.h),
      child: Row(
        mainAxisAlignment:
            isUser ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          if (!isUser) ...[
            // AI avatar — brand gradient circle
            Container(
              width: 28.r,
              height: 28.r,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: AppGradients.brand(primary),
                boxShadow: [
                  BoxShadow(
                    color: primary.withValues(alpha: 0.25),
                    blurRadius: 6,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Icon(Icons.smart_toy_outlined,
                  size: 14.sp, color: Colors.white),
            ),
            SizedBox(width: 8.w),
          ],
          Flexible(
            child: isUser
                ? _buildSentBubble(msg, br, palette, primary, theme)
                : _buildReceivedBubble(msg, br, palette, primary),
          ),
          if (isUser) SizedBox(width: 8.w),
        ],
      ),
    );
  }

  // Sent bubble: brand gradient + glow shadow
  Widget _buildSentBubble(AIChatMessage msg, BorderRadius br,
      AppPalette palette, Color primary, ThemeData theme) {
    final appText = AppText.of(context);
    return Container(
      constraints: BoxConstraints(maxWidth: 0.72.sw),
      decoration: BoxDecoration(
        gradient: AppGradients.brand(theme.primaryColor),
        borderRadius: br,
        boxShadow: [
          BoxShadow(
            color: theme.primaryColor.withValues(alpha: 0.25),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 10.h),
        child: Text(
          msg.content,
          style: appText.bodyM.copyWith(
            fontSize: 14.sp,
            color: Colors.white,
            height: 1.45,
          ),
        ),
      ),
    );
  }

  Widget _buildReceivedBubble(
      AIChatMessage msg, BorderRadius br, AppPalette palette, Color primary) {
    final appText = AppText.of(context);
    return ClipRRect(
      borderRadius: br,
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
        child: Container(
          constraints: BoxConstraints(maxWidth: 0.72.sw),
          decoration: BoxDecoration(
            color: palette.glassFill,
            borderRadius: br,
            border: Border.all(
              color: palette.glassStroke,
              width: 0.5,
            ),
            boxShadow: [
              BoxShadow(
                color: palette.shadow.withValues(alpha: 0.06),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Stack(
            children: [
              Positioned(
                left: 0,
                top: 0,
                bottom: 0,
                child: Container(
                  width: 2,
                  color: palette.info.withValues(alpha: 0.60),
                ),
              ),
              Padding(
                padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 10.h),
                child: Text(
                  msg.content,
                  style: appText.bodyM.copyWith(
                    fontSize: 14.sp,
                    color: palette.textPrimary,
                    height: 1.45,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // Typing indicator: frosted glass pill with 3-dot animation
  Widget _buildTypingIndicator(
      AppLocalizations l10n, AppPalette palette, Color primary) {
    return Padding(
      padding: EdgeInsets.fromLTRB(16.w, 0, 16.w, 4.h),
      child: Row(
        children: [
          Container(
            width: 28.r,
            height: 28.r,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: AppGradients.brand(primary),
              boxShadow: [
                BoxShadow(
                  color: primary.withValues(alpha: 0.25),
                  blurRadius: 6,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Icon(Icons.smart_toy_outlined,
                size: 14.sp, color: Colors.white),
          ),
          SizedBox(width: 8.w),
          ClipRRect(
            borderRadius: BorderRadius.circular(16.r),
            child: BackdropFilter(
              filter: ImageFilter.blur(
                sigmaX: AppPalette.glassBlurSubtle,
                sigmaY: AppPalette.glassBlurSubtle,
              ),
              child: Container(
                padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 10.h),
                decoration: BoxDecoration(
                  color: palette.glassFill,
                  borderRadius: BorderRadius.circular(16.r),
                  border: Border.all(color: palette.glassStroke, width: 0.5),
                  boxShadow: [
                    BoxShadow(
                      color: palette.shadow.withValues(alpha: 0.05),
                      blurRadius: 4,
                      offset: const Offset(0, 2),
                    ),
                  ],
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
            ),
          ),
        ],
      ),
    );
  }

  // Input bar: ClipRect + BackdropFilter glass + glassStroke top border;
  // send button → brand gradient circle + glow
  Widget _buildInputBar(AppLocalizations l10n, AppPalette palette,
      AppText appText, Color primary, ThemeData theme) {
    return ClipRect(
      child: BackdropFilter(
        filter: ImageFilter.blur(
          sigmaX: AppPalette.glassBlurDefault,
          sigmaY: AppPalette.glassBlurDefault,
        ),
        child: Container(
          padding: EdgeInsets.fromLTRB(
            16.w,
            10.h,
            16.w,
            10.h + MediaQuery.of(context).padding.bottom,
          ),
          decoration: BoxDecoration(
            color: palette.glassFill,
            border: Border(
              top: BorderSide(color: palette.glassStroke, width: 0.5),
            ),
            boxShadow: [
              BoxShadow(
                color: palette.shadow.withValues(alpha: 0.06),
                blurRadius: 12,
                offset: const Offset(0, -4),
              ),
            ],
          ),
          child: Row(
            children: [
              Expanded(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(24.r),
                  child: BackdropFilter(
                    filter: ImageFilter.blur(
                      sigmaX: AppPalette.glassBlurSubtle,
                      sigmaY: AppPalette.glassBlurSubtle,
                    ),
                    child: Container(
                      decoration: BoxDecoration(
                        color: palette.surfaceVariant.withValues(alpha: 0.70),
                        borderRadius: BorderRadius.circular(24.r),
                        border: Border.all(
                          color: palette.glassStroke,
                          width: 0.5,
                        ),
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
                ),
              ),
              SizedBox(width: 10.w),
              // Brand gradient send button with glow
              GestureDetector(
                onTap: () => _sendMessage(_inputController.text),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  width: 46.w,
                  height: 46.w,
                  decoration: BoxDecoration(
                    gradient: _isTyping
                        ? LinearGradient(
                            colors: [
                              AppPalette.sunsetA.withValues(alpha: 0.5),
                              primary.withValues(alpha: 0.5),
                            ],
                          )
                        : AppGradients.brand(theme.primaryColor),
                    shape: BoxShape.circle,
                    boxShadow: _isTyping
                        ? []
                        : [
                            BoxShadow(
                              color: theme.primaryColor.withValues(alpha: 0.35),
                              blurRadius: 8,
                              offset: const Offset(0, 3),
                            ),
                          ],
                  ),
                  child: Icon(Icons.send_rounded,
                      color: Colors.white, size: 20.sp),
                ),
              ),
            ],
          ),
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
