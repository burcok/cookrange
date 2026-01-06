import 'package:flutter/material.dart';
import 'package:cookrange/core/localization/app_localizations.dart';

class PriorityOnboardingScreen extends StatelessWidget {
  const PriorityOnboardingScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(AppLocalizations.of(context)
            .translate('onboarding.priority.title')),
      ),
      body: Center(
        child: Text(AppLocalizations.of(context)
            .translate('onboarding.priority.description')),
      ),
    );
  }
}
