import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/services/auth_service.dart';
import '../../core/models/user_model.dart';
import '../../core/services/storage_service.dart';
import '../../core/providers/user_provider.dart';
import '../../core/constants/onboarding_options.dart';
import '../../core/localization/app_localizations.dart';
import '../../constants.dart';
import 'edit_profile_screen.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  @override
  void initState() {
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Profile',
            style: TextStyle(fontWeight: FontWeight.bold)),
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.edit_outlined),
            onPressed: () async {
              final user = context.read<UserProvider>().user;
              if (user != null && context.mounted) {
                await Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => EditProfileScreen(user: user),
                  ),
                );
              }
            },
          ),
          IconButton(
            icon: const Icon(Icons.settings_outlined),
            onPressed: () {
              // Placeholder for settings
            },
          ),
        ],
      ),
      body: Consumer<UserProvider>(
        builder: (context, userProvider, child) {
          if (userProvider.isLoading && userProvider.user == null) {
            return const Center(child: CircularProgressIndicator());
          }
          final user = userProvider.user;
          if (user == null) {
            return const Center(child: Text('Failed to load profile.'));
          }
          return _buildProfileBody(context, user);
        },
      ),
    );
  }

  Widget _buildProfileBody(BuildContext context, UserModel user) {
    final onboardingData = user.onboardingData ?? {};
    final weight = (onboardingData['weight'] as num?)?.toDouble() ?? 0.0;
    final height = (onboardingData['height'] as num?)?.toDouble() ?? 0.0;
    final birthDateStr = onboardingData['birth_date'] as String?;
    final gender = onboardingData['gender'] as String? ?? 'Not specified';

    int age = 0;
    if (birthDateStr != null) {
      final birthDate = DateTime.parse(birthDateStr);
      age = DateTime.now().difference(birthDate).inDays ~/ 365;
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20.0),
      child: Column(
        children: [
          _buildHeader(user),
          const SizedBox(height: 32),
          _buildSectionTitle("Physical Info"),
          const SizedBox(height: 12),
          _buildStatsGrid(weight, height, age, gender),
          const SizedBox(height: 32),
          _buildSectionTitle("Goals"),
          const SizedBox(height: 12),
          _buildGoalsSection(onboardingData),
          const SizedBox(height: 32),
          _buildSectionTitle("Weight History"),
          const SizedBox(height: 12),
          _buildWeightHistory(),
          const SizedBox(height: 48),
          _buildLogoutButton(context),
        ],
      ),
    );
  }

  Widget _buildWeightHistory() {
    final storage = StorageService();
    final history = storage.getWeightHistory();

    return Column(
      children: [
        if (history.isEmpty)
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: Colors.grey[100],
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Center(
              child: Text("No weight history yet.",
                  style: TextStyle(color: Colors.grey)),
            ),
          )
        else
          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: history.length > 5 ? 5 : history.length,
            separatorBuilder: (context, index) => const Divider(),
            itemBuilder: (context, index) {
              final item = history[index];
              return ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.show_chart, color: primaryColor),
                title: Text("${item['weight']} kg",
                    style: const TextStyle(fontWeight: FontWeight.bold)),
                subtitle: Text(item['date']),
              );
            },
          ),
        const SizedBox(height: 12),
        TextButton.icon(
          onPressed: _showAddWeightDialog,
          icon: const Icon(Icons.add),
          label: const Text("Log Weight"),
        ),
      ],
    );
  }

  void _showAddWeightDialog() {
    final controller = TextEditingController();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Log Current Weight"),
        content: TextField(
          controller: controller,
          keyboardType: TextInputType.number,
          decoration: const InputDecoration(
            labelText: "Weight (kg)",
            suffixText: "kg",
          ),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text("Cancel")),
          ElevatedButton(
            onPressed: () async {
              final weight = double.tryParse(controller.text);
              if (weight != null) {
                final navigator = Navigator.of(context);
                await StorageService().saveWeight(DateTime.now(), weight);
                if (mounted) {
                  navigator.pop();
                  setState(() {}); // Refresh history
                }
              }
            },
            child: const Text("Save"),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader(UserModel user) {
    return Column(
      children: [
        CircleAvatar(
          radius: 50,
          backgroundColor: primaryColor.withValues(alpha: 0.1),
          child: user.photoURL != null
              ? ClipOval(child: Image.network(user.photoURL!))
              : const Icon(Icons.person, size: 50, color: primaryColor),
        ),
        const SizedBox(height: 16),
        Text(
          user.displayName ?? "User Name",
          style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
        ),
        Text(
          user.email ?? "",
          style: TextStyle(color: Colors.grey[600], fontSize: 16),
        ),
      ],
    );
  }

  Widget _buildSectionTitle(String title) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Text(
        title,
        style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
      ),
    );
  }

  Widget _buildStatsGrid(double weight, double height, int age, String gender) {
    return GridView.count(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisCount: 2,
      mainAxisSpacing: 12,
      crossAxisSpacing: 12,
      childAspectRatio: 2.5,
      children: [
        _statTile("Weight", "$weight kg", Icons.monitor_weight_outlined),
        _statTile("Height", "$height cm", Icons.height_outlined),
        _statTile("Age", "$age years", Icons.cake_outlined),
        _statTile("Gender", gender, Icons.person_outline),
      ],
    );
  }

  Widget _statTile(String label, String value, IconData icon) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.grey[100],
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Icon(icon, color: primaryColor, size: 24),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(label,
                  style: TextStyle(color: Colors.grey[600], fontSize: 12)),
              Text(value,
                  style: const TextStyle(
                      fontWeight: FontWeight.bold, fontSize: 14)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildGoalsSection(Map<String, dynamic> data) {
    final localizations = AppLocalizations.of(context);

    // Resolve primary goal
    String primaryGoalLabel = 'N/A';
    final primaryGoals = data['primary_goals'] as List?;
    if (primaryGoals != null && primaryGoals.isNotEmpty) {
      final firstGoal = primaryGoals.first;
      if (firstGoal is String) {
        // New format (ID)
        final option = OnboardingOptions.primaryGoals[firstGoal];
        primaryGoalLabel = option != null
            ? localizations.translate(option['label'] as String)
            : firstGoal;
      } else if (firstGoal is Map && firstGoal.containsKey('label')) {
        // Old format (Map)
        primaryGoalLabel = firstGoal['label'] as String;
      }
    }

    // Resolve activity level
    String activityLevelLabel = 'N/A';
    final activityLevel = data['activity_level'];
    if (activityLevel is String) {
      // New format (ID)
      final option = OnboardingOptions.activityLevels[activityLevel];
      activityLevelLabel = option != null
          ? localizations.translate(option['label'] as String)
          : activityLevel;
    } else if (activityLevel is Map && activityLevel.containsKey('label')) {
      // Old format (Map)
      activityLevelLabel = activityLevel['label'] as String;
    }

    return Column(
      children: [
        _goalTile("Active Goal", primaryGoalLabel, Icons.flag_outlined),
        const SizedBox(height: 8),
        _goalTile("Activity Level", activityLevelLabel,
            Icons.directions_run_outlined),
      ],
    );
  }

  Widget _goalTile(String label, String value, IconData icon) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.grey[100],
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Icon(icon, color: primaryColor),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label,
                    style: TextStyle(color: Colors.grey[600], fontSize: 12)),
                Text(value,
                    style: const TextStyle(
                        fontWeight: FontWeight.bold, fontSize: 16)),
              ],
            ),
          ),
          const Icon(Icons.edit_outlined, size: 20, color: Colors.grey),
        ],
      ),
    );
  }

  Widget _buildLogoutButton(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: OutlinedButton(
        onPressed: () async {
          final navigator = Navigator.of(context);
          await AuthService().signOut();
          if (mounted) {
            navigator.pushNamedAndRemoveUntil('/login', (route) => false);
          }
        },
        style: OutlinedButton.styleFrom(
          foregroundColor: Colors.red,
          side: const BorderSide(color: Colors.red),
          padding: const EdgeInsets.symmetric(vertical: 16),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
        child:
            const Text("Logout", style: TextStyle(fontWeight: FontWeight.bold)),
      ),
    );
  }
}
