import 'package:flutter/material.dart';
import '../../core/services/auth_service.dart';
import '../../core/utils/calorie_calculator.dart';
import 'package:intl/intl.dart';
import '../../core/models/user_model.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  late Future<UserModel?> _userDataFuture;

  @override
  void initState() {
    super.initState();
    _userDataFuture = _loadUserData();
  }

  Future<UserModel?> _loadUserData() async {
    final user = AuthService().currentUser;
    if (user != null) {
      return await AuthService().getUserData(user.uid);
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Home'),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () async {
              await AuthService().signOut();
              Navigator.pushNamedAndRemoveUntil(
                  context, '/login', (route) => false);
            },
          ),
        ],
      ),
      body: FutureBuilder<UserModel?>(
        future: _userDataFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          } else if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}'));
          } else if (!snapshot.hasData || snapshot.data == null) {
            return const Center(child: Text('User data not found.'));
          } else {
            final userModel = snapshot.data!;
            return _buildFullHomeScreen(context, userModel);
          }
        },
      ),
    );
  }

  Widget _buildFullHomeScreen(BuildContext context, UserModel userModel) {
    final onboardingData = userModel.onboardingData ?? {};
    // Extract data, providing sensible defaults to avoid null errors
    final height = (onboardingData['height'] as num?)?.toDouble() ?? 170.0;
    final weight = (onboardingData['weight'] as num?)?.toDouble() ?? 70.0;
    final birthDate = onboardingData['birth_date'] != null
        ? DateTime.parse(onboardingData['birth_date'] as String)
        : DateTime.now().subtract(
            const Duration(days: 365 * 30)); // Default to 30 years old
    final gender = onboardingData['gender'] as String? ?? 'Male';
    final activityLevel =
        onboardingData['activity_level'] as String? ?? 'Sedentary';
    final primaryGoal =
        (onboardingData['primary_goals'] as List<dynamic>?)?.isNotEmpty ?? false
            ? (onboardingData['primary_goals'] as List<dynamic>).first as String
            : 'Maintain Weight';

    // Calculate age
    final age = DateTime.now().difference(birthDate).inDays ~/ 365;

    // Perform calculations
    final bmr = CalorieCalculator.calculateBMR(
        weight: weight, height: height, age: age, gender: gender);
    final tdee =
        CalorieCalculator.calculateTDEE(bmr: bmr, activityLevel: activityLevel);
    final adjustedTDEE = CalorieCalculator.adjustTDEEForGoal(
        tdee: tdee, primaryGoal: primaryGoal);
    final macros = CalorieCalculator.calculateMacros(adjustedTDEE);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _buildWelcomeHeader(context, userModel),
          const SizedBox(height: 24),
          _buildCaloriesCard(context, adjustedTDEE),
          const SizedBox(height: 24),
          _buildMacrosGrid(context, macros),
          const SizedBox(height: 24),
          _buildMealPlanSection(context),
        ],
      ),
    );
  }

  Widget _buildWelcomeHeader(BuildContext context, UserModel userModel) {
    return Text(
      "Welcome back, ${userModel.displayName ?? userModel.email ?? 'User'}!",
      style: Theme.of(context)
          .textTheme
          .headlineSmall
          ?.copyWith(fontWeight: FontWeight.bold),
    );
  }

  Widget _buildCaloriesCard(BuildContext context, double calories) {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          children: [
            Text(
              "Your Daily Calorie Target",
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 12),
            Text(
              NumberFormat.decimalPattern().format(calories.toInt()),
              style: Theme.of(context).textTheme.displayMedium?.copyWith(
                    color: Theme.of(context).colorScheme.primary,
                    fontWeight: FontWeight.bold,
                  ),
            ),
            Text(
              "kcal",
              style: Theme.of(context).textTheme.bodyLarge,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMacrosGrid(BuildContext context, Map<String, double> macros) {
    return GridView.count(
      crossAxisCount: 3,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisSpacing: 16,
      mainAxisSpacing: 16,
      children: [
        _buildMacroCard(
            context, "Protein", macros['protein'] ?? 0, Colors.blue),
        _buildMacroCard(context, "Carbs", macros['carbs'] ?? 0, Colors.orange),
        _buildMacroCard(context, "Fat", macros['fat'] ?? 0, Colors.green),
      ],
    );
  }

  Widget _buildMacroCard(
      BuildContext context, String title, double grams, Color color) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              title,
              style: Theme.of(context)
                  .textTheme
                  .titleMedium
                  ?.copyWith(fontWeight: FontWeight.bold, color: color),
            ),
            const SizedBox(height: 8),
            Text(
              "${grams.toInt()}g",
              style: Theme.of(context).textTheme.headlineSmall,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMealPlanSection(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          "Your Daily Meal Plan",
          style: Theme.of(context)
              .textTheme
              .headlineSmall
              ?.copyWith(fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 16),
        const Card(
          child: ListTile(
            leading: Icon(Icons.breakfast_dining),
            title: Text("Breakfast Suggestion"),
            subtitle: Text("Details about the meal..."),
          ),
        ),
        const Card(
          child: ListTile(
            leading: Icon(Icons.lunch_dining),
            title: Text("Lunch Suggestion"),
            subtitle: Text("Details about the meal..."),
          ),
        ),
        const Card(
          child: ListTile(
            leading: Icon(Icons.dinner_dining),
            title: Text("Dinner Suggestion"),
            subtitle: Text("Details about the meal..."),
          ),
        ),
      ],
    );
  }
}
