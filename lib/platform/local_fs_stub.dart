import 'fs_entry.dart';

Future<void> writeBytesToPath(String path, List<int> bytes) async {
  throw UnsupportedError('Local filesystem is not available on this platform');
}

Future<List<int>> readBytesFromPath(String path) async {
  throw UnsupportedError('Local filesystem is not available on this platform');
}

Future<String> readStringFromPath(String path) async {
  throw UnsupportedError('Local filesystem is not available on this platform');
}

Future<bool> pathExists(String path) async => false;

Future<void> deletePath(String path) async {}

Future<void> ensureDir(String path) async {}

Future<List<FsEntry>> listDir(String dirPath) async => const [];
