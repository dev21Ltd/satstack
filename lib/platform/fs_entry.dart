class FsEntry {
  final String path;
  final String name;
  final int size;
  final DateTime modified;
  final bool isFile;

  const FsEntry({
    required this.path,
    required this.name,
    required this.size,
    required this.modified,
    required this.isFile,
  });
}
