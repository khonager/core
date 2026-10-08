import 'package:flutter/material.dart';
import '../domain/project.dart';

abstract final class CoreColors {
  static const background = Color(0xFFF6F2E8);
  static const surface = Color(0xFFEEE8DC);
  static const ink = Color(0xFF292C25);
  static const muted = Color(0xFF68685F);
  static const green = Color(0xFF4C795A);
  static const orange = Color(0xFFB87627);
  static const red = Color(0xFFB44D40);
  static const blue = Color(0xFF346EBD);
  static const neutral = Color(0xFFB8B4A9);
  static Color status(BuildStatus s) => switch (s) {
    BuildStatus.failure => red,
    BuildStatus.running => orange,
    BuildStatus.success => green,
    _ => neutral,
  };
}

ThemeData coreTheme() {
  final scheme = ColorScheme.fromSeed(
    seedColor: CoreColors.ink,
    brightness: Brightness.light,
    surface: CoreColors.background,
    primary: CoreColors.ink,
    onPrimary: Colors.white,
    error: CoreColors.red,
  );
  return ThemeData(
    useMaterial3: true,
    colorScheme: scheme,
    scaffoldBackgroundColor: CoreColors.background,
    appBarTheme: const AppBarTheme(
      backgroundColor: CoreColors.background,
      scrolledUnderElevation: 0,
    ),
    textTheme: const TextTheme(
      headlineLarge: TextStyle(
        fontSize: 36,
        fontWeight: FontWeight.w700,
        letterSpacing: -1.2,
        color: CoreColors.ink,
      ),
      headlineMedium: TextStyle(
        fontSize: 28,
        fontWeight: FontWeight.w700,
        letterSpacing: -.6,
      ),
      titleLarge: TextStyle(fontSize: 21, fontWeight: FontWeight.w700),
      titleMedium: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
      bodyMedium: TextStyle(
        fontSize: 15,
        height: 1.45,
        color: CoreColors.muted,
      ),
      bodySmall: TextStyle(fontSize: 13, height: 1.4, color: CoreColors.muted),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: CoreColors.surface,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(24),
        borderSide: BorderSide.none,
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        minimumSize: const Size(48, 52),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
    ),
    bottomSheetTheme: const BottomSheetThemeData(
      backgroundColor: CoreColors.background,
      showDragHandle: true,
    ),
    dividerTheme: const DividerThemeData(
      color: CoreColors.neutral,
      thickness: .5,
    ),
  );
}

class ProjectIcon extends StatelessWidget {
  const ProjectIcon(this.project, {super.key, this.size = 76});
  final Project project;
  final double size;
  @override
  Widget build(BuildContext context) => ClipRRect(
    borderRadius: BorderRadius.circular(size * .27),
    child: ColoredBox(
      color: CoreColors.surface,
      child: SizedBox.square(
        dimension: size,
        child: project.icon == null
            ? ColoredBox(
                color: CoreColors.surface,
                child: project.website != null
                    ? Icon(Icons.language_rounded, size: size * .45)
                    : Center(
                        child: Text(
                          project.name[0],
                          style: TextStyle(
                            fontSize: size * .45,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
              )
            : Image.asset(
                project.icon!,
                fit: BoxFit.cover,
                errorBuilder: (_, e, st) => ColoredBox(
                  color: CoreColors.surface,
                  child: Center(
                    child: Text(
                      project.name[0],
                      style: Theme.of(context).textTheme.headlineMedium,
                    ),
                  ),
                ),
              ),
      ),
    ),
  );
}
