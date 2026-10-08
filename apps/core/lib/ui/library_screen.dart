import 'package:flutter/material.dart';
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
                      padding: const EdgeInsets.fromLTRB(24, 0, 24, 32),
                      sliver: SliverList.builder(
                        itemCount: items.length,
                        itemBuilder: (context, index) {
                          final p = items[index];
                          final s = widget.library.states[p.id]!;
                          return AppRow(
                            project: p,
                            state: s,
                            transfer: widget.library.transfer(p),
                            selected: wide && selected?.id == p.id,
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
    this.transfer,
    this.selected = false,
  });
  final Project project;
  final ProjectState state;
  final VoidCallback onTap;
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
          child: Padding(
            padding: const EdgeInsets.only(top: 20),
            child: Column(
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    ProjectIcon(project),
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
