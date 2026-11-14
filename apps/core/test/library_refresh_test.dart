import 'dart:convert';

import 'package:core_app/data/github.dart';
import 'package:core_app/data/github_auth.dart';
import 'package:core_app/data/library.dart';
import 'package:core_app/domain/project.dart';
import 'package:core_app/platform/device.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

class TestDevice extends Device {
  @override
  bool get android => false;
}

class UpdateDevice extends TestDevice {
  final downloadsStarted = <String>[];
  final installsStarted = <String>[];
  @override
  bool get android => true;
  @override
  Future<String?> readGitHubAuth() async => null;
  @override
  Future<String?> readToken() async => null;
  @override
  Future<Map<String, dynamic>> status(String id, String? packageId) async => {
    'phase': downloadsStarted.contains(id) ? 'ready' : 'none',
    if (packageId != null) 'version': '1.0.0',
  };
  @override
  Future<void> download(
    String id,
    String name,
    String url,
    String? packageId,
  ) async {
    downloadsStarted.add(id);
  }

  @override
  Future<void> install(String id) async {
    installsStarted.add(id);
  }
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
      expect(requests, 0);
      await first.refreshProject(first.projects.first, automatic: true);
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
      await second.refreshProject(second.projects.first, automatic: true);
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
    await library.refresh();
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
    await library.refreshProject(library.projects.first, automatic: true);
    expect(library.github.rateLimited, isTrue);
    await library.connectCredentials(
      const GitHubCredentials(token: 'ghu_test'),
    );
    expect(library.github.rateLimited, isFalse);
    expect(authenticatedRequests, greaterThan(0));
    expect(library.states[library.projects.first.id]!.buildError, isNull);
  });

  test(
    'full library refresh stops when the anonymous budget runs low',
    () async {
      SharedPreferences.setMockInitialValues({});
      var requests = 0;
      final reset = DateTime.now().add(const Duration(hours: 1));
      final preferences = await SharedPreferences.getInstance();
      final library = Library(
        preferences: preferences,
        github: GitHub(
          client: MockClient((request) async {
            requests++;
            final remaining = 21 - requests;
            final headers = {
              'x-ratelimit-remaining': '$remaining',
              'x-ratelimit-reset': '${reset.millisecondsSinceEpoch ~/ 1000}',
            };
            return request.url.path.endsWith('/actions/runs')
                ? http.Response(
                    jsonEncode({'workflow_runs': []}),
                    200,
                    headers: headers,
                  )
                : http.Response('[]', 200, headers: headers);
          }),
        ),
        device: TestDevice(),
      );
      addTearDown(library.dispose);
      await library.init();
      expect(requests, 0);
      await library.refresh();
      expect(requests, 2);
      expect(library.refreshNotice, contains('running low'));
      final reopened = Library(
        preferences: preferences,
        github: GitHub(
          client: MockClient((_) async {
            requests++;
            throw StateError('The saved budget should stop a full refresh.');
          }),
        ),
        device: TestDevice(),
      );
      addTearDown(reopened.dispose);
      await reopened.init();
      await reopened.refresh();
      expect(requests, 2);
    },
  );

  test('build refresh reuses recent jobs and previous-run history', () async {
    SharedPreferences.setMockInitialValues({});
    var currentJobs = 0, previousJobs = 0, history = 0;
    final library = Library(
      preferences: await SharedPreferences.getInstance(),
      github: GitHub(
        client: MockClient((request) async {
          final path = request.url.path;
          if (path.endsWith('/actions/runs/8/jobs')) {
            currentJobs++;
            return http.Response(jsonEncode({'jobs': []}), 200);
          }
          if (path.endsWith('/actions/runs/7/jobs')) {
            previousJobs++;
            return http.Response(jsonEncode({'jobs': []}), 200);
          }
          if (path.contains('/actions/workflows/')) {
            history++;
            return http.Response(
              jsonEncode({
                'workflow_runs': [
                  {
                    'id': 7,
                    'workflow_id': 1,
                    'status': 'completed',
                    'conclusion': 'success',
                  },
                ],
              }),
              200,
            );
          }
          throw StateError('Unexpected request: $path');
        }),
      ),
      device: TestDevice(),
    );
    addTearDown(library.dispose);
    await library.init();
    final project = library.projects.first;
    final run = BuildRun({
      'id': 8,
      'workflow_id': 1,
      'status': 'in_progress',
      'head_branch': 'main',
    });
    await library.loadBuildDetails(project, run);
    await library.loadBuildDetails(project, run, force: true);
    expect(currentJobs, 1);
    expect(previousJobs, 1);
    expect(history, 1);
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

  test('stable and development commits keep separate caches', () async {
    SharedPreferences.setMockInitialValues({});
    final preferences = await SharedPreferences.getInstance();
    final requestedRefs = <String?>[];
    GitHub github() => GitHub(
      client: MockClient((request) async {
        if (request.url.path.endsWith('/commits')) {
          final ref = request.url.queryParameters['sha'];
          requestedRefs.add(ref);
          return http.Response(
            jsonEncode([
              {
                'sha': ref == null ? 'stable123456789' : 'dev123456789',
                'html_url': 'https://github.com/owner/core/commit/1',
                'commit': {
                  'message': ref == null ? 'Stable change' : 'Dev change',
                  'committer': {'date': '2026-10-22T12:00:00Z'},
                },
              },
            ]),
            200,
          );
        }
        return http.Response('[]', 200);
      }),
    );
    final first = Library(
      preferences: preferences,
      github: github(),
      device: TestDevice(),
    );
    await first.init();
    final project = first.projects.first;
    first.states[project.id]!.releases = [
      Release({
        'tag_name': 'dev',
        'prerelease': true,
        'published_at': '2026-10-22T12:00:00Z',
        'assets': [],
      }),
    ];
    await first.refreshCommits(project);
    await first.refreshCommits(project, dev: true);
    expect(requestedRefs, [null, 'dev']);
    expect(
      first.commits.where((entry) => entry.dev).single.title,
      'Dev change',
    );
    expect(
      first.commits.where((entry) => !entry.dev).single.title,
      'Stable change',
    );
    first.dispose();

    final second = Library(
      preferences: preferences,
      github: github(),
      device: TestDevice(),
    );
    addTearDown(second.dispose);
    await second.init();
    expect(
      second.commits.where((entry) => entry.dev).single.title,
      'Dev change',
    );
    expect(
      second.commits.where((entry) => !entry.dev).single.title,
      'Stable change',
    );
  });

  test(
    'loading more commits appends the next page and stops at the end',
    () async {
      SharedPreferences.setMockInitialValues({});
      final pages = <String?>[];
      final lib = Library(
        preferences: await SharedPreferences.getInstance(),
        device: TestDevice(),
        github: GitHub(
          client: MockClient((request) async {
            if (!request.url.path.endsWith('/commits')) {
              return http.Response('[]', 200);
            }
            final page = request.url.queryParameters['page'];
            pages.add(page);
            final count = page == '1' ? 5 : 2;
            return http.Response(
              jsonEncode([
                for (var i = 0; i < count; i++)
                  {
                    'sha': '$page${i}abcde123456789',
                    'html_url': 'https://github.com/owner/core/commit/$page-$i',
                    'commit': {
                      'message': 'Commit $page-$i',
                      'committer': {'date': '2026-10-22T12:00:00Z'},
                    },
                  },
              ]),
              200,
            );
          }),
        ),
      );
      addTearDown(lib.dispose);
      await lib.init();
      final project = lib.projects.first;
      await lib.refreshCommits(project);
      await lib.refreshCommits(project, loadMore: true);
      await lib.refreshCommits(project, loadMore: true);
      expect(pages, ['1', '2']);
      expect(
        lib.commits.where((commit) => commit.project.id == project.id),
        hasLength(7),
      );
      expect(lib.commitsHasMore[lib.commitKey(project, false)], false);
    },
  );

  test('selected app updates download and ask Android to install', () async {
    SharedPreferences.setMockInitialValues({});
    final device = UpdateDevice();
    final lib = Library(
      preferences: await SharedPreferences.getInstance(),
      device: device,
      github: GitHub(
        client: MockClient((request) async {
          if (request.url.path.endsWith('/releases')) {
            return http.Response(
              jsonEncode([
                for (final version in ['2.0.0', '1.0.0'])
                  {
                    'tag_name': 'v$version',
                    'prerelease': false,
                    'draft': false,
                    'published_at': version == '2.0.0'
                        ? '2026-11-01T12:00:00Z'
                        : '2026-10-01T12:00:00Z',
                    'html_url':
                        'https://github.com/khonager/core/releases/tag/v$version',
                    'assets': [
                      {
                        'name': 'app-universal.apk',
                        'size': 100,
                        'browser_download_url':
                            'https://github.com/khonager/core/releases/download/v$version/app-universal.apk',
                      },
                    ],
                  },
              ]),
              200,
            );
          }
          return http.Response(jsonEncode({'workflow_runs': []}), 200);
        }),
      ),
    );
    addTearDown(lib.dispose);
    await lib.init();
    final project = lib.projects.first;
    await lib.setAutoUpdate(project, false, true);
    expect(lib.autoUpdateEnabled(project, false), isTrue);
    expect(device.downloadsStarted, ['${project.id}.stable']);
    expect(device.installsStarted, ['${project.id}.stable']);
    await lib.setAutoUpdate(project, false, false);
    expect(lib.autoUpdateEnabled(project, false), isFalse);
  });
}
