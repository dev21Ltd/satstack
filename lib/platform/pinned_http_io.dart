import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';

import 'pinned_http_types.dart';

/// Leaf SHA-256 as of 2026-09. Issuer backup covers a leaf rotation on the
/// same certificate authority. A cert from any other issuer still fails.
const _coingeckoLeaf = 'e1480dae7135f20c8d1b586701071a9f9f401ea980cd29a00cec4c7520a6ec40';
const _coinbaseLeaf = 'b22debd26a0759bb6afd66d17b66aaf2fc11a91d4e1b6bc7105901199e24770b';
const _blockchainLeaf = 'a7f0de39fb635f27fb249648d8a21bd41ca9cea62111ab5c51ac0e6cb0452348';

bool _gtsWe1(String issuer) =>
    issuer.contains('google trust services') && issuer.contains('we1');

bool _pinOk(X509Certificate cert, String host) {
  final fp = sha256.convert(cert.der).toString();
  final issuer = cert.issuer.toLowerCase();
  switch (host) {
    case 'api.coingecko.com':
      return fp == _coingeckoLeaf || _gtsWe1(issuer);
    case 'api.coinbase.com':
      return fp == _coinbaseLeaf || _gtsWe1(issuer);
    case 'blockchain.info':
      return fp == _blockchainLeaf || issuer.contains('digicert');
    default:
      return false;
  }
}

Future<PinnedHttpResponse> pinnedGet(
  Uri uri, {
  Map<String, String>? headers,
  Duration timeout = const Duration(seconds: 15),
}) async {
  if (uri.host != 'api.coingecko.com' &&
      uri.host != 'api.coinbase.com' &&
      uri.host != 'blockchain.info') {
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
