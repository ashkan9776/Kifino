import 'package:flutter_test/flutter_test.dart';
import 'package:kifino/core/services/file_transfer.dart';

void main() {
  group('describeLocation', () {
    test('Android SAF document URI shows the folder path', () {
      final uri = Uri.parse(
        'content://com.android.providers.downloads.documents/document/'
        'primary%3ADownload%2Fkifino_backup.kfn',
      );
      expect(
        describeLocation(uri, fallback: 'x'),
        'Download/kifino_backup.kfn',
      );
    });

    test('Downloads provider id still names the Download folder', () {
      final uri = Uri.parse(
        'content://com.android.providers.downloads.documents/document/msf%3A1000',
      );
      expect(
        describeLocation(uri, fallback: 'kifino.kfn'),
        'Download/kifino.kfn',
      );
    });

    test('other opaque provider ids fall back to the file name', () {
      final uri = Uri.parse(
        'content://com.google.android.apps.docs.storage/document/acc%3D1%3Bdoc%3D9',
      );
      expect(describeLocation(uri, fallback: 'kifino.kfn'), 'kifino.kfn');
    });

    test('file URI shows the path', () {
      expect(
        describeLocation(
          Uri.file('/home/u/Downloads/a.csv'),
          fallback: 'a.csv',
        ),
        '/home/u/Downloads/a.csv',
      );
    });
  });
}
