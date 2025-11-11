import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'chat_models.dart' show Conference, ConferenceRole, ConferenceParticipant;

// Re-export for backward compatibility
export 'chat_models.dart' show Conference, ConferenceRole, ConferenceParticipant;

/// Helper class for JWT decoding and timing calculation
class JwtTimingCalculator {
  /// Decodes JWT payload and calculates the appropriate wait time before joining
  /// Returns the wait time in milliseconds
  static int calculateJwtWaitTime(String jwt) {
    try {
      final parts = jwt.split('.');
      if (parts.length != 3) {
        return 1500; // Default wait if JWT format is invalid
      }

      // Decode the payload (middle part)
      String payload = parts[1];
      // Add padding if needed
      payload = payload.padRight((payload.length + 3) ~/ 4 * 4, '=');
      // Replace URL-safe characters with standard base64 characters
      payload = payload.replaceAll('-', '+').replaceAll('_', '/');

      final decoded = utf8.decode(base64Url.decode(payload));
      final jsonPayload = jsonDecode(decoded) as Map<String, dynamic>;

      final now = DateTime.now().millisecondsSinceEpoch ~/ 1000;
      
      // Check for nbf (not before) or iat (issued at) claim
      final nbfOrIat = (jsonPayload['nbf'] ?? jsonPayload['iat'] ?? now) as int;
      
      // Calculate wait time: difference between token time and now, plus buffer
      final calculatedWait = ((nbfOrIat - now) * 1000 + 500).toInt();
      
      // Ensure minimum 1500ms wait and maximum reasonable wait
      return (calculatedWait).clamp(1500, 30000);
    } catch (e) {
      print('Could not decode JWT timing, using default delay: $e');
      return 1500; // Default safe wait time
    }
  }
}

class ConferenceJoinResponse {
  final String jwt;
  final String roomName;
  final ConferenceRole role;
  final String jitsiServerUrl;

  ConferenceJoinResponse({
    required this.jwt,
    required this.roomName,
    required this.role,
    required this.jitsiServerUrl,
  });

  factory ConferenceJoinResponse.fromJson(Map<String, dynamic> json) {
    return ConferenceJoinResponse(
      jwt: json['jwt'],
      roomName: json['roomName'],
      role: _parseConferenceRole(json['role']),
      jitsiServerUrl: json['jitsiServerUrl'] ?? 'https://team-room-jitsi.duckdns.org',
    );
  }

  static ConferenceRole _parseConferenceRole(String? roleStr) {
    switch (roleStr) {
      case 'MODERATOR':
        return ConferenceRole.MODERATOR;
      case 'MEMBER':
        return ConferenceRole.MEMBER;
      case 'VIEWER':
        return ConferenceRole.VIEWER;
      default:
        return ConferenceRole.UNKNOWN;
    }
  }
}

class ConferenceService {
  static const String _baseUrl = 'https://team-room-jitsi.duckdns.org';

