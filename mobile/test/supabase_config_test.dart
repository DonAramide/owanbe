import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:owambe/supabase/supabase_config.dart';
import 'package:owambe/supabase/supabase_diagnostic.dart';

void main() {
  tearDown(SupabaseConfig.debugReset);

  test('accepts valid supabase URL and matching anon JWT ref', () {
    const url = 'https://iozdkiwcwblydsomxhxa.supabase.co';
    final payload = base64Url.encode(
      utf8.encode('{"ref":"iozdkiwcwblydsomxhxa","role":"anon"}'),
    );
    final anon = 'eyJhbGciOiJub25lIn0.$payload.sig';

    final config = SupabaseConfig.parseAndValidate({
      'SUPABASE_URL': url,
      'SUPABASE_ANON_KEY': anon,
    });

    expect(config.url, url);
    expect(config.projectRef, 'iozdkiwcwblydsomxhxa');
    expect(config.host, 'iozdkiwcwblydsomxhxa.supabase.co');
  });

  test('rejects missing URL', () {
    expect(
      () => SupabaseConfig.parseAndValidate({'SUPABASE_ANON_KEY': 'x.y.z'}),
      throwsA(
        isA<SupabaseConfigException>().having(
          (e) => e.diagnostic.kind,
          'kind',
          SupabaseFailureKind.missingUrl,
        ),
      ),
    );
  });

  test('rejects http URL', () {
    expect(
      () => SupabaseConfig.parseAndValidate({
        'SUPABASE_URL': 'http://iozdkiwcwblydsomxhxa.supabase.co',
        'SUPABASE_ANON_KEY': 'aaaa.bbbb.cccc',
      }),
      throwsA(
        isA<SupabaseConfigException>().having(
          (e) => e.diagnostic.kind,
          'kind',
          SupabaseFailureKind.notHttps,
        ),
      ),
    );
  });

  test('rejects whitespace in URL', () {
    expect(
      () => SupabaseConfig.parseAndValidate({
        'SUPABASE_URL': ' https://iozdkiwcwblydsomxhxa.supabase.co',
        'SUPABASE_ANON_KEY': 'aaaa.bbbb.cccc',
      }),
      throwsA(
        isA<SupabaseConfigException>().having(
          (e) => e.diagnostic.kind,
          'kind',
          SupabaseFailureKind.whitespaceInUrl,
        ),
      ),
    );
  });

  test('rejects malformed project host', () {
    expect(
      () => SupabaseConfig.parseAndValidate({
        'SUPABASE_URL': 'https://not-supabase.example.com',
        'SUPABASE_ANON_KEY': 'aaaa.bbbb.cccc',
      }),
      throwsA(
        isA<SupabaseConfigException>().having(
          (e) => e.diagnostic.kind,
          'kind',
          SupabaseFailureKind.malformedProjectRef,
        ),
      ),
    );
  });
}
