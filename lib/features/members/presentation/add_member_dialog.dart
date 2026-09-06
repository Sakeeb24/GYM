// lib/features/members/presentation/add_member_dialog.dart
// Owner / Front Desk Direct Athlete Enrollment Modal
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/services/supabase_client.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_radii.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/utils/app_error_mapper.dart';
import '../../../core/widgets/app_button.dart';
import '../../../core/widgets/app_text_field.dart';
import '../../auth/auth_notifier.dart';

class AddMemberDialog extends ConsumerStatefulWidget {
  const AddMemberDialog({super.key});

  @override
  ConsumerState<AddMemberDialog> createState() => _AddMemberDialogState();
}

class _AddMemberDialogState extends ConsumerState<AddMemberDialog> {
  final _fullName = TextEditingController();
  final _phone = TextEditingController();
  final _email = TextEditingController();
  bool _submitting = false;
  String? _error;

  @override
  void dispose() {
    _fullName.dispose();
    _phone.dispose();
    _email.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    setState(() => _error = null);
    final name = _fullName.text.trim();
    final phone = _phone.text.trim();
    final email = _email.text.trim();

    if (name.isEmpty) {
      setState(() => _error = 'Please enter member full name.');
      return;
    }
    if (phone.isEmpty || phone.length < 8) {
      setState(() => _error = 'Please enter a valid phone number.');
      return;
    }

    setState(() => _submitting = true);
    try {
      final profile = ref.read(authStateProvider).valueOrNull;
      if (profile == null) throw StateError('Not authenticated');

      final client = AppSupabase.client;

      // Generate next member number
      final countRes = await client
          .from('members')
          .select('id')
          .eq('gym_id', profile.gymId);

      final nextNumber = 'LF-${(countRes as List).length + 101}';

      await client.from('members').insert({
        'gym_id': profile.gymId,
        'full_name': name,
        'phone': phone,
        'email': email.isNotEmpty ? email : null,
        'member_number': nextNumber,
        'status': 'active',
      }).select().single();

      if (mounted) {
        Navigator.pop(context, true);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Athlete $name enrolled successfully (#$nextNumber)')),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _error = AppErrorMapper.toUserMessage(e));
      }
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Dialog(
      backgroundColor: isDark ? AppColors.dSurface : AppColors.lSurface,
      shape: RoundedRectangleBorder(borderRadius: AppRadii.card),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 440),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'ENROLL NEW ATHLETE',
                    style: AppTypography.labelAthletic.copyWith(
                      fontSize: 16,
                      letterSpacing: 1.5,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close_rounded),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              AppTextField(
                controller: _fullName,
                label: 'Full Name',
                hint: 'e.g. Marcus Vance',
                keyboard: TextInputType.name,
              ),
              const SizedBox(height: 12),
              AppTextField(
                controller: _phone,
                label: 'Phone Number',
                hint: '+91 98765 43210',
                keyboard: TextInputType.phone,
              ),
              const SizedBox(height: 12),
              AppTextField(
                controller: _email,
                label: 'Email (Optional)',
                hint: 'athlete@example.com',
                keyboard: TextInputType.emailAddress,
              ),
              const SizedBox(height: 16),

              if (_error != null) ...[
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: AppColors.error.withAlpha(25),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: AppColors.error),
                  ),
                  child: Text(
                    _error!,
                    style: AppTypography.bodySmall.copyWith(color: AppColors.error),
                  ),
                ),
                const SizedBox(height: 16),
              ],

              AppButton(
                text: 'Enroll Athlete',
                icon: const Icon(Icons.person_add_alt_1_rounded),
                loading: _submitting,
                onPressed: _submit,
                fullWidth: true,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
