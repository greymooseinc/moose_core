import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:moose_core/src/app/moose_app_notifier.dart';

void main() {
  group('MooseAppNotifier batched notifications', () {
    testWidgets(
      'setThemeMode and setLocale in same frame trigger only one notification',
      (tester) async {
        final notifier = MooseAppNotifier();
        int notifyCount = 0;
        notifier.addListener(() => notifyCount++);

        // Pump a minimal widget tree so the scheduler drives frames,
        // allowing addPostFrameCallback to fire on the next pump().
        await tester.pumpWidget(const SizedBox.shrink());

        notifier.setThemeMode(ThemeMode.dark);
        notifier.setLocale(const Locale('ja'));

        await tester.pump(); // process post-frame callbacks

        expect(notifyCount, equals(1));
      },
    );
  });
}
