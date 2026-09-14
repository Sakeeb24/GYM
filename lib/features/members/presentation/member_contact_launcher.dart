// lib/features/members/presentation/member_contact_launcher.dart
// Web & Mobile Safe Direct Communication Utility & Dialog
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../core/models/member.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_radii.dart';
import '../../../core/theme/app_typography.dart';

class MemberContactHelper {
  static String cleanPhoneNumber(String phone) {
    // Retain leading '+' if present, strip all other non-numeric chars
    final hasPlus = phone.trim().startsWith('+');
    final digits = phone.replaceAll(RegExp(r'\D'), '');
    return hasPlus ? '+$digits' : digits;
  }

  static Future<bool> launchWhatsApp({
    required String phone,
    required String message,
  }) async {
    final clean = cleanPhoneNumber(phone).replaceAll('+', '');
    final uri = Uri.parse('https://wa.me/$clean?text=${Uri.encodeComponent(message)}');
    try {
      return await launchUrl(uri, mode: LaunchMode.externalApplication);
    } catch (_) {
      return false;
    }
  }

  static Future<bool> launchCall({required String phone}) async {
    final clean = cleanPhoneNumber(phone);
    final uri = Uri.parse('tel:$clean');
    try {
      return await launchUrl(uri);
    } catch (_) {
      return false;
    }
  }

  static Future<bool> launchSms({
    required String phone,
    required String message,
  }) async {
    final clean = cleanPhoneNumber(phone);
    final uri = Uri.parse('sms:$clean?body=${Uri.encodeComponent(message)}');
    try {
      return await launchUrl(uri);
    } catch (_) {
      return false;
    }
  }
}

class MemberQuickContactDialog extends StatefulWidget {
  final Member member;
  final String? gymName;
  final DateTime? membershipExpiresAt;

  const MemberQuickContactDialog({
    super.key,
    required this.member,
    this.gymName,
    this.membershipExpiresAt,
  });

  @override
  State<MemberQuickContactDialog> createState() => _MemberQuickContactDialogState();
}

class _MemberQuickContactDialogState extends State<MemberQuickContactDialog> {
  int _selectedTemplate = 0;
  late final TextEditingController _messageController;

  @override
  void initState() {
    super.initState();
    _messageController = TextEditingController(text: _getTemplateText(0));
  }

  @override
  void dispose() {
    _messageController.dispose();
    super.dispose();
  }

  String _getTemplateText(int index) {
    final gym = widget.gymName ?? 'LiftFlow Gym';
    final name = widget.member.fullName;
    final expDate = widget.membershipExpiresAt != null
        ? '${widget.membershipExpiresAt!.year}-${widget.membershipExpiresAt!.month.toString().padLeft(2, '0')}-${widget.membershipExpiresAt!.day.toString().padLeft(2, '0')}'
        : 'soon';

    switch (index) {
      case 0:
        return 'Hi $name! 👋 This is a reminder from $gym. Your gym membership expires on $expDate. Contact us or visit front desk to renew!';
      case 1:
        return 'Hey $name! 🔥 We missed you at $gym this week! Ready to crush another workout session? Come on in today!';
      case 2:
        return 'Welcome to $gym, $name! 🏋️ We are thrilled to have you train with us. Let us know if you need anything from the coaching team!';
      default:
        return 'Hi $name, message from $gym: ';
    }
  }

