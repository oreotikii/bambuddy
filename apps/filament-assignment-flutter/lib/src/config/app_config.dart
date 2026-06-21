/// Build-time baked configuration. Mirrors the Android app's resValue pattern
/// (bambuddy.api.key / bambuddy.base.url / bambuddy.pin from local.properties),
/// but read here via --dart-define so a single build works across devices.
///
/// Pass at build time, e.g.:
///   flutter run \
///     --dart-define=BAMBUDDY_API_KEY=bb_... \
///     --dart-define=BAMBUDDY_BASE_URL=https://bambuddy.local \
///     --dart-define=BAMBUDDY_PIN=1234
///
/// Empty string (the default) means "not baked" — the app asks the user.
class AppConfig {
  AppConfig._();

  static const String bakedApiKey =
      String.fromEnvironment('BAMBUDDY_API_KEY', defaultValue: '');
  static const String bakedBaseUrl =
      String.fromEnvironment('BAMBUDDY_BASE_URL', defaultValue: '');
  static const String bakedPin =
      String.fromEnvironment('BAMBUDDY_PIN', defaultValue: '');

  static bool get isKeyBaked => bakedApiKey.isNotEmpty;
  static bool get isBaseUrlBaked => bakedBaseUrl.isNotEmpty;
  static bool get isPinBaked => bakedPin.isNotEmpty;
}
