import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../domain/project.dart';
import '../platform/device.dart';
import 'github.dart';
import 'github_auth.dart';

class Library extends ChangeNotifier {
  Library({
    required this.preferences,
    required this.github,
    required this.device,
    GitHubAuth? auth,
  }) : auth = auth ?? GitHubAuth(client: github.client);
  final SharedPreferences preferences;
  final GitHub github;
  final Device device;
  final GitHubAuth auth;
  GitHubCredentials? _credentials;
  List<Project> projects = [];
  final states = <String, ProjectState>{};
  final downloads = <String, Map<String, dynamic>>{};
  final installed = <String, String>{};
  List<ProjectCommit> commits = [];
  final commitsErrors = <String, String>{};
  final commitsLoading = <String>{};
  String? refreshNotice;
  String? error, deviceError;
  bool refreshing = false, _disposed = false, _polling = false;
  Timer? _timer;
  void changed() {
    if (!_disposed) notifyListeners();
  }

  Future<void> init() async {
    try {
      final data =
          jsonDecode(await rootBundle.loadString('assets/catalog.json'))
              as List;
      projects = data
          .cast<Map<String, dynamic>>()
          .map(Project.fromJson)
          .toList();
      for (final p in projects) {
        final state = states[p.id] = ProjectState();
        try {
          final cache = jsonDecode(
            preferences.getString('cache.v1.${p.id}') ?? '{}',
          );
          state.releases = parseReleases(cache['releases'] as List? ?? []);
          state.runs = (cache['runs'] as List? ?? [])
              .cast<Map<String, dynamic>>()
              .map(BuildRun.new)
              .toList();
          state.checked = DateTime.tryParse(cache['checked'] as String? ?? '');
        } catch (_) {
          /* An invalid cache must never prevent the catalog opening. */
        }
      }
      try {
        final saved =
            jsonDecode(preferences.getString('commits.cache.v1') ?? '{}')
                as Map<String, dynamic>;
        final byId = {for (final p in projects) p.id: p};
        commits = (saved['entries'] as List? ?? [])
            .cast<Map<String, dynamic>>()
            .where((entry) => byId.containsKey(entry['projectId']))
            .map(
              (entry) => ProjectCommit(
                project: byId[entry['projectId']]!,
                json: entry['commit'] as Map<String, dynamic>,
              ),
            )
            .toList();
      } catch (_) {
        // A damaged feed cache should not stop the catalog opening.
      }
      try {
        final saved = await device.readGitHubAuth();
        if (saved != null) {
          _credentials = GitHubCredentials.fromJson(
            jsonDecode(saved) as Map<String, dynamic>,
          );
          github.token = _credentials!.token;
        } else {
          github.token = await device.readToken();
        }
      } catch (_) {
        deviceError =
            'Saved GitHub access could not be read. Reconnect from project details.';
      }
      final retryAt = preferences.getInt('github.rateLimitUntil');
      if (retryAt != null) {
        github.restoreRateLimit(DateTime.fromMillisecondsSinceEpoch(retryAt));
      }
      final budgetReset = preferences.getInt('github.budgetReset');
      github.restoreBudget(
        preferences.getInt('github.budgetRemaining'),
        budgetReset == null
            ? null
            : DateTime.fromMillisecondsSinceEpoch(budgetReset),
      );
      changed();
      await pollDevice();
      _timer = Timer.periodic(const Duration(seconds: 2), (_) {
        if (downloads.values.any(
          (d) => d['phase'] == 'downloading' || d['phase'] == 'installing',
        )) {
          pollDevice();
        }
      });
      // Metadata is loaded when a project is opened. Refreshing every
      // repository on launch consumes most of GitHub's anonymous allowance.
    } catch (_) {
      error = 'The catalog could not be loaded. Restart Core to retry.';
      changed();
    }
  }

  Future<void> refresh() => _refresh(automatic: false);

