import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../core/localization/app_localizations.dart';
import '../../../core/services/storage_service.dart';

/// Combined hydration + weight tracking card for the home screen.
/// Uses local Hive storage (StorageService) — no Firestore dependency.
class TrackingCard extends StatefulWidget {
  const TrackingCard({super.key});

  @override
  State<TrackingCard> createState() => _TrackingCardState();
}

class _TrackingCardState extends State<TrackingCard> {
  final StorageService _storage = StorageService();
  static const double _goalMl = 2000;
  static const double _stepMl = 250;

  double _todayMl = 0;
  double? _todayWeight;
  List<Map<String, dynamic>> _weightHistory = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  void _load() {
    final today = DateTime.now();
    setState(() {
      _todayMl = _storage.getHydration(today);
      _todayWeight = _storage.getWeight(today);
      _weightHistory = _storage.getWeightHistory().take(7).toList();
    });
  }

  Future<void> _addWater() async {
    final today = DateTime.now();
    final next = (_todayMl + _stepMl).clamp(0.0, _goalMl);
    await _storage.saveHydration(today, next);
    unawaited(HapticFeedback.selectionClick());
    setState(() => _todayMl = next);
  }

  Future<void> _removeWater() async {
    final today = DateTime.now();
    final next = (_todayMl - _stepMl).clamp(0.0, double.infinity);
    await _storage.saveHydration(today, next);
    unawaited(HapticFeedback.selectionClick());
    setState(() => _todayMl = next);
  }

  Future<void> _showWeightDialog() async {
    final l10n = AppLocalizations.of(context);

    await showDialog<void>(
      context: context,
      builder: (ctx) => _WeightInputDialog(
        initialWeight: _todayWeight,
        weightHistory: _weightHistory,
        l10n: l10n,
        onSave: (val) async {
          await _storage.saveWeight(DateTime.now(), val);
          _load();
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final primary = theme.colorScheme.primary;
    final cardBg =
        isDark ? const Color(0xFF1C2330) : Colors.white;
    final fraction = (_todayMl / _goalMl).clamp(0.0, 1.0);
    final glasses = (_todayMl / 250).round();

    return Container(
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.3 : 0.06),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // --- Hydration ---
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.blue.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.water_drop,
                      color: Colors.blue, size: 20),
                ),
                const SizedBox(width: 10),
                Text(
                  l10n.translate('tracking.hydration.title'),
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: isDark ? Colors.white : Colors.black87,
                  ),
                ),
                const Spacer(),
                Text(
                  '$glasses ${l10n.translate('tracking.hydration.glasses')} • ${_todayMl.round()} ml',
                  style: TextStyle(
                    fontSize: 12,
                    color: isDark ? Colors.grey[400] : Colors.grey[600],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            // Progress bar
            ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: LinearProgressIndicator(
                value: fraction,
                minHeight: 8,
                backgroundColor: isDark
                    ? Colors.white10
                    : Colors.blue.withValues(alpha: 0.1),
                valueColor:
                    const AlwaysStoppedAnimation<Color>(Colors.blue),
              ),
            ),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  '${(_goalMl - _todayMl).clamp(0, _goalMl).round()} ml ${l10n.translate('tracking.hydration.remaining')}',
                  style: TextStyle(
                    fontSize: 11,
                    color: isDark ? Colors.grey[500] : Colors.grey[500],
                  ),
                ),
                Row(
                  children: [
                    _iconBtn(
                      icon: Icons.remove,
                      color: Colors.blue,
                      onTap: _todayMl > 0 ? _removeWater : null,
                    ),
                    const SizedBox(width: 8),
                    _iconBtn(
                      icon: Icons.add,
                      color: Colors.blue,
                      onTap: _todayMl < _goalMl ? _addWater : null,
                      label: '+250ml',
                    ),
                  ],
                ),
              ],
            ),

            const Padding(
              padding: EdgeInsets.symmetric(vertical: 14),
              child: Divider(height: 1),
            ),

            // --- Weight ---
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: primary.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child:
                      Icon(Icons.monitor_weight, color: primary, size: 20),
                ),
                const SizedBox(width: 10),
                Text(
                  l10n.translate('tracking.weight.title'),
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: isDark ? Colors.white : Colors.black87,
                  ),
                ),
                const Spacer(),
                GestureDetector(
                  onTap: _showWeightDialog,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: _todayWeight != null
                          ? primary.withValues(alpha: 0.1)
                          : primary,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      _todayWeight != null
                          ? '${_todayWeight!.toStringAsFixed(1)} kg'
                          : l10n.translate('tracking.weight.log'),
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: _todayWeight != null ? primary : Colors.white,
                      ),
                    ),
                  ),
                ),
              ],
            ),
            if (_weightHistory.length > 1) ...[
              const SizedBox(height: 12),
              _buildWeightMiniChart(isDark, primary),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildWeightMiniChart(bool isDark, Color primary) {
    final entries = _weightHistory.reversed.toList();
    if (entries.length < 2) return const SizedBox.shrink();

    final weights =
        entries.map((e) => (e['weight'] as double)).toList();
    final minW = weights.reduce((a, b) => a < b ? a : b);
    final maxW = weights.reduce((a, b) => a > b ? a : b);
    final range = (maxW - minW).clamp(0.5, double.infinity);

    return SizedBox(
      height: 36,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: weights.map((w) {
          final fraction = (maxW - minW) < 0.1
              ? 0.5
              : ((w - minW) / range).clamp(0.1, 1.0);
          return Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 2),
              child: Tooltip(
                message: '${w.toStringAsFixed(1)} kg',
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 300),
                  height: 36 * fraction,
                  decoration: BoxDecoration(
                    color: primary.withValues(alpha: 0.6),
                    borderRadius: const BorderRadius.vertical(
                        top: Radius.circular(4)),
                  ),
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _iconBtn({
    required IconData icon,
    required Color color,
    VoidCallback? onTap,
    String? label,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: label != null
            ? const EdgeInsets.symmetric(horizontal: 10, vertical: 6)
            : const EdgeInsets.all(6),
        decoration: BoxDecoration(
          color: onTap != null
              ? color.withValues(alpha: 0.12)
              : Colors.grey.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(10),
        ),
        child: label != null
            ? Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(icon,
                      color: onTap != null ? color : Colors.grey,
                      size: 14),
                  const SizedBox(width: 4),
                  Text(
                    label,
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: onTap != null ? color : Colors.grey,
                    ),
                  ),
                ],
              )
            : Icon(icon,
                color: onTap != null ? color : Colors.grey, size: 16),
      ),
    );
  }
}

