class Project {
  const Project({
    required this.id,
    required this.name,
    required this.description,
    required this.repository,
    this.icon,
    this.website,
    this.packageId,
    this.devPackageId,
  });
  final String id, name, description, repository;
  final String? icon, website, packageId, devPackageId;
  String get githubUrl => 'https://github.com/$repository';
  factory Project.fromJson(Map<String, dynamic> j) {
    final repo = j['repository'] as String;
    if (!RegExp(r'^[\w.-]+/[\w.-]+$').hasMatch(repo)) {
      throw const FormatException('Invalid catalog repository');
    }
    return Project(
      id: j['id'] as String,
      name: j['name'] as String,
      description: j['description'] as String,
      repository: repo,
      icon: j['icon'] as String?,
      website: j['website'] as String?,
      packageId: j['packageId'] as String?,
      devPackageId: j['devPackageId'] as String?,
    );
  }
}

enum BuildStatus { unknown, running, success, failure, cancelled }

class BuildRun {
  BuildRun(this.json);
  final Map<String, dynamic> json;
  int get id => json['id'] as int;
  String get title => json['name'] as String? ?? 'Build';
  String get branch => json['head_branch'] as String? ?? '';
  String get sha => (json['head_sha'] as String? ?? '').substring(
    0,
    ((json['head_sha'] as String? ?? '').length).clamp(0, 7),
  );
  String get url => json['html_url'] as String;
  BuildStatus get status {
    if (json['status'] != 'completed') return BuildStatus.running;
    return switch (json['conclusion']) {
      'success' => BuildStatus.success,
      'failure' ||
      'timed_out' ||
      'action_required' ||
      'startup_failure' => BuildStatus.failure,
      'cancelled' || 'skipped' || 'neutral' || 'stale' => BuildStatus.cancelled,
      _ => BuildStatus.unknown,
    };
  }

  String get label => switch (status) {
    BuildStatus.running =>
      json['status'] == 'queued' ? 'Build queued' : 'Build running',
    BuildStatus.success => 'Build passed',
    BuildStatus.failure => 'Build failed',
    BuildStatus.cancelled => 'Build ${json['conclusion']}',
    BuildStatus.unknown => 'Build status unknown',
  };
}

class Release {
  Release(this.json);
  final Map<String, dynamic> json;
  String get tag => json['tag_name'] as String;
  String get notes => json['body'] as String? ?? '';
  String get url => json['html_url'] as String;
  bool get dev => json['prerelease'] == true;
  DateTime get date =>
      DateTime.tryParse(json['published_at'] as String? ?? '') ??
      DateTime(1970);
  List<Map<String, dynamic>> get apks => (json['assets'] as List? ?? [])
      .cast<Map<String, dynamic>>()
      .where((a) => (a['name'] as String).toLowerCase().endsWith('.apk'))
      .toList();
}

List<Release> parseReleases(List<dynamic> data) =>
    data
        .cast<Map<String, dynamic>>()
        .where((r) => r['draft'] != true)
        .map(Release.new)
        .toList()
      ..sort((a, b) => b.date.compareTo(a.date));

class ProjectState {
  List<Release> releases = [];
  List<BuildRun> runs = [];
  DateTime? checked;
  String? releaseError, buildError;
  bool loading = false;
  Release? latest(bool dev) {
    for (final release in releases) {
      if (release.dev == dev) return release;
    }
    return null;
  }

  BuildStatus get status {
    if (buildError != null || runs.isEmpty) return BuildStatus.unknown;
    if (runs.any((r) => r.status == BuildStatus.failure)) {
      return BuildStatus.failure;
    }
    if (runs.any((r) => r.status == BuildStatus.running)) {
      return BuildStatus.running;
    }
    if (runs.every((r) => r.status == BuildStatus.success)) {
      return BuildStatus.success;
    }
    return BuildStatus.cancelled;
  }

  String get label => switch (status) {
    BuildStatus.failure => 'A workflow failed',
    BuildStatus.running => 'Builds in progress',
    BuildStatus.success => 'Builds passed',
    BuildStatus.cancelled => 'Builds cancelled or skipped',
    BuildStatus.unknown =>
      buildError != null ? 'Build status unavailable' : 'No recent builds',
  };
}
