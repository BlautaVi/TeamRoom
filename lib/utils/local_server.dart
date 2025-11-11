import 'dart:io';
import 'package:shelf/shelf.dart';
import 'package:shelf/shelf_io.dart' as shelf_io;

class LocalServerService {
  static HttpServer? _server;
  static const int _port = 9090;

  static Future<void> startServer() async {
    if (_server != null) return;

    final handler = const Pipeline().addMiddleware(logRequests()).addHandler(_handleRequest);
    _server = await shelf_io.serve(handler, 'localhost', _port);
    print('✓ Локальний сервер запущений на http://localhost:$_port');
  }

  static Future<void> stopServer() async {
    if (_server != null) {
      await _server!.close(force: true);
      _server = null;
      print('✓ Локальний сервер зупинений');
    }
  }

  static String get baseUrl => 'http://localhost:$_port';

  static Response _handleRequest(Request request) {
    final path = request.url.path;

    if (path == '/' || path.isEmpty) {
      return Response.ok(
        '<html><body>Локальний сервер Jitsi конференцій</body></html>',
        headers: {'Content-Type': 'text/html; charset=utf-8'},
      );
    }

    if (path == '/conference') {
      final htmlContent = request.url.queryParameters['html'];
      if (htmlContent != null) {
        return Response.ok(
          htmlContent,
          headers: {'Content-Type': 'text/html; charset=utf-8'},
        );
      }
    }

    return Response.notFound('Not found: $path');
  }
}
