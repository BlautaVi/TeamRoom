import 'package:file_picker/file_picker.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:io';

class PCloudService {
  final String _apiBaseUrl = "https://team-room-back.onrender.com/api";

  Future<String> uploadFileAndGetPublicLink({
    required PlatformFile file,
    required String authToken,
    required String purpose,
  }) async {
    final uploadLinkData = await _getUploadLink(authToken, purpose);
    final uploadUrl = uploadLinkData['link'];
    if (uploadUrl == null) {
      throw Exception("Сервер не повернув посилання для завантаження.");
    }

    final fileId = await _uploadFileToCloud(uploadUrl, file);
    if (fileId == null) {
      throw Exception("Не вдалося отримати fileId після завантаження на PCloud.");
    }

    final publicLink = await _getPublicLink(authToken, fileId);
    if (publicLink == null) {
      throw Exception("Не вдалося отримати публічне посилання від сервера.");
    }

    return publicLink;
  }

  Future<Map<String, dynamic>> _getUploadLink(String token, String purpose) async {
    final uri = Uri.parse('$_apiBaseUrl/cloud-storage/get-upload-link?purpose=$purpose');
    final response = await http.get(uri, headers: {'Authorization': 'Bearer $token'});
    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    }
    throw Exception('Не вдалося отримати посилання для завантаження від сервера.');
  }

  Future<String?> _uploadFileToCloud(String uploadUrl, PlatformFile file) async {
    final request = http.MultipartRequest('POST', Uri.parse(uploadUrl));
    request.files.add(await http.MultipartFile.fromPath('file', file.path!, filename: file.name));
    final streamedResponse = await request.send();
    final response = await http.Response.fromStream(streamedResponse);

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      if (data['metadata'] is List && (data['metadata'] as List).isNotEmpty) {
        return (data['metadata'][0]['fileid']).toString();
      }
    }
    throw Exception('Помилка завантаження файлу на PCloud.');
  }

  Future<String?> _getPublicLink(String token, String fileId) async {
    final uri = Uri.parse('$_apiBaseUrl/cloud-storage/get-public-link?fileid=$fileId');
    final response = await http.get(uri, headers: {'Authorization': 'Bearer $token'});
    if (response.statusCode == 200) {
      return jsonDecode(response.body)['link'];
    }
    throw Exception('Не вдалося отримати публічне посилання від сервера.');
  }
}