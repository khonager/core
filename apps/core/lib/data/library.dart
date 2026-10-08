import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../domain/project.dart';
import '../platform/device.dart';
import 'github.dart';

class Library extends ChangeNotifier {
  Library({
    required this.preferences,
    required this.github,
    required this.device,
  });
  final SharedPreferences preferences;
  final GitHub github;
  final Device device;
  List<Project> projects = [];
  final states = <String, ProjectState>{};
  final downloads = <String, Map<String, dynamic>>{};
  final installed = <String, String>{};
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
        github.token = await device.readToken();
      } catch (_) {
        deviceError =
            'Saved GitHub access could not be read. Reconnect from project details.';
      }
      changed();
      await pollDevice();
      _timer = Timer.periodic(const Duration(seconds: 2), (_) {
        if (downloads.values.any(
          (d) => d['phase'] == 'downloading' || d['phase'] == 'installing',
        )) {
          pollDevice();
        }
      });
      await refresh();
    } catch (_) {
      error = 'The catalog could not be loaded. Restart Core to retry.';
      changed();
    }
  }

  Future<void> refresh() async {
    if (refreshing) return;
    refreshing = true;
    changed();
    // At most two projects at once; this also avoids a burst on public API limits.
    for (var i = 0; i < projects.length; i += 2) {
      await Future.wait(projects.skip(i).take(2).map(refreshProject));
    }
    refreshing = false;
    changed();
  }

  Future<void> refreshProject(Project p) async {
    final s = states[p.id]!;
    if (s.loading) return;
    s.loading = true;
    changed();
    final oldStable = s.latest(false)?.tag, oldDev = s.latest(true)?.tag;
    final oldRuns = {for (final r in s.runs) r.id: r.status};
    final hadBaseline = s.checked != null;
    await Future.wait([
      () async {
        try {
          s.releases = await github.releases(p);
          s.releaseError = null;
        } catch (e) {
          s.releaseError = _message(e);
        }
      }(),
      () async {
        try {
          s.runs = await github.runs(p);
          s.buildError = null;
        } catch (e) {
          s.buildError = _message(e);
        }
      }(),
    ]);
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
    changed();
  }

  String _message(Object e) => e is GitHubException
      ? e.message
      : 'Could not refresh. Check your connection and retry. Saved information is shown when available.';
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
    await device.storeToken(token);
    github.token = token;
    // Clear account-dependent cached data when changing access.
    for (final project in projects) {
      await preferences.remove('cache.v1.${project.id}');
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
