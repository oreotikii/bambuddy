import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../app/app_model.dart';
import '../config/app_config.dart';
import '../core/api_exception.dart';
import '../core/url_validator.dart';
import '../data/api_client.dart';
import '../data/session_store.dart';

/// Initial setup: collect the Bambuddy base URL and API key, validate the key
/// against the server, then hand off to the PIN gate. Ported from MainActivity.
class SetupScreen extends StatefulWidget {
  const SetupScreen({super.key});

  @override
  State<SetupScreen> createState() => _SetupScreenState();
}

class _SetupScreenState extends State<SetupScreen> {
  final _urlCtrl = TextEditingController();
  final _keyCtrl = TextEditingController();
  String? _error;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _restoreSavedUrl();
  }

  Future<void> _restoreSavedUrl() async {
    final saved = await SessionStore.getBaseUrl();
    if (saved != null && mounted) setState(() => _urlCtrl.text = saved);
  }

  Future<void> _connect() async {
    setState(() => _error = null);
    final model = context.read<AppModel>();

    String base;
    if (AppConfig.isBaseUrlBaked) {
      final n = UrlValidator.normalize(AppConfig.bakedBaseUrl);
      if (n == null) {
        _setError(
            'The built-in server URL is invalid. Rebuild with a correct BAMBUDDY_BASE_URL.');
        return;
      }
      base = n;
    } else {
      final n = UrlValidator.normalize(_urlCtrl.text);
      if (n == null) {
        _setError(
            'Enter a valid Bambuddy URL, e.g. http://192.168.1.10 or https://bambuddy.local');
        return;
      }
      base = n;
    }

    String apiKey;
    if (AppConfig.isKeyBaked) {
      apiKey = AppConfig.bakedApiKey;
    } else {
      apiKey = _keyCtrl.text.trim();
      if (apiKey.isEmpty) {
        _setError('Enter your Bambuddy API key.');
        return;
      }
    }

    setState(() => _busy = true);
    await SessionStore.setBaseUrl(base);
    if (!AppConfig.isKeyBaked) await SessionStore.setApiKey(apiKey);

    try {
      final api = await ApiClient.create();
      await api.getList('/printers/');
      api.close();
      if (!mounted) return;
      await model.completeSetup();
    } on ApiException catch (e) {
      if (!mounted) return;
      if (e.isUnauthorized) {
        _setError('API key rejected by Bambuddy. Check the key and its scopes.');
        if (!AppConfig.isKeyBaked) await SessionStore.clearCredentials();
      } else if (e.statusCode == 0) {
        _setError(
            'Could not reach Bambuddy at $base. Check the URL, your network, and that the server is running.');
      } else {
        _setError('Unexpected response: ${e.detailMessage()}');
      }
    } catch (_) {
      if (mounted) {
        _setError('Could not reach Bambuddy at $base.');
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _setError(String m) => setState(() => _error = m);

  @override
  void dispose() {
    _urlCtrl.dispose();
    _keyCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 480),
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
                      height: 130,
                      child: Icon(Icons.inventory_2_outlined,
                          size: 64, color: cs.primary),
                    ),
                  ),
                  const SizedBox(height: 18),
                  Text('Bambuddy Assign',
                      style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                          fontWeight: FontWeight.bold, color: cs.onSurface)),
                  const SizedBox(height: 6),
                  Text(
                    AppConfig.isKeyBaked
                        ? 'Connect to your Bambuddy server'
                        : 'Enter your Bambuddy server and API key',
                    style: TextStyle(color: cs.onSurfaceVariant, fontSize: 15),
                  ),
                  if (!AppConfig.isBaseUrlBaked) ...[
                    const SizedBox(height: 22),
                    TextField(
                      controller: _urlCtrl,
                      keyboardType: TextInputType.url,
                      autocorrect: false,
                      decoration: const InputDecoration(
                          hintText: 'http://192.168.1.10  or  https://bambuddy.local'),
                    ),
                  ],
                  if (!AppConfig.isKeyBaked) ...[
                    const SizedBox(height: 12),
                    TextField(
                      controller: _keyCtrl,
                      obscureText: true,
                      autocorrect: false,
                      decoration:
                          const InputDecoration(hintText: 'API key  (e.g. bb_…)'),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      'API key: read, inventory write, and printer control.',
                      style: TextStyle(color: cs.onSurfaceVariant, fontSize: 12),
                    ),
                  ] else ...[
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(
                        color: cs.primaryContainer,
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Text(
                        'API key is built into this app build.',
                        style: TextStyle(color: cs.onPrimaryContainer, fontSize: 12),
                      ),
                    ),
                  ],
                  if (_error != null) ...[
                    const SizedBox(height: 10),
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: cs.errorContainer,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: cs.error),
                      ),
                      child: Text(_error!, style: TextStyle(color: cs.error)),
                    ),
                  ],
                  const SizedBox(height: 18),
                  FilledButton(
                    onPressed: _busy ? null : _connect,
                    child: _busy
                        ? const SizedBox(
                            width: 20, height: 20,
                            child: CircularProgressIndicator(
                                color: Colors.black, strokeWidth: 2))
                        : const Text('Connect'),
                  ),
                  const SizedBox(height: 12),
                  Text('v1.0 / internal build',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                          color: cs.onSurfaceVariant,
                          fontSize: 11,
                          fontFamily: 'monospace')),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