  Future<void> _refresh({required bool automatic}) async {
    if (refreshing) return;
    refreshing = true;
    refreshNotice = null;
    changed();
    for (final project in projects) {
      if (github.rateLimited) {
        final state = states[project.id]!;
        state.releaseError = github.rateLimitMessage;
        state.buildError = github.rateLimitMessage;
        continue;
      }
      if (github.lowBudget) {
        refreshNotice =
            'GitHub requests are running low. Open an app to update its details.';
        break;
      }
      await refreshProject(project, automatic: automatic);
    }
    refreshing = false;
    changed();
  }

  Future<void> refreshCommits(Project p, {bool automatic = true}) async {
    if (commitsLoading.contains(p.repository)) return;
    if (github.rateLimited) {
      commitsErrors[p.repository] = github.rateLimitMessage;
      changed();
      return;
    }
    final attemptKey = 'commits.refresh.v1.${p.repository}';
    final previous = preferences.getInt(attemptKey);
    final interval = automatic
        ? const Duration(minutes: 30)
        : const Duration(minutes: 2);
    if (previous != null &&
        DateTime.now().difference(
              DateTime.fromMillisecondsSinceEpoch(previous),
            ) <
            interval) {
      return;
    }
    await preferences.setInt(attemptKey, DateTime.now().millisecondsSinceEpoch);
    commitsLoading.add(p.repository);
    changed();
    try {
      final fetched = await github.commits(p);
      commits = [
        ...commits.where((entry) => entry.project.repository != p.repository),
        ...fetched,
      ]..sort((a, b) => b.date.compareTo(a.date));
      try {
        await preferences.setString(
          'commits.cache.v1',
          jsonEncode({
            'entries': [
              for (final entry in commits)
                {'projectId': entry.project.id, 'commit': entry.json},
            ],
          }),
        );
      } catch (_) {
        // Live commits remain visible if local storage fails.
      }
      commitsErrors.remove(p.repository);
    } catch (e) {
      commitsErrors[p.repository] = _message(e);
    }
    commitsLoading.remove(p.repository);
    await _saveBudget();
    changed();
  }

  Future<void> _saveBudget() async {
    if (github.connected ||
        github.remaining == null ||
        github.windowResetsAt == null) {
      return;
    }
    try {
      await preferences.setInt('github.budgetRemaining', github.remaining!);
      await preferences.setInt(
        'github.budgetReset',
        github.windowResetsAt!.millisecondsSinceEpoch,
      );
    } catch (_) {
      // Saved quota is advisory; current network data remains usable.
    }
  }

  final _historicalJobs = <int, List<BuildJob>>{};
  final _historicalBuilds = <String, (BuildRun?, List<BuildJob>)>{};

  Future<void> loadBuildDetails(
    Project p,
    BuildRun run, {
    bool force = false,
  }) async {
    final state = states[p.id]!;
    if (state.buildDetailsLoading.contains(run.id) ||
        (!force &&
            (state.buildDetails.containsKey(run.id) ||
                state.buildDetailsErrors.containsKey(run.id)))) {
      return;
    }
    if (github.rateLimited) {
      state.buildDetailsErrors[run.id] = github.rateLimitMessage;
      changed();
      return;
    }
    state.buildDetailsLoading.add(run.id);
    changed();
    try {
      final jobs = await github.jobs(p, run);
      List<BuildJob> previousJobs = [];
      BuildRun? previousRun;
      try {
        final key = '${p.repository}:${run.id}';
        final cached = _historicalBuilds[key];
        if (cached != null) {
          previousRun = cached.$1;
          previousJobs = cached.$2;
        } else {
          previousRun = await github.previousSuccessfulRun(p, run);
          if (previousRun != null) {
            previousJobs =
                _historicalJobs[previousRun.id] ??
                await github.jobs(p, previousRun);
            _historicalJobs[previousRun.id] = previousJobs;
          }
          _historicalBuilds[key] = (previousRun, previousJobs);
        }
      } catch (_) {
        // Current step information remains useful without an estimate.
      }
      state.buildDetails[run.id] = BuildDetails(
        jobs: jobs,
        previousJobs: previousJobs,
        previousRun: previousRun,
      );
      state.buildDetailsErrors.remove(run.id);
    } catch (e) {
      state.buildDetailsErrors[run.id] = _message(e);
    } finally {
      state.buildDetailsLoading.remove(run.id);
      await _saveBudget();
      changed();
    }
  }

