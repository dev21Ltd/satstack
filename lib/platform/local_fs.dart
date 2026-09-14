import 'fs_entry.dart';
import 'local_fs_stub.dart' if (dart.library.io) 'local_fs_io.dart' as impl;

export 'fs_entry.dart';

Future<void> writeBytesToPath(String path, List<int> bytes) =>
    impl.writeBytesToPath(path, bytes);

Future<List<int>> readBytesFromPath(String path) =>
    impl.readBytesFromPath(path);

Future<String> readStringFromPath(String path) =>
    impl.readStringFromPath(path);

Future<bool> pathExists(String path) => impl.pathExists(path);

Future<void> deletePath(String path) => impl.deletePath(path);

Future<void> ensureDir(String path) => impl.ensureDir(path);

Future<List<FsEntry>> listDir(String dirPath) => impl.listDir(dirPath);
