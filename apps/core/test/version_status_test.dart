import 'package:core_app/domain/project.dart';
import 'package:flutter_test/flutter_test.dart';

Release release(String tag, int day, {bool dev = false}) => Release({
  'tag_name': tag,
  'published_at': '2026-01-${day.toString().padLeft(2, '0')}',
  'prerelease': dev,
});

void main() {
  test('reads APK versions from release notes and titles', () {
    final rolling = release('dev-latest', 5, dev: true);
    rolling.json['body'] = 'Version: `1.0.0-dev.12`';
    final named = release('dev-11-1', 4, dev: true);
    named.json['name'] = 'Trans 1.0.0-dev.11.1';
    final state = ProjectState()..releases = [rolling, named];
    expect(rolling.versionLabel, '1.0.0-dev.12');
    expect(state.versionsBehind('1.0.0-dev.12', true), 0);
    expect(state.versionsBehind('1.0.0-dev.11.1', true), 1);
  });

  test('counts releases rather than version number gaps, per channel', () {
    final state = ProjectState()
      ..releases = [
        release('v3.0.0', 5),
        release('v4.0.0-dev.9', 4, dev: true),
        release('v1.2.0', 3),
        release('v1.0.0', 1),
      ];
    expect(state.versionsBehind('1.0.0', false), 2);
    expect(state.versionsBehind('v3.0.0', false), 0);
    expect(state.versionsBehind('4.0.0-dev.9', true), 0);
    expect(state.versionsBehind('4.0.0-dev.9', false), isNull);
    expect(state.versionSummary('1.2.0', false), contains('1 version behind'));
    expect(state.versionSummary('3.0.0', false), contains('Up to date'));
  });

  test('unknown, rolling, and unmatched build identities are not current', () {
    final state = ProjectState()
      ..releases = [release('dev-latest', 5, dev: true), release('v1.0.0', 1)];
    expect(state.versionsBehind('dev-latest', true), isNull);
    expect(state.versionsBehind('1.0.0+2', false), isNull);
    expect(state.versionsBehind('0.1.0', false), isNull);
    expect(state.versionSummary('0.1.0', false), contains('unavailable'));
    state.releaseError = 'offline';
    expect(
      state.versionSummary('1.0.0', false),
      contains('Saved release data'),
    );
  });
}
