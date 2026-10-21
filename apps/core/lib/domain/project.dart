class Project {
  const Project({
    required this.id,
    required this.name,
    required this.description,
    required this.repository,
    this.category = 'Other',
    this.icon,
    this.website,
    this.packageId,
    this.devPackageId,
  });
  final String id, name, description, repository;
  final String category;
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
      category: j['category'] as String? ?? 'Other',
      icon: j['icon'] as String?,
      website: j['website'] as String?,
      packageId: j['packageId'] as String?,
      devPackageId: j['devPackageId'] as String?,
    );
  }
}

class ProjectCommit {
  ProjectCommit({required this.project, required this.json});
  final Project project;
  final Map<String, dynamic> json;

  String get title =>
      ((json['commit'] as Map<String, dynamic>)['message'] as String? ?? '')
          .split('\n')
          .first;
  String get url => json['html_url'] as String;
  String get sha => (json['sha'] as String).substring(0, 7);
  DateTime get date {
    final commit = json['commit'] as Map<String, dynamic>;
    final committer = commit['committer'] as Map<String, dynamic>?;
    final author = commit['author'] as Map<String, dynamic>?;
    return DateTime.tryParse(
          (committer?['date'] ?? author?['date']) as String? ?? '',
        ) ??
        DateTime(1970);
  }
}

enum BuildStatus { unknown, running, success, failure, cancelled }

class BuildRun {
  BuildRun(this.json);
  final Map<String, dynamic> json;
  int get id => json['id'] as int;
  int get workflowId => json['workflow_id'] as int;
  String get title => json['name'] as String? ?? 'Build';
  String get branch => json['head_branch'] as String? ?? '';
  String get sha => (json['head_sha'] as String? ?? '').substring(
    0,
    ((json['head_sha'] as String? ?? '').length).clamp(0, 7),
  );
  String get url => json['html_url'] as String;
  DateTime? get startedAt =>
      DateTime.tryParse(json['run_started_at'] as String? ?? '');
  DateTime? get completedAt =>
      DateTime.tryParse(json['updated_at'] as String? ?? '');
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

class BuildStep {
  BuildStep(this.json);
  final Map<String, dynamic> json;
  String get name => json['name'] as String? ?? 'Step';
  int get number => json['number'] as int? ?? 0;
  String get status => json['status'] as String? ?? 'queued';
  String? get conclusion => json['conclusion'] as String?;
  DateTime? get startedAt =>
      DateTime.tryParse(json['started_at'] as String? ?? '');
  DateTime? get completedAt =>
      DateTime.tryParse(json['completed_at'] as String? ?? '');
  Duration? get duration {
    final start = startedAt, end = completedAt;
    if (start == null || end == null || end.isBefore(start)) return null;
    return end.difference(start);
  }

  bool get done => status == 'completed';
  bool get failed =>
      done &&
      {
        'failure',
        'timed_out',
        'action_required',
        'startup_failure',
      }.contains(conclusion);
}

class BuildJob {
  BuildJob(this.json);
  final Map<String, dynamic> json;
  String get name => json['name'] as String? ?? 'Job';
  DateTime? get startedAt =>
      DateTime.tryParse(json['started_at'] as String? ?? '');
  DateTime? get completedAt =>
      DateTime.tryParse(json['completed_at'] as String? ?? '');
  List<BuildStep> get steps => (json['steps'] as List? ?? [])
      .cast<Map<String, dynamic>>()
      .map(BuildStep.new)
      .toList();
}

class BuildDetails {
  BuildDetails({
    required this.jobs,
    this.previousJobs = const [],
    this.previousRun,
  });
  final List<BuildJob> jobs, previousJobs;
  final BuildRun? previousRun;
  List<(BuildJob, BuildStep)> get steps => [
    for (final job in jobs)
      for (final step in job.steps) (job, step),
  ];
  (BuildJob, BuildStep)? get failedStep {
    for (final pair in steps) {
      if (pair.$2.failed) return pair;
    }
    return null;
  }

  BuildJob? get failedJob {
    for (final job in jobs) {
      if ({
        'failure',
        'timed_out',
        'action_required',
        'startup_failure',
      }.contains(job.json['conclusion'])) {
        return job;
      }
    }
    return null;
  }

  (BuildJob, BuildStep)? get activeStep {
    for (final pair in steps) {
      if (pair.$2.status == 'in_progress') return pair;
    }
    return null;
  }

  Duration? previousStepDuration(BuildJob job, BuildStep step) {
    for (final previousJob in previousJobs) {
      if (previousJob.name != job.name) continue;
      for (final previousStep in previousJob.steps) {
        if (previousStep.number == step.number &&
            previousStep.name == step.name) {
          return previousStep.duration;
        }
      }
    }
    return null;
  }

  Duration? get previousTotalDuration {
    final runStart = previousRun?.startedAt;
    final runEnd = previousRun?.completedAt;
    if (runStart != null && runEnd != null && runEnd.isAfter(runStart)) {
      return runEnd.difference(runStart);
    }
    final starts = previousJobs.map((j) => j.startedAt).whereType<DateTime>();
    final ends = previousJobs.map((j) => j.completedAt).whereType<DateTime>();
    if (starts.isEmpty || ends.isEmpty) return null;
    final start = starts.reduce((a, b) => a.isBefore(b) ? a : b);
    final end = ends.reduce((a, b) => a.isAfter(b) ? a : b);
    return end.isAfter(start) ? end.difference(start) : null;
  }

  double progress(DateTime now) {
    if (steps.isEmpty) return 0;
    var completed = steps.where((pair) => pair.$2.done).length.toDouble();
    final active = activeStep;
    if (active != null) {
      final prior = previousStepDuration(active.$1, active.$2);
      final started = active.$2.startedAt;
      if (prior != null && prior.inSeconds > 0 && started != null) {
        completed += (now.difference(started).inSeconds / prior.inSeconds)
            .clamp(0.0, 0.95);
      }
    }
    return (completed / steps.length).clamp(0.0, 1.0);
  }
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
  final buildDetails = <int, BuildDetails>{};
  final buildDetailsLoading = <int>{};
  final buildDetailsErrors = <int, String>{};
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
