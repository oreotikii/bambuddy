import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../app/app_model.dart';
import '../core/api_exception.dart';
import '../data/api_client.dart';
import '../data/session_store.dart';
import 'crav3d_logo.dart';

/// First-run / re-login screen: the user signs in with their Bambuddy
/// username + password. The server URL is baked into the build, so it is never
/// entered here. On success the credentials + access token are stored and the
/// app proceeds straight to the main surface.
class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _userCtrl = TextEditingController();
  final _passCtrl = TextEditingController();
  final _userFocus = FocusNode();
  final _passFocus = FocusNode();
  String? _error;
  bool _busy = false;

  Future<void> _signIn() async {
    setState(() => _error = null);
    final model = context.read<AppModel>();

    final base = await SessionStore.getBaseUrl();
    if (base == null) {
      _setError(
        'The built-in server URL is invalid. Rebuild with a correct BAMBUDDY_BASE_URL.',
      );
      return;
    }

    final username = _userCtrl.text.trim();
    final password = _passCtrl.text;
    if (username.isEmpty) {
      _setError('Enter your Bambuddy username.');
      return;
    }
    if (password.isEmpty) {
      _setError('Enter your password.');
      return;
    }

    setState(() => _busy = true);
    try {
      final res = await ApiClient.login(base, username, password);
      if (res.requires2fa) {
        _setError(
          'This account has 2FA enabled. Sign-in needs 2FA off — disable it '
          'for this account.',
        );
        return;
      }
      if (res.accessToken == null) {
        _setError('Sign-in failed. Check your username and password.');
        return;
      }
      await SessionStore.setUsername(username);
      await SessionStore.setPassword(password);
      await SessionStore.setAccessToken(res.accessToken!);
      if (!mounted) return;
      await model.completeLogin();
    } on ApiException catch (e) {
      if (!mounted) return;
      if (e.isUnauthorized) {
        _setError('Username or password incorrect.');
      } else if (e.isForbidden) {
        _setError('This account lacks permission to use CRAV3D Assist.');
      } else if (e.statusCode == 0) {
        _setError(
          'Could not reach Bambuddy. Check your network and that the server is running.',
        );
      } else {
        _setError('Unexpected response: ${e.detailMessage()}');
      }
    } catch (_) {
      if (mounted) {
        _setError('Could not reach Bambuddy.');
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _setError(String m) => setState(() => _error = m);

  @override
  void dispose() {
    _userCtrl.dispose();
    _passCtrl.dispose();
    _userFocus.dispose();
    _passFocus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
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
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Crav3dLogo(width: 250),
                          const Spacer(),
                          _InternalBadge(),
                        ],
                      ),
                      const SizedBox(height: 52),
                      const _GreenRule(),
                      const SizedBox(height: 22),
                      const Text(
                        'Sign in.',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 35,
                          fontWeight: FontWeight.w900,
                          height: 1.0,
                          letterSpacing: -1.8,
                        ),
                      ),
                      const SizedBox(height: 20),
                      const Text(
                        'CRAV3D Assist — filament management\nfor your print farm.',
                        style: TextStyle(
                          color: Color(0xFF71717A),
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                          height: 1.55,
                        ),
                      ),
                      const SizedBox(height: 38),
                      _LabeledField(
                        shellKey: const ValueKey('login-user-field-shell'),
                        fieldKey: const ValueKey('login-user-field'),
                        label: 'Username',
                        hintText: 'your.username',
                        controller: _userCtrl,
                        focusNode: _userFocus,
                        keyboardType: TextInputType.text,
                        textInputAction: TextInputAction.next,
                      ),
                      const SizedBox(height: 18),
                      _LabeledField(
                        shellKey: const ValueKey('login-pass-field-shell'),
                        fieldKey: const ValueKey('login-pass-field'),
                        label: 'Password',
                        hintText: '••••••••',
                        controller: _passCtrl,
                        focusNode: _passFocus,
                        obscureText: true,
                        textInputAction: TextInputAction.go,
                        onSubmitted: (_) => _signIn(),
                      ),
                      if (_error != null) ...[
                        const SizedBox(height: 22),
                        _InlineMessage(message: _error!),
                      ],
                      const SizedBox(height: 30),
                      _SignInButton(busy: _busy, onPressed: _signIn),
                      const SizedBox(height: 28),
                      Row(
                        children: const [
                          Text(
                            'v1.0 · internal build',
                            style: TextStyle(
                              color: Color(0xFF3F3F46),
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              letterSpacing: 0.2,
                            ),
                          ),
                          Spacer(),
                          Text(
                            'CRAV3D',
                            style: TextStyle(
                              color: Color(0xFF3F3F46),
                              fontSize: 11,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 1.8,
                            ),
                          ),
                        ],
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

class _InternalBadge extends StatelessWidget {
  const _InternalBadge();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        border: Border.all(color: const Color(0xFF27272A)),
        borderRadius: BorderRadius.circular(6),
      ),
      child: const Text(
        'INTERNAL',
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

class _SignInButton extends StatelessWidget {
  const _SignInButton({required this.busy, required this.onPressed});

  final bool busy;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 60,
      child: FilledButton(
        onPressed: busy ? null : onPressed,
        style: FilledButton.styleFrom(
          backgroundColor: const Color(0xFF00C853),
          foregroundColor: Colors.black,
          disabledBackgroundColor: const Color(
            0xFF00C853,
          ).withValues(alpha: 0.35),
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
            : const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    'Sign in',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                      letterSpacing: -0.3,
                    ),
                  ),
                  SizedBox(width: 8),
                  Icon(Icons.arrow_forward_rounded, size: 18),
                ],
              ),
      ),
    );
  }
}

