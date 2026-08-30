import 'dart:io';

import 'package:path/path.dart' as p;

/// Prefix used by background_downloader temporary files.
const backgroundDownloaderTempFilePrefix = 'com.bbflight.background_downloader';

// Includes the current dotted form and the legacy undelimited form. A leading
// dot was used by the desktop fallback that stages beside the destination.
final _temporaryFileName = RegExp(
  r'^\.?com\.bbflight\.background_downloader(?:\.-?\d+|\.[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}|-?\d+)$',
);

/// Whether [entity] is a regular file with a current or legacy temporary-file
/// name used by background_downloader.
Future<bool> isBackgroundDownloaderTempFile(FileSystemEntity entity) async {
  if (!_temporaryFileName.hasMatch(p.basename(entity.path))) {
    return false;
  }
  return FileSystemEntity.typeSync(entity.path, followLinks: false) ==
      FileSystemEntityType.file;
}

/// Deletes matching files directly inside [directories].
///
/// This deliberately uses a filename heuristic for legacy files. It does not
/// establish ownership. Directories are not traversed, and links and
/// directories are never deleted.
Future<int> deleteBackgroundDownloaderTempFiles(
  Iterable<String> directories,
) async {
  final normalizedDirectories = directories.map(_normalizedPath).toSet();
  var deletedCount = 0;

  for (final directoryPath in normalizedDirectories) {
    final directory = Directory(directoryPath);
    try {
      if (!await directory.exists()) {
        continue;
      }
      await for (final entity in directory.list(followLinks: false)) {
        if (!await isBackgroundDownloaderTempFile(entity)) {
          continue;
        }
        try {
          await entity.delete();
          deletedCount++;
        } on FileSystemException {
          // A task or the OS may have changed or removed the file after listing.
        }
      }
    } on FileSystemException {
      // An external or caller-provided directory may be unavailable.
    }
  }
  return deletedCount;
}

String _normalizedPath(String path) {
  final normalized = p.normalize(p.absolute(path));
  return Platform.isWindows ? normalized.toLowerCase() : normalized;
}
