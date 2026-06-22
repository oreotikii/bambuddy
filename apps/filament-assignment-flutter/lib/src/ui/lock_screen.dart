import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:local_auth/local_auth.dart';
import 'package:provider/provider.dart';

import '../app/app_model.dart';
import 'crav3d_logo.dart';

/// Biometric/device-auth gate shown after a signed-in session is re-locked.
class LockScreen extends StatefulWidget {
  const LockScreen({super.key});

  @override
  State<LockScreen> createState() => _LockScreenState();
}

class _LockScreenState extends State<LockScreen> {
  static const Color _background = Color(0xFF18181B);
  static const Color _copy = Color(0xFFA1A1AA);

  final LocalAuthentication _auth = LocalAuthentication();
  bool _checking = true;
  bool _authenticating = false;
  bool _deviceAuthAvailable = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    unawaited(_resolveDeviceAuth());
  }

  Future<void> _resolveDeviceAuth() async {
    final available = await _canUseDeviceAuth();
    if (!mounted) return;
    setState(() {
      _checking = false;
      _deviceAuthAvailable = available;
      _error = available
          ? null
          : 'Device unlock is not available on this device.';
    });
    if (available) unawaited(_authenticate());
  }

  Future<bool> _canUseDeviceAuth() async {
    try {
      final canCheckBiometrics = await _auth.canCheckBiometrics;
      final deviceSupported = await _auth.isDeviceSupported();
      return canCheckBiometrics || deviceSupported;
    } catch (_) {
      return false;
    }
  }

  Future<void> _authenticate() async {
    if (_authenticating) return;
    setState(() {
      _authenticating = true;
      _error = null;
    });

    try {
      final ok = await _auth.authenticate(
        localizedReason: 'Unlock Bambuddy Assign',
        options: const AuthenticationOptions(
          biometricOnly: false,
          stickyAuth: true,
        ),
      );
      if (!mounted) return;
      if (ok) {
        context.read<AppModel>().unlock();
        return;
      }
      setState(() => _error = 'Could not verify your identity. Try again.');
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _deviceAuthAvailable = false;
        _error = 'Device unlock failed. Try again or sign out.';
      });
    } finally {
      if (mounted) setState(() => _authenticating = false);
    }
  }

  Future<void> _signOut() async {
    try {
      await _auth.stopAuthentication();
    } catch (_) {
      // Some platforms throw when no auth prompt is active.
    }
    if (!mounted) return;
    final model = context.read<AppModel>();
    await model.signOut();
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Scaffold(
      backgroundColor: _background,
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final contentWidth = math.min(
              360.0,
              math.max(0.0, constraints.maxWidth - 48),
            );

            return Stack(
              children: [
                const Positioned.fill(
                  child: CustomPaint(painter: _LockToolpathPainter()),
                ),
                Center(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 24,
                      vertical: 24,
                    ),
                    child: ConstrainedBox(
                      constraints: BoxConstraints(maxWidth: contentWidth),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          const Center(child: Crav3dLogo(width: 220)),
                          const SizedBox(height: 18),
                          const Center(
                            child: _LockStatusPill(label: 'App locked'),
                          ),
                          const SizedBox(height: 60),
                          const Center(child: _DeviceUnlockOrb()),
                          const SizedBox(height: 30),
                          Text(
                            'Verify with device security',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: cs.onSurface,
                              fontSize: 22,
                              fontWeight: FontWeight.w800,
                              height: 1.14,
                              letterSpacing: 0,
                            ),
                          ),
                          const SizedBox(height: 8),
                          const Text(
                            'Use Face ID, Touch ID, fingerprint, or device passcode to continue.',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: _copy,
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                              height: 1.3,
                              letterSpacing: 0,
                            ),
                          ),
                          if (_error != null) ...[
                            const SizedBox(height: 24),
                            _InlineLockMessage(message: _error!),
                          ],
                          const SizedBox(height: 32),
                          FilledButton.icon(
                            key: const ValueKey('lock-unlock-button'),
                            onPressed: _checking || _authenticating
                                ? null
                                : _authenticate,
                            style: FilledButton.styleFrom(
                              minimumSize: const Size.fromHeight(56),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(15),
                              ),
                            ),
                            icon: _authenticating
                                ? const SizedBox(
                                    width: 18,
                                    height: 18,
                                    child: CircularProgressIndicator(
                                      color: Colors.black,
                                      strokeWidth: 2,
                                    ),
                                  )
                                : Icon(
                                    _deviceAuthAvailable
                                        ? Icons.fingerprint
                                        : Icons.lock_open,
                                  ),
                            label: Text(
                              _checking
                                  ? 'Checking device security'
                                  : _authenticating
                                  ? 'Waiting for device unlock'
                                  : 'Unlock with device security',
                            ),
                          ),
                          const SizedBox(height: 14),
                          TextButton(
                            key: const ValueKey('lock-sign-out-button'),
                            onPressed: _signOut,
                            style: TextButton.styleFrom(
                              foregroundColor: _copy,
                              textStyle: const TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                                letterSpacing: 0,
                              ),
                            ),
                            child: const Text('Sign out'),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _DeviceUnlockOrb extends StatelessWidget {
  const _DeviceUnlockOrb();

  @override
  Widget build(BuildContext context) {
    return Container(
      key: const ValueKey('lock-device-orb'),
      width: 104,
      height: 104,
      decoration: BoxDecoration(
        color: const Color(0xFF064E2D),
        shape: BoxShape.circle,
        border: Border.all(color: const Color(0xFF00C853), width: 2.6),
        boxShadow: const [
          BoxShadow(color: Color(0x5200C853), blurRadius: 28, spreadRadius: 2),
        ],
      ),
      child: const Icon(Icons.fingerprint, color: Color(0xFFB7F4C8), size: 56),
    );
  }
}

class _LockStatusPill extends StatelessWidget {
  const _LockStatusPill({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 9),
      decoration: BoxDecoration(
        color: const Color(0xFF064E2D),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: const Color(0xFF00C853)),
      ),
      child: Text(
        label,
        style: const TextStyle(
          color: Color(0xFFB7F4C8),
          fontSize: 12,
          fontWeight: FontWeight.w800,
          letterSpacing: 0,
        ),
      ),
    );
  }
}

