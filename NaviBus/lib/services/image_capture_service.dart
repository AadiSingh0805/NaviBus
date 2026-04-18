import 'dart:io';

import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';

class ImageCaptureService {
  ImageCaptureService._();

  static ImageCaptureService? _instance;
  static ImageCaptureService get instance => _instance ??= ImageCaptureService._();

  final ImagePicker _picker = ImagePicker();

  Future<String?> captureFromCamera({
    required String folderName,
    String filePrefix = 'capture',
  }) async {
    final picked = await _picker.pickImage(
      source: ImageSource.camera,
      imageQuality: 85,
      maxWidth: 1920,
    );

    if (picked == null) {
      return null;
    }

    return _storePickedFile(
      picked,
      folderName: folderName,
      filePrefix: filePrefix,
    );
  }

  Future<String?> pickFromGallery({
    required String folderName,
    String filePrefix = 'capture',
  }) async {
    final picked = await _picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 90,
      maxWidth: 1920,
    );

    if (picked == null) {
      return null;
    }

    return _storePickedFile(
      picked,
      folderName: folderName,
      filePrefix: filePrefix,
    );
  }

  Future<String?> _storePickedFile(
    XFile picked, {
    required String folderName,
    required String filePrefix,
  }) async {
    try {
      final appDirectory = await getApplicationDocumentsDirectory();
      final targetDirectory = Directory('${appDirectory.path}/$folderName');
      if (!targetDirectory.existsSync()) {
        await targetDirectory.create(recursive: true);
      }

      final extension = _extractExtension(picked.path);
      final filename = '${filePrefix}_${DateTime.now().millisecondsSinceEpoch}$extension';
      final targetPath = '${targetDirectory.path}/$filename';

      await File(picked.path).copy(targetPath);
      return targetPath;
    } catch (_) {
      return null;
    }
  }

  String _extractExtension(String path) {
    final dotIndex = path.lastIndexOf('.');
    if (dotIndex == -1) {
      return '.jpg';
    }
    return path.substring(dotIndex);
  }
}
