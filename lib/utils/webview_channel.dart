import 'package:flutter/services.dart';

/// Канал для взаємодії з нативним Windows WebView кодом
class WebViewChannel {
  static const platform = MethodChannel('com.example.teamroom/webview');

  /// Запускає нативне вікно Windows з WebView2
  static Future<bool> launchWebView({
    required String htmlPath,
    required String title,
  }) async {
    try {
      final result = await platform.invokeMethod<bool>(
        'launchWebView',
        {
          'htmlPath': htmlPath,
          'title': title,
        },
      );
      return result ?? false;
    } catch (e) {
      print('Error launching WebView: $e');
      return false;
    }
  }

  /// Закриває нативне вікно WebView
  static Future<void> closeWebView() async {
    try {
      await platform.invokeMethod('closeWebView');
    } catch (e) {
      print('Error closing WebView: $e');
    }
  }
}
