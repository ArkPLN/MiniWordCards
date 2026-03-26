import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/services.dart';
import 'package:path/path.dart' as p;

class PickedCsvFile {
  final String path;
  final String name;

  const PickedCsvFile({required this.path, required this.name});

  String get basenameWithoutExtension => p.basenameWithoutExtension(name);
}

/// 文件服务，负责词典导入导出的文件选择和读写。
class DictionaryFileService {
  Future<String> loadAsset(String assetPath) {
    return rootBundle.loadString(assetPath);
  }

  Future<String> readFile(String filePath) {
    return File(filePath).readAsString();
  }

  Future<void> writeFile(String filePath, String content) {
    return File(filePath).writeAsString(content);
  }

  Future<PickedCsvFile?> pickCsvFile() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['csv'],
      allowMultiple: false,
    );

    if (result == null || result.files.isEmpty) {
      return null;
    }

    final file = result.files.first;
    if (file.path == null) {
      throw Exception('无法获取文件路径');
    }

    return PickedCsvFile(path: file.path!, name: file.name);
  }

  Future<String?> pickSaveCsvPath(String fileName) {
    return FilePicker.platform.saveFile(
      dialogTitle: '导出词典',
      fileName: fileName,
      type: FileType.custom,
      allowedExtensions: ['csv'],
    );
  }

  Future<bool> exists(String filePath) {
    return File(filePath).exists();
  }
}
