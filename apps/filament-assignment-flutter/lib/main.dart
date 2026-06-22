import 'package:flutter/material.dart';
import 'package:flutter_villains/villain.dart';
import 'package:provider/provider.dart';

import 'src/app/app_model.dart';
import 'src/app/theme.dart';
import 'src/ui/lock_screen.dart';
import 'src/ui/login_screen.dart';
import 'src/ui/main_scaffold.dart';
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
        navigatorObservers: [VillainTransitionObserver()],
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
      case AppGate.login:
        return const LoginScreen();
      case AppGate.locked:
        return const LockScreen();
      case AppGate.main:
        return const MainScaffold();
    }
  }
}
