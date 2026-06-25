/// Build-time configuration. The Bambuddy server URL is baked in permanently
/// as the default (override via `--dart-define BAMBUDDY_BASE_URL=...` only for
/// staging). Authentication is always credentials sign-in — there is no API
/// key and no PIN.
class AppConfig {
  AppConfig._();

  /// The Bambuddy server base URL, baked permanently into the build.
  static const String bakedBaseUrl = String.fromEnvironment(
    'BAMBUDDY_BASE_URL',
    defaultValue: 'https://print.crav3d.com',
  );

  /// Optional internal Bambuddy server base URL. When this URL is reachable,
  /// the app uses it instead of [bakedBaseUrl].
  static const String bakedInternalBaseUrl = String.fromEnvironment(
    'BAMBUDDY_INTERNAL_BASE_URL',
    defaultValue: '',
  );

  static bool get isBaseUrlBaked => bakedBaseUrl.isNotEmpty;
}
