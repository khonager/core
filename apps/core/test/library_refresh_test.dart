import 'dart:convert';

import 'package:core_app/data/github.dart';
import 'package:core_app/data/github_auth.dart';
import 'package:core_app/data/library.dart';
import 'package:core_app/platform/device.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

class TestDevice extends Device {
  @override
  bool get android => false;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test(
    'a new launch uses cached metadata during the refresh interval',
    () async {
      SharedPreferences.setMockInitialValues({});
      final preferences = await SharedPreferences.getInstance();
      var requests = 0;
      GitHub github() => GitHub(
        client: MockClient((request) async {
          requests++;
          return request.url.path.endsWith('/actions/runs')
              ? http.Response(jsonEncode({'workflow_runs': []}), 200)
              : http.Response('[]', 200);
        }),
      );

      final first = Library(
        preferences: preferences,
        github: github(),
        device: TestDevice(),
      );
      await first.init();
      expect(requests, greaterThan(0));
      first.dispose();

      requests = 0;
      final second = Library(
        preferences: preferences,
        github: github(),
        device: TestDevice(),
      );
      addTearDown(second.dispose);
      await second.init();
      expect(requests, 0);
      await second.refresh();
      expect(requests, 0);
    },
  );

  test('rate limit stops requests for the rest of the catalog', () async {
    SharedPreferences.setMockInitialValues({});
    final preferences = await SharedPreferences.getInstance();
    var requests = 0;
    final library = Library(
      preferences: preferences,
      github: GitHub(
        client: MockClient((_) async {
          requests++;
          return http.Response(
            '',
            403,
            headers: {'x-ratelimit-remaining': '0', 'retry-after': '120'},
          );
        }),
      ),
      device: TestDevice(),
    );
    addTearDown(library.dispose);
    await library.init();
    expect(requests, 1);
    for (final project in library.projects) {
      expect(library.states[project.id]!.buildError, contains('rate limit'));
    }
    final reopened = Library(
      preferences: preferences,
      github: GitHub(
        client: MockClient((_) async {
          requests++;
          return http.Response('[]', 200);
        }),
      ),
      device: TestDevice(),
    );
    addTearDown(reopened.dispose);
    await reopened.init();
    expect(requests, 1);
  });

  test('sign-in clears the cooldown and refreshes with user access', () async {
    SharedPreferences.setMockInitialValues({});
    var authenticatedRequests = 0;
    final library = Library(
      preferences: await SharedPreferences.getInstance(),
      github: GitHub(
        client: MockClient((request) async {
          if (request.url.path == '/user') {
            expect(request.headers['Authorization'], 'Bearer ghu_test');
            return http.Response('{}', 200);
          }
          if (request.headers['Authorization'] == null) {
            return http.Response(
              '',
              403,
              headers: {'x-ratelimit-remaining': '0', 'retry-after': '120'},
            );
          }
          authenticatedRequests++;
          return request.url.path.endsWith('/actions/runs')
              ? http.Response(jsonEncode({'workflow_runs': []}), 200)
              : http.Response('[]', 200);
        }),
      ),
      device: TestDevice(),
    );
    addTearDown(library.dispose);
    await library.init();
    expect(library.github.rateLimited, isTrue);
    await library.connectCredentials(
      const GitHubCredentials(token: 'ghu_test'),
    );
    expect(library.github.rateLimited, isFalse);
    expect(authenticatedRequests, greaterThan(0));
    expect(library.states[library.projects.first.id]!.buildError, isNull);
  });
}
