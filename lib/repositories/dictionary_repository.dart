import 'package:path/path.dart' as p;

import '../dto/dictionary.dart';
import '../services/csv_dictionary_codec_service.dart';
import '../services/database_service.dart';
import '../services/deleted_dictionary_store.dart';
import '../services/dictionary_file_service.dart';

/// 词典仓库 - 处理数据导入和查询
class DictionaryRepository {
  DictionaryRepository({
    DatabaseService? databaseService,
    DictionaryFileService? fileService,
    CsvDictionaryCodecService? csvCodecService,
    DeletedDictionaryStore? deletedDictionaryStore,
  }) : _db = databaseService ?? DatabaseService(),
       _fileService = fileService ?? DictionaryFileService(),
       _csvCodecService = csvCodecService ?? CsvDictionaryCodecService(),
       _deletedDictionaryStore =
           deletedDictionaryStore ?? DeletedDictionaryStore();

  final DatabaseService _db;
  final DictionaryFileService _fileService;
  final CsvDictionaryCodecService _csvCodecService;
  final DeletedDictionaryStore _deletedDictionaryStore;

  /// 初始化默认词典
  /// [deletedUrls] 已删除词典的 URL 集合，这些词典不会被自动导入
  Future<void> initDefaultDictionary({Set<String>? deletedUrls}) async {
    const defaultPath = 'lib/data/default.csv';

    final urls = deletedUrls ?? await _deletedDictionaryStore.loadDeletedUrls();

    // 如果默认词典已被删除，则不导入
    if (urls.contains(defaultPath)) {
      return;
    }

    // 检查是否已导入
    if (await _db.isDictionaryBookExists(defaultPath)) {
      return;
    }

    // 导入默认词典
    await importCsvFromAssets(
      assetPath: defaultPath,
      name: '纳米材料词典',
      comment: '纳米生物材料相关术语',
    );
  }

  /// 从 assets 导入 CSV 词典
  Future<int> importCsvFromAssets({
    required String assetPath,
    required String name,
    String comment = '',
  }) async {
    final csvContent = await _fileService.loadAsset(assetPath);
    return await importCsvFromString(
      csvContent: csvContent,
      name: name,
      url: assetPath,
      comment: comment,
    );
  }

  /// 从字符串导入 CSV
  Future<int> importCsvFromString({
    required String csvContent,
    required String name,
    required String url,
    String comment = '',
  }) async {
    final nextId = await _db.getNextDictionaryBookId();
    final words = _csvCodecService.parseWords(
      csvContent: csvContent,
      bookId: nextId,
    );

    // 创建词典书
    final now = DateTime.now();
    final addDate =
        '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';

    final book = DictionaryBook(
      id: nextId,
      name: name,
      url: url,
      len: words.length,
      type: 'CSV',
      comment: comment,
      addDate: addDate,
      enabled: true,
    );

    await _db.addDictionaryBook(book);

    await _db.addWords(words);

    return book.id;
  }

  /// 从文件导入 CSV
  Future<int> importCsvFromFilePath(
    String filePath, {
    String? name,
    String comment = '',
  }) async {
    final csvContent = await _fileService.readFile(filePath);

    return await importCsvFromString(
      csvContent: csvContent,
      name: name ?? p.basenameWithoutExtension(filePath),
      url: filePath,
      comment: comment,
    );
  }

  /// 打开文件选择器导入 CSV
  Future<int?> pickAndImportCsv() async {
    final pickedFile = await _fileService.pickCsvFile();
    if (pickedFile == null) {
      return null;
    }

    return await importCsvFromFilePath(
      pickedFile.path,
      name: pickedFile.basenameWithoutExtension,
    );
  }

  /// 导出词典书为 CSV
  Future<String> exportDictionaryBook(int bookId, {String? outputPath}) async {
    final book = await _db.getDictionaryBook(bookId);
    if (book == null) {
      throw Exception('词典书不存在');
    }

    final words = await _db.getWordsByBookId(bookId);
    final csvContent = _csvCodecService.encodeWords(words);

    // 确定输出路径
    final filePath =
        outputPath ?? await _fileService.pickSaveCsvPath('${book.name}.csv');
    if (filePath == null) {
      throw Exception('导出已取消');
    }

    await _fileService.writeFile(filePath, csvContent);
    return filePath;
  }

  /// 选择保存位置并导出
  Future<String?> pickAndExportDictionaryBook(int bookId) async {
    final book = await _db.getDictionaryBook(bookId);
    if (book == null) {
      throw Exception('词典书不存在');
    }

    final result = await _fileService.pickSaveCsvPath('${book.name}.csv');

    if (result == null) {
      return null;
    }

    return exportDictionaryBook(bookId, outputPath: result);
  }

