// lib/features/members/presentation/renew_membership_dialog.dart
// Owner / Staff Membership Renewal & Plan Switching Modal
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/models/member.dart';
import '../../../core/services/supabase_client.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_radii.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/utils/app_error_mapper.dart';
import '../../../core/widgets/app_button.dart';
import '../../auth/auth_notifier.dart';

class RenewMembershipDialog extends ConsumerStatefulWidget {
  final Member member;
  final String? currentPlanName;
  final DateTime? currentExpiresAt;

  const RenewMembershipDialog({
    super.key,
    required this.member,
    this.currentPlanName,
    this.currentExpiresAt,
  });

  @override
  ConsumerState<RenewMembershipDialog> createState() => _RenewMembershipDialogState();
}

class _RenewMembershipDialogState extends ConsumerState<RenewMembershipDialog> {
  bool _loadingPlans = true;
  bool _submitting = false;
  String? _error;

  List<Map<String, dynamic>> _plans = [];
  Map<String, dynamic>? _selectedPlan;
  int _extensionDays = 30;
  DateTime? _computedNewExpiry;

  @override
  void initState() {
    super.initState();
    _loadGymPlans();
  }

  Future<void> _loadGymPlans() async {
    if (!AppSupabase.isConfigured) {
      _loadFallbackPlans();
      return;
    }

    try {
      final profile = ref.read(authStateProvider).valueOrNull;
      if (profile == null) {
        _loadFallbackPlans();
        return;
      }

      final client = AppSupabase.client;
      final res = await client
          .from('membership_plans')
          .select('id, name, duration_days, price_cents, currency, billing_interval')
          .eq('gym_id', profile.gymId)
          .eq('is_active', true)
          .order('duration_days', ascending: true);

      final fetched = List<Map<String, dynamic>>.from(res as List);
      if (fetched.isNotEmpty) {
        if (mounted) {
          setState(() {
            _plans = fetched;
            _selectedPlan = fetched.first;
            _extensionDays = (_selectedPlan!['duration_days'] as num?)?.toInt() ?? 30;
            _updateComputedExpiry();
            _loadingPlans = false;
          });
        }
      } else {
        _loadFallbackPlans();
      }
    } catch (_) {
      _loadFallbackPlans();
    }
  }

  void _loadFallbackPlans() {
    final fallback = [
      {
        'id': 'fallback_monthly',
        'name': 'Standard Monthly (30 Days)',
        'duration_days': 30,
        'price_cents': 199900,
        'currency': 'INR',
      },
      {
        'id': 'fallback_quarterly',
        'name': 'Quarterly Athletic Pass (90 Days)',
        'duration_days': 90,
        'price_cents': 499900,
        'currency': 'INR',
      },
      {
        'id': 'fallback_annual',
        'name': 'Annual Elite Pass (365 Days)',
        'duration_days': 365,
        'price_cents': 1499900,
        'currency': 'INR',
      },
    ];
    if (mounted) {
      setState(() {
        _plans = fallback;
        _selectedPlan = fallback.first;
        _extensionDays = 30;
        _updateComputedExpiry();
        _loadingPlans = false;
      });
    }
  }

  void _updateComputedExpiry() {
    final baseDate = (widget.currentExpiresAt != null && widget.currentExpiresAt!.isAfter(DateTime.now()))
        ? widget.currentExpiresAt!
        : DateTime.now();

    _computedNewExpiry = baseDate.add(Duration(days: _extensionDays));
  }

  void _onSelectPlan(Map<String, dynamic> plan) {
    setState(() {
      _selectedPlan = plan;
      _extensionDays = (plan['duration_days'] as num?)?.toInt() ?? 30;
      _updateComputedExpiry();
    });
  }

