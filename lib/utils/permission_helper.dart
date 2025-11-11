import 'package:permission_handler/permission_handler.dart';

class PermissionHelper {
  /// Запитує дозволи на камеру та мікрофон для конференції
  /// Повертає true якщо обидва дозволи надані (або не потрібні на даній платформі)
  static Future<({bool camera, bool microphone})> requestConferencePermissions() async {
    final cameraStatus = await Permission.camera.request();
    final microphoneStatus = await Permission.microphone.request();
    
    return (
      camera: cameraStatus.isGranted,
      microphone: microphoneStatus.isGranted,
    );
  }

  /// Перевіряє статус дозволів без запиту
  static Future<({bool camera, bool microphone})> checkConferencePermissions() async {
    final cameraStatus = await Permission.camera.status;
    final microphoneStatus = await Permission.microphone.status;
    
    return (
      camera: cameraStatus.isGranted,
      microphone: microphoneStatus.isGranted,
    );
  }

  /// Відкриває налаштування програми якщо дозволи заборонені назавжди
  static Future<void> openAppSettings() async {
    await openAppSettings();
  }
}
