import 'package:flutter/widgets.dart';
import 'package:tronskins_app/common/widgets/flutter_patcher_update_gate.dart';
import 'package:tronskins_app/common/widgets/local_flutter_patcher_update_gate.dart';

/// Selects the hot-update gate used by the current build.
class AppHotUpdateGate extends StatelessWidget {
  const AppHotUpdateGate({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    if (LocalFlutterPatcherUpdateGate.enabled) {
      return LocalFlutterPatcherUpdateGate(child: child);
    }
    return FlutterPatcherUpdateGate(child: child);
  }
}
