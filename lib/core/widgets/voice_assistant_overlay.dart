import 'dart:async';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;
import '../services/navigation_provider.dart';
import '../localization/app_localizations.dart';
import '../providers/theme_provider.dart';

class VoiceAssistantOverlay extends StatefulWidget {
  const VoiceAssistantOverlay({super.key});

  @override
  State<VoiceAssistantOverlay> createState() => _VoiceAssistantOverlayState();
}

class _VoiceAssistantOverlayState extends State<VoiceAssistantOverlay>
    with SingleTickerProviderStateMixin {
  static final stt.SpeechToText _speech = stt.SpeechToText();
  bool _isListening = false;
  String _text = "";
  final TextEditingController _textController = TextEditingController();
  Timer? _silenceTimer;
  double _soundLevel = 0.0;

  bool _isInitialized = false;
  late AnimationController _pulseController;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 1),
    )..repeat(reverse: true);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _initSpeech();
    });
  }

  Future<void> _initSpeech() async {
    try {
      // Re-initialize to ensure fresh session especially if permissions were just granted
      bool available = await _speech.initialize(
        onStatus: (status) {
          debugPrint('Speech Status: $status');
          if (status == 'done' || status == 'notListening') {
            Future.delayed(const Duration(milliseconds: 600), () {
              if (mounted) setState(() => _isListening = false);
            });
          }
        },
        onError: (error) {
          debugPrint('Speech Error: $error');
          if (mounted) setState(() => _isListening = false);
        },
      ).timeout(const Duration(seconds: 4), onTimeout: () => false);

      if (mounted) {
        setState(() => _isInitialized = available);
        if (available) {
          _startListening();
        }
      }
    } catch (e) {
      debugPrint('Speech Init Exception: $e');
    }
  }

  void _startListening() async {
    if (!_isInitialized) {
      // Try one last time to initialize if it failed before
      await _initSpeech();
      if (!_isInitialized) return;
    }

    if (mounted) {
      setState(() {
        _isListening = true;
        _text = "";
        _soundLevel = 0.0;
      });
    }

    try {
      await _speech.listen(
        onResult: (result) {
          debugPrint(
              'Speech Result: ${result.recognizedWords}, final: ${result.finalResult}');
          if (mounted) {
            setState(() {
              _text = result.recognizedWords;
              if (_text.isNotEmpty) {
                _textController.text = _text;
                _textController.selection = TextSelection.fromPosition(
                  TextPosition(offset: _textController.text.length),
                );
              }
            });
            _resetSilenceTimer();
          }
        },
        onSoundLevelChange: (level) {
          if (mounted) {
            setState(() => _soundLevel = level);
          }
        },
        localeId: Localizations.localeOf(context).toString(),
        listenOptions: stt.SpeechListenOptions(
          cancelOnError: false,
          partialResults: true,
          listenMode: stt.ListenMode.dictation,
        ),
      );
    } catch (e) {
      debugPrint('Listen Exception: $e');
    }
    _resetSilenceTimer();
  }

  void _stopListening() async {
    try {
      await _speech.stop();
    } catch (e) {
      debugPrint('Stop Error: $e');
    }
    if (mounted) {
      setState(() {
        _isListening = false;
        _soundLevel = 0.0;
      });
    }
    _silenceTimer?.cancel();
  }

  void _resetSilenceTimer() {
    _silenceTimer?.cancel();
    _silenceTimer = Timer(const Duration(seconds: 3), () {
      if (_isListening && mounted) {
        _stopListening();
      }
    });
  }

  @override
  void dispose() {
    _silenceTimer?.cancel();
    _pulseController.dispose();
    try {
      _speech.cancel();
    } catch (e) {
      debugPrint('Dispose Cancel Error: $e');
    }
    _textController.dispose();
    super.dispose();
  }

  double _scale(BuildContext context, double value) {
    final screenWidth = MediaQuery.of(context).size.width;
    return value * (screenWidth / 390.0);
  }

  @override
  Widget build(BuildContext context) {
    final nav = context.watch<NavigationProvider>();

    return Material(
      color: Colors.transparent,
      child: Stack(
        children: [
          // Glass Background
          BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 15, sigmaY: 15),
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () => nav.toggleVoiceAssistant(false),
              child: Container(
                color: Colors.black.withAlpha(160),
                width: double.infinity,
                height: double.infinity,
              ),
            ),
          ),
          // Main Content
          SafeArea(
            child: Column(
              children: [
                SizedBox(height: _scale(context, 20)),
                Align(
                  alignment: Alignment.topRight,
                  child: Padding(
                    padding: EdgeInsets.only(right: _scale(context, 20)),
                    child: IconButton(
                      icon: const Icon(Icons.close,
                          color: Colors.white, size: 36),
                      onPressed: () => nav.toggleVoiceAssistant(false),
                    ),
                  ),
                ),
                const Spacer(flex: 1),
                // Glowing AI Icon
                _buildGlowingIcon(context),
                SizedBox(height: _scale(context, 50)),
                Padding(
                  padding:
                      EdgeInsets.symmetric(horizontal: _scale(context, 30)),
                  child: Text(
                    AppLocalizations.of(context)
                        .translate('assistant.how_can_i_help'),
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: _scale(context, 32),
                      fontWeight: FontWeight.bold,
                      letterSpacing: -0.5,
                    ),
                  ),
                ),
                SizedBox(height: _scale(context, 16)),
                // Status and Visualizer
                _buildStatusSection(context),
                const Spacer(flex: 2),
                // Suggestion chips at bottom
                _buildSuggestions(context),
                // Input Field at bottom
                _buildInputField(context, nav),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGlowingIcon(BuildContext context) {
    return ScaleTransition(
      scale: _isListening
          ? Tween<double>(begin: 1.0, end: 1.15).animate(CurvedAnimation(
              parent: _pulseController, curve: Curves.easeInOut))
          : const AlwaysStoppedAnimation(1.0),
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Background Glow
          Container(
            width: _scale(context, 200),
            height: _scale(context, 200),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: RadialGradient(
                colors: [
                  context.watch<ThemeProvider>().primaryColor.withAlpha(150),
                  context.watch<ThemeProvider>().primaryColor.withAlpha(0),
                ],
              ),
            ),
          ),
          // Icon
          Icon(
            Icons.auto_awesome,
            color: Colors.white,
            size: _scale(context, 80),
            shadows: [
              Shadow(
                color: Colors.white.withAlpha(100),
                blurRadius: 20,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStatusSection(BuildContext context) {
    return Column(
      children: [
        if (_isListening)
          _buildVoiceVisualizer(context)
        else
          Text(
            _text.isEmpty
                ? (_isInitialized
                    ? AppLocalizations.of(context)
                        .translate('assistant.listening_stopped')
                    : AppLocalizations.of(context)
                        .translate('assistant.preparing_mic'))
                : _text,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Colors.white.withAlpha(180),
              fontSize: _scale(context, 18),
              fontStyle: FontStyle.italic,
            ),
          ),
        SizedBox(height: _scale(context, 16)),
        if (!_isListening)
          GestureDetector(
            onTap: _startListening,
            child: Container(
              padding: EdgeInsets.symmetric(
                horizontal: _scale(context, 24),
                vertical: _scale(context, 12),
              ),
              decoration: BoxDecoration(
                color: Colors.white.withAlpha(40),
                borderRadius: BorderRadius.circular(_scale(context, 30)),
                border: Border.all(color: Colors.white.withAlpha(50)),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.mic, color: Colors.white, size: 20),
                  SizedBox(width: _scale(context, 8)),
                  Text(
                    _isInitialized
                        ? AppLocalizations.of(context)
                            .translate('assistant.listen_again')
                        : AppLocalizations.of(context)
                            .translate('assistant.start'),
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildVoiceVisualizer(BuildContext context) {
    // Simple bar visualizer that reacts to _soundLevel
    // _soundLevel is usually in dB (-2 to 10 range depending on platform)
    final normalizedLevel = (_soundLevel + 2).clamp(0, 12) / 12.0;

    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(5, (index) {
        final heightMultiplier = [0.4, 0.7, 1.0, 0.7, 0.4][index];
        return AnimatedContainer(
          duration: const Duration(milliseconds: 100),
          margin: const EdgeInsets.symmetric(horizontal: 3),
          width: 4,
          height: 20 + (30 * normalizedLevel * heightMultiplier),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(2),
          ),
        );
      }),
    );
  }

  Widget _buildSuggestions(BuildContext context) {
    final suggestions =
        AppLocalizations.of(context).translateArray('assistant.suggestions');
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: EdgeInsets.symmetric(horizontal: _scale(context, 20)),
      child: Row(
        children: suggestions.map((s) => _suggestionChip(context, s)).toList(),
      ),
    );
  }

  Widget _buildInputField(BuildContext context, NavigationProvider nav) {
    return Padding(
      padding: EdgeInsets.all(_scale(context, 20)),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(_scale(context, 30)),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
          child: Container(
            decoration: BoxDecoration(
              color: Colors.white.withAlpha(30),
              borderRadius: BorderRadius.circular(_scale(context, 30)),
              border: Border.all(color: Colors.white.withAlpha(40)),
            ),
            child: TextField(
              controller: _textController,
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                hintText: AppLocalizations.of(context)
                    .translate('assistant.input_hint'),
                hintStyle: TextStyle(color: Colors.white.withAlpha(120)),
                border: InputBorder.none,
                contentPadding: EdgeInsets.symmetric(
                  horizontal: _scale(context, 20),
                  vertical: _scale(context, 16),
                ),
                suffixIcon: IconButton(
                  icon: Icon(Icons.send,
                      color: context.watch<ThemeProvider>().primaryColor),
                  onPressed: () {
                    nav.toggleVoiceAssistant(false);
                  },
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _suggestionChip(BuildContext context, String text) {
    return Container(
      margin: EdgeInsets.only(right: _scale(context, 10)),
      padding: EdgeInsets.symmetric(
        horizontal: _scale(context, 20),
        vertical: _scale(context, 12),
      ),
      decoration: BoxDecoration(
        color: Colors.white.withAlpha(20),
        borderRadius: BorderRadius.circular(_scale(context, 30)),
        border: Border.all(color: Colors.white.withAlpha(30)),
      ),
      child: Text(
        text,
        style: TextStyle(
          color: Colors.white,
          fontSize: _scale(context, 14),
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }
}
