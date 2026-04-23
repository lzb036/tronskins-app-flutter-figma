import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tronskins_app/common/theme/settings_top_bar_style.dart';
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

  testWidgets('SettingsStyleNavigationRow pads trailing actions', (
    tester,
  ) async {
    const actionKey = Key('top-action');
    const rowWidth = 400.0;

    await tester.pumpWidget(
      const MaterialApp(
        home: Align(
          alignment: Alignment.topLeft,
          child: SizedBox(
            width: rowWidth,
            child: SettingsStyleNavigationRow(
              title: 'Filter',
              actions: [SizedBox(key: actionKey, width: 32, height: 32)],
            ),
          ),
        ),
      ),
    );

    expect(
      tester.getTopRight(find.byKey(actionKey)).dx,
      rowWidth - settingsTopBarActionTrailingPadding,
    );
  });

  testWidgets('SettingsStyleAppBar pads trailing actions', (tester) async {
    const actionKey = Key('app-bar-action');

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          appBar: SettingsStyleAppBar(
            title: const Text('Title'),
            actions: const [SizedBox(key: actionKey, width: 32, height: 32)],
          ),
        ),
      ),
    );

    final screenWidth =
        tester.view.physicalSize.width / tester.view.devicePixelRatio;
    expect(
      tester.getTopRight(find.byKey(actionKey)).dx,
      screenWidth - settingsTopBarActionTrailingPadding,
    );
  });
}