  void _onSelectTemplate(int index) {
    setState(() {
      _selectedTemplate = index;
      _messageController.text = _getTemplateText(index);
    });
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final phone = widget.member.phone ?? '';

    return Dialog(
      backgroundColor: isDark ? AppColors.dSurface : AppColors.lSurface,
      shape: RoundedRectangleBorder(borderRadius: AppRadii.card),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 480),
        child: Padding(
          padding: const EdgeInsets.all(22),
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
                        child: const Icon(Icons.send_rounded, color: AppColors.brand, size: 20),
                      ),
                      const SizedBox(width: 10),
                      Text(
                        'QUICK CONTACT',
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
                'To: ${widget.member.fullName} (${phone.isNotEmpty ? phone : 'No Phone Number Registered'})',
                style: AppTypography.bodySmall.copyWith(
                  fontWeight: FontWeight.w600,
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 14),

              // Template Chips
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: [
                  _TemplateChip(
                    label: 'Renewal Reminder',
                    selected: _selectedTemplate == 0,
                    onTap: () => _onSelectTemplate(0),
                  ),
                  _TemplateChip(
                    label: 'Missed Workout',
                    selected: _selectedTemplate == 1,
                    onTap: () => _onSelectTemplate(1),
                  ),
                  _TemplateChip(
                    label: 'Welcome',
                    selected: _selectedTemplate == 2,
                    onTap: () => _onSelectTemplate(2),
                  ),
                  _TemplateChip(
                    label: 'Custom',
                    selected: _selectedTemplate == 3,
                    onTap: () => _onSelectTemplate(3),
                  ),
                ],
              ),
              const SizedBox(height: 14),

              TextField(
                controller: _messageController,
                maxLines: 4,
                decoration: InputDecoration(
                  labelText: 'Message Text',
                  alignLabelWithHint: true,
                  border: OutlineInputBorder(borderRadius: AppRadii.r8),
                  contentPadding: const EdgeInsets.all(12),
                ),
              ),
              const SizedBox(height: 18),

              if (phone.isEmpty)
                Container(
                  padding: const EdgeInsets.all(10),
                  margin: const EdgeInsets.only(bottom: 12),
                  decoration: BoxDecoration(
                    color: AppColors.warning.withAlpha(25),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: AppColors.warning),
                  ),
                  child: Text(
                    'No phone number available for this athlete. You can copy the message text below.',
                    style: AppTypography.bodySmall.copyWith(color: AppColors.warning),
                  ),
                ),

              // Action Buttons
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF25D366),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(borderRadius: AppRadii.r8),
                      ),
                      icon: const Icon(Icons.chat_rounded, size: 18),
                      label: const Text('WhatsApp', style: TextStyle(fontWeight: FontWeight.w700)),
                      onPressed: phone.isEmpty
                          ? null
                          : () {
                              MemberContactHelper.launchWhatsApp(
                                phone: phone,
                                message: _messageController.text,
                              );
                              Navigator.pop(context);
                            },
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(borderRadius: AppRadii.r8),
                      ),
                      icon: const Icon(Icons.sms_outlined, size: 18),
                      label: const Text('SMS', style: TextStyle(fontWeight: FontWeight.w700)),
                      onPressed: phone.isEmpty
                          ? null
                          : () {
                              MemberContactHelper.launchSms(
                                phone: phone,
                                message: _messageController.text,
                              );
                              Navigator.pop(context);
                            },
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 10),
                        shape: RoundedRectangleBorder(borderRadius: AppRadii.r8),
                      ),
                      icon: const Icon(Icons.phone_rounded, size: 16),
                      label: const Text('Call Phone', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 12)),
                      onPressed: phone.isEmpty
                          ? null
                          : () {
                              MemberContactHelper.launchCall(phone: phone);
                              Navigator.pop(context);
                            },
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 10),
                        shape: RoundedRectangleBorder(borderRadius: AppRadii.r8),
                      ),
                      icon: const Icon(Icons.copy_rounded, size: 16),
                      label: const Text('Copy Text', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 12)),
                      onPressed: () {
                        Clipboard.setData(ClipboardData(text: _messageController.text));
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Message copied to clipboard')),
                        );
                        Navigator.pop(context);
                      },
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _TemplateChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _TemplateChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return ChoiceChip(
      label: Text(
        label,
        style: AppTypography.bodySmall.copyWith(
          fontSize: 11,
          fontWeight: FontWeight.w600,
        ),
      ),
      selected: selected,
      onSelected: (_) => onTap(),
      selectedColor: isDark ? AppColors.brand.withAlpha(30) : AppColors.brandContainer,
      side: BorderSide(
        color: selected
            ? (isDark ? AppColors.brand : AppColors.brandDark)
            : cs.outline,
      ),
      padding: const EdgeInsets.symmetric(horizontal: 4),
    );
  }
}
