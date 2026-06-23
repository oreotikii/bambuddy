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
  static const Color _copy = Color(0xFF71717A);

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
        localizedReason: 'Unlock CRAV3D Assist',
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
    await context.read<AppModel>().signOut();
  }

  @override
  Widget build(BuildContext context) {
    final busy = _checking || _authenticating;
    return Scaffold(
      backgroundColor: const Color(0xFF18181B),
      body: SafeArea(
        child: Stack(
          children: [
            const Positioned.fill(
              child: CustomPaint(painter: _SpoolArcPainter()),
            ),
            Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(
                  horizontal: 28,
                  vertical: 32,
                ),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 430),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: const [
                          Crav3dLogo(width: 110),
                          Spacer(),
                          _LockedBadge(),
                        ],
                      ),
                      const SizedBox(height: 52),
                      const _GreenRule(),
                      const SizedBox(height: 22),
                      const Text(
                        'Locked.',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 42,
                          fontWeight: FontWeight.w900,
                          height: 1.0,
                          letterSpacing: -1.8,
                        ),
                      ),
                      const SizedBox(height: 10),
                      const Text(
                        'Verify your identity to continue\nwhere you left off.',
                        style: TextStyle(
                          color: _copy,
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                          height: 1.55,
                        ),
                      ),
                      const SizedBox(height: 52),
                      const Center(child: _DeviceUnlockOrb()),
                      const SizedBox(height: 44),
                      if (_error != null) ...[
                        _InlineMessage(message: _error!),
                        const SizedBox(height: 20),
                      ],
                      _UnlockButton(
                        busy: busy,
                        deviceAuthAvailable: _deviceAuthAvailable,
                        onPressed: _authenticate,
                      ),
                      const SizedBox(height: 20),
                      TextButton(
                        key: const ValueKey('lock-sign-out-button'),
                        onPressed: _signOut,
                        style: TextButton.styleFrom(
                          foregroundColor: const Color(0xFF3F3F46),
                          textStyle: const TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            letterSpacing: 0.2,
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
      width: 96,
      height: 96,
      decoration: BoxDecoration(
        color: const Color(0xFF064E2D),
        shape: BoxShape.circle,
        border: Border.all(color: const Color(0xFF00C853), width: 2.0),
        boxShadow: const [
          BoxShadow(
            color: Color(0x3800C853),
            blurRadius: 32,
            spreadRadius: 4,
          ),
        ],
      ),
      child: const Icon(Icons.fingerprint, color: Color(0xFFB7F4C8), size: 52),
    );
  }
}

class _LockedBadge extends StatelessWidget {
  const _LockedBadge();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        border: Border.all(color: const Color(0xFF27272A)),
        borderRadius: BorderRadius.circular(6),
      ),
      child: const Text(
        'LOCKED',
        style: TextStyle(
          color: Color(0xFF52525B),
          fontSize: 10,
          fontWeight: FontWeight.w800,
          letterSpacing: 1.4,
        ),
      ),
    );
  }
}

class _GreenRule extends StatelessWidget {
  const _GreenRule();

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 32,
          height: 3,
          decoration: BoxDecoration(
            color: const Color(0xFF00C853),
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        const SizedBox(width: 5),
        Container(
          width: 10,
          height: 3,
          decoration: BoxDecoration(
            color: const Color(0xFF00C853).withValues(alpha: 0.3),
            borderRadius: BorderRadius.circular(2),
          ),
        ),
      ],
    );
  }
}

class _UnlockButton extends StatelessWidget {
  const _UnlockButton({
    required this.busy,
    required this.deviceAuthAvailable,
    required this.onPressed,
  });

  final bool busy;
  final bool deviceAuthAvailable;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 60,
      child: FilledButton(
        key: const ValueKey('lock-unlock-button'),
        onPressed: busy ? null : onPressed,
        style: FilledButton.styleFrom(
          backgroundColor: const Color(0xFF00C853),
          foregroundColor: Colors.black,
          disabledBackgroundColor: const Color(0xFF00C853).withValues(
            alpha: 0.35,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
          elevation: 0,
        ),
        child: busy
            ? const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  color: Colors.black,
                  strokeWidth: 2.5,
                ),
              )
            : Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Text(
                    'Unlock with device security',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                      letterSpacing: -0.3,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Icon(
                    deviceAuthAvailable
                        ? Icons.fingerprint
                        : Icons.arrow_forward_rounded,
                    size: 18,
                  ),
                ],
              ),
      ),
    );
  }
}

class _InlineMessage extends StatelessWidget {
  const _InlineMessage({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
      decoration: BoxDecoration(
        color: const Color(0xFF2C1414),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFF7F1D1D)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.only(top: 1),
            child: Icon(
              Icons.error_outline_rounded,
              color: Color(0xFFF87171),
              size: 15,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              message,
              style: const TextStyle(
                color: Color(0xFFFCA5A5),
                fontSize: 13,
                fontWeight: FontWeight.w600,
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// Filament spool cross-section as concentric arcs — same painter as login
// screen so both screens share a visual signature.
class _SpoolArcPainter extends CustomPainter {
  const _SpoolArcPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width * 1.06, -size.height * 0.03);

    const arcCount = 10;
    const startRadius = 55.0;
    const radiusStep = 36.0;
    const sweepAngle = math.pi * 0.68;
    const startAngle = math.pi * 0.88;

    for (var i = 0; i < arcCount; i++) {
      final radius = startRadius + i * radiusStep;
      final opacity = 0.13 - (i * 0.011);
      if (opacity <= 0) continue;

      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius),
        startAngle,
        sweepAngle,
        false,
        Paint()
          ..color = const Color(0xFF00C853).withValues(alpha: opacity)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.1
          ..strokeCap = StrokeCap.round,
      );
    }

    final center2 = Offset(-size.width * 0.04, size.height * 1.04);
    for (var i = 0; i < 6; i++) {
      final radius = 70.0 + i * 44.0;
      final opacity = 0.04 - (i * 0.006);
      if (opacity <= 0) continue;

      canvas.drawArc(
        Rect.fromCircle(center: center2, radius: radius),
        -math.pi * 0.12,
        math.pi * 0.55,
        false,
        Paint()
          ..color = Colors.white.withValues(alpha: opacity)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 0.9,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _SpoolArcPainter oldDelegate) => false;
}
