import 'package:flutter/material.dart';
import 'package:flutter_villains/villain.dart';
import 'package:provider/provider.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

import 'src/app/app_model.dart';
import 'src/app/theme.dart';
import 'src/ui/design_effects.dart';
import 'src/ui/lock_screen.dart';
import 'src/ui/login_screen.dart';
import 'src/ui/main_scaffold.dart';
import 'src/ui/splash_screen.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  WakelockPlus.enable();
  runApp(const BambuddyAssignApp());
}

class BambuddyAssignApp extends StatelessWidget {
  const BambuddyAssignApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => AppModel()..init(),
      child: MaterialApp(
        title: 'CRAV3D Assist',
        debugShowCheckedModeBanner: false,
        theme: bambuddyTheme,
        navigatorObservers: [VillainTransitionObserver()],
        home: Consumer<AppModel>(
          builder: (_, model, _) {
            return AnimatedSwitcher(
              duration: appMotionDuration,
              switchInCurve: Curves.easeOutCubic,
              switchOutCurve: Curves.easeInCubic,
              transitionBuilder: (child, animation) {
                final curved = CurvedAnimation(
                  parent: animation,
                  curve: Curves.easeOutCubic,
                  reverseCurve: Curves.easeInCubic,
                );
                return FadeTransition(
                  opacity: curved,
                  child: SlideTransition(
                    position: Tween<Offset>(
                      begin: const Offset(0, 0.025),
                      end: Offset.zero,
                    ).animate(curved),
                    child: ScaleTransition(
                      scale: Tween<double>(
                        begin: 0.985,
                        end: 1,
                      ).animate(curved),
                      child: child,
                    ),
                  ),
                );
              },
              child: KeyedSubtree(
                key: ValueKey(model.gate),
                child: CravVillainScreenTransition(
                  child: _screenFor(model.gate),
                ),
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
