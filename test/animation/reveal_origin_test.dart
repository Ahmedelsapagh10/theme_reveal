import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:theme_reveal_kit/theme_reveal_kit.dart';

void main() {
  testWidgets('every origin resolves in viewport-local space, including RTL', (
    tester,
  ) async {
    final viewportKey = GlobalKey();
    final triggerKey = GlobalKey();
    await tester.pumpWidget(
      Directionality(
        textDirection: TextDirection.ltr,
        child: Align(
          alignment: Alignment.topLeft,
          child: Padding(
            padding: const EdgeInsets.only(left: 41, top: 53),
            child: SizedBox(
              key: viewportKey,
              width: 300,
              height: 200,
              child: Align(
                alignment: Alignment.topLeft,
                child: Padding(
                  padding: const EdgeInsets.only(left: 60, top: 70),
                  child: SizedBox(key: triggerKey, width: 48, height: 48),
                ),
              ),
            ),
          ),
        ),
      ),
    );
    final viewport =
        viewportKey.currentContext!.findRenderObject()! as RenderBox;
    final cases = <RevealOrigin, Offset>{
      const RevealOrigin.buttonCenter(): const Offset(84, 94),
      RevealOrigin.fromKey(triggerKey): const Offset(84, 94),
      const RevealOrigin.gesture(): const Offset(16, 27),
      const RevealOrigin.screenCenter(): const Offset(150, 100),
      const RevealOrigin.topLeft(): Offset.zero,
      const RevealOrigin.topRight(): const Offset(300, 0),
      const RevealOrigin.bottomLeft(): const Offset(0, 200),
      const RevealOrigin.bottomRight(): const Offset(300, 200),
      const RevealOrigin.normalized(.25, .75): const Offset(75, 150),
      const RevealOrigin.offset(20, 30): const Offset(20, 30),
      const RevealOrigin.topStart(): Offset.zero,
      const RevealOrigin.topEnd(): const Offset(300, 0),
      const RevealOrigin.bottomStart(): const Offset(0, 200),
      const RevealOrigin.bottomEnd(): const Offset(300, 200),
    };
    for (final entry in cases.entries) {
      expect(
        entry.key.resolve(
          viewport: viewport,
          from: triggerKey.currentContext,
          globalPosition: const Offset(57, 80),
        ),
        entry.value,
      );
    }
    expect(
      const RevealOrigin.topStart().resolve(
        viewport: viewport,
        textDirection: TextDirection.rtl,
      ),
      const Offset(300, 0),
    );
    expect(
      const RevealOrigin.topEnd().resolve(
        viewport: viewport,
        textDirection: TextDirection.rtl,
      ),
      Offset.zero,
    );
    expect(
      const RevealOrigin.bottomStart().resolve(
        viewport: viewport,
        textDirection: TextDirection.rtl,
      ),
      const Offset(300, 200),
    );
    expect(
      const RevealOrigin.bottomEnd().resolve(
        viewport: viewport,
        textDirection: TextDirection.rtl,
      ),
      const Offset(0, 200),
    );
    expect(
      const RevealOrigin.buttonCenter().resolve(viewport: viewport),
      const Offset(150, 100),
    );
    expect(
      const RevealOrigin.gesture().resolve(
        viewport: viewport,
        from: triggerKey.currentContext,
      ),
      const Offset(84, 94),
    );
    expect(
      () => RevealOrigin.fromKey(GlobalKey()).resolve(viewport: viewport),
      throwsA(isA<RevealException>()),
    );
    expect(
      () =>
          const RevealOrigin.offset(double.nan, 0).resolve(viewport: viewport),
      throwsA(isA<RevealException>()),
    );
  });

  testWidgets(
    'keyed and contextual origins through SafeArea, scrolling, rotation and nested Navigator',
    (tester) async {
      final viewportKey = GlobalKey();
      final buttonKey = GlobalKey();
      final scroll = ScrollController(initialScrollOffset: 160);
      await tester.pumpWidget(
        MaterialApp(
          home: MediaQuery(
            data: const MediaQueryData(padding: EdgeInsets.only(top: 30)),
            child: SizedBox(
              key: viewportKey,
              child: SafeArea(
                child: Navigator(
                  onGenerateRoute: (_) => MaterialPageRoute<void>(
                    builder: (_) => ListView(
                      controller: scroll,
                      children: [
                        const SizedBox(height: 250),
                        Transform.translate(
                          offset: const Offset(20, 15),
                          child: Align(
                            alignment: Alignment.centerLeft,
                            child: Transform.rotate(
                              angle: math.pi / 2,
                              alignment: Alignment.topLeft,
                              child: SizedBox(
                                key: buttonKey,
                                width: 48,
                                height: 48,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 1000),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      final viewport =
          viewportKey.currentContext!.findRenderObject()! as RenderBox;
      expect(
        RevealOrigin.fromKey(buttonKey).resolve(viewport: viewport),
        const Offset(-4, 159),
      );
      expect(
        const RevealOrigin.buttonCenter().resolve(
          viewport: viewport,
          from: buttonKey.currentContext,
        ),
        const Offset(-4, 159),
      );
      final button = buttonKey.currentContext!.findRenderObject()! as RenderBox;
      expect(
        const RevealOrigin.gesture().resolve(
          viewport: viewport,
          globalPosition: button.localToGlobal(const Offset(8, 12)),
        ),
        const Offset(8, 143),
      );
      scroll.jumpTo(210);
      await tester.pumpAndSettle();
      expect(
        RevealOrigin.fromKey(buttonKey).resolve(viewport: viewport),
        const Offset(-4, 109),
      );
      await tester.pumpWidget(const SizedBox.shrink());
      scroll.dispose();
    },
  );
}
