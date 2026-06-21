import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../app/app_model.dart';
import '../config/app_config.dart';
import '../data/session_store.dart';

/// Local 4-digit PIN gate. Two modes:
///  - Setup (first run, no baked PIN): enter + confirm a 4-digit PIN.
///  - Unlock (subsequent launches, or any baked-PIN build): enter the PIN.
/// Ported from PinActivity.
class PinScreen extends StatefulWidget {
  const PinScreen({super.key});

  @override
  State<PinScreen> createState() => _PinScreenState();
}

class _PinScreenState extends State<PinScreen> {
  static const int _pinLength = 4;

  final _pinCtrl = TextEditingController();
  final _confirmCtrl = TextEditingController();
  String? _error;
  bool? _setupMode; // null while loading

  @override
  void initState() {
    super.initState();
    _resolveMode();
  }

  Future<void> _resolveMode() async {
    final setup = !AppConfig.isPinBaked && !(await SessionStore.isPinSet());
    if (mounted) setState(() => _setupMode = setup);
  }

  bool get _isSetup => _setupMode == true;

  Future<void> _onSubmit() async {
    setState(() => _error = null);
    final model = context.read<AppModel>();
    final pin = _pinCtrl.text.trim();

    if (pin.length != _pinLength) {
      _setError('PIN must be exactly $_pinLength digits.');
      return;
    }
    if (!RegExp(r'^\d+$').hasMatch(pin)) {
      _setError('PIN must be digits only.');
      return;
    }

    if (_isSetup) {
      final confirm = _confirmCtrl.text.trim();
      if (pin != confirm) {
        _setError('PINs do not match.');
        return;
      }
      await SessionStore.setPin(pin);
      model.unlock();
    } else {
      if (await SessionStore.checkPin(pin)) {
        model.unlock();
      } else {
        _setError('Incorrect PIN.');
        _pinCtrl.clear();
      }
    }
  }

  void _setError(String m) => setState(() => _error = m);

  @override
  void dispose() {
    _pinCtrl.dispose();
    _confirmCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    if (_setupMode == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Card(
                    color: cs.surfaceContainerHighest,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                        side: BorderSide(color: cs.outline)),
                    child: SizedBox(
                      height: 112,
                      child: Icon(Icons.lock_outline,
                          size: 56, color: cs.primary),
                    ),
                  ),
                  const SizedBox(height: 18),
                  Text(
                    _isSetup ? 'Set a PIN' : 'Enter PIN',
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.bold, color: cs.onSurface),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    _isSetup
                        ? 'Choose a 4-digit PIN to lock the app.'
                        : 'Unlock Bambuddy Assign',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: cs.onSurfaceVariant, fontSize: 14),
                  ),
                  const SizedBox(height: 22),
                  TextField(
                    controller: _pinCtrl,
                    keyboardType: TextInputType.number,
                    obscureText: true,
                    textAlign: TextAlign.center,
                    maxLength: _pinLength,
                    decoration: const InputDecoration(
                      hintText: '4-digit PIN',
                      counterText: '',
                    ),
                  ),
                  if (_isSetup) ...[
                    const SizedBox(height: 12),
                    TextField(
                      controller: _confirmCtrl,
                      keyboardType: TextInputType.number,
                      obscureText: true,
                      textAlign: TextAlign.center,
                      maxLength: _pinLength,
                      decoration: const InputDecoration(
                        hintText: 'Confirm PIN',
                        counterText: '',
                      ),
                    ),
                  ],
                  if (_error != null) ...[
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: cs.errorContainer,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: cs.error),
                      ),
                      child: Text(_error!,
                          textAlign: TextAlign.center,
                          style: TextStyle(color: cs.error)),
                    ),
                  ],
                  const SizedBox(height: 18),
                  FilledButton(
                    onPressed: _onSubmit,
                    child: Text(_isSetup ? 'Create PIN' : 'Unlock'),
                  ),
                  if (!AppConfig.isKeyBaked) ...[
                    const SizedBox(height: 10),
                    OutlinedButton(
                      onPressed: () => context.read<AppModel>().logoutToSetup(),
                      child: const Text('Change server / API key'),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
