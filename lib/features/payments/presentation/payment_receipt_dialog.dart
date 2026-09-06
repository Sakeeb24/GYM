// lib/features/payments/presentation/payment_receipt_dialog.dart
// Payment Receipt Confirmation & Membership Extension Dialog (Apex Precision)
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_radii.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/widgets/app_button.dart';

class PaymentReceiptDialog extends StatelessWidget {
  final String transactionId;
  final String planName;
  final double amountInr;
  final int durationDays;
  final DateTime paymentDate;

  const PaymentReceiptDialog({
    super.key,
    required this.transactionId,
    required this.planName,
    required this.amountInr,
    required this.durationDays,
    required this.paymentDate,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Dialog(
      backgroundColor: isDark ? AppColors.dSurface : AppColors.lSurface,
      shape: RoundedRectangleBorder(borderRadius: AppRadii.card),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 420),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Success Badge
              Container(
                width: 64,
                height: 64,
                decoration: BoxDecoration(
                  color: AppColors.success.withAlpha(30),
                  shape: BoxShape.circle,
                  border: Border.all(color: AppColors.success, width: 2),
                ),
                child: const Center(
                  child: Icon(Icons.check_rounded, color: AppColors.success, size: 36),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'PAYMENT SUCCESSFUL',
                style: AppTypography.labelAthletic.copyWith(
                  fontSize: 18,
                  letterSpacing: 2.0,
                  color: AppColors.success,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Membership extended by $durationDays days.',
                style: AppTypography.bodySmall.copyWith(color: cs.onSurfaceVariant),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 20),

              // Receipt Details Card
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: isDark ? AppColors.dSurfaceAlt : AppColors.lSurfaceAlt,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: cs.outline),
                ),
                child: Column(
                  children: [
                    _ReceiptRow(label: 'AMOUNT PAID', value: '₹${amountInr.toInt()}'),
                    const SizedBox(height: 8),
                    _ReceiptRow(label: 'PLAN EXTENDED', value: planName),
                    const SizedBox(height: 8),
                    _ReceiptRow(
                      label: 'TRANSACTION ID',
                      value: transactionId.length > 18 ? transactionId.substring(0, 18) : transactionId,
                    ),
                    const SizedBox(height: 8),
                    _ReceiptRow(
                      label: 'DATE & TIME',
                      value: DateFormat('d MMM yyyy, hh:mm a').format(paymentDate),
                    ),
                    const SizedBox(height: 8),
                    const _ReceiptRow(label: 'STATUS', value: 'VERIFIED & PAID', isStatus: true),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              AppButton(
                text: 'Done',
                onPressed: () {
                  Navigator.pop(context); // Close receipt
                },
                fullWidth: true,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ReceiptRow extends StatelessWidget {
  final String label;
  final String value;
  final bool isStatus;

  const _ReceiptRow({
    required this.label,
    required this.value,
    this.isStatus = false,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: AppTypography.labelAthletic.copyWith(
            fontSize: 9,
            color: cs.onSurfaceVariant,
          ),
        ),
        Text(
          value,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w800,
            color: isStatus ? AppColors.success : cs.onSurface,
          ),
        ),
      ],
    );
  }
}
