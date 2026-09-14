import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';

import 'pinned_http_types.dart';

/// Leaf SHA-256 of api.coingecko.com as of 2026-09. Issuer backup: GTS WE1.
/// If CoinGecko rotates the leaf, the Google Trust Services issuer still passes
/// so prices keep working; a foreign MITM cert does not.
const _leafPins = {
  'e1480dae7135f20c8d1b586701071a9f9f401ea980cd29a00cec4c7520a6ec40',
};

bool _pinOk(X509Certificate cert, String host) {
  if (host != 'api.coingecko.com') return false;
  final fp = sha256.convert(cert.der).toString();
  if (_leafPins.contains(fp)) return true;
  final issuer = cert.issuer.toLowerCase();
  return issuer.contains('google trust services') && issuer.contains('we1');
}

Future<PinnedHttpResponse> pinnedGet(
  Uri uri, {
  Map<String, String>? headers,
  Duration timeout = const Duration(seconds: 15),
}) async {
  if (uri.host != 'api.coingecko.com') {
    throw TlsPinException('Unexpected host ${uri.host}');
  }

  final client = HttpClient();
  client.connectionTimeout = timeout;
  try {
    final request = await client.getUrl(uri).timeout(timeout);
    headers?.forEach(request.headers.set);
    final response = await request.close().timeout(timeout);
    final cert = response.certificate;
    if (cert == null || !_pinOk(cert, uri.host)) {
      throw TlsPinException('TLS certificate pin mismatch for ${uri.host}');
    }
    final body = await response.transform(utf8.decoder).join();
    return PinnedHttpResponse(response.statusCode, body);
  } finally {
    client.close(force: true);
  }
}
