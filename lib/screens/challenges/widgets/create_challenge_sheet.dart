import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../../core/localization/app_localizations.dart';
import '../../../core/models/challenge_model.dart';
import '../../../core/providers/theme_provider.dart';
import '../../../core/services/challenge_service.dart';

class CreateChallengeSheet extends StatefulWidget {
  const CreateChallengeSheet({super.key});

  @override
  State<CreateChallengeSheet> createState() => _CreateChallengeSheetState();
}

class _CreateChallengeSheetState extends State<CreateChallengeSheet> {
  final ChallengeService _service = ChallengeService();
  final TextEditingController _titleCtrl = TextEditingController();
  final TextEditingController _descCtrl = TextEditingController();
  final TextEditingController _goalCtrl = TextEditingController();

  ChallengeType _selectedType = ChallengeType.steps;
  DateTime _endDate = DateTime.now().add(const Duration(days: 7));
  bool _isPublic = true;
  bool _isCreating = false;

  static IconData _typeIcon(ChallengeType t) {
    switch (t) {
      case ChallengeType.steps:
        return Icons.directions_walk;
      case ChallengeType.calories:
        return Icons.local_fire_department;
      case ChallengeType.workoutDays:
        return Icons.fitness_center;
      case ChallengeType.custom:
        return Icons.emoji_events;
    }
  }

  static String _typeLabelKey(ChallengeType t) {
    switch (t) {
      case ChallengeType.steps:
        return 'challenge.type.steps';
      case ChallengeType.calories:
        return 'challenge.type.calories';
      case ChallengeType.workoutDays:
        return 'challenge.type.workoutDays';
      case ChallengeType.custom:
        return 'challenge.type.custom';
    }
  }

  static String _typeDefaultUnit(ChallengeType t) {
    switch (t) {
      case ChallengeType.steps:
        return 'steps';
      case ChallengeType.calories:
        return 'kcal';
      case ChallengeType.workoutDays:
        return 'days';
      case ChallengeType.custom:
        return '';
    }
  }

  static String _typeDefaultGoal(ChallengeType t) {
    switch (t) {
      case ChallengeType.steps:
        return '10000';
      case ChallengeType.calories:
        return '500';
      case ChallengeType.workoutDays:
        return '5';
      case ChallengeType.custom:
        return '100';
    }
  }

  @override
  void initState() {
    super.initState();
    _goalCtrl.text = '10000';
  }

  @override
  void dispose() {
    _titleCtrl.dispose();
    _descCtrl.dispose();
    _goalCtrl.dispose();
    super.dispose();
  }

  bool get _canCreate =>
      _titleCtrl.text.trim().isNotEmpty &&
      (int.tryParse(_goalCtrl.text) ?? 0) > 0 &&
      !_isCreating;

