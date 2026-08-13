import 'dart:async';

import 'package:http/http.dart' as http;

/// Default timeout for Owambe REST calls — avoids infinite loading when API is down.
/// Profile upserts / media can exceed 12s under JWKS or storage latency.
const Duration kOwambeHttpTimeout = Duration(seconds: 45);

http.Client createOwambeHttpClient() => _TimeoutClient(http.Client(), kOwambeHttpTimeout);

class _TimeoutClient extends http.BaseClient {
  _TimeoutClient(this._inner, this.timeout);

  final http.Client _inner;
  final Duration timeout;

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) {
    return _inner.send(request).timeout(
      timeout,
      onTimeout: () => throw TimeoutException(
        'Could not reach Owambe API (${request.url.host}) within ${timeout.inSeconds}s. '
        'Is the backend running on OWANBE_API_BASE?',
      ),
    );
  }

  @override
  void close() => _inner.close();
}
