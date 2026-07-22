import 'package:flutter/material.dart';

class InitialAvatar extends StatelessWidget {
  final String name;
  final double radius;

  const InitialAvatar({
    super.key,
    required this.name,
    this.radius = 16,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final initial = (name.isNotEmpty ? name.trim()[0] : '?').toUpperCase();
    return CircleAvatar(
      radius: radius,
      backgroundColor: theme.primaryColor.withOpacity(0.15),
      child: Text(
        initial,
        style: TextStyle(
          color: theme.primaryColor,
          fontWeight: FontWeight.bold,
          fontSize: radius,
        ),
      ),
    );
  }
}


