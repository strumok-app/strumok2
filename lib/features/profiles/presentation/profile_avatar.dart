import 'package:flutter/material.dart';

import '../domain/profile.dart';

/// Circle with the profile color and initial (Google photo arrives with account linking, M4).
class ProfileAvatar extends StatelessWidget {
  final Profile profile;
  final double radius;

  const ProfileAvatar({super.key, required this.profile, this.radius = 20});

  @override
  Widget build(BuildContext context) {
    final color = Color(profile.colorSeed);
    final foreground = ThemeData.estimateBrightnessForColor(color) == Brightness.dark ? Colors.white : Colors.black;
    return CircleAvatar(
      radius: radius,
      backgroundColor: color,
      child: Text(
        profile.initial,
        style: TextStyle(color: foreground, fontSize: radius * 0.9, fontWeight: FontWeight.w600),
      ),
    );
  }
}
