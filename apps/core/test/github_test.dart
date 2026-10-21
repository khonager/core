import 'dart:convert';
import 'package:core_app/data/github.dart';
import 'package:core_app/domain/project.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

const project = Project(
  id: 'sample',
  name: 'Sample',
  description: 'Test',
  repository: 'owner/sample',
);
Map<String, dynamic> release(
  String tag,
  bool dev,
  String date, {
  bool draft = false,
}) => {
  'tag_name': tag,
  'prerelease': dev,
  'published_at': date,
  'draft': draft,
  'html_url': 'https://github.com/owner/sample/releases/tag/$tag',
  'assets': [
    {
      'name': 'app.apk',
      'size': 12,
      'browser_download_url':
          'https://github.com/owner/sample/releases/download/$tag/app.apk',
    },
    {'name': 'source.zip'},
  ],
};
Map<String, dynamic> run(
  int id,
  int workflow,
  String conclusion, {
  String status = 'completed',
}) => {
  'id': id,
  'workflow_id': workflow,
  'status': status,
  'conclusion': conclusion,
  'name': 'Android',
  'head_branch': 'main',
  'head_sha': 'abcdef123456',
  'html_url': 'https://github.com/owner/sample/actions/runs/$id',
};
void main() {
  test(
    'private APK resolves through the asset API without leaking access',
    () async {
      final github = GitHub(
        client: MockClient((request) async {
          expect(
            request.url.toString(),
            'https://api.github.com/repos/owner/sample/releases/assets/123',
          );
          expect(request.headers['authorization'], 'Bearer test-token');
          expect(request.headers['accept'], 'application/octet-stream');
          expect(request.followRedirects, false);
          return http.Response(
            '',
            302,
            headers: {
              'location':
                  'https://release-assets.githubusercontent.com/signed?token=short-lived',
            },
          );
        }),
      )..token = 'test-token';
      final url = await github.apkDownloadUrl({
        'url': 'https://api.github.com/repos/owner/sample/releases/assets/123',
        'browser_download_url':
            'https://github.com/owner/sample/releases/download/v1/app.apk',
      });
      expect(url, startsWith('https://release-assets.githubusercontent.com/'));
    },
  );

  test(
    'private APK rejects redirects away from GitHub asset storage',
    () async {
      final github = GitHub(
        client: MockClient(
          (_) async => http.Response(
            '',
            302,
            headers: {'location': 'https://example.com/app.apk'},
          ),
        ),
      )..token = 'test-token';
      expect(
        () => github.apkDownloadUrl({
          'url':
              'https://api.github.com/repos/owner/sample/releases/assets/123',
          'browser_download_url':
              'https://github.com/owner/sample/releases/download/v1/app.apk',
        }),
        throwsA(isA<GitHubException>()),
      );
    },
  );

  test('release channels use publication order and exclude drafts', () {
    final releases = parseReleases([
      release('v1', false, '2025-01-01'),
      release('v2-dev', true, '2025-03-01'),
      release('draft', false, '2025-04-01', draft: true),
      release('v2', false, '2025-02-01'),
    ]);
    final state = ProjectState()..releases = releases;
    expect(state.latest(false)!.tag, 'v2');
    expect(state.latest(true)!.tag, 'v2-dev');
    expect(state.latest(false)!.apks.single['name'], 'app.apk');
  });
  test(
    'latest successful workflow does not hide another failing workflow',
    () async {
      final github = GitHub(
        client: MockClient(
          (_) async => http.Response(
            jsonEncode({
              'workflow_runs': [
                run(4, 1, 'success'),
                run(3, 2, 'failure'),
                run(2, 1, 'failure'),
              ],
            }),
            200,
          ),
        ),
      );
      final state = ProjectState()..runs = await github.runs(project);
      expect(state.runs.map((r) => r.id), [4, 3]);
      expect(state.status, BuildStatus.failure);
    },
  );
  test(
    'run feed supplies the prior success without another API request',
    () async {
      var requests = 0;
      final github = GitHub(
        client: MockClient((_) async {
          requests++;
          return http.Response(
            jsonEncode({
              'workflow_runs': [run(8, 1, 'failure'), run(7, 1, 'success')],
            }),
            200,
          );
        }),
      );
      final current = (await github.runs(project)).single;
      expect((await github.previousSuccessfulRun(project, current))?.id, 7);
      expect(requests, 1);
    },
  );
  test('rate limit has actionable error', () async {
    var requests = 0;
    final github = GitHub(
      client: MockClient((_) async {
        requests++;
        return http.Response(
          '',
          403,
          headers: {'x-ratelimit-remaining': '0', 'retry-after': '120'},
        );
      }),
    );
    await expectLater(
      github.releases(project),
      throwsA(
        isA<GitHubException>().having(
          (e) => e.message,
          'message',
          contains('rate limit'),
        ),
      ),
    );
    expect(github.rateLimited, isTrue);
    await expectLater(github.runs(project), throwsA(isA<GitHubException>()));
    expect(requests, 1);
  });
  test('access denied is not mistaken for rate limiting', () async {
    final github = GitHub(
      client: MockClient((_) async => http.Response('', 403)),
    );
    await expectLater(
      github.runs(project),
      throwsA(
        isA<GitHubException>().having(
          (e) => e.message,
          'message',
          contains('denied access'),
        ),
      ),
    );
    expect(github.rateLimited, isFalse);
  });
  test('anonymous requests reserve the last five API calls', () async {
    var requests = 0;
    final reset = DateTime.now().add(const Duration(hours: 1));
    final github = GitHub(
      client: MockClient((_) async {
        requests++;
        return http.Response(
          '[]',
          200,
          headers: {
            'x-ratelimit-remaining': '5',
            'x-ratelimit-reset': '${reset.millisecondsSinceEpoch ~/ 1000}',
          },
        );
      }),
    );
    await github.commits(project);
    expect(github.lowBudget, isTrue);
    expect(github.budgetExhausted, isTrue);
    expect(await github.commits(project), isEmpty);
    await expectLater(
      github.get('/repos/owner/another/commits'),
      throwsA(
        isA<GitHubException>().having(
          (e) => e.message,
          'message',
          contains('nearly exhausted'),
        ),
      ),
    );
    expect(requests, 1);
  });
  test('ETag revalidation keeps prior result on 304', () async {
    var requests = 0;
    final github = GitHub(
      client: MockClient((r) async {
        if (requests++ == 0) {
          return http.Response('[]', 200, headers: {'etag': 'test'});
        }
        expect(r.headers['If-None-Match'], 'test');
        return http.Response('', 304);
      }),
    );
    await github.get('/repos/owner/sample/releases');
    expect(await github.get('/repos/owner/sample/releases'), isEmpty);
  });
  test('copy full logs includes every job and context', () async {
    final github = GitHub(
      client: MockClient((r) async {
        if (r.url.path.endsWith('/jobs')) {
          return http.Response(
            jsonEncode({
              'jobs': [
                {'id': 1, 'name': 'Analyze', 'status': 'completed'},
                {'id': 2, 'name': 'Build', 'status': 'completed'},
              ],
            }),
            200,
          );
        }
        return http.Response(
          r.url.path.contains('/1/') ? 'analysis output' : 'build output',
          200,
        );
      }),
    );
    final text = await github.logs(project, BuildRun(run(2, 1, 'failure')));
    expect(text, contains('analysis output'));
    expect(text, contains('build output'));
    expect(text, contains('owner/sample'));
  });
  test(
    'missing job log fails rather than silently copying partial logs',
    () async {
      final github = GitHub(
        client: MockClient(
          (r) async => r.url.path.endsWith('/jobs')
              ? http.Response(
                  jsonEncode({
                    'jobs': [
                      {'id': 1, 'name': 'Build', 'status': 'completed'},
                    ],
                  }),
                  200,
                )
              : http.Response('', 410),
        ),
      );
      expect(
        () => github.logs(project, BuildRun(run(2, 1, 'failure'))),
        throwsA(isA<GitHubException>()),
      );
    },
  );
  test('unknown and cancelled builds do not claim success', () {
    expect(ProjectState().status, BuildStatus.unknown);
    expect(BuildRun(run(1, 1, 'cancelled')).status, BuildStatus.cancelled);
    expect(BuildRun(run(1, 1, '', status: 'queued')).label, 'Build queued');
  });
  test(
    'build progress uses matching step and total durations from prior jobs',
    () {
      Map<String, dynamic> step(
        int number,
        String name,
        String status,
        String start,
        String? end,
        String? conclusion,
      ) => {
        'number': number,
        'name': name,
        'status': status,
        'started_at': start,
        'completed_at': end,
        'conclusion': conclusion,
      };
      final previous = BuildJob({
        'name': 'Android',
        'started_at': '2026-10-19T10:00:00Z',
        'completed_at': '2026-10-19T10:10:00Z',
        'steps': [
          step(
            1,
            'Setup',
            'completed',
            '2026-10-19T10:00:00Z',
            '2026-10-19T10:02:00Z',
            'success',
          ),
          step(
            2,
            'Compile',
            'completed',
            '2026-10-19T10:02:00Z',
            '2026-10-19T10:10:00Z',
            'success',
          ),
        ],
      });
      final current = BuildJob({
        'name': 'Android',
        'steps': [
          step(
            1,
            'Setup',
            'completed',
            '2026-10-20T10:00:00Z',
            '2026-10-20T10:02:00Z',
            'success',
          ),
          step(2, 'Compile', 'in_progress', '2026-10-20T10:02:00Z', null, null),
        ],
      });
      final details = BuildDetails(jobs: [current], previousJobs: [previous]);
      expect(details.activeStep?.$2.name, 'Compile');
      expect(
        details.previousStepDuration(current, current.steps.last),
        const Duration(minutes: 8),
      );
      expect(details.previousTotalDuration, const Duration(minutes: 10));
      final withRunTiming = BuildDetails(
        jobs: [current],
        previousJobs: [previous],
        previousRun: BuildRun({
          ...run(2, 1, 'success'),
          'run_started_at': '2026-10-19T09:59:00Z',
          'updated_at': '2026-10-19T10:11:00Z',
        }),
      );
      expect(withRunTiming.previousTotalDuration, const Duration(minutes: 12));
      expect(details.progress(DateTime.parse('2026-10-20T10:06:00Z')), 0.75);
      current.json['steps'] = [
        step(
          1,
          'Setup',
          'completed',
          '2026-10-20T10:00:00Z',
          '2026-10-20T10:02:00Z',
          'success',
        ),
        step(
          2,
          'Compile',
          'completed',
          '2026-10-20T10:02:00Z',
          '2026-10-20T10:06:00Z',
          'failure',
        ),
      ];
      expect(details.failedStep?.$2.name, 'Compile');
    },
  );

  test('GitHub loads jobs and the previous successful run', () async {
    final requested = <String>[];
    final github = GitHub(
      client: MockClient((request) async {
        requested.add(request.url.path);
        if (request.url.path.endsWith('/jobs')) {
          return http.Response(
            jsonEncode({
              'jobs': [
                {'name': 'Build', 'steps': []},
              ],
            }),
            200,
          );
        }
        expect(request.url.queryParameters['branch'], 'main');
        return http.Response(
          jsonEncode({
            'workflow_runs': [run(3, 1, 'success'), run(2, 1, 'success')],
          }),
          200,
        );
      }),
    );
    final current = BuildRun(run(3, 1, 'success'));
    expect((await github.jobs(project, current)).single.name, 'Build');
    expect((await github.previousSuccessfulRun(project, current))?.id, 2);
    expect(requested, [
      '/repos/owner/sample/actions/runs/3/jobs',
      '/repos/owner/sample/actions/workflows/1/runs',
    ]);
  });
  test(
    'authenticated log redirect does not leak the token to storage',
    () async {
      final github = GitHub(
        client: MockClient((r) async {
          if (r.url.host == 'logs.example.com') {
            expect(r.headers['Authorization'], isNull);
            return http.Response('complete log', 200);
          }
          expect(r.headers['Authorization'], 'Bearer test-only-token');
          if (r.url.path.endsWith('/jobs')) {
            return http.Response(
              jsonEncode({
                'jobs': [
                  {'id': 1, 'name': 'Build', 'status': 'completed'},
                ],
              }),
              200,
            );
          }
          expect(r.followRedirects, isFalse);
          return http.Response(
            '',
            302,
            headers: {'location': 'https://logs.example.com/signed'},
          );
        }),
      )..token = 'test-only-token';
      expect(
        await github.logs(project, BuildRun(run(1, 1, 'success'))),
        contains('complete log'),
      );
    },
  );
  test('stable release outside the recent dev feed is still found', () async {
    final github = GitHub(
      client: MockClient(
        (r) async => http.Response(
          jsonEncode(
            r.url.path.endsWith('/latest')
                ? release('v1', false, '2025-01-01')
                : [release('v2-dev', true, '2025-03-01')],
          ),
          200,
        ),
      ),
    );
    final state = ProjectState()..releases = await github.releases(project);
    expect(state.latest(false)!.tag, 'v1');
    expect(state.latest(true)!.tag, 'v2-dev');
  });
  test('development release beyond the first page is found', () async {
    final requestedPages = <String?>[];
    final github = GitHub(
      client: MockClient((r) async {
        requestedPages.add(r.url.queryParameters['page']);
        final data = r.url.queryParameters['page'] == '1'
            ? List.generate(30, (i) => release('v$i', false, '2025-01-01'))
            : [release('dev-latest', true, '2025-02-01')];
        return http.Response(jsonEncode(data), 200);
      }),
    );
    final state = ProjectState()..releases = await github.releases(project);
    expect(requestedPages, ['1', '2']);
    expect(state.latest(true)!.tag, 'dev-latest');
  });
}