class _InlineLockMessage extends StatelessWidget {
  const _InlineLockMessage({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
      decoration: BoxDecoration(
        color: cs.errorContainer,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: cs.error),
      ),
      child: Text(
        message,
        textAlign: TextAlign.center,
        style: TextStyle(
          color: cs.onErrorContainer,
          fontSize: 13,
          fontWeight: FontWeight.w700,
          height: 1.25,
        ),
      ),
    );
  }
}

class _LockToolpathPainter extends CustomPainter {
  const _LockToolpathPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final topPaint = Paint()
      ..color = const Color(0xFF27272A)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.25;
    final top = Path()
      ..moveTo(size.width * 0.08, size.height * 0.16)
      ..cubicTo(
        size.width * 0.26,
        size.height * 0.05,
        size.width * 0.37,
        size.height * 0.27,
        size.width * 0.57,
        size.height * 0.15,
      )
      ..cubicTo(
        size.width * 0.71,
        size.height * 0.07,
        size.width * 0.8,
        size.height * 0.13,
        size.width * 0.94,
        size.height * 0.18,
      );
    canvas.drawPath(top, topPaint);

    final bottomPaint = Paint()
      ..color = const Color(0xFF202027)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.1;
    final bottom = Path()
      ..moveTo(size.width * 0.08, size.height * 0.82)
      ..cubicTo(
        size.width * 0.26,
        size.height * 0.71,
        size.width * 0.39,
        size.height * 0.9,
        size.width * 0.57,
        size.height * 0.78,
      )
      ..cubicTo(
        size.width * 0.74,
        size.height * 0.67,
        size.width * 0.82,
        size.height * 0.75,
        size.width * 0.94,
        size.height * 0.8,
      );
    canvas.drawPath(bottom, bottomPaint);
  }

  @override
  bool shouldRepaint(covariant _LockToolpathPainter oldDelegate) => false;
}
