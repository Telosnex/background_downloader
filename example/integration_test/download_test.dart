// A download completes from the local server started by the CI job
// (tool/download_server.dart), on every platform the plugin supports.

import 'dart:io';

import 'package:background_downloader/background_downloader.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

import '../tool/download_server.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  // The emulator reaches the host's loopback at 10.0.2.2; other platforms run
  // the test on the host itself.
  final host = Platform.isAndroid ? '10.0.2.2' : '127.0.0.1';
  final url = 'http://$host:$serverPort$testFilePath';

  test('a download completes from the local server', () async {
    final task = DownloadTask(url: url, filename: 'ci-download-test.bin');
    final path = await task.filePath();
    final file = File(path);
    if (file.existsSync()) file.deleteSync();

    final result = await FileDownloader().download(task);
    expect(result.status, TaskStatus.complete);
    expect(file.existsSync(), isTrue);
    expect(await file.readAsBytes(), equals(testFileBytes()));

    file.deleteSync();
  }, timeout: const Timeout(Duration(minutes: 5)));
}
