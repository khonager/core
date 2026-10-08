import 'dart:convert';

import 'package:core_app/data/github_auth.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

void main() {
  test('device sign-in respects pending and slow-down responses', () async {
    final waits = <Duration>[];
    var polls = 0;
    final auth = GitHubAuth(
      clientId: 'Iv1.test-client',
      wait: (duration) async => waits.add(duration),
      client: MockClient((request) async {
        expect(request.url.host, 'github.com');
        expect(request.headers['Accept'], 'application/json');
        if (request.url.path.endsWith('/device/code')) {
          expect(request.bodyFields['client_id'], 'Iv1.test-client');
          return http.Response(
            jsonEncode({
              'device_code': 'device-secret',
              'user_code': 'ABCD-1234',
              'verification_uri': 'https://github.com/login/device',
              'expires_in': 900,
              'interval': 5,
            }),
            200,
          );
        }
        expect(request.bodyFields['device_code'], 'device-secret');
        expect(
          request.bodyFields['grant_type'],
          'urn:ietf:params:oauth:grant-type:device_code',
        );
        polls++;
        return http.Response(
          jsonEncode(switch (polls) {
            1 => {'error': 'authorization_pending'},
            2 => {'error': 'slow_down', 'interval': 10},
            _ => {
              'access_token': 'ghu_test',
              'refresh_token': 'ghr_test',
              'expires_in': 28800,
              'token_type': 'bearer',
            },
          }),
          200,
        );
      }),
    );
    final code = await auth.start();
    expect(code.userCode, 'ABCD-1234');
    final credentials = await auth.poll(code, cancelled: () => false);
    expect(credentials!.token, 'ghu_test');
    expect(credentials.refreshToken, 'ghr_test');
    expect(waits, [
      const Duration(seconds: 5),
      const Duration(seconds: 5),
      const Duration(seconds: 10),
    ]);
  });

  test(
    'refresh rotates both tokens and saved credentials round-trip',
    () async {
      final auth = GitHubAuth(
        clientId: 'Iv1.test-client',
        client: MockClient((request) async {
          expect(request.bodyFields['grant_type'], 'refresh_token');
          expect(request.bodyFields['refresh_token'], 'ghr_old');
          return http.Response(
            jsonEncode({
              'access_token': 'ghu_new',
              'refresh_token': 'ghr_new',
              'expires_in': 28800,
              'token_type': 'bearer',
            }),
            200,
          );
        }),
      );
      final updated = await auth.refresh(
        const GitHubCredentials(token: 'ghu_old', refreshToken: 'ghr_old'),
      );
      final restored = GitHubCredentials.fromJson(updated.toJson());
      expect(restored.token, 'ghu_new');
      expect(restored.refreshToken, 'ghr_new');
      expect(restored.expiresAt, isNotNull);
    },
  );

  test('device flow rejects non-GitHub verification links', () async {
    final auth = GitHubAuth(
      clientId: 'Iv1.test-client',
      client: MockClient(
        (_) async => http.Response(
          jsonEncode({
            'device_code': 'device-secret',
            'user_code': 'ABCD-1234',
            'verification_uri': 'https://example.com/login/device',
            'expires_in': 900,
          }),
          200,
        ),
      ),
    );
    await expectLater(auth.start(), throwsA(isA<GitHubAuthException>()));
  });
}
