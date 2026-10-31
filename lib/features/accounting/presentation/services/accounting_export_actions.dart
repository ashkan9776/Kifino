import 'package:flutter/material.dart';

import '../../../../app/theme/app_colors.dart';

/// Shared AppBar «خروجی اکسل» action for the accounting report pages.
///
/// Handles the in-progress icon swap, the Persian user-facing errors
/// (StateError messages come from the repositories) and the result SnackBar
/// showing the saved file path.
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
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          duration: const Duration(seconds: 4),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'فایل اکسل ذخیره شد',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
              ),
              const SizedBox(height: 2),
              Text(
                path,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 11,
                  color: Colors.white.withValues(alpha: 0.85),
                ),
              ),
            ],
          ),
        ),
      );
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
