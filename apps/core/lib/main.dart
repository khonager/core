import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'data/github.dart';
import 'data/library.dart';
import 'platform/device.dart';
import 'ui/library_screen.dart';
import 'ui/theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final preferences = await SharedPreferences.getInstance();
  final library = Library(
    preferences: preferences,
    github: GitHub(),
    device: Device(),
  );
  runApp(CoreApp(library: library));
  await library.init();
}

class CoreApp extends StatelessWidget {
  const CoreApp({super.key, required this.library});
  final Library library;
  @override
  Widget build(BuildContext context) => MaterialApp(
    title: 'Core',
    debugShowCheckedModeBanner: false,
    theme: coreTheme(),
    home: LibraryScreen(library: library),
  );
}
