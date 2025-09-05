import 'package:flutter/material.dart';

class PriorityOnboardingScreen extends StatefulWidget {
  const PriorityOnboardingScreen({super.key});

  @override
  State<PriorityOnboardingScreen> createState() =>
      _PriorityOnboardingScreenState();
}

class _PriorityOnboardingScreenState extends State<PriorityOnboardingScreen> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Priority Onboarding'),
      ),
      body: const Center(
        child: Text('This is the priority onboarding screen.'),
      ),
    );
  }
}
