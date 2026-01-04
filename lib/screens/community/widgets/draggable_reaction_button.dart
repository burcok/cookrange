import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class DraggableReactionButton extends StatefulWidget {
  final Function(String emoji) onReactionSelected;
  final bool isDark;
  final bool isSmall;
  final String?
      commentId; // For uniqueness if needed in keys, though distinct instances suffice

  const DraggableReactionButton({
    super.key,
    required this.onReactionSelected,
    required this.isDark,
    this.isSmall = false,
    this.commentId,
  });

  @override
  State<DraggableReactionButton> createState() =>
      _DraggableReactionButtonState();
}

class _DraggableReactionButtonState extends State<DraggableReactionButton> {
  OverlayEntry? _overlayEntry;
  final LayerLink _layerLink = LayerLink();
  final List<String> _emojis = ['👍', '👎', '😂', '😮', '😢', '🔥'];

  // State for drag tracking
  int? _focusedIndex;

  void _showOverlay({bool isTapMode = false}) {
    if (_overlayEntry != null) return;

    // Calculate safe offset
    final RenderBox? renderBox = context.findRenderObject() as RenderBox?;
    Offset safeOffset = const Offset(-150.0, -60.0); // Default

    if (renderBox != null) {
      final buttonPosition = renderBox.localToGlobal(Offset.zero);
      final screenSize = MediaQuery.of(context).size;

      // Estimated Tooltip Width: 6 emojis * ~45px + 24px padding = ~294px. Safe bet 300.
      const tooltipWidth = 300.0;
      const screenPadding = 12.0;

      double targetXOffset =
          -150.0; // Centered relative to button if button is small

      // Calculate where the tooltip would start globally
      double globalTooltipLeft = buttonPosition.dx + targetXOffset;

      // 1. Check Left Overflow
      if (globalTooltipLeft < screenPadding) {
        // Shift right by the amount of overflow + padding
        targetXOffset += (screenPadding - globalTooltipLeft);
      }
      // 2. Check Right Overflow
      else if (globalTooltipLeft + tooltipWidth >
          screenSize.width - screenPadding) {
        // Shift left
        targetXOffset -= ((globalTooltipLeft + tooltipWidth) -
            (screenSize.width - screenPadding));
      }

      safeOffset = Offset(targetXOffset, -60.0);
    }

    _overlayEntry = _createOverlayEntry(isTapMode, safeOffset);
    Overlay.of(context).insert(_overlayEntry!);
  }

  void _removeOverlay() {
    _overlayEntry?.remove();
    _overlayEntry = null;
    if (mounted) setState(() => _focusedIndex = null);
  }

  // _updateFocus logic remains mostly same but relativeX needs to know the NEW offset?
  // Current _updateFocus assumes -150.0. We should store the active offset or recalculate?
  // Easier: Store _activeOffset in state when showing overlay.
  Offset _activeOffset = const Offset(-150.0, -60.0);

  void _updateFocus(Offset localPosition) {
    const itemWidth = 45.0;

    // Use the actual active offset for calculation
    final overlayStartX = _activeOffset.dx;
    final relativeX = localPosition.dx - overlayStartX;

    int index = (relativeX / itemWidth).floor();
    if (index < 0) index = 0;
    if (index >= _emojis.length) index = _emojis.length - 1;

    // Optional: Check Y bounds
    final relativeY = localPosition.dy - _activeOffset.dy;
    // Overlay is above, so _activeOffset.dy is usually -60.
    // If dy is 0 (on button), relativeY = 0 - (-60) = 60.
    // Allow roughly -50 to +100 range from overlay top?
    // Actually relativeY logic was: localPosition.dy - (-60).
    // Now: localPosition.dy is relative to button.
    // Overlay Top is at _activeOffset.dy relative to button.
    // So touch Y relative to Overlay Top is: localPosition.dy - _activeOffset.dy.

    // Bounds check
    bool outOfBounds = relativeY < -50 || relativeY > 100;
    if (relativeX < -50 || relativeX > (_emojis.length * itemWidth) + 50) {
      outOfBounds = true;
    }

    if (outOfBounds) {
      if (_focusedIndex != null) {
        setState(() => _focusedIndex = null);
        _overlayEntry?.markNeedsBuild();
      }
      return;
    }

    if (_focusedIndex != index) {
      setState(() => _focusedIndex = index);
      HapticFeedback.selectionClick();
      _overlayEntry?.markNeedsBuild();
    }
  }

