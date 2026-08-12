import 'package:flutter/material.dart';
import 'package:lottie/lottie.dart';

/// Shared Lottie loading animation from `digital_wall/assets/lottie/loading.json`.
///
/// Usage:
/// ```dart
/// const AppLoader()
/// // or centered:
/// const Center(child: AppLoader())
/// ```
class AppLoader extends StatelessWidget {
  const AppLoader({
    super.key,
    this.size = 80,
    this.color = const Color.fromARGB(255, 57, 73, 95),
  });

  final double size;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return ColorFiltered(
      colorFilter: ColorFilter.mode(color, BlendMode.srcIn),
      child: Lottie.asset(
        'assets/lottie/loading.json',
        package: 'digital_wall',
        width: size,
        height: size,
        fit: BoxFit.contain,
        repeat: true,
      ),
    );
  }
}
