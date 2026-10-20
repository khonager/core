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

  test('recent commits load per repository and are cached', () async {
    SharedPreferences.setMockInitialValues({});
    final preferences = await SharedPreferences.getInstance();
    final requestedRepos = <String>[];
    GitHub github() => GitHub(
      client: MockClient((request) async {
        if (request.url.path.endsWith('/commits')) {
          final repo = request.url.path.split('/')[3];
          requestedRepos.add(request.url.path);
          return http.Response(
            jsonEncode([
              {
                'sha': '${repo}123456789',
                'html_url': 'https://github.com/owner/$repo/commit/1',
                'commit': {
                  'message': 'Add $repo feature\nMore detail',
                  'committer': {
                    'date': repo == 'core'
                        ? '2026-10-20T12:00:00Z'
                        : '2026-10-19T12:00:00Z',
                  },
                },
              },
            ]),
            200,
          );
        }
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
    await first.refreshCommits(first.projects.first);
    await first.refreshCommits(
      first.projects.firstWhere((p) => p.id == 'files'),
    );
    await first.refreshCommits(
      first.projects.firstWhere((p) => p.id == 'wisec'),
    );
    expect(first.commits.first.project.id, 'core');
    expect(first.commits.first.title, 'Add core feature');
    expect(
      requestedRepos.where((path) => path.endsWith('/files/commits')),
      hasLength(1),
    );
    expect(requestedRepos.length, 2);
    first.dispose();

    requestedRepos.clear();
    final second = Library(
      preferences: preferences,
      github: github(),
      device: TestDevice(),
    );
    addTearDown(second.dispose);
    await second.init();
    await second.refreshCommits(second.projects.first);
    expect(second.commits.first.title, 'Add core feature');
    expect(requestedRepos, isEmpty);
  });
}
