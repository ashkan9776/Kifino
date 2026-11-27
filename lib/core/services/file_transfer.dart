import 'dart:io';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

/// A file the app generated (backup, CSV, Excel report), held in memory
/// until the user decides where it goes.
class ExportFile {
  final String name;
  final Uint8List bytes;
  final String mimeType;

  const ExportFile({
    required this.name,
    required this.bytes,
    required this.mimeType,
  });

  static const xlsxMime =
      'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet';

  /// Wraps a file already written to disk (e.g. a temp export).
  static Future<ExportFile> fromPath(String path, {String? mimeType}) async =>
      ExportFile(
        name: p.basename(path),
        bytes: await File(path).readAsBytes(),
        mimeType: mimeType ?? _mimeFor(path),
      );

  static String _mimeFor(String path) => switch (p.extension(path)) {
    '.csv' => 'text/csv',
    '.xlsx' => xlsxMime,
    _ => 'application/octet-stream',
  };
}

/// A file the user picked with the system file picker.
class PickedFile {
  final String name;
  final Uint8List bytes;

  const PickedFile({required this.name, required this.bytes});
}

/// Moves files between the app and places the user can reach.
///
/// Nothing is written to the app's private folder (`/data/user/…`), which
/// the user can't open without root and which is wiped on uninstall. Files
/// go through the system dialogs instead (Storage Access Framework on
/// Android), so no storage permission is needed and the user can choose
/// Downloads, an SD card, Google Drive, etc.
abstract class FileTransfer {
  /// Opens the system «Save as» dialog. Returns a readable description of
  /// where the file went (e.g. `Download/kifino_backup.kfn`), or `null` if
  /// the user cancelled.
  Future<String?> saveAs(ExportFile file);

  /// Whether [share] is available on this platform.
  bool get canShare;

  /// Opens the system share sheet (Telegram, email, Drive, …).
  Future<void> share(ExportFile file);

  /// Opens the system file picker. `null` if the user cancelled.
  Future<PickedFile?> pick();
}

class SystemFileTransfer implements FileTransfer {
  @override
  Future<String?> saveAs(ExportFile file) async {
    final uri = await FilePicker.saveFile(
      fileName: file.name,
      bytes: file.bytes,
      mimeType: file.mimeType,
    );
    if (uri == null) return null;
    return describeLocation(uri, fallback: file.name);
  }

  @override
  bool get canShare => Platform.isAndroid || Platform.isIOS || Platform.isMacOS;

  @override
  Future<void> share(ExportFile file) async {
    // The share sheet needs a real file; the temp folder is the OS's to
    // clear, so nothing lingers in private storage.
    final dir = await getTemporaryDirectory();
    final path = p.join(dir.path, file.name);
    await File(path).writeAsBytes(file.bytes, flush: true);
    await SharePlus.instance.share(
      ShareParams(
        files: [XFile(path, mimeType: file.mimeType)],
        title: file.name,
      ),
    );
  }

  @override
  Future<PickedFile?> pick() async {
    final picked = await FilePicker.pickFile();
    if (picked == null) return null;
    return PickedFile(name: picked.name, bytes: await picked.readAsBytes());
  }
}

/// Turns the [uri] a save dialog returns into something a person can read.
///
/// Android SAF document URIs look like
/// `content://…/document/primary%3ADownload%2Fkifino.kfn`; the part after
/// `primary:` is the path inside the storage volume.
String describeLocation(Uri uri, {required String fallback}) {
  if (uri.scheme == 'file') return uri.toFilePath();
  final last = uri.pathSegments.isEmpty ? '' : uri.pathSegments.last;
  final decoded = Uri.decodeComponent(last);
  final colon = decoded.indexOf(':');
  final path = colon >= 0 ? decoded.substring(colon + 1) : decoded;
  if (path.isNotEmpty && path.contains('/')) return path;
  // The Downloads provider hands out opaque ids (`msf:1000`), but the file
  // is in the public Download folder either way.
  if (uri.authority == 'com.android.providers.downloads.documents') {
    return 'Download/$fallback';
  }
  return fallback;
}
