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
        _setError('This account lacks permission to use Bambuddy Assign.');
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
    final cs = Theme.of(context).colorScheme;
    return Scaffold(
      backgroundColor: const Color(0xFF18181B),
      body: SafeArea(
        child: Stack(
          children: [
            const Positioned.fill(
              child: CustomPaint(painter: _ToolpathPainter()),
            ),
            Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 28,
                ),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 430),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Crav3dLogo(width: 132),
                      const SizedBox(height: 3),
                      Text(
                        'Bambuddy Assign',
                        style: TextStyle(
                          color: cs.onSurfaceVariant,
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0,
                        ),
                      ),
                      const SizedBox(height: 34),
                      const Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          _StatusPill(
                            label: 'Internal connection',
                            strong: true,
                          ),
                          _StatusPill(label: 'Stored on device'),
                        ],
                      ),
                      const SizedBox(height: 32),
                      Text(
                        'Sign in',
                        style: TextStyle(
                          color: cs.onSurface,
                          fontSize: 29,
                          fontWeight: FontWeight.w800,
                          height: 1.1,
                          letterSpacing: 0,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Use your Bambuddy account to continue.',
                        style: TextStyle(
                          color: cs.onSurfaceVariant,
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          height: 1.35,
                        ),
                      ),
                      const SizedBox(height: 30),
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
                      const SizedBox(height: 10),
                      Text(
                        'Credentials are stored on this device to keep you signed in.',
                        style: TextStyle(
                          color: cs.onSurfaceVariant,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      if (_error != null) ...[
                        const SizedBox(height: 18),
                        _InlineMessage(message: _error!),
                      ],
                      const SizedBox(height: 26),
                      FilledButton(
                        onPressed: _busy ? null : _signIn,
                        style: FilledButton.styleFrom(
                          minimumSize: const Size.fromHeight(58),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(15),
                          ),
                        ),
                        child: _busy
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                  color: Colors.black,
                                  strokeWidth: 2,
                                ),
                              )
                            : const Text('Sign in'),
                      ),
                      const SizedBox(height: 18),
                      Text(
                        'v1.0 / internal build',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: cs.onSurfaceVariant,
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          fontFeatures: const [FontFeature.tabularFigures()],
                        ),
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
    final cs = Theme.of(context).colorScheme;
    final focused = widget.focusNode.hasFocus;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          widget.label,
          style: TextStyle(
            color: cs.onSurfaceVariant,
            fontSize: 17,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 8),
        AnimatedContainer(
          key: widget.shellKey,
          duration: const Duration(milliseconds: 160),
          curve: Curves.easeOutCubic,
          decoration: BoxDecoration(
            color: const Color(0xFF323238),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: focused
                  ? const Color(0xFF00C853)
                  : const Color(0xFF3F3F46),
              width: focused ? 2.5 : 2,
            ),
            boxShadow: focused
                ? const [
                    BoxShadow(
                      color: Color(0x5200C853),
                      blurRadius: 18,
                      spreadRadius: 1,
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
            style: TextStyle(
              color: cs.onSurface,
              fontSize: 16,
              fontWeight: FontWeight.w700,
            ),
            decoration: InputDecoration(
              hintText: widget.hintText,
              hintStyle: TextStyle(
                color: cs.onSurfaceVariant,
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
              filled: false,
              border: InputBorder.none,
              enabledBorder: InputBorder.none,
              focusedBorder: InputBorder.none,
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 20,
                vertical: 18,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _StatusPill extends StatelessWidget {
  const _StatusPill({required this.label, this.strong = false});

  final String label;
  final bool strong;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
      decoration: BoxDecoration(
        color: strong ? cs.primaryContainer : cs.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: strong ? cs.primary : cs.outline),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: strong ? cs.onPrimaryContainer : cs.onSurfaceVariant,
          fontSize: 12,
          fontWeight: FontWeight.w800,
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

class _ToolpathPainter extends CustomPainter {
  const _ToolpathPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = const Color(0xFF27272A)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.3;
    final top = Path()
      ..moveTo(size.width * 0.07, size.height * 0.18)
      ..cubicTo(
        size.width * 0.25,
        size.height * 0.08,
        size.width * 0.34,
        size.height * 0.28,
        size.width * 0.52,
        size.height * 0.18,
      )
      ..cubicTo(
        size.width * 0.68,
        size.height * 0.09,
        size.width * 0.78,
        size.height * 0.15,
        size.width * 0.93,
        size.height * 0.21,
      );
    canvas.drawPath(top, paint);

    final bottomPaint = Paint()
      ..color = const Color(0xFF202027)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.1;
    final bottom = Path()
      ..moveTo(size.width * 0.08, size.height * 0.83)
      ..cubicTo(
        size.width * 0.27,
        size.height * 0.74,
        size.width * 0.36,
        size.height * 0.91,
        size.width * 0.56,
        size.height * 0.79,
      )
      ..cubicTo(
        size.width * 0.72,
        size.height * 0.7,
        size.width * 0.8,
        size.height * 0.77,
        size.width * 0.94,
        size.height * 0.81,
      );
    canvas.drawPath(bottom, bottomPaint);
  }

  @override
  bool shouldRepaint(covariant _ToolpathPainter oldDelegate) => false;
}
