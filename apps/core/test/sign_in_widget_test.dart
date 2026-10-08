import 'dart:convert';

import 'package:core_app/data/github.dart';
import 'package:core_app/data/github_auth.dart';
import 'package:core_app/data/library.dart';
import 'package:core_app/main.dart';
import 'package:core_app/platform/device.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

class TestAndroidDevice extends Device {
  @override
  bool get android => true;
  @override
  Future<String?> readToken() async => null;
  @override
  Future<String?> readGitHubAuth() async => null;
  @override
  Future<Map<String, dynamic>> status(String id, String? packageId) async => {};
}

void main() {
  testWidgets('rate-limit notice opens optional GitHub sign-in on tap', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    var signInRequests = 0;
    final client = MockClient((request) async {
      if (request.url.host == 'github.com') {
        signInRequests++;
        if (request.url.path.endsWith('/device/code')) {
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
        return http.Response(
          jsonEncode({'error': 'authorization_pending'}),
          200,
        );
      }
      return http.Response(
        '',
        403,
        headers: {'x-ratelimit-remaining': '0', 'retry-after': '120'},
      );
    });
    final library = Library(
      preferences: await SharedPreferences.getInstance(),
      github: GitHub(client: client),
      auth: GitHubAuth(client: client, clientId: 'Iv1.test-client'),
      device: TestAndroidDevice(),
    );
    addTearDown(library.dispose);
    await tester.runAsync(library.init);
    await tester.pumpWidget(CoreApp(library: library));
    await tester.pumpAndSettle();
    expect(signInRequests, 0);
    await tester.tap(find.text('Core').last);
    await tester.pumpAndSettle();
    expect(find.textContaining('Tap to sign in to GitHub.'), findsWidgets);
    await tester.tap(find.textContaining('Tap to sign in to GitHub.').first);
    await tester.pumpAndSettle();
    expect(signInRequests, 1);
    expect(find.text('ABCD-1234'), findsOneWidget);
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    await tester.pump(const Duration(seconds: 5));
    expect(library.github.connected, isFalse);
  });
}
