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
  test('rate limit has actionable error', () async {
    final github = GitHub(
      client: MockClient((_) async => http.Response('', 403)),
    );
    expect(
      () => github.releases(project),
      throwsA(
        isA<GitHubException>().having(
          (e) => e.message,
          'message',
          contains('rate limit'),
        ),
      ),
    );
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
    await github.releases(project);
    expect(await github.releases(project), isEmpty);
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
