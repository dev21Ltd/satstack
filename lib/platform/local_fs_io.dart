import 'dart:io';

import 'fs_entry.dart';

Future<void> writeBytesToPath(String path, List<int> bytes) async {
  final file = File(path);
  await file.writeAsBytes(bytes, flush: true);
}

Future<List<int>> readBytesFromPath(String path) {
  return File(path).readAsBytes();
}

Future<String> readStringFromPath(String path) {
  return File(path).readAsString();
}

Future<bool> pathExists(String path) {
  return File(path).exists();
}

Future<void> deletePath(String path) async {
  final file = File(path);
  if (await file.exists()) {
    await file.delete();
  }
}

Future<void> ensureDir(String path) async {
  final dir = Directory(path);
  if (!await dir.exists()) {
    await dir.create(recursive: true);
  }
}

Future<List<FsEntry>> listDir(String dirPath) async {
  final dir = Directory(dirPath);
  if (!await dir.exists()) return const [];

  final entries = <FsEntry>[];
  await for (final entity in dir.list()) {
    if (entity is! File) continue;
    final stat = await entity.stat();
    entries.add(FsEntry(
      path: entity.path,
      name: entity.uri.pathSegments.isEmpty
          ? entity.path
          : entity.uri.pathSegments.last,
      size: stat.size,
      modified: stat.modified,
      isFile: true,
    ));
  }
  return entries;
}
