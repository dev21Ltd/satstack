import 'package:http/http.dart' as http;

import 'pinned_http_types.dart';

Future<PinnedHttpResponse> pinnedGet(
  Uri uri, {
  Map<String, String>? headers,
  Duration timeout = const Duration(seconds: 15),
}) async {
  final response = await http.get(uri, headers: headers).timeout(timeout);
  return PinnedHttpResponse(response.statusCode, response.body);
}
