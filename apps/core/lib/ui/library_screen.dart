import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../data/library.dart';
import '../domain/project.dart';
import 'details_screen.dart';
import 'theme.dart';

class LibraryScreen extends StatefulWidget {
  const LibraryScreen({super.key, required this.library});
  final Library library;
  @override
  State<LibraryScreen> createState() => _LibraryScreenState();
}

class _LibraryScreenState extends State<LibraryScreen>
    with WidgetsBindingObserver {
  final search = TextEditingController();
  Project? selected;
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    search.dispose();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) widget.library.pollDevice();
  }

  Future<void> openApp(String packageId) async {
    try {
      await widget.library.device.launchApp(packageId);
    } catch (e) {
      if (!mounted) return;
      final reason = e is PlatformException
          ? e.message ?? 'Android could not open this app.'
          : 'This app could not be opened.';
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(reason)));
    }
  }

  Future<void> openCommit(ProjectCommit commit) async {
    try {
      await widget.library.device.open(commit.url);
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not open this commit on GitHub.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: widget.library,
    builder: (context, _) => LayoutBuilder(
      builder: (context, constraints) {
        final wide = constraints.maxWidth >= 900;
        final query = search.text.trim().toLowerCase();
        final items = widget.library.projects
            .where(
              (p) => '${p.name} ${p.description}'.toLowerCase().contains(query),
            )
            .toList();
        final list = Scaffold(
          body: SafeArea(
            child: RefreshIndicator(
              onRefresh: widget.library.refresh,
              child: CustomScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                slivers: [
                  SliverPadding(
                    padding: const EdgeInsets.fromLTRB(24, 24, 24, 12),
                    sliver: SliverToBoxAdapter(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  'Core',
                                  style: Theme.of(
                                    context,
                                  ).textTheme.headlineLarge,
                                ),
                              ),
                              IconButton(
                                onPressed: widget.library.refreshing
                                    ? null
                                    : widget.library.refresh,
                                tooltip: 'Refresh library',
                                icon: widget.library.refreshing
                                    ? const SizedBox.square(
                                        dimension: 20,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                        ),
                                      )
                                    : const Icon(Icons.refresh_rounded),
                              ),
                            ],
                          ),
                          const SizedBox(height: 24),
                          TextField(
                            controller: search,
                            onChanged: (_) => setState(() {}),
                            decoration: InputDecoration(
                              hintText: 'Search your apps',
                              prefixIcon: const Icon(Icons.search_rounded),
                              suffixIcon: query.isEmpty
                                  ? null
                                  : IconButton(
                                      tooltip: 'Clear search',
                                      onPressed: () {
                                        search.clear();
                                        setState(() {});
                                      },
                                      icon: const Icon(Icons.close_rounded),
                                    ),
                            ),
                          ),
                          const SizedBox(height: 12),
                          if (widget.library.error != null)
                            Text(widget.library.error!),
                        ],
                      ),
                    ),
                  ),
                  if (widget.library.projects.isEmpty &&
                      widget.library.error == null)
                    const SliverFillRemaining(
                      child: Center(child: CircularProgressIndicator()),
                    )
                  else if (items.isEmpty)
                    const SliverFillRemaining(
                      hasScrollBody: false,
                      child: Center(
                        child: Text('No apps found. Try another search.'),
                      ),
                    )
                  else
                    SliverPadding(
                      padding: const EdgeInsets.fromLTRB(24, 0, 24, 12),
                      sliver: SliverList.builder(
                        itemCount: items.length,
                        itemBuilder: (context, index) {
                          final p = items[index];
                          final s = widget.library.states[p.id]!;
                          final installedPackage = [p.packageId, p.devPackageId]
                              .whereType<String>()
                              .where(widget.library.installed.containsKey)
                              .firstOrNull;
                          return AppRow(
                            project: p,
                            state: s,
                            transfer: widget.library.transfer(p),
                            selected: wide && selected?.id == p.id,
                            onOpen: installedPackage == null
                                ? null
                                : () => openApp(installedPackage),
                            onTap: () {
                              if (wide) {
                                setState(() => selected = p);
                              } else {
                                Navigator.of(context).push(
                                  MaterialPageRoute<void>(
                                    builder: (_) => DetailsScreen(
                                      project: p,
                                      library: widget.library,
                                    ),
                                  ),
                                );
                              }
                            },
                          );
                        },
                      ),
                    ),
                  if (widget.library.projects.isNotEmpty &&
                      items.isNotEmpty) ...[
                    SliverPadding(
                      padding: const EdgeInsets.fromLTRB(24, 24, 24, 12),
                      sliver: SliverToBoxAdapter(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Recent commits',
                              style: Theme.of(context).textTheme.headlineMedium,
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Latest changes across your projects',
                              style: Theme.of(context).textTheme.bodyMedium,
                            ),
                            if (widget.library.commitsError
                                case final error?) ...[
                              const SizedBox(height: 12),
                              Text(
                                error,
                                style: Theme.of(context).textTheme.bodySmall,
                              ),
                            ],
                          ],
                        ),
                      ),
                    ),
                    if (widget.library.commits.isEmpty)
                      SliverPadding(
                        padding: const EdgeInsets.fromLTRB(24, 8, 24, 40),
                        sliver: SliverToBoxAdapter(
                          child: widget.library.commitsLoading
                              ? const Center(child: CircularProgressIndicator())
                              : const Text('No recent commits available.'),
                        ),
                      )
                    else
                      SliverPadding(
                        padding: const EdgeInsets.fromLTRB(24, 0, 24, 40),
                        sliver: SliverList.builder(
                          itemCount: widget.library.commits.length,
                          itemBuilder: (context, index) {
                            final commit = widget.library.commits[index];
                            return ListTile(
                              contentPadding: const EdgeInsets.symmetric(
                                vertical: 4,
                              ),
                              leading: ProjectIcon(commit.project, size: 44),
                              title: Text(
                                commit.title,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                              subtitle: Text(
                                '${commit.project.name} · ${MaterialLocalizations.of(context).formatMediumDate(commit.date.toLocal())} · ${commit.sha}',
                              ),
                              trailing: const Icon(
                                Icons.open_in_new_rounded,
                                size: 18,
                              ),
                              onTap: () => openCommit(commit),
                            );
                          },
                        ),
                      ),
                  ],
                ],
              ),
            ),
          ),
        );
        if (!wide) return list;
        return Row(
          children: [
            SizedBox(width: 390, child: list),
            const VerticalDivider(width: 1),
            Expanded(
              child: selected == null
                  ? const Scaffold(
                      body: Center(
                        child: Text('Choose an app to explore its releases.'),
                      ),
                    )
                  : DetailsScreen(
                      key: ValueKey(selected!.id),
                      project: selected!,
                      library: widget.library,
                      embedded: true,
                    ),
            ),
          ],
        );
      },
    ),
  );
}