  OverlayEntry _createOverlayEntry(bool isTapMode, Offset offset) {
    _activeOffset = offset; // Store for drag calc
    return OverlayEntry(
      builder: (context) => Stack(
        children: [
          if (isTapMode)
            Positioned.fill(
              child: GestureDetector(
                behavior: HitTestBehavior.translucent,
                onTap: _removeOverlay,
                child: Container(color: Colors.transparent),
              ),
            ),
          CompositedTransformFollower(
            link: _layerLink,
            showWhenUnlinked: false,
            offset: offset,
            child: Material(
              elevation: 8,
              color: Colors.transparent,
              child: StatefulBuilder(builder: (context, setStateOverlay) {
                return _buildEmojiRow();
              }),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmojiRow() {
    return Container(
      decoration: BoxDecoration(
          color: widget.isDark ? const Color(0xFF334155) : Colors.white,
          borderRadius: BorderRadius.circular(30)),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      height: 55, // Fixed height
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: List.generate(_emojis.length, (index) {
          final isFocused = _focusedIndex == index;
          return GestureDetector(
            // Allow direct tap on items in Tap Mode
            onTap: () {
              widget.onReactionSelected(_emojis[index]);
              _removeOverlay();
            },
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 150),
              curve: Curves.easeOutBack,
              transform: Matrix4.identity()..scale(isFocused ? 1.5 : 1.0),
              transformAlignment: Alignment.center,
              margin: EdgeInsets.symmetric(horizontal: isFocused ? 10 : 4),
              decoration: BoxDecoration(
                color: isFocused
                    ? const Color(0xFFF97316).withOpacity(0.2)
                    : Colors.transparent,
                shape: BoxShape.circle,
              ),
              child: Text(
                _emojis[index],
                style: const TextStyle(fontSize: 24),
              ),
            ),
          );
        }),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return CompositedTransformTarget(
      link: _layerLink,
      child: GestureDetector(
        onLongPressStart: (details) {
          HapticFeedback.mediumImpact();
          _showOverlay(isTapMode: false);
          _updateFocus(details.localPosition); // Init focus
        },
        onLongPressMoveUpdate: (details) {
          _updateFocus(details.localPosition);
        },
        onLongPressEnd: (details) {
          if (_focusedIndex != null &&
              _focusedIndex! >= 0 &&
              _focusedIndex! < _emojis.length) {
            widget.onReactionSelected(_emojis[_focusedIndex!]);
            HapticFeedback.lightImpact();
          }
          _removeOverlay();
        },
        // Tap behavior: Use legacy/simple popup or simple toggle?
        // User asked: "Add Reaction + button to be usable by hold".
        // Tap could just open specific "Add" menu or same overlay but persistent?
        // Let's make TAP open the overlay in a "Persistent" mode (dismiss on tap outside),
        // duplicating popup menu behavior but with our custom UI.
        // For simplicity and matching the request to allow "pressing and holding directly",
        // we'll keep tap = legacy popup or this same overlay but requiring a second tap.
        // Let's implement Tap = Toggle Visibility.
        onTap: () {
          if (_overlayEntry != null) {
            _removeOverlay();
          } else {
            _showOverlay(isTapMode: true);
          }
        },
        // We will wrap the child with Listener to catch Up events if GestureDetector fails? No.

        child: Container(
          padding: const EdgeInsets.all(4),
          decoration: widget.isSmall
              ? BoxDecoration(
                  color: widget.isDark ? Colors.white10 : Colors.grey.shade200,
                  shape: BoxShape.circle)
              : null,
          child: Icon(Icons.add_reaction_outlined,
              size: widget.isSmall ? 16 : 20,
              color: widget.isDark ? Colors.white70 : Colors.grey.shade600),
        ),
      ),
    );
  }
}
