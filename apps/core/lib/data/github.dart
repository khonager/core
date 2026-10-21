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
  DateTime? _rateLimitedUntil;
  int? _remaining;
  DateTime? _windowResetsAt;
  bool get connected => _token != null;
  int? get remaining => _remaining;
  DateTime? get windowResetsAt => _windowResetsAt;
  void restoreBudget(int? remaining, DateTime? resetsAt) {
    if (resetsAt != null && DateTime.now().isBefore(resetsAt)) {
      _remaining = remaining;
      _windowResetsAt = resetsAt;
    }
  }

  bool get lowBudget =>
      !connected &&
      _remaining != null &&
      _remaining! <= 20 &&
      (_windowResetsAt == null || DateTime.now().isBefore(_windowResetsAt!));
  bool get budgetExhausted => lowBudget && _remaining! <= 5;
  bool get rateLimited =>
      _rateLimitedUntil != null && DateTime.now().isBefore(_rateLimitedUntil!);
  DateTime? get rateLimitedUntil => _rateLimitedUntil;
  void restoreRateLimit(DateTime? until) => _rateLimitedUntil = until;
  set token(String? value) {
    _token = value;
    _rateLimitedUntil = null;
    _remaining = null;
    _windowResetsAt = null;
    _cache.clear();
    _previousSuccess.clear();
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

  final Map<String, (String?, dynamic, DateTime)> _cache = {};
  final Map<int, BuildRun> _previousSuccess = {};
  Future<dynamic> get(
    String path, {
    Map<String, String>? query,
    Duration? maxAge,
  }) async {
    final uri = Uri.https('api.github.com', path, query);
    final cacheKey = uri.toString();
    final cached = _cache[cacheKey];
    if (cached != null &&
        maxAge != null &&
        DateTime.now().difference(cached.$3) < maxAge) {
      return cached.$2;
    }
    if (rateLimited) throw GitHubException(rateLimitMessage, statusCode: 429);
    if (budgetExhausted) {
      throw GitHubException(
        'GitHub requests are nearly exhausted. Try again later or connect GitHub.',
        statusCode: 429,
      );
    }
    final response = await client
        .get(
          uri,
          headers: {
            ...headers,
            if (cached?.$1 != null) 'If-None-Match': cached!.$1!,
          },
        )
        .timeout(const Duration(seconds: 20));
    final remaining = response.headers['x-ratelimit-remaining'];
    final parsedRemaining = int.tryParse(remaining ?? '');
    final resetSeconds = int.tryParse(
      response.headers['x-ratelimit-reset'] ?? '',
    );
    if (parsedRemaining != null) _remaining = parsedRemaining;
    if (resetSeconds != null) {
      _windowResetsAt = DateTime.fromMillisecondsSinceEpoch(
        resetSeconds * 1000,
      );
    }
    final isRateLimit =
        response.statusCode == 429 ||
        (response.statusCode == 403 &&
            (remaining == '0' ||
                response.body.toLowerCase().contains('rate limit')));
    if (isRateLimit || remaining == '0') {
      final retrySeconds = int.tryParse(response.headers['retry-after'] ?? '');
      _rateLimitedUntil = retrySeconds != null
          ? DateTime.now().add(Duration(seconds: retrySeconds))
          : remaining == '0' && resetSeconds != null
          ? DateTime.fromMillisecondsSinceEpoch(resetSeconds * 1000)
          : DateTime.now().add(const Duration(minutes: 1));
    }
    if (response.statusCode == 304 && cached != null) {
      _cache[cacheKey] = (cached.$1, cached.$2, DateTime.now());
      return cached.$2;
    }
    if (response.statusCode != 200) {
      throw GitHubException(switch (response.statusCode) {
        403 || 429 when isRateLimit => rateLimitMessage,
        403 =>
          'GitHub denied access to this resource. Connect GitHub or open it in a browser.',
        404 => 'Repository or resource is unavailable. It may be private.',
        401 => 'GitHub requires authentication for this resource.',
        _ =>
          'GitHub is unavailable (${response.statusCode}). Pull down to retry.',
      }, statusCode: response.statusCode);
    }
    final data = jsonDecode(response.body);
    _cache[cacheKey] = (response.headers['etag'], data, DateTime.now());
    return data;
  }

  String get rateLimitMessage => rateLimited
      ? 'GitHub rate limit reached. Try again after ${_rateLimitedUntil!.toLocal().hour.toString().padLeft(2, '0')}:${_rateLimitedUntil!.toLocal().minute.toString().padLeft(2, '0')}.'
      : 'GitHub rate limit reached. Try again later.';

  /// Resolve a release asset while the GitHub token is still in this process.
  /// DownloadManager receives only GitHub's short-lived storage URL, never the
  /// token. A public release still uses its normal browser URL.
  Future<String> apkDownloadUrl(Map<String, dynamic> asset) async {
    final publicUrl = asset['browser_download_url'] as String;
    if (!connected) return publicUrl;
    final apiUrl = Uri.tryParse(asset['url'] as String? ?? '');
    if (apiUrl == null ||
        apiUrl.scheme != 'https' ||
        apiUrl.host != 'api.github.com' ||
        !RegExp(
          r'^/repos/[^/]+/[^/]+/releases/assets/\d+$',
        ).hasMatch(apiUrl.path)) {
      throw GitHubException('GitHub returned an invalid APK asset link.');
    }
    final request = http.Request('GET', apiUrl)
      ..followRedirects = false
      ..headers.addAll({...headers, 'Accept': 'application/octet-stream'});
    final response = await client
        .send(request)
        .timeout(const Duration(seconds: 20));
    // Do not buffer an APK if GitHub streams the asset instead of redirecting.
    await response.stream.listen((_) {}).cancel();
    if (response.statusCode == 302 || response.statusCode == 301) {
      final target = Uri.tryParse(response.headers['location'] ?? '');
      if (target != null &&
          target.scheme == 'https' &&
          (target.host == 'release-assets.githubusercontent.com' ||
              target.host == 'objects.githubusercontent.com')) {
        return target.toString();
      }
      throw GitHubException('GitHub returned an unsafe APK download link.');
    }
    if (response.statusCode == 401 ||
        response.statusCode == 403 ||
        response.statusCode == 404) {
      throw GitHubException(
        'This APK needs GitHub access to its repository. Connect an account or token with Contents: read permission.',
        needsAccess: true,
        statusCode: response.statusCode,
      );
    }
    throw GitHubException(
      'GitHub could not prepare this APK download (${response.statusCode}). Try again.',
      statusCode: response.statusCode,
    );
  }

  Future<List<Release>> releases(Project p) async {
    final releases = <Release>[];
    var page = 1;
    while (true) {
      final batch =
          await get(
                '/repos/${p.repository}/releases',
                query: {'per_page': '30', 'page': '$page'},
                maxAge: const Duration(minutes: 2),
              )
              as List;
      releases.addAll(parseReleases(batch));
      if (releases.any((r) => r.dev) || batch.length < 30) break;
      page++;
    }
    releases.sort((a, b) => b.date.compareTo(a.date));
    // A busy dev channel can still push the stable release out of the feed.
    if (releases.isNotEmpty && !releases.any((r) => !r.dev)) {
      try {
        releases.add(
          Release(
            await get(
                  '/repos/${p.repository}/releases/latest',
                  maxAge: const Duration(minutes: 2),
                )
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
        await get(
              '/repos/${p.repository}/actions/runs',
              maxAge: const Duration(seconds: 30),
            )
            as Map<String, dynamic>;
    // Preserve the latest run of EACH workflow, so an unrelated successful job
    // cannot hide a failing workflow. GitHub returns newest runs first.
    final all = (data['workflow_runs'] as List).cast<Map<String, dynamic>>();
    final seen = <dynamic>{};
    final latest = all
        .where((r) => seen.add(r['workflow_id']))
        .map(BuildRun.new)
        .toList();
    for (final run in latest) {
      final previous = all.where(
        (candidate) =>
            candidate['workflow_id'] == run.workflowId &&
            candidate['head_branch'] == run.branch &&
            candidate['conclusion'] == 'success' &&
            candidate['id'] != run.id,
      );
      if (previous.isNotEmpty) {
        _previousSuccess[run.id] = BuildRun(previous.first);
      }
    }
    return latest;
  }

  Future<List<ProjectCommit>> commits(Project p) async {
    final data =
        await get(
              '/repos/${p.repository}/commits',
              query: {'per_page': '5'},
              maxAge: const Duration(minutes: 30),
            )
            as List;
    return data
        .cast<Map<String, dynamic>>()
        .map((json) => ProjectCommit(project: p, json: json))
        .toList();
  }

  Future<List<BuildJob>> jobs(Project p, BuildRun run) async {
    final jobs = <BuildJob>[];
    var page = 1;
    while (true) {
      final data =
          await get(
                '/repos/${p.repository}/actions/runs/${run.id}/jobs',
                query: {'per_page': '100', 'page': '$page'},
                maxAge: run.status == BuildStatus.running
                    ? const Duration(seconds: 30)
                    : const Duration(minutes: 30),
              )
              as Map<String, dynamic>;
      final batch = (data['jobs'] as List).cast<Map<String, dynamic>>();
      jobs.addAll(batch.map(BuildJob.new));
      if (batch.length < 100) break;
      page++;
    }
    return jobs;
  }

  Future<BuildRun?> previousSuccessfulRun(Project p, BuildRun run) async {
    if (_previousSuccess[run.id] case final previous?) return previous;
    final data =
        await get(
              '/repos/${p.repository}/actions/workflows/${run.workflowId}/runs',
              query: {
                'status': 'success',
                'per_page': '10',
                if (run.branch.isNotEmpty) 'branch': run.branch,
              },
            )
            as Map<String, dynamic>;
    for (final json
        in (data['workflow_runs'] as List).cast<Map<String, dynamic>>()) {
      if (json['id'] != run.id) return BuildRun(json);
    }
    return null;
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
