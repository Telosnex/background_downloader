import 'dart:io';

import 'package:background_downloader/src/temp_file_cleanup.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;

void main() {
  late Directory tempDirectory;

  setUp(() async {
    tempDirectory = await Directory.systemTemp.createTemp(
      'background_downloader_cleanup_test.',
    );
  });

  tearDown(() async {
    if (await tempDirectory.exists()) {
      await tempDirectory.delete(recursive: true);
    }
  });

  test('deletes current and legacy filename formats', () async {
    final files = [
      File(
        p.join(tempDirectory.path, '${backgroundDownloaderTempFilePrefix}123'),
      ),
      File(
        p.join(tempDirectory.path, '$backgroundDownloaderTempFilePrefix-123'),
      ),
      File(
        p.join(tempDirectory.path, '$backgroundDownloaderTempFilePrefix.456'),
      ),
      File(
        p.join(
          tempDirectory.path,
          '$backgroundDownloaderTempFilePrefix.'
          '550e8400-e29b-41d4-a716-446655440000',
        ),
      ),
      File(
        p.join(tempDirectory.path, '.$backgroundDownloaderTempFilePrefix.789'),
      ),
    ];
    for (final file in files) {
      await file.writeAsString('temporary');
    }

    final deleted = await deleteBackgroundDownloaderTempFiles([
      tempDirectory.path,
    ]);

    expect(deleted, files.length);
    for (final file in files) {
      expect(await file.exists(), isFalse);
    }
  });

  test('explicit heuristic also deletes an exact-name collision', () async {
    final unrelatedFile = File(
      p.join(tempDirectory.path, '$backgroundDownloaderTempFilePrefix.123'),
    );
    await unrelatedFile.writeAsString('unrelated application data');

    final deleted = await deleteBackgroundDownloaderTempFiles([
      tempDirectory.path,
    ]);

    expect(deleted, 1);
    expect(await unrelatedFile.exists(), isFalse);
  });

  test('does not guess bare legacy integer or UUID ownership', () async {
    final files = [
      File(p.join(tempDirectory.path, '123456')),
      File(p.join(tempDirectory.path, '550e8400-e29b-41d4-a716-446655440000')),
      File(p.join(tempDirectory.path, 'keep-me')),
      File(
        p.join(
          tempDirectory.path,
          '$backgroundDownloaderTempFilePrefix.settings',
        ),
      ),
    ];
    for (final file in files) {
      await file.writeAsString('keep');
    }

    final deleted = await deleteBackgroundDownloaderTempFiles([
      tempDirectory.path,
    ]);

    expect(deleted, 0);
    for (final file in files) {
      expect(await file.exists(), isTrue);
    }
  });

  test('does not delete directories or scan recursively', () async {
    final matchingDirectory = Directory(
      p.join(tempDirectory.path, '$backgroundDownloaderTempFilePrefix.100'),
    )..createSync();
    final nestedDirectory = Directory(p.join(tempDirectory.path, 'nested'))
      ..createSync();
    final nestedFile = File(
      p.join(nestedDirectory.path, '$backgroundDownloaderTempFilePrefix.200'),
    )..writeAsStringSync('nested');

    final deleted = await deleteBackgroundDownloaderTempFiles([
      tempDirectory.path,
    ]);

    expect(deleted, 0);
    expect(await matchingDirectory.exists(), isTrue);
    expect(await nestedFile.exists(), isTrue);
  });
}
