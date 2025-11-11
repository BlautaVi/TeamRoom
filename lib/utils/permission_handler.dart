import 'dart:io';
import 'package:flutter/foundation.dart';

/// Утиліта для керування дозволами на мікрофон та камеру
/// На Windows WebView2 дозволи обробляються автоматично браузером
class ConferencePermissionHandler {
  /// На Windows дозволи завжди включені (WebView2 обробляє їх)
  static Future<Map<String, bool>> requestAudioVideoPermissions() async {
    // Windows/Web: дозволи обробляються браузером WebView2
    // Користувач видить діалог "Allow/Deny" від браузера
    return {
      'camera': true,
      'microphone': true,
    };
  }

  /// Перевіряє, чи надані дозволи без запиту
  static Future<Map<String, bool>> checkAudioVideoPermissions() async {
    return {
      'camera': true,
      'microphone': true,
    };
  }

  static String getPlatformName() {
    if (Platform.isWindows) return 'windows';
    if (Platform.isLinux) return 'linux';
    if (Platform.isMacOS) return 'macos';
    if (kIsWeb) return 'web';
    return 'unknown';
  }
}
