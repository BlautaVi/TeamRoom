import 'package:file_picker/file_picker.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

class PCloudService {
  final String _apiBaseUrl = "http://localhost:8080/api";

  Future<String?> getDirectImageUrl(String publicUrl) async {
    try {
      final uri = Uri.parse(publicUrl);
      final code = uri.queryParameters['code'];
      if (code == null) {
        print("PCloud URL не містить 'code': $publicUrl");
        return null;
      }

      String apiHost = (uri.host == 'e.pcloud.link')
          ? 'eapi.pcloud.com'
          : 'api.pcloud.com';

      final apiUrl = Uri.https(apiHost, '/getpublinkdownload', {'code': code});
      final apiResponse = await http.get(apiUrl);

      if (apiResponse.statusCode == 200) {
        final jsonResponse = jsonDecode(apiResponse.body);
        if (jsonResponse['result'] == 0) {
          final path = jsonResponse['path'] as String?;
          final hosts = (jsonResponse['hosts'] as List?) ?? [];
          if (hosts.isNotEmpty && path != null) {
            return 'https://${hosts.first}$path';
          }
        } else {
          print("PCloud API error: ${jsonResponse['error']}");
        }
      }
    } catch (e) {
      print("Помилка обробки URL $publicUrl: $e");
    }
    return null;
  }

  Future<String> uploadFileAndGetPublicLink({
    required PlatformFile file,
    required String authToken,
    required String purpose,
  }) async {
    final uploadLinkData = await _getUploadLink(authToken, purpose);
    String? uploadUrl = uploadLinkData['link'];

    if (uploadUrl == null) {
      throw Exception("Сервер не повернув посилання для завантаження.");
    }
    if (uploadUrl.contains("&path=null")) {
      print("--- WARNING: Backend returned 'path=null'. Fixing in client...");
      uploadUrl = uploadUrl.replaceAll("&path=null", "&folderid=0");
      print("--- Fixed URL for upload: $uploadUrl");
    }
    final fileId = await _uploadFileToCloud(uploadUrl, file);
    if (fileId == null) {
      throw Exception(
        "Не вдалося отримати fileId після завантаження на PCloud.",
      );
    }

    final publicLink = await _getPublicLink(authToken, fileId);

    if (publicLink == null) {
      throw Exception("Не вдалося отримати публічне посилання від сервера.");
    }

    return publicLink;
  }

  Future<Map<String, dynamic>> _getUploadLink(
    String token,
    String purpose,
  ) async {
    final uri = Uri.parse(
      '$_apiBaseUrl/cloud-storage/get-upload-link?purpose=$purpose',
    );

    final response = await http.get(
      uri,
      headers: {'Authorization': 'Bearer $token'},
    );

    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    }

    throw Exception(
      'Не вдалося отримати посилання для завантаження від сервера.',
    );
  }

  Future<String?> _uploadFileToCloud(
    String uploadUrl,
    PlatformFile file,
  ) async {
    print("--- Attempting to upload to PCloud URL: $uploadUrl");
    final request = http.MultipartRequest('POST', Uri.parse(uploadUrl));

    if (file.path == null) {
      throw Exception("File path is null, cannot upload.");
    }

    request.files.add(
      await http.MultipartFile.fromPath(
        'file',
        file.path!,
        filename: file.name,
      ),
    );

    http.StreamedResponse streamedResponse;
    try {
      streamedResponse = await request.send();
    } catch (e) {
      print("--- PCloud upload request failed: $e");
      throw Exception('Помилка надсилання запиту на PCloud: $e');
    }

    final response = await http.Response.fromStream(streamedResponse);

    print("--- PCloud upload response status: ${response.statusCode}");
    print("--- PCloud upload response body: ${response.body}");

    if (response.statusCode == 200) {
      try {
        final data = jsonDecode(response.body);

        if (data.containsKey('result') && data['result'] != 0) {
          final pCloudError =
              data['error'] ?? 'Невідома помилка PCloud (result != 0)';
          print("--- PCloud API Error (result != 0): $pCloudError");
          throw Exception('Помилка PCloud API: $pCloudError');
        }

        if (data['metadata'] is List && (data['metadata'] as List).isNotEmpty) {
          final fileIdNum = data['metadata'][0]['fileid'];
          if (fileIdNum != null) {
            print("--- PCloud upload successful, fileId: $fileIdNum");
            return fileIdNum.toString();
          }
        }
        print(
          "--- PCloud upload response structure unexpected (missing metadata or fileid)",
        );
        throw Exception('Не вдалося отримати fileId з відповіді PCloud.');
      } catch (e) {
        print("--- Error processing PCloud response: $e");
        if (e is Exception) {
          rethrow;
        }
        throw Exception('Помилка обробки відповіді від PCloud: $e');
      }
    } else {
      throw Exception(
        'Помилка завантаження файлу на PCloud (Статус: ${response.statusCode}). Відповідь: ${response.body}',
      );
    }
  }

  Future<String?> _getPublicLink(String token, String fileId) async {
    final uri = Uri.parse(
      '$_apiBaseUrl/cloud-storage/get-public-link?fileid=$fileId',
    );

    final response = await http.get(
      uri,
      headers: {'Authorization': 'Bearer $token'},
    );

    if (response.statusCode == 200) {
      return jsonDecode(response.body)['link'];
    }

    throw Exception('Не вдалося отримати публічне посилання від сервера.');
  }
}
