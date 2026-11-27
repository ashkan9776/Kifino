import 'package:flutter/material.dart';

import '../../app/theme/app_spacing.dart';
import '../di/injection.dart';
import '../services/file_transfer.dart';
import '../utils/text_normalizer.dart';
import 'app_button.dart';
import 'app_kit.dart';

/// After a file is generated, asks where it should go: saved to a place the
/// user picks (Downloads, SD card, Drive…) or sent through the share sheet.
///
/// Shows the outcome as a SnackBar on [context]'s page.
Future<void> showExportSheet(
  BuildContext context, {
  required ExportFile file,
  String title = 'فایل آماده است',
  String? note,
}) async {
  final transfer = sl<FileTransfer>();
  final messenger = ScaffoldMessenger.of(context);

  final choice = await showAppSheet<_ExportChoice>(
    context: context,
    title: title,
    builder: (sheetContext) => Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        AppListGroup(
          children: [
            AppListRow(
              icon: Icons.insert_drive_file_outlined,
              title: file.name,
              subtitle: _sizeLabel(file.bytes.length),
            ),
          ],
        ),
        if (note != null) ...[
          const SizedBox(height: AppSpacing.md),
          AppNotice(message: note, icon: Icons.info_outline_rounded),
        ],
        const SizedBox(height: AppSpacing.lg),
        AppButton(
          label: 'ذخیره در گوشی',
          icon: const Icon(Icons.save_alt_rounded, size: 20),
          onPressed: () => Navigator.pop(sheetContext, _ExportChoice.save),
        ),
        if (transfer.canShare) ...[
          const SizedBox(height: AppSpacing.sm),
          AppButton(
            label: 'ارسال (تلگرام، ایمیل، …)',
            variant: AppButtonVariant.outline,
            icon: const Icon(Icons.share_rounded, size: 20),
            onPressed: () => Navigator.pop(sheetContext, _ExportChoice.share),
          ),
        ],
      ],
    ),
  );

  try {
    switch (choice) {
      case _ExportChoice.save:
        final where = await transfer.saveAs(file);
        if (where != null) {
          messenger.showSnackBar(
            SnackBar(
              content: Text('ذخیره شد در:\n$where'),
              duration: const Duration(seconds: 5),
            ),
          );
        }
      case _ExportChoice.share:
        await transfer.share(file);
      case null:
        break;
    }
  } catch (e) {
    messenger.showSnackBar(SnackBar(content: Text('ذخیره فایل انجام نشد: $e')));
  }
}

enum _ExportChoice { save, share }

String _sizeLabel(int bytes) {
  final kb = bytes / 1024;
  final label = kb < 1024
      ? '${kb.toStringAsFixed(kb < 10 ? 1 : 0)} کیلوبایت'
      : '${(kb / 1024).toStringAsFixed(1)} مگابایت';
  return TextNormalizer.toPersianDigits(label);
}
