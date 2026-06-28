import 'package:flutter/material.dart';
import 'package:cookrange/core/localization/app_localizations.dart';
import '../../../core/models/signal_model.dart';
import '../../../core/services/signal_service.dart';
import '../../../core/theme/app_palette.dart';
import '../../../core/theme/app_typography.dart';

class SignalDialog extends StatefulWidget {
  const SignalDialog({super.key});

  @override
  State<SignalDialog> createState() => _SignalDialogState();
}

class _SignalDialogState extends State<SignalDialog> {
  final SignalService _signalService = SignalService();
  final TextEditingController _messageController = TextEditingController();
  SignalType _selectedType = SignalType.gymHelp;
  bool _isLoading = false;

  final Map<SignalType, List<String>> _presets = {
    SignalType.gymHelp: [
      "signal.presets.gym_1",
      "signal.presets.gym_2",
      "signal.presets.gym_3",
    ],
    SignalType.mealShare: [
      "signal.presets.meal_1",
      "signal.presets.meal_2",
      "signal.presets.meal_3",
    ],
    SignalType.general: [
      "signal.presets.general_1",
      "signal.presets.general_2",
    ]
  };

  Future<void> _sendSignal() async {
    if (_messageController.text.trim().isEmpty) return;

    setState(() => _isLoading = true);
    try {
      await _signalService.sendSignal(
        type: _selectedType,
        message: _messageController.text.trim(),
        durationMinutes: 60,
      );
      if (mounted) {
        Navigator.pop(context, true);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text(AppLocalizations.of(context).translate(
                  'signal.error',
                  variables: {'error': e.toString()}))),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  void dispose() {
    _messageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final palette = AppPalette.of(context);
    final appText = AppText.of(context);

    return AlertDialog(
      backgroundColor: palette.surface,
      title: Text(
        AppLocalizations.of(context).translate('signal.title'),
        style: appText.titleL,
      ),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              AppLocalizations.of(context).translate('signal.select_type'),
              style: appText.labelL.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            DropdownButtonFormField<SignalType>(
              initialValue: _selectedType,
              dropdownColor: palette.surfaceVariant,
              style: TextStyle(color: palette.textPrimary),
              items: SignalType.values.map((type) {
                String label;
                switch (type) {
                  case SignalType.gymHelp:
                    label = AppLocalizations.of(context)
                        .translate('signal.type.gym');
                    break;
                  case SignalType.mealShare:
                    label = AppLocalizations.of(context)
                        .translate('signal.type.meal');
                    break;
                  case SignalType.general:
                    label = AppLocalizations.of(context)
                        .translate('signal.type.general');
                    break;
                }
                return DropdownMenuItem(value: type, child: Text(label));
              }).toList(),
              onChanged: (val) {
                if (val != null) {
                  setState(() {
                    _selectedType = val;
                    _messageController.clear();
                  });
                }
              },
              decoration: InputDecoration(
                border: OutlineInputBorder(
                  borderSide: BorderSide(color: palette.border),
                ),
                enabledBorder: OutlineInputBorder(
                  borderSide: BorderSide(color: palette.border),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              AppLocalizations.of(context).translate('signal.message_label'),
              style: appText.labelL.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              children: (_presets[_selectedType] ?? []).map((preset) {
                return ActionChip(
                  label: Text(
                    AppLocalizations.of(context).translate(preset),
                    style: TextStyle(
                        fontSize: 12, color: palette.textSecondary),
                  ),
                  backgroundColor: palette.surfaceVariant,
                  onPressed: () {
                    _messageController.text =
                        AppLocalizations.of(context).translate(preset);
                  },
                );
              }).toList(),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _messageController,
              style: TextStyle(color: palette.textPrimary),
              decoration: InputDecoration(
                hintText: AppLocalizations.of(context)
                    .translate('signal.custom_message_hint'),
                hintStyle: TextStyle(color: palette.textTertiary),
                border: OutlineInputBorder(
                  borderSide: BorderSide(color: palette.border),
                ),
                enabledBorder: OutlineInputBorder(
                  borderSide: BorderSide(color: palette.border),
                ),
              ),
              maxLines: 2,
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(
            AppLocalizations.of(context).translate('signal.cancel'),
            style: TextStyle(color: palette.textSecondary),
          ),
        ),
        ElevatedButton(
          onPressed: _isLoading ? null : _sendSignal,
          style: ElevatedButton.styleFrom(
            backgroundColor: palette.error,
            foregroundColor: Colors.white,
            disabledBackgroundColor: palette.border,
          ),
          child: _isLoading
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                      strokeWidth: 2, color: Colors.white))
              : Text(AppLocalizations.of(context).translate('signal.send')),
        ),
      ],
    );
  }
}