  Future<List<Conference>> getCourseConferences(
    String authToken,
    int courseId,
  ) async {
    try {
      final response = await http.get(
        Uri.parse('$_baseUrl/api/course/$courseId/conferences'),
        headers: {
          'Authorization': 'Bearer $authToken',
          'Content-Type': 'application/json',
        },
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final List<dynamic> data = jsonDecode(response.body);
        return data.map((json) => Conference.fromJson(json)).toList();
      } else if (response.statusCode == 401) {
        throw Exception('Неавторизований');
      } else if (response.statusCode == 403) {
        throw Exception('Доступ заборонено');
      } else if (response.statusCode == 500) {
        String serverMessage = 'Помилка сервера';
        try {
          final error = jsonDecode(utf8.decode(response.bodyBytes));
          if (error is Map && error.containsKey('message')) {
            serverMessage = error['message'];
          }
        } catch (_) {}
        throw Exception('Помилка сервера (500): $serverMessage');
      } else {
        String serverMessage = 'Невідома помилка';
        try {
          final error = jsonDecode(utf8.decode(response.bodyBytes));
          if (error is Map && error.containsKey('message')) {
            serverMessage = error['message'];
          }
        } catch (_) {}
        throw Exception('Помилка завантаження конференцій (${response.statusCode}): $serverMessage');
      }
    } catch (e) {
      throw Exception('Помилка підключення: $e');
    }
  }
  Future<ConferenceJoinResponse> createConference(
      String authToken,
      int courseId,
      String subject,
      ) async {
    try {
      final response = await http.post(
        Uri.parse('$_baseUrl/api/course/$courseId/conferences'),
        headers: {
          'Authorization': 'Bearer $authToken',
          'Content-Type': 'application/json; charset=UTF-8',
        },
        body: jsonEncode({
          'subject': subject,
        }),
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode == 201 || response.statusCode == 200) {
        return ConferenceJoinResponse.fromJson(jsonDecode(utf8.decode(response.bodyBytes)));
      } else if (response.statusCode == 401) {
        throw Exception('Неавторизований');
      } else if (response.statusCode == 403) {
        String serverMessage = response.body;
        try {
          final error = jsonDecode(utf8.decode(response.bodyBytes));
          if (error is Map && error.containsKey('message')) {
            serverMessage = error['message'];
          }
        } catch (_) {
          if (serverMessage.isEmpty) serverMessage = "Немає деталей від сервера";
        }
        throw Exception('Доступ заборонено (403): $serverMessage');
      } else if (response.statusCode == 500) {
        String serverMessage = 'Помилка сервера';
        try {
          final error = jsonDecode(utf8.decode(response.bodyBytes));
          if (error is Map && error.containsKey('message')) {
            serverMessage = error['message'];
          }
        } catch (_) {
          // Пробуємо спарсити як звичайний текст
        }
        throw Exception('Помилка сервера (500): $serverMessage');
      } else {
        String serverMessage = response.body;
        try {
          final error = jsonDecode(utf8.decode(response.bodyBytes));
          if (error is Map && error.containsKey('message')) {
            serverMessage = error['message'];
          }
        } catch (_) {
          if (serverMessage.isEmpty) serverMessage = "Немає деталей від сервера";
        }
        throw Exception('Помилка створення конференції (${response.statusCode}): $serverMessage');
      }
    } catch (e) {
      throw Exception('Помилка підключення: $e');
    }
  }

  Future<Conference> getConferenceDetails(
    String authToken,
    int courseId,
    int conferenceId,
  ) async {
    try {
      final response = await http.get(
        Uri.parse('$_baseUrl/api/course/$courseId/conferences/$conferenceId'),
        headers: {
          'Authorization': 'Bearer $authToken',
          'Content-Type': 'application/json',
        },
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        return Conference.fromJson(jsonDecode(response.body));
      } else if (response.statusCode == 401) {
        throw Exception('Неавторизований');
      } else if (response.statusCode == 404) {
        throw Exception('Конференція не знайдена');
      } else if (response.statusCode == 500) {
        String serverMessage = 'Помилка сервера';
        try {
          final error = jsonDecode(utf8.decode(response.bodyBytes));
          if (error is Map && error.containsKey('message')) {
            serverMessage = error['message'];
          }
        } catch (_) {}
        throw Exception('Помилка сервера (500): $serverMessage');
      } else {
        String serverMessage = 'Невідома помилка';
        try {
          final error = jsonDecode(utf8.decode(response.bodyBytes));
          if (error is Map && error.containsKey('message')) {
            serverMessage = error['message'];
          }
        } catch (_) {}
        throw Exception('Помилка завантаження деталей (${response.statusCode}): $serverMessage');
      }
    } catch (e) {
      throw Exception('Помилка підключення: $e');
    }
  }

  Future<ConferenceJoinResponse> joinConference(
    String authToken,
    int courseId,
    int conferenceId,
  ) async {
    try {
      final response = await http.post(
        Uri.parse('$_baseUrl/api/course/$courseId/conferences/$conferenceId'),
        headers: {
          'Authorization': 'Bearer $authToken',
          'Content-Type': 'application/json; charset=UTF-8',
        },
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        return ConferenceJoinResponse.fromJson(jsonDecode(response.body));
      } else if (response.statusCode == 401) {
        throw Exception('Неавторизований');
      } else if (response.statusCode == 403) {
        String serverMessage = 'Конференція завершена або ви вже в ній';
        try {
          final error = jsonDecode(utf8.decode(response.bodyBytes));
          if (error is Map && error.containsKey('message')) {
            serverMessage = error['message'];
          }
        } catch (_) {}
        throw Exception(serverMessage);
      } else if (response.statusCode == 404) {
        throw Exception('Конференція не знайдена');
      } else if (response.statusCode == 500) {
        String serverMessage = 'Помилка сервера';
        try {
          final error = jsonDecode(utf8.decode(response.bodyBytes));
          if (error is Map && error.containsKey('message')) {
            serverMessage = error['message'];
          }
        } catch (_) {}
        throw Exception('Помилка сервера (500): $serverMessage');
      } else {
        String serverMessage = 'Невідома помилка';
        try {
          final error = jsonDecode(utf8.decode(response.bodyBytes));
          if (error is Map && error.containsKey('message')) {
            serverMessage = error['message'];
          }
        } catch (_) {
          serverMessage = response.body.isEmpty ? serverMessage : response.body;
        }
        throw Exception('Помилка приєднання (${response.statusCode}): $serverMessage');
      }
    } catch (e) {
      throw Exception('Помилка підключення: $e');
    }
  }

