part of 'localstore.dart';

/// The entry point for accessing a [Localstore].
///
/// You can get an instance by calling [Localstore.instance], for example:
///
/// ```dart
/// final db = Localstore.instance;
/// ```
final class Localstore implements LocalstoreImpl {
  final _databaseDirectory = _resolveDatabaseDirectory();
  final _delegate = DocumentRef._('');
  static final Localstore _localstore = Localstore._();

  /// Private initializer
  Localstore._();

  /// Returns an instance using the default [Localstore].
  static Localstore get instance => _localstore;

  Future<Directory> get databaseDirectory => _databaseDirectory;

  /// Clears the cache - needed only if filesystem has been manipulated directly
  void clearCache() {
    Utils.instance.clearCache();
  }

  @override
  CollectionRef collection(String path) => CollectionRef(path, null, _delegate);
}

/// Where the database lives: the app support folder, except on Windows.
///
/// On Windows the support folder is Roaming AppData, which roaming profiles
/// copy to the user's other PCs and Folder Redirection shares between PCs
/// signed in at once. Task records, resume data and paused tasks belong to
/// one PC, so Windows uses Local AppData (path_provider's cache folder,
/// `%LOCALAPPDATA%\<company>\<product>`). Records in the old Roaming folder
/// are not moved; they are deleted.
Future<Directory> _resolveDatabaseDirectory() async {
  if (!Platform.isWindows) return getApplicationSupportDirectory();
  final local = await getApplicationCacheDirectory();
  await _deleteRoamingDatabase();
  return local;
}

Future<void> _deleteRoamingDatabase() async {
  try {
    final roaming = await getApplicationSupportDirectory();
    for (final name in const [
      'backgroundDownloaderTaskRecords',
      'backgroundDownloaderResumeData',
      'backgroundDownloaderPausedTasks',
      'backgroundDownloaderDatabase',
    ]) {
      final dir = Directory(p.join(roaming.path, name));
      if (await dir.exists()) await dir.delete(recursive: true);
    }
  } catch (_) {
    // Best effort: a left-over folder is only stale data.
  }
}