  Future<void> refreshBuilds(Project p) async {
    final state = states[p.id]!;
    if (github.rateLimited) return;
    try {
      state.runs = await github.runs(p);
      state.buildError = null;
      changed();
      for (final run in state.runs) {
        await loadBuildDetails(p, run, force: true);
        if (github.rateLimited) break;
      }
    } catch (e) {
      state.buildError = _message(e);
      changed();
    } finally {
      await _saveBudget();
    }
  }

  Future<void> refreshProject(Project p, {bool automatic = false}) async {
    final s = states[p.id]!;
    if (s.loading) return;
    if (github.rateLimited) {
      s.releaseError = github.rateLimitMessage;
      s.buildError = github.rateLimitMessage;
      changed();
      return;
    }
    try {
      await _ensureAuth();
    } catch (e) {
      s.releaseError = _message(e);
      s.buildError = _message(e);
      changed();
      return;
    }
    final attemptKey = 'refresh.attempt.v1.${p.id}';
    final previous = preferences.getInt(attemptKey);
    final interval = automatic
        ? const Duration(minutes: 30)
        : const Duration(minutes: 2);
    if (previous != null &&
        DateTime.now().difference(
              DateTime.fromMillisecondsSinceEpoch(previous),
            ) <
            interval) {
      return;
    }
    await preferences.setInt(attemptKey, DateTime.now().millisecondsSinceEpoch);
    s.loading = true;
    changed();
    final oldStable = s.latest(false)?.tag, oldDev = s.latest(true)?.tag;
    final oldRuns = {for (final r in s.runs) r.id: r.status};
    final hadBaseline = s.checked != null;
    try {
      s.releases = await github.releases(p);
      s.releaseError = null;
    } catch (e) {
      s.releaseError = _message(e);
    }
    if (github.rateLimited) {
      s.buildError = github.rateLimitMessage;
    } else {
      try {
        s.runs = await github.runs(p);
        s.buildError = null;
      } catch (e) {
        s.buildError = _message(e);
      }
    }
    if (github.rateLimitedUntil case final until?) {
      await preferences.setInt(
        'github.rateLimitUntil',
        until.millisecondsSinceEpoch,
      );
    }
    if (s.releaseError == null && s.buildError == null) {
      s.checked = DateTime.now();
    }
    try {
      await preferences.setString(
        'cache.v1.${p.id}',
        jsonEncode({
          'releases': s.releases.map((r) => r.json).toList(),
          'runs': s.runs.map((r) => r.json).toList(),
          'checked': s.checked?.toIso8601String(),
        }),
      );
      if (hadBaseline) {
        if (s.releaseError == null) {
          if (enabled(p, 'stable') &&
              s.latest(false)?.tag != oldStable &&
              s.latest(false) != null) {
            await device.notify(
              p.id,
              '${p.name} updated',
              s.latest(false)!.tag,
            );
          }
          if (enabled(p, 'dev') &&
              s.latest(true)?.tag != oldDev &&
              s.latest(true) != null) {
            await device.notify(
              p.id,
              '${p.name} development release',
              s.latest(true)!.tag,
            );
          }
        }
        if (s.buildError == null) {
          for (final run in s.runs) {
            if (oldRuns[run.id] == run.status) continue;
            if ((run.status == BuildStatus.failure && enabled(p, 'failed')) ||
                (run.status == BuildStatus.success && enabled(p, 'finished'))) {
              await device.notify(
                '${p.id}.${run.id}',
                '${p.name}: ${run.label}',
                run.title,
              );
            }
          }
        }
      }
    } catch (_) {
      /* A notification or cache failure must not hide live data. */
    }
    s.loading = false;
    await _saveBudget();
    changed();
  }

