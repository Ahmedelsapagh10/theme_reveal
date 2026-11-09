// snippet:cubit:file
// 1) Import flutter_bloc along with Flutter and Theme Reveal Kit.
import 'package:flutter/material.dart';
import 'package:theme_reveal_kit/theme_reveal_kit.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

void main() => runApp(const CubitThemeApp());

class ThemeCubit extends Cubit<ThemeMode> {
  ThemeCubit() : super(ThemeMode.system);
  // YOUR CODE: keep your existing persistence when emitting a new preference.
  void toggle() =>
      emit(state == ThemeMode.dark ? ThemeMode.light : ThemeMode.dark);
}

class CubitThemeApp extends StatelessWidget {
  const CubitThemeApp({super.key});
  @override
  Widget build(BuildContext context) => BlocProvider(
    // 2) BlocProvider owns and closes this Cubit.
    create: (_) => ThemeCubit(),
    child: BlocBuilder<ThemeCubit, ThemeMode>(
      builder: (context, mode) => MaterialApp(
        // YOUR CODE: replace themes and screen content.
        theme: ThemeData.light(),
        darkTheme: ThemeData.dark(),
        themeMode: mode,
        // 3) Keep the viewport and zero theme animation duration.
        themeAnimationDuration: Duration.zero,
        builder: (context, child) => ThemeRevealViewport(child: child!),
        home: Scaffold(
          body: Builder(
            builder: (buttonContext) => FilledButton(
              // 4) Emit only inside the accepted theme change callback.
              onPressed: () => ThemeRevealViewport.of(buttonContext).reveal(
                from: buttonContext,
                onThemeChange: () => buttonContext.read<ThemeCubit>().toggle(),
              ),
              child: const Text('Change theme'),
            ),
          ),
        ),
      ),
    ),
  );
}

// end:cubit