  Future<void> _pickEndDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _endDate,
      firstDate: DateTime.now().add(const Duration(days: 1)),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (picked != null && mounted) setState(() => _endDate = picked);
  }

  Future<void> _create() async {
    final l10n = AppLocalizations.of(context);
    final title = _titleCtrl.text.trim();
    final goal = int.tryParse(_goalCtrl.text) ?? 0;
    if (title.isEmpty || goal <= 0) return;

    final unit = _selectedType == ChallengeType.custom
        ? l10n.translate('challenge.type.custom_unit')
        : _typeDefaultUnit(_selectedType);

    setState(() => _isCreating = true);
    try {
      final challenge = await _service.createChallenge(
        title: title,
        description: _descCtrl.text.trim(),
        type: _selectedType,
        goal: goal,
        unit: unit,
        endDate: _endDate,
        isPublic: _isPublic,
      );
      if (mounted) Navigator.pop(context, challenge);
    } catch (e) {
      if (mounted) {
        setState(() => _isCreating = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.toString())),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primary = context.read<ThemeProvider>().primaryColor;

    return Container(
      height: MediaQuery.of(context).size.height * 0.88,
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF111827) : Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        children: [
          Container(
            width: 36,
            height: 4,
            margin: const EdgeInsets.only(top: 12, bottom: 20),
            decoration: BoxDecoration(
              color: isDark ? Colors.white24 : Colors.black12,
              borderRadius: BorderRadius.circular(2),
            ),
          ),

          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    l10n.translate('challenge.create.title'),
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      color: isDark ? Colors.white : const Color(0xFF0F172A),
                    ),
                  ),
                  const SizedBox(height: 24),

                  _label(l10n.translate('challenge.create.name_label'), isDark),
                  const SizedBox(height: 6),
                  _textField(
                    controller: _titleCtrl,
                    hint: l10n.translate('challenge.create.name_hint'),
                    isDark: isDark,
                    onChanged: (_) => setState(() {}),
                  ),
                  const SizedBox(height: 16),

                  _label(l10n.translate('challenge.create.desc_label'), isDark),
                  const SizedBox(height: 6),
                  _textField(
                    controller: _descCtrl,
                    hint: l10n.translate('challenge.create.desc_hint'),
                    isDark: isDark,
                    maxLines: 3,
                  ),
                  const SizedBox(height: 20),

                  _label(l10n.translate('challenge.create.type_label'), isDark),
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: ChallengeType.values.map((t) {
                      final isSelected = _selectedType == t;
                      return GestureDetector(
                        onTap: () {
                          setState(() {
                            _selectedType = t;
                            _goalCtrl.text = _typeDefaultGoal(t);
                          });
                        },
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 180),
                          padding: const EdgeInsets.symmetric(
                              horizontal: 14, vertical: 8),
                          decoration: BoxDecoration(
                            color: isSelected
                                ? primary
                                : (isDark
                                    ? Colors.white.withValues(alpha: 0.08)
                                    : Colors.grey.shade100),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: isSelected ? primary : Colors.transparent,
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(_typeIcon(t),
                                  size: 16,
                                  color: isSelected
                                      ? Colors.white
                                      : (isDark
                                          ? Colors.white60
                                          : Colors.black54)),
                              const SizedBox(width: 6),
                              Text(
                                l10n.translate(_typeLabelKey(t)),
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                  color: isSelected
                                      ? Colors.white
                                      : (isDark
                                          ? Colors.white70
                                          : Colors.black87),
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 20),

                  _label(l10n.translate('challenge.create.goal_label'), isDark),
                  const SizedBox(height: 6),
                  _textField(
                    controller: _goalCtrl,
                    hint: l10n.translate('challenge.create.goal_hint'),
                    isDark: isDark,
                    keyboardType: TextInputType.number,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    onChanged: (_) => setState(() {}),
                  ),
                  const SizedBox(height: 20),

                  _label(l10n.translate('challenge.create.end_date_label'),
                      isDark),
                  const SizedBox(height: 6),
                  GestureDetector(
                    onTap: _pickEndDate,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 14),
                      decoration: BoxDecoration(
                        color: isDark
                            ? Colors.white.withValues(alpha: 0.06)
                            : Colors.grey.shade100,
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.calendar_today,
                              size: 18,
                              color: isDark ? Colors.white54 : Colors.black45),
                          const SizedBox(width: 10),
                          Text(
                            '${_endDate.day.toString().padLeft(2, '0')}.${_endDate.month.toString().padLeft(2, '0')}.${_endDate.year}',
                            style: TextStyle(
                              fontSize: 15,
                              color: isDark
                                  ? Colors.white
                                  : const Color(0xFF0F172A),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),

                  Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              l10n.translate(
                                  'challenge.create.public_label'),
                              style: TextStyle(
                                fontWeight: FontWeight.w600,
                                color: isDark
                                    ? Colors.white
                                    : const Color(0xFF0F172A),
                              ),
                            ),
                            Text(
                              l10n.translate(
                                  'challenge.create.public_subtitle'),
                              style: TextStyle(
                                fontSize: 12,
                                color:
                                    isDark ? Colors.white54 : Colors.black45,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Switch(
                        value: _isPublic,
                        onChanged: (v) => setState(() => _isPublic = v),
                        activeColor: primary,
                      ),
                    ],
                  ),
                  const SizedBox(height: 28),
                ],
              ),
            ),
          ),

          Padding(
            padding: EdgeInsets.fromLTRB(
                24, 8, 24, MediaQuery.of(context).padding.bottom + 16),
            child: SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _canCreate ? _create : null,
                style: ElevatedButton.styleFrom(
                  backgroundColor: primary,
                  disabledBackgroundColor:
                      isDark ? Colors.white12 : Colors.black12,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14)),
                ),
                child: _isCreating
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                            color: Colors.white, strokeWidth: 2))
                    : Text(
                        l10n.translate('challenge.create.btn'),
                        style: const TextStyle(
                            fontSize: 16, fontWeight: FontWeight.bold),
                      ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _label(String text, bool isDark) => Text(
        text,
        style: TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w600,
          color: isDark ? Colors.white60 : Colors.black54,
        ),
      );

  Widget _textField({
    required TextEditingController controller,
    required String hint,
    required bool isDark,
    int maxLines = 1,
    TextInputType? keyboardType,
    List<TextInputFormatter>? inputFormatters,
    ValueChanged<String>? onChanged,
  }) {
    return TextField(
      controller: controller,
      maxLines: maxLines,
      keyboardType: keyboardType,
      inputFormatters: inputFormatters,
      onChanged: onChanged,
      style: TextStyle(
          color: isDark ? Colors.white : const Color(0xFF0F172A)),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle:
            TextStyle(color: isDark ? Colors.white38 : Colors.black38),
        filled: true,
        fillColor: isDark
            ? Colors.white.withValues(alpha: 0.06)
            : Colors.grey.shade100,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide.none,
        ),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      ),
    );
  }
}
