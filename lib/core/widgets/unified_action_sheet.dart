import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/theme_provider.dart';

class ActionSheetItem {
  final String label;
  final IconData icon;
  final VoidCallback onTap;
  final bool isDestructive;
  final bool isSelected;

  ActionSheetItem({
    required this.label,
    required this.icon,
    required this.onTap,
    this.isDestructive = false,
    this.isSelected = false,
  });
}

class UnifiedActionSheet extends StatelessWidget {
  final String? title;
  final List<ActionSheetItem> actions;
  final String? cancelLabel;

  const UnifiedActionSheet({
    super.key,
    this.title,
    required this.actions,
    this.cancelLabel,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primaryColor = context.watch<ThemeProvider>().primaryColor;

    return ClipRRect(
      borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
        child: Container(
          decoration: BoxDecoration(
            color: isDark
                ? const Color(0xFF1E293B).withOpacity(0.9)
                : Colors.white.withOpacity(0.9),
            border: Border(
              top: BorderSide(
                color: isDark
                    ? Colors.white.withOpacity(0.1)
                    : Colors.black.withOpacity(0.05),
                width: 1,
              ),
            ),
          ),
          child: SafeArea(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const SizedBox(height: 8),
                // Handle bar
                Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: isDark
                        ? Colors.white.withOpacity(0.2)
                        : Colors.black.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(height: 16),

                if (title != null) ...[
                  Padding(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
                    child: Text(
                      title!,
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: isDark ? Colors.white : const Color(0xFF0F172A),
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Divider(
                    height: 1,
                    color: isDark
                        ? Colors.white.withOpacity(0.1)
                        : Colors.black.withOpacity(0.05),
                  ),
                ],

                Flexible(
                  child: SingleChildScrollView(
                    physics: const BouncingScrollPhysics(),
                    child: Column(
                      children: actions
                          .map((action) => _buildActionItem(
                              context, action, isDark, primaryColor))
                          .toList(),
                    ),
                  ),
                ),

                const SizedBox(height: 8),
                Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  child: SizedBox(
                    width: double.infinity,
                    child: TextButton(
                      onPressed: () => Navigator.pop(context),
                      style: TextButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        backgroundColor: isDark
                            ? Colors.white.withOpacity(0.05)
                            : Colors.black.withOpacity(0.05),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
                      child: Text(
                        cancelLabel ?? "Cancel",
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: isDark ? Colors.white70 : Colors.black54,
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 8),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildActionItem(BuildContext context, ActionSheetItem action,
      bool isDark, Color primaryColor) {
    return InkWell(
      onTap: () {
        Navigator.pop(context);
        action.onTap();
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
        decoration: BoxDecoration(
          color: action.isSelected
              ? primaryColor.withOpacity(isDark ? 0.2 : 0.1)
              : Colors.transparent,
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: action.isDestructive
                    ? Colors.red.withOpacity(0.1)
                    : (action.isSelected
                        ? primaryColor.withOpacity(0.2)
                        : (isDark
                            ? Colors.white.withOpacity(0.05)
                            : Colors.black.withOpacity(0.05))),
                shape: BoxShape.circle,
              ),
              child: Icon(
                action.icon,
                size: 20,
                color: action.isDestructive
                    ? Colors.red
                    : (action.isSelected
                        ? primaryColor
                        : (isDark ? Colors.white : const Color(0xFF0F172A))),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Text(
                action.label,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight:
                      action.isSelected ? FontWeight.w600 : FontWeight.w500,
                  color: action.isDestructive
                      ? Colors.red
                      : (action.isSelected
                          ? primaryColor
                          : (isDark ? Colors.white : const Color(0xFF0F172A))),
                ),
              ),
            ),
            if (action.isSelected)
              Icon(Icons.check, color: primaryColor, size: 20),
          ],
        ),
      ),
    );
  }
}

Future<void> showUnifiedActionSheet({
  required BuildContext context,
  String? title,
  required List<ActionSheetItem> actions,
  String? cancelLabel,
}) {
  return showModalBottomSheet(
    context: context,
    backgroundColor: Colors.transparent,
    isScrollControlled: true, // Allows sheet to take needed height up to limits
    builder: (context) => UnifiedActionSheet(
      title: title,
      actions: actions,
      cancelLabel: cancelLabel,
    ),
  );
}
