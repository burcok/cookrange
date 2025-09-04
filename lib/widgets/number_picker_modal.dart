import 'package:flutter/material.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/localization/app_localizations.dart';

class NumberPickerModal extends StatelessWidget {
  final String title;
  final int min;
  final int max;
  final String unit;
  final int initialValue;
  const NumberPickerModal({
    super.key,
    required this.title,
    required this.min,
    required this.max,
    required this.unit,
    required this.initialValue,
  });

  @override
  Widget build(BuildContext context) {
    int tempIndex = initialValue - min;
    final localizations = AppLocalizations.of(context);
    return SizedBox(
      height: 300,
      child: Column(
        children: [
          const SizedBox(height: 12),
          Text(
            title,
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
          ),
          Expanded(
            child: ListWheelScrollView.useDelegate(
              itemExtent: 44,
              diameterRatio: 1.2,
              perspective: 0.003,
              physics: const FixedExtentScrollPhysics(),
              controller: FixedExtentScrollController(initialItem: tempIndex),
              onSelectedItemChanged: (i) {
                tempIndex = i;
              },
              childDelegate: ListWheelChildBuilderDelegate(
                builder: (context, i) {
                  if (i < 0 || i > max - min) return null;
                  return Center(
                    child: Text(
                      '${min + i} $unit',
                      style: const TextStyle(fontSize: 20),
                    ),
                  );
                },
                childCount: max - min + 1,
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor:
                      Theme.of(context).colorScheme.onboardingNextButtonColor,
                  foregroundColor: Theme.of(context)
                      .colorScheme
                      .onboardingNextButtonBorderColor,
                ),
                onPressed: () {
                  Navigator.of(context).pop(min + tempIndex);
                },
                child: Text(
                  localizations.translate('common.select'),
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
