import 'pinned_http_stub.dart' if (dart.library.io) 'pinned_http_io.dart' as impl;
import 'pinned_http_types.dart';
export 'pinned_http_types.dart';

Future<PinnedHttpResponse> pinnedGet(
  Uri uri, {
  Map<String, String>? headers,
  Duration timeout = const Duration(seconds: 15),
}) {
  return impl.pinnedGet(uri, headers: headers, timeout: timeout);
}
