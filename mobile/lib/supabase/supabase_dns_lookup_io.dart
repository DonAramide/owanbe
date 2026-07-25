import 'dart:async';
import 'dart:io';

Future<({bool ok, String? error})> lookupHost(
  String host, {
  Duration timeout = const Duration(seconds: 4),
}) async {
  try {
    final addresses = await InternetAddress.lookup(host).timeout(timeout);
    if (addresses.isEmpty) {
      return (ok: false, error: 'InternetAddress.lookup($host) returned no addresses');
    }
    return (ok: true, error: null);
  } on SocketException catch (e) {
    return (ok: false, error: '$e');
  } on TimeoutException catch (e) {
    return (ok: false, error: '$e');
  } catch (e) {
    return (ok: false, error: '$e');
  }
}
