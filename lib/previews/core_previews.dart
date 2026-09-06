// lib/previews/core_previews.dart
import 'package:flutter/material.dart';
import 'package:flutter/widget_previews.dart';
import '../core/theme/app_theme.dart';
import '../core/theme/app_colors.dart';
import '../core/widgets/app_button.dart';
import '../core/widgets/app_text_field.dart';
import '../core/widgets/app_badge.dart';
import '../core/widgets/app_stat_card.dart';
import '../core/widgets/app_empty_state.dart';
import '../core/widgets/app_error_state.dart';

Widget _wrapCore(Widget child, {bool isDark = true}) {
  return MaterialApp(
    debugShowCheckedModeBanner: false,
    theme: isDark ? AppTheme.dark() : AppTheme.light(),
    home: Scaffold(
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: child,
        ),
      ),
    ),
  );
}

@Preview(name: 'AppButton - Variants', group: 'Core Widgets')
Widget previewButtons() => _wrapCore(
  Column(
    mainAxisSize: MainAxisSize.min,
    children: [
      AppButton(
        text: 'Primary Filled',
        onPressed: () {},
        icon: const Icon(Icons.fitness_center, size: 18),
      ),
      const SizedBox(height: 12),
      AppButton(
        text: 'Outlined Button',
        variant: AppButtonVariant.outlined,
        onPressed: () {},
        icon: const Icon(Icons.person_outline, size: 18),
      ),
      const SizedBox(height: 12),
      AppButton(
        text: 'Tonal Button',
        variant: AppButtonVariant.tonal,
        onPressed: () {},
        icon: const Icon(Icons.bolt, size: 18),
      ),
      const SizedBox(height: 12),
      const AppButton(
        text: 'Disabled Button',
        enabled: false,
      ),
    ],
  ),
);

@Preview(name: 'AppTextField - States', group: 'Core Widgets')
Widget previewTextFields() => _wrapCore(
  ConstrainedBox(
    constraints: const BoxConstraints(maxWidth: 340),
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: const [
        AppTextField(
          label: 'Username',
          hint: 'Enter your username',
        ),
        SizedBox(height: 16),
        AppTextField(
          label: 'Password',
          obscure: true,
          hint: 'Enter your password',
        ),
        SizedBox(height: 16),
        AppTextField(
          label: 'With Error',
          errorText: 'This field is required.',
        ),
      ],
    ),
  ),
);

@Preview(name: 'StatCard - Grid', group: 'Core Widgets')
Widget previewStatCard() => _wrapCore(
  ConstrainedBox(
    constraints: const BoxConstraints(maxWidth: 340),
    child: Row(
      children: const [
        Expanded(
          child: StatCard(
            data: StatCardData(
              title: 'Active Members',
              value: '248',
              subtitle: '+12% this month',
              icon: Icon(Icons.people_alt_rounded),
            ),
          ),
        ),
        SizedBox(width: 12),
        Expanded(
          child: StatCard(
            data: StatCardData(
              title: 'Today Visits',
              value: '42',
              subtitle: 'Peak hours: 6-8 PM',
              icon: Icon(Icons.qr_code_scanner_rounded),
            ),
          ),
        ),
      ],
    ),
  ),
);

@Preview(name: 'Badges - Status Variants', group: 'Core Widgets')
Widget previewBadges() => _wrapCore(
  Wrap(
    spacing: 8,
    runSpacing: 8,
    children: const [
      AppBadge(label: 'Active', color: AppColors.statusActive),
      AppBadge(label: 'Paused', color: AppColors.statusPaused),
      AppBadge(label: 'Expired', color: AppColors.statusExpired),
      AppBadge(label: 'Canceled', color: AppColors.statusCanceled),
      AppBadge(label: 'Open Issue', color: AppColors.statusOpen),
      AppBadge(label: 'Resolved', color: AppColors.statusResolved),
    ],
  ),
);

@Preview(name: 'Empty State', group: 'Core Widgets')
Widget previewEmptyState() => _wrapCore(
  const AppEmptyState(
    message: 'Add your first gym member to get started.',
    icon: Icons.person_search_rounded,
    actionLabel: 'Add Member',
  ),
);

@Preview(name: 'Error State', group: 'Core Widgets')
Widget previewErrorState() => _wrapCore(
  AppErrorState(
    message: 'Failed to connect to the server.',
    onRetry: () {},
  ),
);
