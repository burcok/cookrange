import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/services/auth_service.dart';
import '../../core/models/user_model.dart';
import '../../core/services/storage_service.dart';
import '../../core/providers/user_provider.dart';
import '../../core/constants/onboarding_options.dart';
import '../../core/localization/app_localizations.dart';
import '../../constants.dart';

class EditProfileScreen extends StatefulWidget {
  final UserModel user;
  const EditProfileScreen({super.key, required this.user});

  @override
  State<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends State<EditProfileScreen> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _weightController;
  late TextEditingController _heightController;
  String? _selectedGoalId;
  String? _selectedActivityId;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    final data = widget.user.onboardingData ?? {};
    _weightController =
        TextEditingController(text: (data['weight'] ?? '').toString());
    _heightController =
        TextEditingController(text: (data['height'] ?? '').toString());

    // Resolve goal ID (handle both new ID format and old Map format)
    final goals = data['primary_goals'] as List?;
    if (goals != null && goals.isNotEmpty) {
      final firstGoal = goals.first;
      if (firstGoal is String) {
        _selectedGoalId = firstGoal;
      } else if (firstGoal is Map) {
        // Try to find matching ID by value or label from old data
        final value = firstGoal['value'] as String?;
        _selectedGoalId = OnboardingOptions.primaryGoals.keys.firstWhere(
          (key) => key == value?.toLowerCase().replaceAll(' ', '_'),
          orElse: () => OnboardingOptions.primaryGoals.keys.first,
        );
      }
    }
    _selectedGoalId ??= OnboardingOptions.primaryGoals.keys.first;

    // Resolve activity ID
    final activity = data['activity_level'];
    if (activity is String) {
      _selectedActivityId = activity;
    } else if (activity is Map) {
      final value = activity['value'] as String?;
      _selectedActivityId = OnboardingOptions.activityLevels.keys.firstWhere(
        (key) => key == value?.toLowerCase().replaceAll(' ', '_'),
        orElse: () => OnboardingOptions.activityLevels.keys.first,
      );
    }
    _selectedActivityId ??= OnboardingOptions.activityLevels.keys.first;
  }

  @override
  void dispose() {
    _weightController.dispose();
    _heightController.dispose();
    super.dispose();
  }

  Future<void> _saveProfile() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);
    try {
      final updatedData =
          Map<String, dynamic>.from(widget.user.onboardingData ?? {});
      updatedData['weight'] = double.parse(_weightController.text);
      updatedData['height'] = double.parse(_heightController.text);
      updatedData['primary_goals'] = [_selectedGoalId];
      updatedData['activity_level'] = _selectedActivityId;

      await AuthService().updateUserData({
        'onboarding_data': updatedData,
      });

      // Update local storage too
      final storage = StorageService();
      final localUser = storage.getUser();
      if (localUser != null) {
        localUser['onboarding_data'] = updatedData;
        await storage.saveUser(localUser);
      }

      if (mounted) {
        final navigator = Navigator.of(context);
        await context.read<UserProvider>().refreshUser();
        navigator.pop(true);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error updating profile: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final localizations = AppLocalizations.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Edit Profile'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20.0),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _buildTextField("Weight (kg)", _weightController),
              const SizedBox(height: 20),
              _buildTextField("Height (cm)", _heightController),
              const SizedBox(height: 20),
              _buildDropdown(
                "Primary Goal",
                _selectedGoalId,
                OnboardingOptions.primaryGoals.entries
                    .map((e) => {
                          'value': e.key,
                          'label': localizations
                              .translate(e.value['label'] as String),
                        })
                    .toList(),
                (val) => setState(() => _selectedGoalId = val),
              ),
              const SizedBox(height: 20),
              _buildDropdown(
                "Activity Level",
                _selectedActivityId,
                OnboardingOptions.activityLevels.entries
                    .map((e) => {
                          'value': e.key,
                          'label': localizations
                              .translate(e.value['label'] as String),
                        })
                    .toList(),
                (val) => setState(() => _selectedActivityId = val),
              ),
              const SizedBox(height: 40),
              ElevatedButton(
                onPressed: _isLoading ? null : _saveProfile,
                style: ElevatedButton.styleFrom(
                  backgroundColor: primaryColor,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                ),
                child: _isLoading
                    ? const CircularProgressIndicator(color: Colors.white)
                    : const Text("Save Changes",
                        style: TextStyle(
                            color: Colors.white, fontWeight: FontWeight.bold)),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTextField(String label, TextEditingController controller) {
    return TextFormField(
      controller: controller,
      keyboardType: TextInputType.number,
      decoration: InputDecoration(
        labelText: label,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
      ),
      validator: (value) {
        if (value == null || value.isEmpty) return 'Required';
        if (double.tryParse(value) == null) return 'Invalid number';
        return null;
      },
    );
  }

  Widget _buildDropdown(String label, String? value,
      List<Map<String, String>> items, Function(String?) onChanged) {
    return DropdownButtonFormField<String>(
      value: value,
      decoration: InputDecoration(
        labelText: label,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
      ),
      items: items.map((item) {
        return DropdownMenuItem(
          value: item['value'],
          child: Text(item['label']!),
        );
      }).toList(),
      onChanged: onChanged,
    );
  }
}
