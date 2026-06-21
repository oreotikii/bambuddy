import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'src/app/app_model.dart';
import 'src/app/theme.dart';
import 'src/ui/main_scaffold.dart';
import 'src/ui/pin_screen.dart';
import 'src/ui/setup_screen.dart';
import 'src/ui/splash_screen.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const BambuddyAssignApp());
}

class BambuddyAssignApp extends StatelessWidget {
  const BambuddyAssignApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => AppModel()..init(),
      child: MaterialApp(
        title: 'Bambuddy Assign',
        debugShowCheckedModeBanner: false,
        theme: bambuddyTheme,
        home: Consumer<AppModel>(
          builder: (_, model, _) {
            return AnimatedSwitcher(
              duration: const Duration(milliseconds: 200),
              child: KeyedSubtree(
                key: ValueKey(model.gate),
                child: _screenFor(model.gate),
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _screenFor(AppGate gate) {
    switch (gate) {
      case AppGate.splash:
        return const SplashScreen();
      case AppGate.setup:
        return const SetupScreen();
      case AppGate.pin:
        return const PinScreen();
      case AppGate.main:
        return const MainScaffold();
    }
  }
}