  String _message(Object e) => e is GitHubException
      ? e.message
      : e is GitHubAuthException
      ? e.message
      : 'Could not refresh. Check your connection and retry. Saved information is shown when available.';

  Future<void> _ensureAuth() async {
    final current = _credentials;
    if (current == null || !current.needsRefresh) return;
    final updated = await auth.refresh(current);
    await device.storeGitHubAuth(jsonEncode(updated.toJson()));
    _credentials = updated;
    github.token = updated.token;
  }

  Future<String> apkDownloadUrl(Map<String, dynamic> asset) async {
    await _ensureAuth();
    return github.apkDownloadUrl(asset);
  }

  bool enabled(Project p, String type) =>
      preferences.getBool('notify.${p.id}.$type') ?? false;
  Future<bool> setNotification(Project p, String type, bool enabled) async {
    if (enabled && !await device.requestNotifications()) return false;
    await preferences.setBool('notify.${p.id}.$type', enabled);
    changed();
    return true;
  }

  Future<void> connect(String? token) async {
    if (refreshing || states.values.any((s) => s.loading)) {
      throw StateError(
        'Wait for the current refresh to finish, then try again.',
      );
    }
    if (token != null) await github.validateToken(token);
    await device.storeGitHubAuth(null);
    await device.storeToken(token);
    _credentials = null;
    github.token = token;
    await _clearAccountCache();
  }

  Future<void> connectCredentials(GitHubCredentials credentials) async {
    if (refreshing || states.values.any((s) => s.loading)) {
      throw StateError(
        'Wait for the current refresh to finish, then try again.',
      );
    }
    await github.validateToken(credentials.token);
    await device.storeGitHubAuth(jsonEncode(credentials.toJson()));
    await device.storeToken(null);
    _credentials = credentials;
    github.token = credentials.token;
    await _clearAccountCache();
  }

  Future<void> _clearAccountCache() async {
    await preferences.remove('github.rateLimitUntil');
    await preferences.remove('github.budgetRemaining');
    await preferences.remove('github.budgetReset');
    await preferences.remove('commits.cache.v1');
    for (final repository in projects.map((p) => p.repository).toSet()) {
      await preferences.remove('commits.refresh.v1.$repository');
    }
    commits = [];
    commitsErrors.clear();
    _historicalJobs.clear();
    _historicalBuilds.clear();
    // Clear account-dependent cached data when changing access.
    for (final project in projects) {
      await preferences.remove('cache.v1.${project.id}');
      await preferences.remove('refresh.attempt.v1.${project.id}');
      states[project.id] = ProjectState();
    }
    changed();
    await refresh();
  }

  Future<void> pollDevice() async {
    if (_polling || !device.android || _disposed) return;
    _polling = true;
    try {
      for (final p in projects) {
        for (final dev in [false, true]) {
          final key = '${p.id}.${dev ? 'dev' : 'stable'}';
          final pkg = dev ? p.devPackageId ?? p.packageId : p.packageId;
          final data = await device.status(key, pkg);
          downloads[key] = data;
          if (pkg != null) {
            if (data['version'] != null) {
              installed[pkg] = data['version'] as String;
            } else {
              installed.remove(pkg);
            }
          }
        }
      }
      changed();
    } catch (_) {
      deviceError =
          'Android app status could not be read. Restart Core to retry.';
      changed();
    } finally {
      _polling = false;
    }
  }

  Map<String, dynamic>? transfer(Project p) {
    for (final channel in ['stable', 'dev']) {
      final d = downloads['${p.id}.$channel'];
      if (d?['phase'] != null && d?['phase'] != 'none') return d;
    }
    return null;
  }

  @override
  void dispose() {
    _disposed = true;
    _timer?.cancel();
    github.dispose();
    super.dispose();
  }
}
