// lib/core/utils/csv_export_helper.dart
// Cross-platform CSV generation and export helper
import 'dart:convert';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';
import '../models/member.dart';

class CsvExportHelper {
  CsvExportHelper._();

  /// Escapes a field for CSV format (wraps in quotes if it contains comma, quote, or newline)
  static String escapeField(String? value) {
    if (value == null) return '';
    final str = value.trim();
    if (str.contains(',') || str.contains('"') || str.contains('\n') || str.contains('\r')) {
      return '"${str.replaceAll('"', '""')}"';
    }
    return str;
  }

  /// Converts a list of [Member] objects to a CSV string
  static String membersToCsv(
    List<Member> members, {
    bool includePhone = true,
    bool includeEmail = true,
    bool includeTags = true,
    bool includeDates = true,
  }) {
    final headers = <String>[
      'Member ID',
      'Full Name',
      if (includePhone) 'Phone',
      if (includeEmail) 'Email',
      'Status',
      if (includeTags) 'Tags',
      if (includeDates) 'Enrolled Date',
    ];

    final buffer = StringBuffer();
    buffer.writeln(headers.map(escapeField).join(','));

    for (final m in members) {
      final row = <String>[
        'LF-${m.memberNumber}',
        m.fullName,
        if (includePhone) m.phone ?? '',
        if (includeEmail) m.email ?? '',
        m.isActive ? 'Active' : 'Inactive',
        if (includeTags) m.tags.join('; '),
        if (includeDates)
          m.createdAt != null
              ? '${m.createdAt!.year}-${m.createdAt!.month.toString().padLeft(2, '0')}-${m.createdAt!.day.toString().padLeft(2, '0')}'
              : '',
      ];
      buffer.writeln(row.map(escapeField).join(','));
    }

    return buffer.toString();
  }

  /// Triggers a CSV download or data URI launch across Web, Desktop, and Mobile
  static Future<bool> downloadOrShareCsv({
    required String fileName,
    required String csvContent,
  }) async {
    try {
      final bytes = utf8.encode(csvContent);
      final base64Content = base64Encode(bytes);
      final uri = Uri.parse('data:text/csv;charset=utf-8;base64,$base64Content');

      final launched = await launchUrl(uri, mode: LaunchMode.externalApplication);
      if (!launched) {
        // Fallback: Copy to clipboard
        await Clipboard.setData(ClipboardData(text: csvContent));
        return true;
      }
      return true;
    } catch (_) {
      // Fallback: Copy to clipboard
      await Clipboard.setData(ClipboardData(text: csvContent));
      return true;
    }
  }
}
