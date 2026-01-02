import 'package:flutter/material.dart';
import 'dart:async';
import 'package:wakelock_plus/wakelock_plus.dart';
import '../../core/models/recipe_model.dart';
import '../../constants.dart';

class CookingModeScreen extends StatefulWidget {
  final Recipe recipe;
  final int initialStepIndex;

  const CookingModeScreen({
    super.key,
    required this.recipe,
    this.initialStepIndex = 0,
  });

  @override
  State<CookingModeScreen> createState() => _CookingModeScreenState();
}

class _CookingModeScreenState extends State<CookingModeScreen> {
  late PageController _pageController;
  late int _currentStep;
  Timer? _timer;
  int _secondsElapsed = 0;
  bool _isTimerRunning = false;

  @override
  void initState() {
    super.initState();
    _currentStep = widget.initialStepIndex;
    _pageController = PageController(initialPage: _currentStep);
    WakelockPlus.enable(); // Keep screen on
  }

  @override
  void dispose() {
    WakelockPlus.disable();
    _pageController.dispose();
    _timer?.cancel();
    super.dispose();
  }

  void _toggleTimer() {
    setState(() {
      _isTimerRunning = !_isTimerRunning;
      if (_isTimerRunning) {
        _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
          setState(() {
            _secondsElapsed++;
          });
        });
      } else {
        _timer?.cancel();
      }
    });
  }

  void _resetTimer() {
    setState(() {
      _timer?.cancel();
      _isTimerRunning = false;
      _secondsElapsed = 0;
    });
  }

  String _formatTime(int seconds) {
    final int minutes = seconds ~/ 60;
    final int remainingSeconds = seconds % 60;
    return '${minutes.toString().padLeft(2, '0')}:${remainingSeconds.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Column(
          children: [
            // Header
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  IconButton(
                    icon: const Icon(Icons.close, color: Colors.white),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                  Text(
                    'Step ${_currentStep + 1} of ${widget.recipe.instructions.length}',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  IconButton(
                    icon: Icon(
                      _isTimerRunning ? Icons.pause_circle : Icons.play_circle,
                      color: primaryColor,
                    ),
                    onPressed: _toggleTimer,
                  ),
                ],
              ),
            ),

            // Timer Display (if active or non-zero)
            if (_secondsElapsed > 0 || _isTimerRunning)
              Padding(
                padding: const EdgeInsets.only(bottom: 16),
                child: GestureDetector(
                  onTap: _toggleTimer,
                  onLongPress: _resetTimer,
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
                    decoration: BoxDecoration(
                      color: Colors.grey[900],
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                          color: _isTimerRunning ? primaryColor : Colors.grey),
                    ),
                    child: Text(
                      _formatTime(_secondsElapsed),
                      style: TextStyle(
                        color: _isTimerRunning ? primaryColor : Colors.white,
                        fontSize: 24,
                        fontFamily: 'Courier',
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
              ),

            // Main Content (PageView)
            Expanded(
              child: PageView.builder(
                controller: _pageController,
                itemCount: widget.recipe.instructions.length,
                onPageChanged: (index) {
                  setState(() {
                    _currentStep = index;
                  });
                },
                itemBuilder: (context, index) {
                  return Padding(
                    padding: const EdgeInsets.all(24.0),
                    child: Center(
                      child: SingleChildScrollView(
                        child: Text(
                          widget.recipe.instructions[index],
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 28,
                            height: 1.4,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),

            // Bottom Controls
            Padding(
              padding: const EdgeInsets.all(24.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  // Previous Button
                  if (_currentStep > 0)
                    FloatingActionButton(
                      heroTag: 'prev',
                      backgroundColor: Colors.grey[800],
                      onPressed: () {
                        _pageController.previousPage(
                          duration: const Duration(milliseconds: 300),
                          curve: Curves.easeInOut,
                        );
                      },
                      child: const Icon(Icons.arrow_back, color: Colors.white),
                    )
                  else
                    const SizedBox(width: 56),

                  // Progress Indicator
                  SizedBox(
                    width: 60,
                    height: 60,
                    child: CircularProgressIndicator(
                      value: (_currentStep + 1) /
                          widget.recipe.instructions.length,
                      strokeWidth: 4,
                      backgroundColor: Colors.grey[800],
                      color: primaryColor,
                    ),
                  ),

                  // Next Button
                  FloatingActionButton(
                    heroTag: 'next',
                    backgroundColor: primaryColor,
                    onPressed: () {
                      if (_currentStep <
                          widget.recipe.instructions.length - 1) {
                        _pageController.nextPage(
                          duration: const Duration(milliseconds: 300),
                          curve: Curves.easeInOut,
                        );
                      } else {
                        // Finish cooking
                        Navigator.of(context).pop();
                        // TODO: Show "Meal Completed" dialog or celebration
                      }
                    },
                    child: Icon(
                      _currentStep < widget.recipe.instructions.length - 1
                          ? Icons.arrow_forward
                          : Icons.check,
                      color: Colors.white,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
