// lib/core/widgets/app_loading_state.dart
import 'package:flutter/material.dart';

class AppLoadingState extends StatelessWidget {
  final double strokeWidth;
  final Color? color;

  const AppLoadingState({super.key, this.strokeWidth = 2.5, this.color});

  @override
  Widget build(BuildContext context) {
    final c = color ?? Theme.of(context).colorScheme.primary;
    return Center(child: SizedBox.square(dimension: 32, child: CircularProgressIndicator(strokeWidth: strokeWidth, color: c)));
  }
}
