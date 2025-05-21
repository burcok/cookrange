import 'package:flutter/material.dart';
import '../../../core/theme/app_theme.dart';

class GenderPickerModal extends StatelessWidget {
  final String? selectedGender;
  final void Function(String gender) onSelected;
  const GenderPickerModal(
      {Key? key, required this.selectedGender, required this.onSelected})
      : super(key: key);

  @override
  Widget build(BuildContext context) {
    String? tempGender = selectedGender;
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
                const Text('Cinsiyetini Seç',
                    style:
                        TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
                const SizedBox(height: 12),
                RadioListTile<String>(
                  value: 'Kadın',
                  groupValue: tempGender,
                  onChanged: (val) {
                    setModalState(() {
                      tempGender = val;
                    });
                  },
                  title: const Text('Kadın'),
                  activeColor:
                      Theme.of(context).colorScheme.onboardingNextButtonColor,
                ),
                RadioListTile<String>(
                  value: 'Erkek',
                  groupValue: tempGender,
                  onChanged: (val) {
                    setModalState(() {
                      tempGender = val;
                    });
                  },
                  title: const Text('Erkek'),
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
                            Navigator.of(context).pop();
                          }
                        : null,
                    child: const Text(
                      'Kaydet',
                      style: TextStyle(
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
