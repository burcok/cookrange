import 'package:flutter/material.dart';
import '../constants.dart';

class CustomBackButton extends StatelessWidget {
  final VoidCallback onTap;
  const CustomBackButton({super.key, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return IconButton(
      icon: Icon(Icons.arrow_back, color: secondaryColor, size: 28),
      onPressed: onTap,
    );
  }
}
