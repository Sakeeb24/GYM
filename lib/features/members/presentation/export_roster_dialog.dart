// lib/features/members/presentation/export_roster_dialog.dart
// Owner / Staff Roster CSV Export Modal
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../core/models/member.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_radii.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/utils/csv_export_helper.dart';
import '../../../core/widgets/app_button.dart';

class ExportRosterDialog extends StatefulWidget {
  final List<Member> allMembers;
  final List<Member> filteredMembers;

  const ExportRosterDialog({
    super.key,
    required this.allMembers,
    required this.filteredMembers,
  });

  @override
  State<ExportRosterDialog> createState() => _ExportRosterDialogState();
}

class _ExportRosterDialogState extends State<ExportRosterDialog> {
  bool _exportFilteredOnly = false;
  bool _includePhone = true;
  bool _includeEmail = true;
  bool _includeTags = true;
  bool _includeDates = true;
  bool _downloading = false;

  @override
  void initState() {
    super.initState();
    // Default to filtered if active filter has fewer items than total
    _exportFilteredOnly = widget.filteredMembers.length < widget.allMembers.length;
  }

  List<Member> get _targetMembers =>
      _exportFilteredOnly ? widget.filteredMembers : widget.allMembers;

  String _generateCsvString() {
    return CsvExportHelper.membersToCsv(
      _targetMembers,
      includePhone: _includePhone,
      includeEmail: _includeEmail,
      includeTags: _includeTags,
      includeDates: _includeDates,
    );
  }

  Future<void> _handleDownload() async {
    setState(() => _downloading = true);
    final now = DateTime.now();
    final dateStr = '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
    final fileName = 'liftflow_roster_$dateStr.csv';
    final csvContent = _generateCsvString();

    await CsvExportHelper.downloadOrShareCsv(
      fileName: fileName,
      csvContent: csvContent,
    );

    if (mounted) {
      setState(() => _downloading = false);
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Exported ${_targetMembers.length} records to $fileName'),
          backgroundColor: AppColors.brand,
        ),
      );
    }
  }

  void _handleCopy() {
    final csvContent = _generateCsvString();
    Clipboard.setData(ClipboardData(text: csvContent));
    Navigator.pop(context);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Copied ${_targetMembers.length} records to clipboard as CSV'),
        backgroundColor: AppColors.brand,
      ),
    );
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
              // Header
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
                        child: const Icon(Icons.file_download_outlined, color: AppColors.brand, size: 20),
                      ),
                      const SizedBox(width: 10),
                      Text(
                        'EXPORT ROSTER (CSV)',
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
              const SizedBox(height: 14),

              // Export Scope Selection
              Text(
                'Export Scope',
                style: AppTypography.bodySmall.copyWith(fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 6),
              Row(
                children: [
                  Expanded(
                    child: _ScopeOption(
                      label: 'All Athletes (${widget.allMembers.length})',
                      selected: !_exportFilteredOnly,
                      onTap: () => setState(() => _exportFilteredOnly = false),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _ScopeOption(
                      label: 'Current Filter (${widget.filteredMembers.length})',
                      selected: _exportFilteredOnly,
                      onTap: () => setState(() => _exportFilteredOnly = true),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // Fields to include
              Text(
                'Columns to Include',
                style: AppTypography.bodySmall.copyWith(fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 6),

              Material(
                color: cs.surface,
                shape: RoundedRectangleBorder(
                  borderRadius: AppRadii.r8,
                  side: BorderSide(color: cs.outline),
                ),
                clipBehavior: Clip.antiAlias,
                child: Column(
                  children: [
                    CheckboxListTile(
                      dense: true,
                      title: Text('Phone Numbers', style: AppTypography.bodyMedium),
                      value: _includePhone,
                      activeColor: AppColors.brand,
                      onChanged: (val) => setState(() => _includePhone = val ?? true),
                    ),
                    const Divider(height: 1),
                    CheckboxListTile(
                      dense: true,
                      title: Text('Email Addresses', style: AppTypography.bodyMedium),
                      value: _includeEmail,
                      activeColor: AppColors.brand,
                      onChanged: (val) => setState(() => _includeEmail = val ?? true),
                    ),
                    const Divider(height: 1),
                    CheckboxListTile(
                      dense: true,
                      title: Text('Athlete Tags & Categories', style: AppTypography.bodyMedium),
                      value: _includeTags,
                      activeColor: AppColors.brand,
                      onChanged: (val) => setState(() => _includeTags = val ?? true),
                    ),
                    const Divider(height: 1),
                    CheckboxListTile(
                      dense: true,
                      title: Text('Enrollment Dates', style: AppTypography.bodyMedium),
                      value: _includeDates,
                      activeColor: AppColors.brand,
                      onChanged: (val) => setState(() => _includeDates = val ?? true),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // Summary Banner
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: isDark ? AppColors.brand.withAlpha(15) : AppColors.brandContainer.withAlpha(100),
                  borderRadius: AppRadii.r8,
                  border: Border.all(color: AppColors.brand.withAlpha(40)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.table_chart_outlined, color: AppColors.brand, size: 20),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        '${_targetMembers.length} athlete records selected for export.',
                        style: AppTypography.bodySmall.copyWith(
                          fontWeight: FontWeight.w700,
                          color: isDark ? Colors.white : AppColors.lTextPrimary,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 18),

              // Action Buttons
              AppButton(
                text: 'Download CSV File',
                icon: const Icon(Icons.download_rounded),
                loading: _downloading,
                onPressed: _targetMembers.isEmpty ? null : _handleDownload,
                fullWidth: true,
              ),
              const SizedBox(height: 8),
              OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(borderRadius: AppRadii.r8),
                ),
                icon: const Icon(Icons.copy_rounded, size: 16),
                label: const Text('Copy CSV Data to Clipboard', style: TextStyle(fontWeight: FontWeight.w700)),
                onPressed: _targetMembers.isEmpty ? null : _handleCopy,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ScopeOption extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _ScopeOption({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return InkWell(
      borderRadius: AppRadii.r8,
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(
          color: selected
              ? (isDark ? AppColors.brand.withAlpha(25) : AppColors.brandContainer)
              : cs.surface,
          borderRadius: AppRadii.r8,
          border: Border.all(
            color: selected ? AppColors.brand : cs.outline,
            width: selected ? 1.5 : 1.0,
          ),
        ),
        child: Center(
          child: Text(
            label,
            style: AppTypography.bodySmall.copyWith(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: selected ? (isDark ? AppColors.brand : AppColors.brandDark) : cs.onSurfaceVariant,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ),
    );
  }
}