class _WeightInputDialog extends StatefulWidget {
  final double? initialWeight;
  final List<dynamic> weightHistory;
  final AppLocalizations l10n;
  final Future<void> Function(double) onSave;

  const _WeightInputDialog({
    required this.initialWeight,
    required this.weightHistory,
    required this.l10n,
    required this.onSave,
  });

  @override
  State<_WeightInputDialog> createState() => _WeightInputDialogState();
}

class _WeightInputDialogState extends State<_WeightInputDialog> {
  late final TextEditingController _controller;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(
      text: widget.initialWeight?.toStringAsFixed(1) ?? '',
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.l10n.translate('tracking.weight.log_title')),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            controller: _controller,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            autofocus: true,
            decoration: InputDecoration(
              labelText: widget.l10n.translate('tracking.weight.field_label'),
              suffix: const Text('kg'),
              border: const OutlineInputBorder(),
            ),
          ),
          if (widget.weightHistory.isNotEmpty) ...[
            const SizedBox(height: 16),
            Text(
              widget.l10n.translate('tracking.weight.recent'),
              style: const TextStyle(
                  fontSize: 12, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 8),
            ...(widget.weightHistory.take(5).map(
                  (e) => Padding(
                    padding: const EdgeInsets.symmetric(vertical: 2),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(e['date'] as String,
                            style: const TextStyle(fontSize: 12)),
                        Text('${e['weight']} kg',
                            style: const TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600)),
                      ],
                    ),
                  ),
                )),
          ],
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(widget.l10n.translate('common.cancel')),
        ),
        ElevatedButton(
          onPressed: _isSaving
              ? null
              : () async {
                  final val = double.tryParse(_controller.text.trim());
                  if (val == null || val <= 0) return;
                  setState(() => _isSaving = true);
                  await widget.onSave(val);
                  if (mounted) Navigator.pop(context);
                },
          child: _isSaving
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2))
              : Text(widget.l10n.translate('common.save')),
        ),
      ],
    );
  }
}
