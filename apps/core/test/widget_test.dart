import 'dart:convert';
import 'package:core_app/data/github.dart';
import 'package:core_app/data/library.dart';
import 'package:core_app/main.dart';
import 'package:core_app/platform/device.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'github_test.dart' show release, run;

class TestDevice extends Device {
  @override
  bool get android => false;
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
  return lib;
}

void main() {
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
    expect(find.text('No stable release published yet.'), findsOneWidget);
  });
  for (final size in [const Size(390, 844), const Size(1280, 900)]) {
    testWidgets('layout ${size.width} and screenshot', (tester) async {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final lib = (await tester.runAsync(() => library()))!;
      addTearDown(lib.dispose);
      await tester.pumpWidget(CoreApp(library: lib));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      await expectLater(
        find.byType(MaterialApp),
        matchesGoldenFile('goldens/library-${size.width.toInt()}.png'),
      );
      await tester.tap(find.text('Trans'));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      await expectLater(
        find.byType(MaterialApp),
        matchesGoldenFile('goldens/details-${size.width.toInt()}.png'),
      );
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
    await tester.tap(find.text('Trans'));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });
}
