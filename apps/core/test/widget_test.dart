import 'dart:convert';
import 'package:core_app/data/github.dart';
import 'package:core_app/data/library.dart';
import 'package:core_app/domain/project.dart';
import 'package:core_app/main.dart';
import 'package:core_app/platform/device.dart';
import 'package:core_app/ui/library_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'github_test.dart' show release, run;

class TestDevice extends Device {
  final launchedPackages = <String>[];
  final openedUrls = <String>[];
  @override
  bool get android => false;
  @override
  Future<void> launchApp(String packageId) async {
    launchedPackages.add(packageId);
  }

  @override
  Future<void> install(String id) async {
    throw PlatformException(
      code: 'signing',
      message:
          'Android cannot update this app because the installed copy uses a different signing key.',
    );
  }

  @override
  Future<void> open(String url) async {
    openedUrls.add(url);
  }
}

Future<Library> library({bool offline = false}) async {
  SharedPreferences.setMockInitialValues({});
  final lib = Library(
    preferences: await SharedPreferences.getInstance(),
    device: TestDevice(),
    github: GitHub(
      client: MockClient((r) async {
        if (offline) throw Exception('offline');
        if (r.url.path.endsWith('/releases')) {
          return http.Response(
            jsonEncode([
              release('v1.2.0', false, '2026-09-01')
                ..['body'] =
                    'A calmer way to get around.\n\n- Improved route search\n- Faster departures',
              release('v1.3.0-dev.4', true, '2026-09-02'),
            ]),
            200,
          );
        }
        if (r.url.path.endsWith('/commits')) {
          final development = r.url.queryParameters['sha'] != null;
          return http.Response(
            jsonEncode([
              {
                'sha': development ? 'fedcba123456789' : 'abcdef123456789',
                'html_url':
                    'https://github.com/khonager/core/commit/${development ? 'fedcba123456789' : 'abcdef123456789'}',
                'commit': {
                  'message': development
                      ? 'Add development feature'
                      : 'Add a new feature\nMore details',
                  'committer': {'date': '2026-10-20T12:00:00Z'},
                },
              },
            ]),
            200,
          );
        }
        if (r.url.path.endsWith('/actions/runs/3/jobs') ||
            r.url.path.endsWith('/actions/runs/2/jobs')) {
          return http.Response(
            jsonEncode({
              'jobs': [
                {
                  'name': 'Build',
                  'started_at': '2026-10-20T10:00:00Z',
                  'completed_at': '2026-10-20T10:05:00Z',
                  'steps': [
                    {
                      'number': 1,
                      'name': 'Compile',
                      'status': 'completed',
                      'conclusion': 'success',
                      'started_at': '2026-10-20T10:00:00Z',
                      'completed_at': '2026-10-20T10:05:00Z',
                    },
                  ],
                },
              ],
            }),
            200,
          );
        }
        if (r.url.path.contains('/actions/workflows/')) {
          return http.Response(
            jsonEncode({
              'workflow_runs': [run(3, 1, 'success'), run(2, 1, 'success')],
            }),
            200,
          );
        }
        return http.Response(
          jsonEncode({
            'workflow_runs': [run(3, 1, 'success')],
          }),
          200,
        );
      }),
    ),
  );
  await lib.init();
  await lib.refresh();
  return lib;
}

