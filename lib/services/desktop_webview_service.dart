import 'package:flutter/services.dart';

class DesktopWebViewService {
  static const platform = MethodChannel('com.example.kurs/webview');

  /// Load HTML content in native WebView (Windows/Linux)
  static Future<void> loadHtml(String htmlContent) async {
    try {
      await platform.invokeMethod('loadHtml', {'html': htmlContent});
    } catch (e) {
      throw Exception('Failed to load HTML: $e');
    }
  }

  /// Dispose native WebView
  static Future<void> dispose() async {
    try {
      await platform.invokeMethod('dispose');
    } catch (e) {
      throw Exception('Failed to dispose WebView: $e');
    }
  }

  /// Check if WebView is available
  static Future<bool> isWebViewAvailable() async {
    try {
      final bool result = await platform.invokeMethod('isAvailable');
      return result;
    } catch (e) {
      return false;
    }
  }
}
