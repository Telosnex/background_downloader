// A local HTTP server for the integration tests: serves one deterministic
// 1 MB file, on all interfaces so that the Android emulator reaches the host
// at 10.0.2.2. Run from the example directory before the tests:
//
//   dart run tool/download_server.dart &
//
// The test computes the same bytes with testFileBytes().

import 'dart:io';
import 'dart:typed_data';

const serverPort = 8080;
const testFilePath = '/files/1MB-test.bin';

/// The content of the file served at [testFilePath].
Uint8List testFileBytes() {
  final bytes = Uint8List(1024 * 1024);
  for (var i = 0; i < bytes.length; i++) {
    bytes[i] = (i * 31 + (i >> 8)) & 0xff;
  }
  return bytes;
}

Future<void> main() async {
  final bytes = testFileBytes();
  final server = await HttpServer.bind(InternetAddress.anyIPv4, serverPort);
  stdout.writeln('serving on port $serverPort');
  await for (final request in server) {
    final response = request.response;
    if (request.method == 'GET' && request.uri.path == testFilePath) {
      response
        ..statusCode = HttpStatus.ok
        ..headers.contentType = ContentType.binary
        ..contentLength = bytes.length
        ..add(bytes);
    } else {
      response.statusCode = HttpStatus.notFound;
    }
    await response.close();
  }
}