void main() {
  testWidgets('sorts apps by update, category, and name', (tester) async {
    final lib = (await tester.runAsync(() => library()))!;
    addTearDown(lib.dispose);
    lib.states['core']!.releases = [
      Release(release('v2', false, '2026-10-20T12:00:00Z')),
    ];
    await tester.pumpWidget(CoreApp(library: lib));
    await tester.pumpAndSettle();

    String firstApp() =>
        tester.widget<AppRow>(find.byType(AppRow).first).project.name;
    expect(firstApp(), 'Core');

    await tester.tap(find.byTooltip('Sort apps'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Name').last);
    await tester.pumpAndSettle();
    expect(firstApp(), 'AdWise');

    await tester.tap(find.byTooltip('Sort apps'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Category').last);
    await tester.pumpAndSettle();
    final rows = tester.widgetList<AppRow>(find.byType(AppRow)).toList();
    expect(rows.take(3).map((row) => row.project.name), [
      'AdWise',
      'Trace',
      'TipStroke',
    ]);
  });

  testWidgets('latest release includes its local publication time', (
    tester,
  ) async {
    final lib = (await tester.runAsync(() => library()))!;
    addTearDown(lib.dispose);
    final date = lib.states['core']!.latest(false)!.date.toLocal();
    await tester.pumpWidget(CoreApp(library: lib));
    await tester.pumpAndSettle();
    final time = TimeOfDay.fromDateTime(
      date,
    ).format(tester.element(find.byType(AppRow).first));
    await tester.tap(find.text('Core').last);
    await tester.pumpAndSettle();
    expect(find.text(time), findsOneWidget);
  });

  testWidgets('opening one app fetches only that repository', (tester) async {
    SharedPreferences.setMockInitialValues({});
    final paths = <String>[];
    final lib = Library(
      preferences: await SharedPreferences.getInstance(),
      device: TestDevice(),
      github: GitHub(
        client: MockClient((request) async {
          paths.add(request.url.path);
          return request.url.path.endsWith('/actions/runs')
              ? http.Response(jsonEncode({'workflow_runs': []}), 200)
              : http.Response('[]', 200);
        }),
      ),
    );
    addTearDown(lib.dispose);
    await tester.runAsync(lib.init);
    expect(paths, isEmpty);
    await tester.pumpWidget(CoreApp(library: lib));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Core').last);
    await tester.pumpAndSettle();
    expect(paths, hasLength(3));
    expect(
      paths.every((path) => path.startsWith('/repos/khonager/core/')),
      isTrue,
    );
  });

  testWidgets('desktop details show commits without scrolling the app list', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1280, 1800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final lib = (await tester.runAsync(() => library()))!;
    addTearDown(lib.dispose);
    await tester.pumpWidget(CoreApp(library: lib));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Core').last);
    await tester.pumpAndSettle();
    expect(find.text('Recent commits'), findsOneWidget);
    expect(find.text('Add a new feature'), findsOneWidget);
    expect(find.text('View build steps'), findsOneWidget);
    await tester.tap(find.text('View build steps'));
    await tester.pumpAndSettle();
    expect(find.text('Compile'), findsOneWidget);
    expect((lib.device as TestDevice).openedUrls, isEmpty);
  });

  testWidgets('development tab shows commits from its release tag', (
    tester,
  ) async {
    final lib = (await tester.runAsync(() => library()))!;
    addTearDown(lib.dispose);
    await tester.pumpWidget(CoreApp(library: lib));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Core').last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Development'));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.text('Add development feature'),
      400,
      scrollable: find.byType(Scrollable).last,
    );
    expect(find.text('Recent development commits'), findsOneWidget);
    expect(find.text('Add development feature'), findsOneWidget);
    expect(find.text('Add a new feature'), findsNothing);
  });

  testWidgets('active build shows current step and prior-build estimates', (
    tester,
  ) async {
    final lib = (await tester.runAsync(() => library()))!;
    addTearDown(lib.dispose);
    final started = DateTime.now().toUtc().subtract(const Duration(minutes: 3));
    final state = lib.states['core']!;
    state.runs = [
      BuildRun({
        ...run(8, 1, '', status: 'in_progress'),
        'run_started_at': started.toIso8601String(),
      }),
    ];
    state.buildDetails[8] = BuildDetails(
      jobs: [
        BuildJob({
          'name': 'Android',
          'steps': [
            {
              'number': 1,
              'name': 'Compile',
              'status': 'in_progress',
              'started_at': started.toIso8601String(),
            },
          ],
        }),
      ],
      previousJobs: [
        BuildJob({
          'name': 'Android',
          'started_at': '2026-10-19T10:00:00Z',
          'completed_at': '2026-10-19T10:10:00Z',
          'steps': [
            {
              'number': 1,
              'name': 'Compile',
              'status': 'completed',
              'conclusion': 'success',
              'started_at': '2026-10-19T10:00:00Z',
              'completed_at': '2026-10-19T10:10:00Z',
            },
          ],
        }),
      ],
    );
    await tester.pumpWidget(CoreApp(library: lib));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Core').last);
    await tester.pumpAndSettle();
    await tester.drag(find.byType(ListView).last, const Offset(0, -700));
    await tester.pumpAndSettle();
    expect(find.text('Now: Android · Compile'), findsOneWidget);
    expect(find.textContaining('Current step: ~10 min total'), findsOneWidget);
    expect(find.textContaining('Build: ~10 min total'), findsOneWidget);
  });

  testWidgets('recent commits appear in app details and open on GitHub', (
    tester,
  ) async {
    final lib = (await tester.runAsync(() => library()))!;
    addTearDown(lib.dispose);
    lib.commits = [
      ProjectCommit(
        project: lib.projects.first,
        json: {
          'sha': 'abcdef123456789',
          'html_url': 'https://github.com/khonager/core/commit/abcdef123456789',
          'commit': {
            'message': 'Add a new feature\nMore details',
            'committer': {'date': '2026-10-20T12:00:00Z'},
          },
        },
      ),
    ];
    await tester.pumpWidget(CoreApp(library: lib));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Core').last);
    await tester.pumpAndSettle();
    await tester.drag(find.byType(ListView).last, const Offset(0, -3000));
    await tester.pumpAndSettle();
    expect(find.text('Recent commits'), findsOneWidget);
    expect(find.text('Add a new feature'), findsOneWidget);
    await tester.tap(find.text('Add a new feature'));
    await tester.pumpAndSettle();
    expect((lib.device as TestDevice).openedUrls, [
      'https://github.com/khonager/core/commit/abcdef123456789',
    ]);
  });

  testWidgets('installed app icon opens the app while row opens details', (
    tester,
  ) async {
    final lib = (await tester.runAsync(() => library()))!;
    addTearDown(lib.dispose);
    lib.installed['de.khonager.trans'] = '1.0';
    lib.changed();
    await tester.pumpWidget(CoreApp(library: lib));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Open Trans'));
    await tester.pumpAndSettle();
    expect((lib.device as TestDevice).launchedPackages, ['de.khonager.trans']);
    expect(find.text('v1.2.0'), findsNothing);
    lib.installed.remove('de.khonager.trans');
    lib.installed['de.khonager.trans.unstable'] = '1.1-dev';
    lib.changed();
    await tester.pump();
    await tester.tap(find.byTooltip('Open Trans'));
    await tester.pumpAndSettle();
    expect((lib.device as TestDevice).launchedPackages, [
      'de.khonager.trans',
      'de.khonager.trans.unstable',
    ]);
    await tester.tap(find.text('Trans'));
    await tester.pumpAndSettle();
    expect(find.text('v1.2.0'), findsOneWidget);
  });

  testWidgets('search, details, release channels and notification sheet work', (
    tester,
  ) async {
    final lib = (await tester.runAsync(() => library()))!;
    addTearDown(lib.dispose);
    await tester.pumpWidget(CoreApp(library: lib));
    await tester.pumpAndSettle();
    expect(find.text('Trans'), findsOneWidget);
    await tester.enterText(find.byType(TextField), 'trans');
    await tester.pump();
    expect(find.text('TypeSync'), findsNothing);
    await tester.tap(find.text('Trans'));
    await tester.pumpAndSettle();
    expect(find.text('v1.2.0'), findsOneWidget);
    await tester.tap(find.text('Development'));
    await tester.pumpAndSettle();
    expect(find.text('v1.3.0-dev.4'), findsOneWidget);
    await tester.tap(find.byTooltip('Notification preferences'));
    await tester.pumpAndSettle();
    expect(find.text('Failed builds'), findsOneWidget);
    expect(find.text('Ratings'), findsNothing);
  });
  testWidgets('signing mismatch explains recovery and opens the release', (
    tester,
  ) async {
    final lib = (await tester.runAsync(() => library()))!;
    addTearDown(lib.dispose);
    lib.downloads['core.dev'] = {'phase': 'ready'};
    await tester.pumpWidget(CoreApp(library: lib));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Core').last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Development'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Install downloaded APK'));
    await tester.pumpAndSettle();
    expect(find.text('Cannot update this app'), findsOneWidget);
    expect(find.textContaining('different signing key'), findsOneWidget);
    await tester.tap(find.text('Open release'));
    await tester.pumpAndSettle();
    expect((lib.device as TestDevice).openedUrls, [
      'https://github.com/owner/sample/releases/tag/v1.3.0-dev.4',
    ]);
  });
  testWidgets('catalog remains usable offline and explains missing data', (
    tester,
  ) async {
    final lib = (await tester.runAsync(() => library(offline: true)))!;
    addTearDown(lib.dispose);
    await tester.pumpWidget(CoreApp(library: lib));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Trans'));
    await tester.pumpAndSettle();
    expect(find.textContaining('Check your connection'), findsWidgets);
    expect(find.text('No stable release published yet.'), findsNothing);
  });
  for (final size in [const Size(390, 844), const Size(1280, 900)]) {
    testWidgets('layout ${size.width}', (tester) async {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final lib = (await tester.runAsync(() => library()))!;
      addTearDown(lib.dispose);
      await tester.pumpWidget(CoreApp(library: lib));
      if (size.width < 900) {
        final context = tester.element(find.byType(MaterialApp));
        for (final icon
            in lib.projects.map((p) => p.icon).whereType<String>()) {
          await tester.runAsync(() => precacheImage(AssetImage(icon), context));
        }
      }
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      if (size.width < 900) {
        await expectLater(
          find.byType(MaterialApp),
          matchesGoldenFile('goldens/library-390.png'),
        );
      } else {
        expect(tester.getSize(find.byType(RefreshIndicator).first).width, 390);
        expect(
          find.text('Choose an app to explore its releases.'),
          findsOneWidget,
        );
      }
      await tester.tap(find.text('Trans'));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      if (size.width < 900) {
        await expectLater(
          find.byType(MaterialApp),
          matchesGoldenFile('goldens/details-390.png'),
        );
      } else {
        expect(tester.getSize(find.byType(RefreshIndicator).first).width, 390);
        expect(find.text('Latest stable release'), findsOneWidget);
        expect(find.text('v1.2.0'), findsOneWidget);
      }
    });
  }
  testWidgets('phone supports 200 percent text scaling', (tester) async {
    tester.view.physicalSize = const Size(360, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final lib = (await tester.runAsync(() => library()))!;
    addTearDown(lib.dispose);
    tester.platformDispatcher.textScaleFactorTestValue = 2;
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    await tester.pumpWidget(CoreApp(library: lib));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'trans');
    await tester.pumpAndSettle();
    await tester.tap(find.text('Trans'));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });
}
