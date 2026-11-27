import 'package:flutter/material.dart';

import '../../../../app/theme/app_colors.dart';
import '../../../../core/services/file_transfer.dart';
import '../../../../core/widgets/export_sheet.dart';

/// Shared AppBar «خروجی اکسل» action for the accounting report pages.
///
/// Handles the in-progress icon swap, the Persian user-facing errors
/// (StateError messages come from the repositories) and then asks where the
/// generated file goes (save to the device or share).
mixin AccountingExportActions<T extends StatefulWidget> on State<T> {
  bool _isExporting = false;

  Widget buildExportAction(Future<String> Function() export) {
    if (_isExporting) {
      return const Padding(
        padding: EdgeInsets.symmetric(horizontal: 16),
        child: SizedBox(
          width: 18,
          height: 18,
          child: CircularProgressIndicator(strokeWidth: 2.4),
        ),
      );
    }
    return IconButton(
      icon: const Icon(Icons.ios_share_rounded),
      tooltip: 'خروجی اکسل',
      onPressed: () => _runExport(export),
    );
  }

  Future<void> _runExport(Future<String> Function() export) async {
    if (_isExporting) return;
    setState(() => _isExporting = true);
    try {
      final path = await export();
      final file = await ExportFile.fromPath(path);
      if (!mounted) return;
      await showExportSheet(context, file: file, title: 'فایل اکسل آماده است');
    } on StateError catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(e.message),
          backgroundColor: context.customColors.expense,
        ),
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('خروجی اکسل انجام نشد'),
          backgroundColor: context.customColors.expense,
        ),
      );
    } finally {
      if (mounted) setState(() => _isExporting = false);
    }
  }
}