  // ========== 搜索功能 ==========

  Future<List<DictionaryWord>> searchByWord(String keyword) async {
    if (keyword.trim().isEmpty) return [];
    return _db.searchByWord(keyword.trim());
  }

  Future<List<DictionaryWord>> searchByMeaning(String keyword) async {
    if (keyword.trim().isEmpty) return [];
    return _db.searchByMeaning(keyword.trim());
  }

  Future<List<DictionaryWord>> search(String keyword) async {
    if (keyword.trim().isEmpty) return [];
    return _db.search(keyword.trim());
  }

  // ========== 管理功能 ==========

  Future<List<DictionaryBook>> getAllDictionaryBooks() async {
    return _db.getAllDictionaryBooks();
  }

  Future<DictionaryBook?> getDictionaryBook(int bookId) async {
    return _db.getDictionaryBook(bookId);
  }

  Future<void> updateBookComment(int bookId, String comment) async {
    await _db.updateBookComment(bookId, comment);
  }

  Future<void> updateBookEnabled(int bookId, bool enabled) async {
    await _db.updateBookEnabled(bookId, enabled);
  }

  Future<void> deleteDictionaryBook(int bookId) async {
    await _db.deleteDictionaryBook(bookId);
  }

  /// 记录已删除的词典 URL（供 UI 层调用）
  Future<void> recordDeletedUrl(String url) async {
    await _deletedDictionaryStore.addDeletedUrl(url);
  }

  /// 删除数据库（清空所有数据）
  Future<void> deleteDatabase() async {
    await _db.deleteDatabase();
  }

  /// 重建数据库（根据已导入词典的文件重新导入数据）
  /// 返回重建结果信息
  Future<RebuildResult> rebuildDatabaseFromFiles() async {
    final result = RebuildResult();

    // 1. 获取所有词典书信息
    final books = await _db.getAllDictionaryBooks();
    if (books.isEmpty) {
      // 没有词典，直接清空数据库
      await _db.deleteDatabase();
      return result;
    }

    // 2. 清空单词数据（保留词典书记录）
    await _db.clearDictionaryWords();

    // 3. 遍历每个词典书，尝试重新导入单词
    for (final book in books) {
      try {
        late final String content;
        if (book.url.startsWith('lib/data/')) {
          content = await _fileService.loadAsset(book.url);
        } else {
          if (!await _fileService.exists(book.url)) {
            result.failedBooks.add('${book.name} (文件不存在)');
            result.failedCount++;
            continue;
          }

          content = await _fileService.readFile(book.url);
        }

        if (content.trim().isEmpty) {
          result.failedBooks.add('${book.name} (文件为空)');
          result.failedCount++;
          continue;
        }

        final words = _csvCodecService.parseWords(
          csvContent: content,
          bookId: book.id,
        );
        if (words.isEmpty) {
          result.failedBooks.add('${book.name} (无有效数据)');
          result.failedCount++;
          continue;
        }

        await _db.addWords(words);

        // 更新词典书的单词数量
        await _db.updateDictionaryBook(book.copyWith(len: words.length));
        result.successCount++;
      } catch (e) {
        result.failedBooks.add('${book.name} ($e)');
        result.failedCount++;
      }
    }

    return result;
  }

  /// 清空已删除词典 URL 记录
  Future<void> clearDeletedUrls() async {
    await _deletedDictionaryStore.clearDeletedUrls();
  }

  Future<String> getDatabasePath() async {
    return _db.getDatabasePath();
  }

  Future<Map<String, dynamic>> getStatistics() async {
    return _db.getStatistics();
  }

  Future<int> getWordCount(int bookId) async {
    return _db.getWordCount(bookId);
  }

  Future<List<DictionaryWord>> getAllEnabledWords() async {
    return _db.getAllEnabledWords();
  }

  Future<int> getEnabledWordCount() async {
    return _db.getEnabledWordCount();
  }

  Future<List<DictionaryWord>> getEnabledWordsPaged({
    required int offset,
    required int limit,
  }) async {
    return _db.getEnabledWordsPaged(offset: offset, limit: limit);
  }
}

/// 重建数据库结果
class RebuildResult {
  int successCount = 0;
  int failedCount = 0;
  int skippedCount = 0;
  List<String> failedBooks = [];
  List<String> skippedBooks = [];

  bool get hasIssues => failedCount > 0 || skippedCount > 0;

  String get summary {
    final parts = <String>[];
    parts.add('成功重建 $successCount 个词典');
    if (failedCount > 0) {
      parts.add('$failedCount 个失败');
    }
    if (skippedCount > 0) {
      parts.add('$skippedCount 个跳过');
    }
    return parts.join('，');
  }
}
