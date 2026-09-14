// lib/features/members/presentation/edit_member_dialog.dart
// Owner / Staff Athlete Details & Tags Editor Modal
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/models/member.dart';
import '../../../core/services/supabase_client.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_radii.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/utils/app_error_mapper.dart';
import '../../../core/widgets/app_button.dart';
import '../../../core/widgets/app_text_field.dart';

class EditMemberDialog extends ConsumerStatefulWidget {
  final Member member;

  const EditMemberDialog({
    super.key,
    required this.member,
  });

  @override
  ConsumerState<EditMemberDialog> createState() => _EditMemberDialogState();
}

class _EditMemberDialogState extends ConsumerState<EditMemberDialog> {
  late final TextEditingController _fullName;
  late final TextEditingController _phone;
  late final TextEditingController _email;
  late final TextEditingController _tagInput;
  late bool _isActive;
  late List<String> _tags;

  bool _submitting = false;
  String? _error;

  final List<String> _suggestedTags = const [
    'VIP',
    'Personal Training',
    'Morning Crew',
    'Evening Beast',
    'Student',
    'Competitor',
    'Newbie',
  ];

  @override
  void initState() {
    super.initState();
    _fullName = TextEditingController(text: widget.member.fullName);
    _phone = TextEditingController(text: widget.member.phone ?? '');
    _email = TextEditingController(text: widget.member.email ?? '');
    _tagInput = TextEditingController();
    _isActive = widget.member.isActive;
    _tags = List<String>.from(widget.member.tags);
  }

  @override
  void dispose() {
    _fullName.dispose();
    _phone.dispose();
    _email.dispose();
    _tagInput.dispose();
    super.dispose();
  }

  void _addTag(String tag) {
    final clean = tag.trim();
    if (clean.isNotEmpty && !_tags.contains(clean)) {
      setState(() {
        _tags.add(clean);
        _tagInput.clear();
      });
    }
  }

  void _removeTag(String tag) {
    setState(() {
      _tags.remove(tag);
    });
  }

  Future<void> _submit() async {
    setState(() => _error = null);
    final name = _fullName.text.trim();
    final phone = _phone.text.trim();
    final email = _email.text.trim();

    if (name.isEmpty) {
      setState(() => _error = 'Full name cannot be empty.');
      return;
    }
    if (phone.isEmpty || phone.length < 8) {
      setState(() => _error = 'Please provide a valid phone number.');
      return;
    }

    setState(() => _submitting = true);
    try {
      final client = AppSupabase.client;

      await client.from('members').update({
        'full_name': name,
        'phone': phone,
        'email': email.isNotEmpty ? email : null,
        'status': _isActive ? 'active' : 'inactive',
        'tags': _tags,
      }).eq('id', widget.member.id);

      if (mounted) {
        final updatedMember = widget.member.copyWith(
          fullName: name,
          phone: phone,
          email: email.isNotEmpty ? email : null,
          status: _isActive ? 'active' : 'inactive',
          tags: _tags,
          isActive: _isActive,
        );
        Navigator.pop(context, updatedMember);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Athlete $name updated successfully')),
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
    final cs = Theme.of(context).colorScheme;

    return Dialog(
      backgroundColor: isDark ? AppColors.dSurface : AppColors.lSurface,
      shape: RoundedRectangleBorder(borderRadius: AppRadii.card),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 480),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: AppColors.brand.withAlpha(25),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Icon(Icons.edit_note_rounded, color: AppColors.brand, size: 20),
                      ),
                      const SizedBox(width: 10),
                      Text(
                        'EDIT ATHLETE',
                        style: AppTypography.labelAthletic.copyWith(
                          fontSize: 16,
                          letterSpacing: 1.5,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ],
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

              // Membership Status Switch
              Container(
                decoration: BoxDecoration(
                  color: cs.surface,
                  borderRadius: AppRadii.r8,
                  border: Border.all(color: cs.outline),
                ),
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Account Status',
                            style: AppTypography.bodySmall.copyWith(
                              fontWeight: FontWeight.w700,
                              color: cs.onSurface,
                            ),
                          ),
                          Text(
                            _isActive ? 'Active Athlete (Allowed Check-in)' : 'Inactive / Deactivated',
                            style: AppTypography.bodySmall.copyWith(
                              fontSize: 11,
                              color: _isActive ? AppColors.brand : AppColors.warning,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Switch.adaptive(
                      value: _isActive,
                      activeTrackColor: AppColors.brand,
                      onChanged: (val) => setState(() => _isActive = val),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // Tags Section
              Text(
                'Athlete Tags & Categories',
                style: AppTypography.bodySmall.copyWith(
                  fontWeight: FontWeight.w700,
                  color: cs.onSurface,
                ),
              ),
              const SizedBox(height: 6),
              if (_tags.isNotEmpty)
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: _tags.map((tag) {
                    return Chip(
                      label: Text(
                        tag,
                        style: AppTypography.bodySmall.copyWith(fontSize: 11, fontWeight: FontWeight.w600),
                      ),
                      deleteIcon: const Icon(Icons.close_rounded, size: 14),
                      onDeleted: () => _removeTag(tag),
                      backgroundColor: isDark ? AppColors.brand.withAlpha(30) : AppColors.brandContainer,
                      side: BorderSide(color: cs.outline),
                      padding: const EdgeInsets.symmetric(horizontal: 4),
                    );
                  }).toList(),
                )
              else
                Text(
                  'No tags assigned yet.',
                  style: AppTypography.bodySmall.copyWith(fontSize: 11, color: cs.onSurfaceVariant),
                ),
              const SizedBox(height: 10),

              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _tagInput,
                      decoration: InputDecoration(
                        hintText: 'Add custom tag...',
                        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        border: OutlineInputBorder(borderRadius: AppRadii.r8),
                      ),
                      onSubmitted: _addTag,
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton(
                    icon: const Icon(Icons.add_circle_outline_rounded, color: AppColors.brand),
                    onPressed: () => _addTag(_tagInput.text),
                  ),
                ],
              ),
              const SizedBox(height: 8),

              // Suggested tag chips
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: _suggestedTags
                      .where((t) => !_tags.contains(t))
                      .take(4)
                      .map((tag) => Padding(
                            padding: const EdgeInsets.only(right: 6),
                            child: ActionChip(
                              label: Text(
                                '+ $tag',
                                style: AppTypography.bodySmall.copyWith(fontSize: 10),
                              ),
                              onPressed: () => _addTag(tag),
                              padding: const EdgeInsets.symmetric(horizontal: 2),
                            ),
                          ))
                      .toList(),
                ),
              ),
              const SizedBox(height: 20),

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
                text: 'Save Changes',
                icon: const Icon(Icons.check_rounded),
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