class _LabeledField extends StatefulWidget {
  const _LabeledField({
    required this.shellKey,
    required this.fieldKey,
    required this.label,
    required this.hintText,
    required this.controller,
    required this.focusNode,
    this.keyboardType,
    this.obscureText = false,
    this.textInputAction,
    this.onSubmitted,
  });

  final Key shellKey;
  final Key fieldKey;
  final String label;
  final String hintText;
  final TextEditingController controller;
  final FocusNode focusNode;
  final TextInputType? keyboardType;
  final bool obscureText;
  final TextInputAction? textInputAction;
  final ValueChanged<String>? onSubmitted;

  @override
  State<_LabeledField> createState() => _LabeledFieldState();
}

class _LabeledFieldState extends State<_LabeledField> {
  @override
  void initState() {
    super.initState();
    widget.focusNode.addListener(_handleFocusChanged);
  }

  @override
  void didUpdateWidget(covariant _LabeledField oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.focusNode != widget.focusNode) {
      oldWidget.focusNode.removeListener(_handleFocusChanged);
      widget.focusNode.addListener(_handleFocusChanged);
    }
  }

  @override
  void dispose() {
    widget.focusNode.removeListener(_handleFocusChanged);
    super.dispose();
  }

  void _handleFocusChanged() => setState(() {});

  @override
  Widget build(BuildContext context) {
    final focused = widget.focusNode.hasFocus;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          widget.label.toUpperCase(),
          style: const TextStyle(
            color: Color(0xFF71717A),
            fontSize: 11,
            fontWeight: FontWeight.w700,
            letterSpacing: 1.1,
          ),
        ),
        const SizedBox(height: 8),
        AnimatedContainer(
          key: widget.shellKey,
          duration: const Duration(milliseconds: 180),
          curve: Curves.easeOutCubic,
          decoration: BoxDecoration(
            color: const Color(0xFF1F1F23),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: focused
                  ? const Color(0xFF00C853)
                  : const Color(0xFF2E2E34),
              width: focused ? 1.5 : 1,
            ),
            boxShadow: focused
                ? const [
                    BoxShadow(
                      color: Color(0x3300C853),
                      blurRadius: 16,
                      spreadRadius: 0,
                    ),
                  ]
                : null,
          ),
          child: TextField(
            key: widget.fieldKey,
            controller: widget.controller,
            focusNode: widget.focusNode,
            keyboardType: widget.keyboardType,
            obscureText: widget.obscureText,
            autocorrect: false,
            textInputAction: widget.textInputAction,
            onSubmitted: widget.onSubmitted,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 15,
              fontWeight: FontWeight.w600,
            ),
            decoration: InputDecoration(
              hintText: widget.hintText,
              hintStyle: const TextStyle(
                color: Color(0xFF52525B),
                fontSize: 15,
                fontWeight: FontWeight.w500,
              ),
              filled: false,
              border: InputBorder.none,
              enabledBorder: InputBorder.none,
              focusedBorder: InputBorder.none,
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 18,
                vertical: 17,
              ),
            ),
          ),
        ),
      ],
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

// Signature element: filament spool cross-section as concentric arcs,
// anchored to the top-right corner. Each ring = one winding of filament.
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

      final paint = Paint()
        ..color = const Color(0xFF00C853).withValues(alpha: opacity)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.1
        ..strokeCap = StrokeCap.round;

      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius),
        startAngle,
        sweepAngle,
        false,
        paint,
      );
    }

    // Subtle secondary cluster bottom-left for balance.
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