  Future<List<ConferenceParticipant>> getConferenceParticipants(
    String authToken,
    int courseId,
    int conferenceId,
  ) async {
    try {
      final response = await http.get(
        Uri.parse('$_baseUrl/api/course/$courseId/conferences/$conferenceId/participants'),
        headers: {
          'Authorization': 'Bearer $authToken',
          'Content-Type': 'application/json',
        },
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final List<dynamic> data = jsonDecode(response.body);
        return data.map((json) => ConferenceParticipant.fromJson(json)).toList();
      } else if (response.statusCode == 401) {
        throw Exception('Неавторизований');
      } else if (response.statusCode == 404) {
        throw Exception('Конференція не знайдена');
      } else {
        throw Exception('Помилка завантаження учасників: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Помилка підключення: $e');
    }
  }

  Future<void> endConference(
    String authToken,
    int courseId,
    int conferenceId,
  ) async {
    try {
      final response = await http.post(
        Uri.parse('$_baseUrl/api/course/$courseId/conferences/$conferenceId/end'),
        headers: {
          'Authorization': 'Bearer $authToken',
          'Content-Type': 'application/json',
        },
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        return;
      } else if (response.statusCode == 401) {
        throw Exception('Неавторизований');
      } else if (response.statusCode == 403) {
        throw Exception('Тільки модератор може завершити конференцію');
      } else if (response.statusCode == 404) {
        throw Exception('Конференція не знайдена');
      } else {
        throw Exception('Помилка завершення конференції: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Помилка підключення: $e');
    }
  }

  /// Generates an HTML page with embedded Jitsi Meet
  String generateJitsiHtml({
  required String jwt,
  required String roomName,
  required String subject,
  required ConferenceRole role,
  String jitsiServerUrl = 'https://team-room-jitsi.duckdns.org',
  bool hasCameraPermission = true,
  bool hasMicrophonePermission = true,
  }) {
  final isViewer = role == ConferenceRole.VIEWER;
  final disableSelfView = isViewer ? 'true' : 'false';
  // Extract domain from URL without trailing slash
  final domain = jitsiServerUrl.replaceAll(RegExp(r'^https?://'), '').replaceAll(RegExp(r'/$'), '');
    
    return '''<!DOCTYPE html>
<html lang="uk">
<head>
  <meta charset="UTF-8">
  <meta name="viewport" content="width=device-width, initial-scale=1.0">
  <title>$subject</title>
  <script src='https://$domain/external_api.js'></script>
  <style>
  * {
  margin: 0;
      padding: 0;
      box-sizing: border-box;
  }
  
  html, body {
  width: 100%;
      height: 100%;
      overflow: hidden;
  }
  
  body {
      font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', 'Roboto', 'Oxygen', 'Ubuntu', 'Cantarell', sans-serif;
      background: #fff;
  }
  
  #jitsi-container {
  width: 100%;
  height: 100%;
      display: flex;
      flex-direction: column;
  }
  
  .loading {
  display: flex;
  align-items: center;
  justify-content: center;
  width: 100%;
  height: 100%;
  background: #f5f5f5;
      font-size: 16px;
          color: #666;
        }
        
      .error {
      display: none;
          align-items: center;
          justify-content: center;
          width: 100%;
      height: 100%;
      background: #fff3cd;
      font-size: 14px;
      color: #856404;
      padding: 20px;
      text-align: center;
  flex-direction: column;
  }
  
  .error.show {
  display: flex;
  }
  </style>
</head>
<body>
  <div id="jitsi-container">
  <div class="loading" id="loading-div">Завантаження конференції...</div>
  <div class="error" id="error-div"></div>
  </div>
  
  <script>
  // Логування інформації про дозволи
  console.log('Camera permission: $hasCameraPermission');
  console.log('Microphone permission: $hasMicrophonePermission');
  console.log('Jitsi Server: https://$domain');
  
  function showError(message) {
  const errorDiv = document.getElementById('error-div');
  const loadingDiv = document.getElementById('loading-div');
  loadingDiv.style.display = 'none';
  errorDiv.textContent = message;
      errorDiv.classList.add('show');
  }
  
  // Check if JitsiMeetExternalAPI is available
  if (typeof JitsiMeetExternalAPI === 'undefined') {
  console.error('JitsiMeetExternalAPI not loaded from https://$domain/external_api.js');
  // Try loading it manually
  const script = document.createElement('script');
  script.src = 'https://$domain/external_api.js';
  script.onload = initializeConference;
  script.onerror = function() {
  console.error('Failed to load external_api.js');
  showError('Не вдалося завантажити конференцію. Перевірте з"єднання з Інтернетом.');
  };
  document.head.appendChild(script);
  } else {
  initializeConference();
  }
  
  function initializeConference() {
  // Запит дозволів браузера на доступ до камери та мікрофону
  async function requestBrowserPermissions() {
  try {
          if ($hasCameraPermission) {
              console.log('Requesting camera access...');
          await navigator.mediaDevices.getUserMedia({ video: true });
          console.log('Camera access granted');
      }
      
      if ($hasMicrophonePermission) {
          console.log('Requesting microphone access...');
          await navigator.mediaDevices.getUserMedia({ audio: true });
              console.log('Microphone access granted');
          }
              
              if ($hasCameraPermission && $hasMicrophonePermission) {
                  console.log('Requesting both camera and microphone...');
                  await navigator.mediaDevices.getUserMedia({ 
                      video: { height: { ideal: 720, max: 720, min: 240 } },
                  audio: true 
              });
              console.log('Both camera and microphone access granted');
          }
      } catch (err) {
          console.error('Permission error:', err);
          // Продовжуємо незалежно від помилки
          }
      }
      
  const options = {
      roomName: '$roomName',
          jwt: '$jwt',
          width: '100%',
          height: '100%',
      parentNode: document.getElementById('jitsi-container'),
          configOverwrite: {
              startWithAudioMuted: ${!hasMicrophonePermission},
              startWithVideoMuted: ${!hasCameraPermission},
          prejoinPageEnabled: true,
              disableSelfView: $disableSelfView,
              subject: '$subject',
              constraints: {
              video: {
                  height: {
                          ideal: 720,
                          max: 720,
                          min: 240
                  }
                  }
              }
          },
      interfaceConfigOverwrite: {
              SHOW_JITSI_WATERMARK: false,
              SHOW_BRAND_WATERMARK: false,
              SHOW_POWERED_BY: false,
          DEFAULT_BACKGROUND: '#ffffff',
      TOOLBAR_ALWAYS_VISIBLE: false,
          INITIAL_TOOLBAR_TIMEOUT: 20000,
              TOOLBAR_TIMEOUT: 5000,
          },
          onload: onJitsiIframeReady,
      };
  
  let api;
      
  function onJitsiIframeReady(jitsiApi) {
      api = jitsiApi;
          api.addEventListener('videoConferenceLeft', onVideoConferenceLeft);
              api.addEventListener('participantJoined', onParticipantJoined);
                api.addEventListener('participantLeft', onParticipantLeft);
                api.addEventListener('readyToClose', onReadyToClose);
                api.addEventListener('audioAvailabilityChanged', onAudioAvailabilityChanged);
                api.addEventListener('videoAvailabilityChanged', onVideoAvailabilityChanged);
            }
            
            function onVideoConferenceLeft() {
                console.log('Video conference left');
                window.location.href = 'about:blank';
            }
            
            function onParticipantJoined(id) {
                console.log('Participant joined:', id);
            }
            
            function onParticipantLeft(id) {
                console.log('Participant left:', id);
            }
            
            function onReadyToClose() {
                console.log('Ready to close');
                window.location.href = 'about:blank';
            }
            
            function onAudioAvailabilityChanged(available) {
                console.log('Audio availability changed:', available);
            }
            
            function onVideoAvailabilityChanged(available) {
                console.log('Video availability changed:', available);
            }
            
            window.addEventListener('beforeunload', function() {
                if (api) {
                    api.dispose();
                }
            });
            
            // Запитуємо дозволи браузера перед ініціалізацією конференції
            requestBrowserPermissions().then(() => {
                console.log('Browser permissions handled');
                api = new JitsiMeetExternalAPI('$domain', options);
            }).catch(err => {
                console.error('Error initializing conference:', err);
                api = new JitsiMeetExternalAPI('$domain', options);
            });
        }
    </script>
</body>
</html>''';
  }
}
