import 'dart:convert';
import 'package:http/http.dart' as http;
import '../domain/project.dart';

class GitHubException implements Exception {
  GitHubException(this.message, {this.needsAccess = false, this.statusCode});
  final bool needsAccess;
  final int? statusCode;
  final String message;
  @override
  String toString() => message;
}

class GitHub {
  GitHub({http.Client? client}) : client = client ?? http.Client();
  final http.Client client;
  String? _token;
  bool get connected => _token != null;
  set token(String? value) {
    _token = value;
    _cache.clear();
  }

  Map<String, String> get headers => {
    'Accept': 'application/vnd.github+json',
    'X-GitHub-Api-Version': '2022-11-28',
    if (_token != null) 'Authorization': 'Bearer $_token',
  };
  Future<void> validateToken(String token) async {
    final response = await client
        .get(
          Uri.https('api.github.com', '/user'),
          headers: {...headers, 'Authorization': 'Bearer $token'},
        )
        .timeout(const Duration(seconds: 20));
    if (response.statusCode != 200) {
      throw GitHubException(
        'GitHub could not validate this token. Check its expiry and permissions.',
      );
    }
  }

  final Map<String, (String?, dynamic)> _cache = {};
  Future<dynamic> get(String path) async {
    final cached = _cache[path];
    final response = await client
        .get(
          Uri.https('api.github.com', path),
          headers: {
            ...headers,
            if (cached?.$1 != null) 'If-None-Match': cached!.$1!,
          },
        )
        .timeout(const Duration(seconds: 20));
    if (response.statusCode == 304 && cached != null) return cached.$2;
    if (response.statusCode != 200) {
      throw GitHubException(switch (response.statusCode) {
        403 || 429 =>
          'GitHub access or rate limit reached. Try again later or open GitHub.',
        404 => 'Repository or resource is unavailable. It may be private.',
        401 => 'GitHub requires authentication for this resource.',
        _ =>
          'GitHub is unavailable (${response.statusCode}). Pull down to retry.',
      }, statusCode: response.statusCode);
    }
    final data = jsonDecode(response.body);
    _cache[path] = (response.headers['etag'], data);
    return data;
  }

  Future<List<Release>> releases(Project p) async {
    final releases = parseReleases(
      await get('/repos/${p.repository}/releases') as List,
    );
    // A busy dev channel can push the stable release out of the first page.
    if (releases.isNotEmpty && !releases.any((r) => !r.dev)) {
      try {
        releases.add(
          Release(
            await get('/repos/${p.repository}/releases/latest')
                as Map<String, dynamic>,
          ),
        );
      } on GitHubException catch (e) {
        if (e.statusCode != 404) rethrow;
      }
    }
    return releases;
  }

  Future<List<BuildRun>> runs(Project p) async {
    final data =
        await get('/repos/${p.repository}/actions/runs')
            as Map<String, dynamic>;
    // Preserve the latest run of EACH workflow, so an unrelated successful job
    // cannot hide a failing workflow. GitHub returns newest runs first.
    final seen = <dynamic>{};
    return (data['workflow_runs'] as List)
        .cast<Map<String, dynamic>>()
        .where((r) => seen.add(r['workflow_id']))
        .map(BuildRun.new)
        .toList();
  }

  Future<String> logs(Project p, BuildRun run) async {
    final output = StringBuffer(
      '${p.repository} • ${run.title}\n${run.branch} • ${run.sha}\n${run.url}\n\n',
    );
    var page = 1;
    while (true) {
      // A separate URI is used here because pagination is query data.
      final response = await client
          .get(
            Uri.https(
              'api.github.com',
              '/repos/${p.repository}/actions/runs/${run.id}/jobs',
              {'per_page': '100', 'page': '$page'},
            ),
            headers: headers,
          )
          .timeout(const Duration(seconds: 20));
      if (response.statusCode != 200) {
        throw GitHubException(
          'Logs unavailable. Open this build on GitHub.',
          needsAccess: response.statusCode == 401 || response.statusCode == 403,
        );
      }
      final jobs = (jsonDecode(response.body)['jobs'] as List)
          .cast<Map<String, dynamic>>();
      for (final job in jobs) {
        if (job['status'] != 'completed') {
          throw GitHubException(
            'Wait for all jobs to finish before copying the full log.',
          );
        }
        // Fetch the signed log redirect without forwarding a GitHub token to
        // the storage host. Browsers can reject opaque manual redirects.
        final request =
            http.Request(
                'GET',
                Uri.https(
                  'api.github.com',
                  '/repos/${p.repository}/actions/jobs/${job['id']}/logs',
                ),
              )
              ..headers.addAll(headers)
              ..followRedirects = false;
        var log = await http.Response.fromStream(
          await client.send(request).timeout(const Duration(seconds: 30)),
        );
        if (log.statusCode == 302 || log.statusCode == 307) {
          final location = Uri.tryParse(log.headers['location'] ?? '');
          if (location == null || location.scheme != 'https') {
            throw GitHubException('GitHub returned an invalid log link.');
          }
          log = await client.get(location).timeout(const Duration(seconds: 30));
        }
        if (log.statusCode != 200) {
          throw GitHubException(
            'Logs are expired or require GitHub access. Open this build on GitHub.',
            needsAccess: log.statusCode == 401 || log.statusCode == 403,
          );
        }
        output.writeln('===== ${job['name']} =====\n${log.body}\n');
      }
      if (jobs.isEmpty && page == 1) {
        throw GitHubException('No job logs are available yet.');
      }
      if (jobs.length < 100) break;
      page++;
    }
    return output.toString();
  }

  void dispose() => client.close();
}
