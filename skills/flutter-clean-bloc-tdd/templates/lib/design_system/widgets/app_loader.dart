import 'package:flutter/material.dart';

/// Full-area loading indicator.
class AppLoader extends StatelessWidget {
  /// Creates an [AppLoader].
  const AppLoader({super.key});

  @override
  Widget build(BuildContext context) =>
      const Center(child: CircularProgressIndicator());
}