class AppRow extends StatelessWidget {
  const AppRow({
    super.key,
    required this.project,
    required this.state,
    required this.onTap,
    this.onOpen,
    this.transfer,
    this.selected = false,
  });
  final Project project;
  final ProjectState state;
  final VoidCallback onTap;
  final VoidCallback? onOpen;
  final Map<String, dynamic>? transfer;
  final bool selected;
  @override
  Widget build(BuildContext context) {
    final phase = transfer?['phase'];
    final downloading =
        phase == 'downloading' || phase == 'installing' || phase == 'ready';
    final progress = (transfer?['progress'] as num?)?.toDouble();
    return Semantics(
      button: true,
      label: '${project.name}. ${downloading ? phase : state.label}',
      child: Material(
        color: selected ? CoreColors.surface : Colors.transparent,
        borderRadius: BorderRadius.circular(20),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(20),
          splashFactory: InkRipple.splashFactory,
          child: Padding(
            padding: const EdgeInsets.only(top: 20),
            child: Column(
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Tooltip(
                      message: onOpen == null
                          ? 'View ${project.name} details'
                          : 'Open ${project.name}',
                      child: Semantics(
                        button: true,
                        label: onOpen == null
                            ? 'View ${project.name} details'
                            : 'Open ${project.name}',
                        child: InkWell(
                          onTap: onOpen ?? onTap,
                          borderRadius: BorderRadius.circular(20),
                          splashFactory: InkRipple.splashFactory,
                          child: ProjectIcon(project),
                        ),
                      ),
                    ),
                    const SizedBox(width: 18),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            project.name,
                            style: Theme.of(context).textTheme.titleLarge,
                          ),
                          const SizedBox(height: 4),
                          Text(
                            project.description,
                            style: Theme.of(context).textTheme.bodyMedium,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 4),
                  ],
                ),
                const SizedBox(height: 20),
                Tooltip(
                  message: downloading ? 'Download: $phase' : state.label,
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: downloading
                        ? LinearProgressIndicator(
                            minHeight: 3,
                            color: CoreColors.blue,
                            backgroundColor: CoreColors.surface,
                            value: phase == 'installing'
                                ? null
                                : phase == 'ready'
                                ? 1
                                : progress,
                          )
                        : Container(
                            height: 3,
                            color: CoreColors.status(state.status),
                          ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
