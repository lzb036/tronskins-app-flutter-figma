import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tronskins_app/common/widgets/settings_style_app_bar.dart';

class _RecordingNavigatorObserver extends NavigatorObserver {
  int didPopCount = 0;

  @override
  void didPop(Route<dynamic> route, Route<dynamic>? previousRoute) {
    didPopCount++;
    super.didPop(route, previousRoute);
  }
}

class _LauncherPage extends StatelessWidget {
  const _LauncherPage();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: FilledButton(
          onPressed: () {
            Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (_) => const _SettingsTopNavigationPage(),
              ),
            );
          },
          child: const Text('Open settings'),
        ),
      ),
    );
  }
}

class _SettingsTopNavigationPage extends StatelessWidget {
  const _SettingsTopNavigationPage();

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Stack(
        children: [
          Positioned.fill(child: ColoredBox(color: Colors.white)),
          SettingsStyleTopNavigation(title: 'Settings'),
        ],
      ),
    );
  }
}

void main() {
  testWidgets(
    'SettingsStyleTopNavigation pops the current navigator by default',
    (tester) async {
      final observer = _RecordingNavigatorObserver();

      await tester.pumpWidget(
        MaterialApp(
          navigatorObservers: [observer],
          home: const _LauncherPage(),
        ),
      );

      await tester.tap(find.text('Open settings'));
      await tester.pumpAndSettle();

      expect(find.text('Settings'), findsOneWidget);
      expect(find.text('Open settings'), findsNothing);

      await tester.tap(find.byIcon(Icons.arrow_back));
      await tester.pumpAndSettle();

      expect(find.text('Open settings'), findsOneWidget);
      expect(observer.didPopCount, 1);
    },
  );
}
