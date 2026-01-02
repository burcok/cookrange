import 'package:flutter/material.dart';
import '../../core/services/auth_service.dart';
import '../../core/models/user_model.dart';
import '../../constants.dart';
import '../../core/services/storage_service.dart';
import '../../core/providers/user_provider.dart';
import 'package:provider/provider.dart';

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
  String? _selectedGoal;
  String? _selectedActivity;
  bool _isLoading = false;

  final List<Map<String, String>> _goals = [
    {'value': 'Lose Weight', 'label': 'Lose Weight'},
    {'value': 'Maintain Weight', 'label': 'Maintain Weight'},
    {'value': 'Gain Weight', 'label': 'Gain Weight'},
    {'value': 'Build Muscle', 'label': 'Build Muscle'},
  ];

  final List<Map<String, String>> _activityLevels = [
    {'value': 'Sedentary', 'label': 'Sedentary (Little/No exercise)'},
    {'value': 'Lightly Active', 'label': 'Lightly Active (1-3 days/week)'},
    {
      'value': 'Moderately Active',
      'label': 'Moderately Active (3-5 days/week)'
    },
    {'value': 'Very Active', 'label': 'Very Active (6-7 days/week)'},
    {'value': 'Extra Active', 'label': 'Extra Active (Hard exercise/job)'},
  ];

  @override
  void initState() {
    super.initState();
    final data = widget.user.onboardingData ?? {};
    _weightController =
        TextEditingController(text: (data['weight'] ?? '').toString());
    _heightController =
        TextEditingController(text: (data['height'] ?? '').toString());

    _selectedGoal = (data['primary_goals'] as List?)?.isNotEmpty ?? false
        ? (data['primary_goals'] as List).first['value'] as String?
        : 'Maintain Weight';

    _selectedActivity =
        (data['activity_level'] as Map?)?['value'] as String? ?? 'Sedentary';
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
      updatedData['primary_goals'] = [
        {'value': _selectedGoal, 'label': _selectedGoal}
      ];
      updatedData['activity_level'] = {
        'value': _selectedActivity,
        'label': _activityLevels
            .firstWhere((e) => e['value'] == _selectedActivity)['label']
      };

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
              _buildDropdown("Primary Goal", _selectedGoal, _goals, (val) {
                setState(() => _selectedGoal = val);
              }),
              const SizedBox(height: 20),
              _buildDropdown(
                  "Activity Level", _selectedActivity, _activityLevels, (val) {
                setState(() => _selectedActivity = val);
              }),
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
