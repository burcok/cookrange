import 'package:flutter/material.dart';
import 'package:cookrange/core/localization/app_localizations.dart';
import '../../../core/models/signal_model.dart';
import '../../../core/services/signal_service.dart';

class SignalDialog extends StatefulWidget {
  const SignalDialog({super.key});

  @override
  State<SignalDialog> createState() => _SignalDialogState();
}

class _SignalDialogState extends State<SignalDialog> {
  final SignalService _signalService = SignalService();
  final TextEditingController _messageController = TextEditingController();
  SignalType _selectedType = SignalType.gym_help;
  bool _isLoading = false;

  final Map<SignalType, List<String>> _presets = {
    SignalType.gym_help: [
      "signal.presets.gym_1",
      "signal.presets.gym_2",
      "signal.presets.gym_3",
    ],
    SignalType.meal_share: [
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
        durationMinutes: 60, // Default 1 hour
      );
      if (mounted) {
        Navigator.pop(context, true); // Return success
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
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(AppLocalizations.of(context).translate('signal.title')),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(AppLocalizations.of(context).translate('signal.select_type'),
                style: const TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            DropdownButtonFormField<SignalType>(
              value: _selectedType,
              items: SignalType.values.map((type) {
                String label;
                switch (type) {
                  case SignalType.gym_help:
                    label = AppLocalizations.of(context)
                        .translate('signal.type.gym');
                    break;
                  case SignalType.meal_share:
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
              decoration: const InputDecoration(border: OutlineInputBorder()),
            ),
            const SizedBox(height: 16),
            Text(AppLocalizations.of(context).translate('signal.message_label'),
                style: const TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              children: (_presets[_selectedType] ?? []).map((preset) {
                return ActionChip(
                  label: Text(AppLocalizations.of(context).translate(preset),
                      style: const TextStyle(fontSize: 12)),
                  onPressed: () {
                    _messageController.text = preset;
                  },
                );
              }).toList(),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _messageController,
              decoration: InputDecoration(
                hintText: AppLocalizations.of(context)
                    .translate('signal.custom_message_hint'),
                border: const OutlineInputBorder(),
              ),
              maxLines: 2,
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(AppLocalizations.of(context).translate('signal.cancel')),
        ),
        ElevatedButton(
          onPressed: _isLoading ? null : _sendSignal,
          child: _isLoading
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2))
              : Text(AppLocalizations.of(context).translate('signal.send')),
        ),
      ],
    );
  }
}