  Future<void> _submit() async {
    if (_selectedPlan == null) return;
    setState(() => _error = null);

    final profile = ref.read(authStateProvider).valueOrNull;
    if (profile == null) {
      setState(() => _error = 'Authentication state missing');
      return;
    }

    setState(() => _submitting = true);
    try {
      final client = AppSupabase.client;
      final planId = _selectedPlan!['id'] as String;
      final newExpiry = _computedNewExpiry ?? DateTime.now().add(Duration(days: _extensionDays));

      // 1. Check if member already has an active/paused/frozen membership
      final activeMembership = await client
          .from('memberships')
          .select('id')
          .eq('member_id', widget.member.id)
          .inFilter('status', ['active', 'paused', 'frozen'])
          .maybeSingle();

      if (activeMembership != null) {
        // Update existing row
        final memId = activeMembership['id'] as String;
        final updateData = <String, dynamic>{
          'status': 'active',
          'expires_at': newExpiry.toUtc().toIso8601String(),
          'updated_at': DateTime.now().toUtc().toIso8601String(),
        };
        if (!planId.startsWith('fallback_')) {
          updateData['plan_id'] = planId;
        }

        await client.from('memberships').update(updateData).eq('id', memId);
      } else {
        // Find a valid plan_id from db if fallback was selected
        String targetPlanId = planId;
        if (targetPlanId.startsWith('fallback_')) {
          final firstDbPlan = await client
              .from('membership_plans')
              .select('id')
              .eq('gym_id', profile.gymId)
              .limit(1)
              .maybeSingle();

          if (firstDbPlan != null) {
            targetPlanId = firstDbPlan['id'] as String;
          } else {
            // Create a default plan on the fly if gym has none
            final newPlan = await client.from('membership_plans').insert({
              'gym_id': profile.gymId,
              'name': _selectedPlan!['name'],
              'duration_days': _extensionDays,
              'price_cents': _selectedPlan!['price_cents'] ?? 199900,
              'currency': _selectedPlan!['currency'] ?? 'INR',
              'is_active': true,
            }).select('id').single();
            targetPlanId = newPlan['id'] as String;
          }
        }

        await client.from('memberships').insert({
          'gym_id': profile.gymId,
          'member_id': widget.member.id,
          'plan_id': targetPlanId,
          'status': 'active',
          'started_at': DateTime.now().toUtc().toIso8601String(),
          'expires_at': newExpiry.toUtc().toIso8601String(),
        });
      }

      // 2. Ensure member status is 'active' in members table
      await client.from('members').update({
        'status': 'active',
      }).eq('id', widget.member.id);

      if (mounted) {
        Navigator.pop(context, true);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Membership renewed successfully for ${widget.member.fullName} until ${_computedNewExpiry!.year}-${_computedNewExpiry!.month.toString().padLeft(2, '0')}-${_computedNewExpiry!.day.toString().padLeft(2, '0')}',
            ),
          ),
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

    final currExpiryStr = widget.currentExpiresAt != null
        ? '${widget.currentExpiresAt!.year}-${widget.currentExpiresAt!.month.toString().padLeft(2, '0')}-${widget.currentExpiresAt!.day.toString().padLeft(2, '0')}'
        : 'None / Expired';

    final newExpiryStr = _computedNewExpiry != null
        ? '${_computedNewExpiry!.year}-${_computedNewExpiry!.month.toString().padLeft(2, '0')}-${_computedNewExpiry!.day.toString().padLeft(2, '0')}'
        : '—';

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
                        child: const Icon(Icons.autorenew_rounded, color: AppColors.brand, size: 20),
                      ),
                      const SizedBox(width: 10),
                      Text(
                        'RENEW MEMBERSHIP',
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
              const SizedBox(height: 12),
              Text(
                'Athlete: ${widget.member.fullName} (#LF-${widget.member.memberNumber})',
                style: AppTypography.bodySmall.copyWith(
                  fontWeight: FontWeight.w600,
                  color: cs.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 14),

              // Current Status Banner
              Container(
                decoration: BoxDecoration(
                  color: cs.surface,
                  borderRadius: AppRadii.r8,
                  border: Border.all(color: cs.outline),
                ),
                padding: const EdgeInsets.all(12),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Current Plan', style: AppTypography.bodySmall.copyWith(fontSize: 11, color: cs.onSurfaceVariant)),
                        Text(widget.currentPlanName ?? 'Standard Plan', style: AppTypography.bodyMedium.copyWith(fontWeight: FontWeight.w700)),
                      ],
                    ),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text('Current Expiry', style: AppTypography.bodySmall.copyWith(fontSize: 11, color: cs.onSurfaceVariant)),
                        Text(currExpiryStr, style: AppTypography.bodyMedium.copyWith(fontWeight: FontWeight.w700)),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              Text(
                'Select Renewal Plan',
                style: AppTypography.bodySmall.copyWith(fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 8),

              if (_loadingPlans)
                const Center(child: Padding(padding: EdgeInsets.all(16), child: CircularProgressIndicator()))
              else ...[
                ..._plans.map((plan) {
                  final isSelected = _selectedPlan?['id'] == plan['id'];
                  final priceVal = ((plan['price_cents'] as num? ?? 0) / 100).toStringAsFixed(0);
                  final currency = (plan['currency'] as String? ?? 'INR').toUpperCase();
                  final duration = plan['duration_days'] ?? 30;

                  return Padding(
                    padding: const EdgeInsets.only(bottom: 6),
                    child: InkWell(
                      borderRadius: AppRadii.r8,
                      onTap: () => _onSelectPlan(plan),
                      child: Container(
                        decoration: BoxDecoration(
                          color: isSelected
                              ? (isDark ? AppColors.brand.withAlpha(25) : AppColors.brandContainer)
                              : cs.surface,
                          borderRadius: AppRadii.r8,
                          border: Border.all(
                            color: isSelected ? AppColors.brand : cs.outline,
                            width: isSelected ? 1.5 : 1.0,
                          ),
                        ),
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                        child: Row(
                          children: [
                            Icon(
                              isSelected ? Icons.radio_button_checked_rounded : Icons.radio_button_off_rounded,
                              color: isSelected ? AppColors.brand : cs.onSurfaceVariant,
                              size: 18,
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    plan['name'] ?? 'Membership Plan',
                                    style: AppTypography.bodyMedium.copyWith(fontWeight: FontWeight.w700, fontSize: 13),
                                  ),
                                  Text(
                                    '$duration Days Extension',
                                    style: AppTypography.bodySmall.copyWith(color: cs.onSurfaceVariant, fontSize: 11),
                                  ),
                                ],
                              ),
                            ),
                            Text(
                              '$currency $priceVal',
                              style: AppTypography.bodyMedium.copyWith(fontWeight: FontWeight.w800, color: AppColors.brand),
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                }),
              ],
              const SizedBox(height: 14),

              // Summary Preview Box
              Container(
                decoration: BoxDecoration(
                  color: isDark ? AppColors.brand.withAlpha(15) : AppColors.brandContainer.withAlpha(100),
                  borderRadius: AppRadii.r8,
                  border: Border.all(color: AppColors.brand.withAlpha(50)),
                ),
                padding: const EdgeInsets.all(12),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'New Expiration Date:',
                      style: AppTypography.bodySmall.copyWith(fontWeight: FontWeight.w600),
                    ),
                    Text(
                      newExpiryStr,
                      style: AppTypography.titleMedium.copyWith(
                        fontWeight: FontWeight.w900,
                        color: AppColors.brand,
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 18),

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
                text: 'Confirm & Activate Renewal',
                icon: const Icon(Icons.check_circle_outline_rounded),
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
