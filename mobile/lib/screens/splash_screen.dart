import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../theme.dart';
import '../widgets/ui.dart';

/// Shown for a moment while the saved session is read from secure storage.
class SplashScreen extends StatelessWidget {
  const SplashScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      child: Scaffold(
        body: Container(
          decoration: const BoxDecoration(gradient: AppColors.brand),
          child: const Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                AppLogo(onGradient: true, size: 88),
                SizedBox(height: 18),
                Text('HelpDesk Pro', style: TextStyle(color: Colors.white, fontSize: 28, fontWeight: FontWeight.w700)),
                SizedBox(height: 28),
                SizedBox.square(dimension: 26, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.6)),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
