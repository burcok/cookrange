import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../core/theme/app_palette.dart';
import '../../../core/theme/app_dimensions.dart';

class DraggableReactionButton extends StatefulWidget {
  final Function(String emoji) onReactionSelected;
  final bool isDark;
  final bool isSmall;
  final String? commentId;

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

  int? _focusedIndex;

  void _showOverlay({bool isTapMode = false}) {
    if (_overlayEntry != null) return;

    final RenderBox? renderBox = context.findRenderObject() as RenderBox?;
    Offset safeOffset = const Offset(-150.0, -60.0);

    if (renderBox != null) {
      final buttonPosition = renderBox.localToGlobal(Offset.zero);
      final screenSize = MediaQuery.of(context).size;

      const tooltipWidth = 300.0;
      const screenPadding = 12.0;

      double targetXOffset = -150.0;
      double globalTooltipLeft = buttonPosition.dx + targetXOffset;

      if (globalTooltipLeft < screenPadding) {
        targetXOffset += (screenPadding - globalTooltipLeft);
      } else if (globalTooltipLeft + tooltipWidth >
          screenSize.width - screenPadding) {
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

  Offset _activeOffset = const Offset(-150.0, -60.0);

  void _updateFocus(Offset localPosition) {
    const itemWidth = 45.0;

    final overlayStartX = _activeOffset.dx;
    final relativeX = localPosition.dx - overlayStartX;

    int index = (relativeX / itemWidth).floor();
    if (index < 0) index = 0;
    if (index >= _emojis.length) index = _emojis.length - 1;

    final relativeY = localPosition.dy - _activeOffset.dy;

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
    _activeOffset = offset;
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
                return _buildEmojiRow(context);
              }),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmojiRow(BuildContext context) {
    final palette = AppPalette.of(context);
    return Container(
      decoration: BoxDecoration(
          color: palette.surfaceElevated,
          borderRadius: BorderRadius.circular(AppRadius.full)),
      padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.sm, vertical: AppSpacing.xs),
      height: 55,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: List.generate(_emojis.length, (index) {
          final isFocused = _focusedIndex == index;
          return GestureDetector(
            onTap: () {
              widget.onReactionSelected(_emojis[index]);
              _removeOverlay();
            },
            child: AnimatedContainer(
              duration: AppMotion.fast,
              curve: Curves.easeOutBack,
              transform: (isFocused
                  ? (Matrix4.identity()..scaleByDouble(1.5, 1.5, 1.0, 1.0))
                  : Matrix4.identity()),
              transformAlignment: Alignment.center,
              margin: EdgeInsets.symmetric(horizontal: isFocused ? 10 : 4),
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
    final palette = AppPalette.of(context);
    return CompositedTransformTarget(
      link: _layerLink,
      child: GestureDetector(
        onLongPressStart: (details) {
          HapticFeedback.mediumImpact();
          _showOverlay();
          _updateFocus(details.localPosition);
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
        onTap: () {
          if (_overlayEntry != null) {
            _removeOverlay();
          } else {
            _showOverlay(isTapMode: true);
          }
        },
        child: Container(
          padding: const EdgeInsets.all(AppSpacing.xxs),
          decoration: widget.isSmall
              ? BoxDecoration(
                  color: palette.surfaceVariant, shape: BoxShape.circle)
              : null,
          child: Icon(Icons.add_reaction_outlined,
              size: widget.isSmall ? AppSize.iconXs : AppSize.iconMd,
              color: palette.textSecondary),
        ),
      ),
    );
  }
}
