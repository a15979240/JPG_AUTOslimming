import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:jpg_slimming/models/file_item.dart';

/// 檔案與資料夾選擇服務
class FileService {
  const FileService._();

  /// 選擇多筆 JPG 檔案
  static Future<List<FileItem>> pickJpgFiles() async {
    final result = await FilePicker.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['jpg', 'jpeg'],
      allowMultiple: true,
      dialogTitle: '選擇 JPG 圖片（可多選）',
    );

    if (result == null || result.files.isEmpty) return [];

    final items = <FileItem>[];
    for (final file in result.files) {
      final path = file.path;
      if (path == null) continue;
      final size = await FileItem.fileSizeBytes(path);
      items.add(
        FileItem(
          path: path,
          fileName: file.name,
          originalSizeBytes: size,
        ),
      );
    }
    return items;
  }

  /// 選擇來源資料夾
  static Future<String?> pickSourceFolder() async {
    return FilePicker.getDirectoryPath(
      dialogTitle: '選擇來源資料夾',
    );
  }

  /// 選擇輸出資料夾
  static Future<String?> pickOutputFolder() async {
    return FilePicker.getDirectoryPath(
      dialogTitle: '選擇輸出資料夾',
    );
  }

  /// 掃描資料夾中的所有 JPG 檔案
  static Future<List<FileItem>> scanFolderForJpgs(String folderPath) async {
    final directory = Directory(folderPath);
    if (!await directory.exists()) return [];

    final items = <FileItem>[];
    await for (final entity
        in directory.list(recursive: true, followLinks: false)) {
      if (entity is! File) continue;
      final lower = entity.path.toLowerCase();
      if (!lower.endsWith('.jpg') && !lower.endsWith('.jpeg')) continue;

      final size = await FileItem.fileSizeBytes(entity.path);
      items.add(
        FileItem(
          path: entity.path,
          fileName: entity.uri.pathSegments.last,
          originalSizeBytes: size,
        ),
      );
    }
    return items;
  }
}

