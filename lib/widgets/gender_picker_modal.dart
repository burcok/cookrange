import 'package:flutter/material.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/localization/app_localizations.dart';

class GenderPickerModal extends StatelessWidget {
  final String? selectedGender;
  final void Function(String gender) onSelected;
  const GenderPickerModal(
      {super.key, required this.selectedGender, required this.onSelected});

  @override
  Widget build(BuildContext context) {
    String? tempGender = selectedGender;
    final localizations = AppLocalizations.of(context);
    return StatefulBuilder(
      builder: (context, setModalState) {
        return Padding(
          padding: MediaQuery.of(context).viewInsets,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 18),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const SizedBox(height: 8),
                Text(
                  localizations.translate('profile.gender.title'),
                  style: const TextStyle(
                      fontWeight: FontWeight.bold, fontSize: 18),
                ),
                const SizedBox(height: 12),
                RadioListTile<String>(
                  value: localizations.translate('profile.gender.female'),
                  groupValue: tempGender,
                  onChanged: (val) {
                    setModalState(() {
                      tempGender = val;
                    });
                  },
                  title: Text(localizations.translate('profile.gender.female')),
                  activeColor:
                      Theme.of(context).colorScheme.onboardingNextButtonColor,
                ),
                RadioListTile<String>(
                  value: localizations.translate('profile.gender.male'),
                  groupValue: tempGender,
                  onChanged: (val) {
                    setModalState(() {
                      tempGender = val;
                    });
                  },
                  title: Text(localizations.translate('profile.gender.male')),
                  activeColor:
                      Theme.of(context).colorScheme.onboardingNextButtonColor,
                ),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Theme.of(context)
                          .colorScheme
                          .onboardingNextButtonColor,
                      foregroundColor: Theme.of(context)
                          .colorScheme
                          .onboardingNextButtonBorderColor,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    onPressed: tempGender != null
                        ? () {
                            onSelected(tempGender!);
                          }
                        : null,
                    child: Text(
                      localizations.translate('common.save'),
                      style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                          fontFamily: 'Poppins'),
                    ),
                  ),
                ),
                const SizedBox(height: 8),
              ],
            ),
          ),
        );
      },
    );
  }
}
