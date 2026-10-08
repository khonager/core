import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_markdown_plus/flutter_markdown_plus.dart';
import '../data/library.dart';
import '../data/github.dart';
import '../domain/project.dart';
import 'theme.dart';

class DetailsScreen extends StatefulWidget {
  const DetailsScreen({
    super.key,
    required this.project,
    required this.library,
    this.embedded = false,
  });
  final Project project;
  final Library library;
  final bool embedded;
  @override
  State<DetailsScreen> createState() => _DetailsScreenState();
}

class _DetailsScreenState extends State<DetailsScreen> {
  bool dev = false, busy = false, copying = false;
  Project get p => widget.project;
  Library get lib => widget.library;
  void message(String text) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
    }
  }

  Future<void> action(Future<void> Function() work) async {
    if (busy) return;
    setState(() => busy = true);
    try {
      await work();
    } catch (e) {
      message(
        e is PlatformException
            ? e.message ?? 'Android could not complete this action.'
            : e.toString(),
      );
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> open(String url) => action(() => lib.device.open(url));
  Future<void> logs(BuildRun run) async {
    if (copying) return;
    setState(() => copying = true);
    try {
      final text = await lib.github.logs(p, run);
      await Clipboard.setData(ClipboardData(text: text));
      message('Full build log copied.');
    } catch (e) {
      if (e is GitHubException && e.needsAccess && mounted) {
        await access();
        message('If connected, tap Copy full log again.');
      } else {
        message(e.toString());
      }
    } finally {
      if (mounted) setState(() => copying = false);
    }
  }

  Future<void> access() async {
    final controller = TextEditingController();
    final token = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('GitHub access'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                lib.device.android
                    ? 'For restricted build logs, add a fine-grained GitHub token with Actions: read permission for your projects. It is stored securely on this device.'
                    : 'Tokens in this browser preview are held in memory for this session only. Log downloads may require the Android app.',
              ),
              const SizedBox(height: 16),
              TextField(
                controller: controller,
                obscureText: true,
                autocorrect: false,
                enableSuggestions: false,
                decoration: const InputDecoration(labelText: 'GitHub token'),
              ),
              TextButton(
                onPressed: () => lib.device
                    .open(
                      'https://github.com/settings/personal-access-tokens/new',
                    )
                    .catchError((Object e) {
                      message('Could not open GitHub.');
                    }),
                child: const Text('Create a token on GitHub'),
              ),
            ],
          ),
        ),
        actions: [
          if (lib.github.connected)
            TextButton(
              onPressed: () => Navigator.pop(context, ''),
              child: const Text('Disconnect'),
            ),
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              if (controller.text.trim().isNotEmpty) {
                Navigator.pop(context, controller.text.trim());
              }
            },
            child: const Text('Connect'),
          ),
        ],
      ),
    );
    // Dispose after the dialog's exit transition has released its text field.
    await Future<void>.delayed(const Duration(milliseconds: 250));
    controller.dispose();
    if (token == null || !mounted) return;
    await action(() async {
      await lib.connect(token.isEmpty ? null : token);
      message(token.isEmpty ? 'GitHub disconnected.' : 'GitHub connected.');
    });
  }

  Future<void> notifications() async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (context) => SafeArea(
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
            child: StatefulBuilder(
              builder: (context, update) => Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Notifications',
                    style: Theme.of(context).textTheme.headlineMedium,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    lib.device.android
                        ? 'Core checks for changes when you open or refresh the app. Background alerts are not available in this version.'
                        : 'Notifications are available in the Android app.',
                  ),
                  const SizedBox(height: 16),
                  for (final option in {
                    'stable': 'Stable releases',
                    'dev': 'Development releases',
                    'failed': 'Failed builds',
                    'finished': 'Successful builds',
                  }.entries)
                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      title: Text(option.value),
                      value: lib.enabled(p, option.key),
                      onChanged: !lib.device.android
                          ? null
                          : (value) async {
                              try {
                                final saved = await lib.setNotification(
                                  p,
                                  option.key,
                                  value,
                                );
                                if (!saved) {
                                  message(
                                    'Allow notifications for Core in Android app settings.',
                                  );
                                }
                                if (context.mounted) update(() {});
                              } catch (_) {
                                message(
                                  'Could not save notification preference.',
                                );
                              }
                            },
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Future<void> download(Release release, String? packageId) async {
    final assets = release.apks;
    if (assets.isEmpty) {
      await open(release.url);
      return;
    }
    final asset = await showModalBottomSheet<Map<String, dynamic>>(
      context: context,
      isScrollControlled: true,
      builder: (context) => SafeArea(
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Choose a download',
                  style: Theme.of(context).textTheme.headlineMedium,
                ),
                const SizedBox(height: 8),
                const Text(
                  'Choose the APK for your device. Universal builds work across supported architectures.',
                ),
                const SizedBox(height: 12),
                for (final a in assets)
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(Icons.android_rounded),
                    title: Text(a['name'] as String),
                    subtitle: Text(
                      '${((a['size'] as num) / 1048576).toStringAsFixed(1)} MB',
                    ),
                    trailing: const Icon(Icons.download_rounded),
                    onTap: () => Navigator.pop(context, a),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
    if (asset == null) return;
    await action(() async {
      await lib.device.download(
        '${p.id}.${dev ? 'dev' : 'stable'}',
        asset['name'] as String,
        asset['browser_download_url'] as String,
        packageId,
      );
      await lib.pollDevice();
    });
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: lib,
    builder: (context, _) {
      final s = lib.states[p.id]!;
      final release = s.latest(dev);
      final packageId = dev ? p.devPackageId ?? p.packageId : p.packageId;
      final installed = lib.installed[packageId];
      final key = '${p.id}.${dev ? 'dev' : 'stable'}';
      final transfer = lib.downloads[key];
      final phase = transfer?['phase'];
      return Scaffold(
        appBar: AppBar(
          automaticallyImplyLeading: !widget.embedded,
          actions: [
            IconButton(
              tooltip: 'Notification preferences',
              onPressed: notifications,
              icon: Icon(
                [
                      'stable',
                      'dev',
                      'failed',
                      'finished',
                    ].any((type) => lib.enabled(p, type))
                    ? Icons.notifications_active_outlined
                    : Icons.notifications_none_rounded,
              ),
            ),
            const SizedBox(width: 12),
          ],
        ),
        body: RefreshIndicator(
          onRefresh: () => lib.refreshProject(p),
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: EdgeInsets.fromLTRB(
              24,
              8,
              24,
              40 + MediaQuery.paddingOf(context).bottom,
            ),
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  ProjectIcon(p, size: 96),
                  const SizedBox(width: 20),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          p.name,
                          style: Theme.of(context).textTheme.headlineMedium,
                        ),
                        const SizedBox(height: 6),
                        Text(p.description),
                        if (installed != null)
                          Padding(
                            padding: const EdgeInsets.only(top: 8),
                            child: Text(
                              'Installed · $installed',
                              style: Theme.of(context).textTheme.bodySmall,
                            ),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 28),
              if (p.website != null)
                Padding(
                  padding: const EdgeInsets.only(bottom: 20),
                  child: FilledButton.icon(
                    onPressed: () => open(p.website!),
                    icon: const Icon(Icons.open_in_browser_rounded),
                    label: const Text('Open website'),
                  ),
                ),
              if (p.packageId != null) ...[
                SegmentedButton<bool>(
                  segments: const [
                    ButtonSegment(value: false, label: Text('Stable')),
                    ButtonSegment(value: true, label: Text('Development')),
                  ],
                  selected: {dev},
                  onSelectionChanged: (v) => setState(() => dev = v.first),
                ),
                const SizedBox(height: 20),
                if (s.releaseError != null)
                  Notice(s.releaseError!, onRetry: () => lib.refreshProject(p)),
                if (s.loading && release == null)
                  const LinearProgressIndicator()
                else if (release == null)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 20),
                    child: Text(
                      dev
                          ? 'No development release published yet.'
                          : 'No stable release published yet.',
                    ),
                  )
                else ...[
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Text(
                          release.tag,
                          style: Theme.of(context).textTheme.titleLarge,
                        ),
                      ),
                      Text(
                        '${release.date.day}.${release.date.month}.${release.date.year}',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    dev
                        ? 'Latest development release'
                        : 'Latest stable release',
                  ),
                  if (dev && p.devPackageId == null)
                    const Padding(
                      padding: EdgeInsets.only(top: 8),
                      child: Text(
                        'Development builds may replace the stable app. Android checks package and signing compatibility.',
                      ),
                    ),
                  const SizedBox(height: 20),
                  if (phase == 'downloading' ||
                      phase == 'installing' ||
                      phase == 'ready') ...[
                    LinearProgressIndicator(
                      color: CoreColors.blue,
                      value: phase == 'installing'
                          ? null
                          : phase == 'ready'
                          ? 1
                          : (transfer?['progress'] as num?)?.toDouble(),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      phase == 'ready'
                          ? 'Download ready to install'
                          : phase == 'installing'
                          ? 'Complete installation in Android'
                          : 'Downloading${transfer?['progress'] == null ? '…' : ' · ${((transfer!['progress'] as num) * 100).round()}%'}',
                    ),
                    if (phase == 'ready' || phase == 'installing')
                      FilledButton.icon(
                        onPressed: busy
                            ? null
                            : () => action(() => lib.device.install(key)),
                        icon: const Icon(Icons.install_mobile_rounded),
                        label: const Text('Install downloaded APK'),
                      ),
                    TextButton(
                      onPressed: () => action(() async {
                        await lib.device.cancel(key);
                        await lib.pollDevice();
                      }),
                      child: Text(
                        phase == 'downloading'
                            ? 'Cancel download'
                            : 'Dismiss download',
                      ),
                    ),
                  ] else ...[
                    if (phase == 'failed')
                      const Notice(
                        'Download failed. Check your connection and try again.',
                      ),
                    FilledButton.icon(
                      onPressed: busy
                          ? null
                          : () => download(release, packageId),
                      icon: const Icon(Icons.download_rounded),
                      label: Text(
                        busy
                            ? 'Please wait…'
                            : release.apks.isEmpty
                            ? 'View release on GitHub'
                            : !lib.device.android
                            ? 'Download APK'
                            : installed == null
                            ? 'Install'
                            : 'Update / reinstall',
                      ),
                    ),
                  ],
                  if (installed != null && packageId != null)
                    TextButton.icon(
                      onPressed: () =>
                          action(() => lib.device.uninstall(packageId)),
                      icon: const Icon(Icons.delete_outline_rounded),
                      label: const Text('Uninstall'),
                    ),
                  const SizedBox(height: 28),
                  Text(
                    'Changelog',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const SizedBox(height: 12),
                  MarkdownBody(
                    data: release.notes.isEmpty
                        ? 'No release notes were provided.'
                        : release.notes,
                    selectable: true,
                    onTapLink: (text, href, title) {
                      if (href != null) {
                        open(Uri.parse(release.url).resolve(href).toString());
                      }
                    },
                  ),
                ],
                const SizedBox(height: 28),
              ],
              const Divider(),
              const SizedBox(height: 20),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      'Build activity',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                  ),
                  IconButton(
                    tooltip: 'Refresh build activity',
                    onPressed: s.loading ? null : () => lib.refreshProject(p),
                    icon: const Icon(Icons.refresh_rounded),
                  ),
                ],
              ),
              if (s.buildError != null)
                Notice(s.buildError!, onRetry: () => lib.refreshProject(p)),
              if (s.runs.isEmpty && !s.loading && s.buildError == null)
                const Text('No recent workflow runs.'),
              if (s.loading)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 8),
                  child: LinearProgressIndicator(),
                ),
              for (final run in s.runs)
                Padding(
                  padding: const EdgeInsets.only(top: 12),
                  child: Material(
                    color: CoreColors.surface,
                    borderRadius: BorderRadius.circular(16),
                    child: InkWell(
                      onTap: () => open(run.url),
                      onLongPress: () => logs(run),
                      borderRadius: BorderRadius.circular(16),
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Icon(
                                  switch (run.status) {
                                    BuildStatus.success =>
                                      Icons.check_circle_outline,
                                    BuildStatus.failure => Icons.error_outline,
                                    BuildStatus.running => Icons.schedule,
                                    _ => Icons.remove_circle_outline,
                                  },
                                  color: CoreColors.status(run.status),
                                  size: 20,
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    run.label,
                                    style: Theme.of(
                                      context,
                                    ).textTheme.titleSmall,
                                  ),
                                ),
                                const Icon(Icons.open_in_new_rounded, size: 18),
                              ],
                            ),
                            const SizedBox(height: 8),
                            Text(
                              run.title,
                              style: Theme.of(context).textTheme.titleMedium,
                            ),
                            Text('${run.branch} · ${run.sha}'),
                            const SizedBox(height: 8),
                            TextButton.icon(
                              onPressed: copying ? null : () => logs(run),
                              icon: const Icon(Icons.copy_rounded, size: 18),
                              label: Text(
                                copying ? 'Getting logs…' : 'Copy full log',
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              const SizedBox(height: 16),
              TextButton.icon(
                onPressed: () => open('${p.githubUrl}/actions'),
                icon: const Icon(Icons.open_in_new_rounded, size: 18),
                label: const Text('Open GitHub Actions'),
              ),
              TextButton(
                onPressed: () => open(p.githubUrl),
                child: Text(p.repository),
              ),
              TextButton.icon(
                onPressed: busy ? null : access,
                icon: const Icon(Icons.key_rounded, size: 18),
                label: Text(
                  lib.github.connected
                      ? 'Manage GitHub access'
                      : 'Connect GitHub',
                ),
              ),
              if (lib.deviceError != null) Notice(lib.deviceError!),
              if (s.checked != null)
                Center(
                  child: Text(
                    'Last synced ${s.checked!.toLocal().toString().substring(0, 16)}',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ),
            ],
          ),
        ),
      );
    },
  );
}

class Notice extends StatelessWidget {
  const Notice(this.text, {super.key, this.onRetry});
  final String text;
  final VoidCallback? onRetry;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 12),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          text,
          style: TextStyle(color: Theme.of(context).colorScheme.error),
        ),
        if (onRetry != null)
          TextButton(onPressed: onRetry, child: const Text('Retry')),
      ],
    ),
  );
}
