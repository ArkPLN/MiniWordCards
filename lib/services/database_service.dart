import 'dart:io';

import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import '../dto/dictionary.dart';

/// 数据库服务 - 管理词典数据
class DatabaseService {
  static Database? _database;
  static const String _dbName = 'mini_word_cards.db';
  static bool _initialized = false;

  /// 初始化数据库（Windows/Linux 需要 FFI 支持）
  static void _initSqflite() {
    if (_initialized) return;
    _initialized = true;

    // Windows/Linux 使用 sqflite_common_ffi
    if (Platform.isWindows || Platform.isLinux) {
      sqfliteFfiInit();
      databaseFactory = databaseFactoryFfi;
    }
  }

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDatabase();
    return _database!;
  }

  Future<Database> _initDatabase() async {
    _initSqflite();
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, _dbName);

    return await openDatabase(
      path,
      version: 3,
      onCreate: _onCreate,
      onUpgrade: _onUpgrade,
    );
  }

  Future<void> _onCreate(Database db, int version) async {
    // 创建词典书表
    await db.execute('''
      CREATE TABLE dictionary_books (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL,
        url TEXT NOT NULL,
        len INTEGER NOT NULL DEFAULT 0,
        type TEXT NOT NULL DEFAULT 'CSV',
        comment TEXT NOT NULL DEFAULT '',
        addDate TEXT NOT NULL,
        enabled INTEGER NOT NULL DEFAULT 1
      )
    ''');

    // 创建词典单词表（包含缩写字段）
    await db.execute('''
      CREATE TABLE dictionary_words (
        bookId INTEGER NOT NULL,
        wordId INTEGER NOT NULL,
        word TEXT NOT NULL,
        wordLower TEXT NOT NULL,
        abbreviation TEXT NOT NULL DEFAULT '',
        abbreviationLower TEXT NOT NULL DEFAULT '',
        meaning TEXT NOT NULL,
        PRIMARY KEY (bookId, wordId),
        FOREIGN KEY (bookId) REFERENCES dictionary_books(id)
      )
    ''');

    // 创建索引以加速搜索
    await db.execute('CREATE INDEX idx_word ON dictionary_words(word)');
    await db.execute(
      'CREATE INDEX idx_word_lower ON dictionary_words(wordLower)',
    );
    await db.execute(
      'CREATE INDEX idx_abbreviation ON dictionary_words(abbreviation)',
    );
    await db.execute(
      'CREATE INDEX idx_abbreviation_lower ON dictionary_words(abbreviationLower)',
    );
    await db.execute('CREATE INDEX idx_meaning ON dictionary_words(meaning)');
  }

  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 2) {
      // 版本1升级到版本2：添加缩写相关字段
      await db.execute(
        'ALTER TABLE dictionary_words ADD COLUMN wordLower TEXT NOT NULL DEFAULT ""',
      );
      await db.execute(
        'ALTER TABLE dictionary_words ADD COLUMN abbreviation TEXT NOT NULL DEFAULT ""',
      );
      await db.execute(
        'ALTER TABLE dictionary_words ADD COLUMN abbreviationLower TEXT NOT NULL DEFAULT ""',
      );
      await db.execute(
        'CREATE INDEX IF NOT EXISTS idx_word_lower ON dictionary_words(wordLower)',
      );
      await db.execute(
        'CREATE INDEX IF NOT EXISTS idx_abbreviation ON dictionary_words(abbreviation)',
      );
      await db.execute(
        'CREATE INDEX IF NOT EXISTS idx_abbreviation_lower ON dictionary_words(abbreviationLower)',
      );
      await db.execute('UPDATE dictionary_words SET wordLower = LOWER(word)');
    }

    if (oldVersion < 3) {
      // 版本2升级到版本3：添加 enabled 字段
      await db.execute(
        'ALTER TABLE dictionary_books ADD COLUMN enabled INTEGER NOT NULL DEFAULT 1',
      );
    }
  }

  /// 添加词典书
  Future<int> addDictionaryBook(DictionaryBook book) async {
    final db = await database;
    return await db.insert('dictionary_books', book.toMap());
  }

  /// 更新词典书
  Future<void> updateDictionaryBook(DictionaryBook book) async {
    final db = await database;
    await db.update(
      'dictionary_books',
      book.toMap(),
      where: 'id = ?',
      whereArgs: [book.id],
    );
  }

  /// 更新词典书注释
  Future<void> updateBookComment(int bookId, String comment) async {
    final db = await database;
    await db.update(
      'dictionary_books',
      {'comment': comment},
      where: 'id = ?',
      whereArgs: [bookId],
    );
  }

  /// 更新词典书启用状态
  Future<void> updateBookEnabled(int bookId, bool enabled) async {
    final db = await database;
    await db.update(
      'dictionary_books',
      {'enabled': enabled ? 1 : 0},
      where: 'id = ?',
      whereArgs: [bookId],
    );
  }

  /// 添加单词
  Future<void> addWord(DictionaryWord word) async {
    final db = await database;
    await db.insert('dictionary_words', {
      'bookId': word.bookId,
      'wordId': word.wordId,
      'word': word.word,
      'wordLower': word.word.toLowerCase(),
      'abbreviation': word.abbreviation,
      'abbreviationLower': word.abbreviation.toLowerCase(),
      'meaning': word.meaning,
    });
  }

  /// 批量添加单词
  Future<void> addWords(List<DictionaryWord> words) async {
    final db = await database;
    final batch = db.batch();
    for (final word in words) {
      batch.insert('dictionary_words', {
        'bookId': word.bookId,
        'wordId': word.wordId,
        'word': word.word,
        'wordLower': word.word.toLowerCase(),
        'abbreviation': word.abbreviation,
        'abbreviationLower': word.abbreviation.toLowerCase(),
        'meaning': word.meaning,
      });
    }
    await batch.commit(noResult: true);
  }

  Future<int> getNextDictionaryBookId() async {
    final db = await database;
    final result = await db.rawQuery(
      'SELECT MAX(id) AS maxId FROM dictionary_books',
    );
    final maxId = result.first['maxId'] as int?;
    return (maxId ?? 0) + 1;
  }

  /// 获取所有词典书
  Future<List<DictionaryBook>> getAllDictionaryBooks() async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query(
      'dictionary_books',
      orderBy: 'id ASC',
    );
    return maps.map((map) => DictionaryBook.fromMap(map)).toList();
  }

  /// 获取启用的词典书
  Future<List<DictionaryBook>> getEnabledDictionaryBooks() async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query(
      'dictionary_books',
      where: 'enabled = ?',
      whereArgs: [1],
      orderBy: 'id ASC',
    );
    return maps.map((map) => DictionaryBook.fromMap(map)).toList();
  }

  /// 检查词典书是否已存在
  Future<bool> isDictionaryBookExists(String url) async {
    final db = await database;
    final result = await db.query(
      'dictionary_books',
      where: 'url = ?',
      whereArgs: [url],
    );
    return result.isNotEmpty;
  }

  /// 按单词搜索（包含匹配 + 缩写优化）
  Future<List<DictionaryWord>> searchByWord(String keyword) async {
    final db = await database;
    final keywordLower = keyword.toLowerCase();
    final isAbbreviationSearch = _isAbbreviation(keyword);

    final List<Map<String, dynamic>> maps;

    if (isAbbreviationSearch) {
      maps = await db.rawQuery(
        '''
        SELECT w.* FROM dictionary_words w
        JOIN dictionary_books b ON w.bookId = b.id
        WHERE b.enabled = 1 AND (w.abbreviationLower = ?
           OR w.wordLower LIKE ?
           OR w.wordLower LIKE ?
           OR w.wordLower LIKE ?)
        ORDER BY
          CASE WHEN w.abbreviationLower = ? THEN 0 ELSE 1 END,
          CASE WHEN w.wordLower = ? THEN 0 ELSE 1 END,
          CASE WHEN w.wordLower LIKE ? THEN 0 ELSE 1 END,
          b.id ASC, w.wordId ASC
      ''',
        [
          keywordLower,
          keywordLower,
          '$keywordLower%',
          '%$keywordLower%',
          keywordLower,
          keywordLower,
          '$keywordLower%',
        ],
      );
    } else {
      maps = await db.rawQuery(
        '''
        SELECT w.* FROM dictionary_words w
        JOIN dictionary_books b ON w.bookId = b.id
        WHERE b.enabled = 1 AND (w.wordLower = ?
           OR w.wordLower LIKE ?
           OR w.wordLower LIKE ?
           OR w.abbreviationLower LIKE ?)
        ORDER BY
          CASE WHEN w.wordLower = ? THEN 0 ELSE 1 END,
          CASE WHEN w.wordLower LIKE ? THEN 0 ELSE 1 END,
          b.id ASC, w.wordId ASC
      ''',
        [
          keywordLower,
          '$keywordLower%',
          '%$keywordLower%',
          '%$keywordLower%',
          keywordLower,
          '$keywordLower%',
        ],
      );
    }

    return _mapToWords(maps);
  }

  /// 按释义搜索
  Future<List<DictionaryWord>> searchByMeaning(String keyword) async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.rawQuery(
      '''
      SELECT w.* FROM dictionary_words w
      JOIN dictionary_books b ON w.bookId = b.id
      WHERE b.enabled = 1 AND w.meaning LIKE ?
      ORDER BY b.id ASC, w.wordId ASC
    ''',
      ['%$keyword%'],
    );
    return _mapToWords(maps);
  }

  /// 综合搜索
  Future<List<DictionaryWord>> search(String keyword) async {
    final db = await database;
    final keywordLower = keyword.toLowerCase();
    final isAbbreviationSearch = _isAbbreviation(keyword);

    final List<Map<String, dynamic>> maps;

    if (isAbbreviationSearch) {
      maps = await db.rawQuery(
        '''
        SELECT w.* FROM dictionary_words w
        JOIN dictionary_books b ON w.bookId = b.id
        WHERE b.enabled = 1 AND (w.abbreviationLower = ?
           OR w.wordLower LIKE ?
           OR w.wordLower LIKE ?
           OR w.wordLower LIKE ?
           OR w.meaning LIKE ?)
        ORDER BY
          CASE WHEN w.abbreviationLower = ? THEN 0 ELSE 1 END,
          CASE WHEN w.wordLower = ? THEN 0 ELSE 1 END,
          CASE WHEN w.wordLower LIKE ? THEN 0 ELSE 1 END,
          b.id ASC, w.wordId ASC
      ''',
        [
          keywordLower,
          keywordLower,
          '$keywordLower%',
          '%$keywordLower%',
          '%$keyword%',
          keywordLower,
          keywordLower,
          '$keywordLower%',
        ],
      );
    } else {
      maps = await db.rawQuery(
        '''
        SELECT w.* FROM dictionary_words w
        JOIN dictionary_books b ON w.bookId = b.id
        WHERE b.enabled = 1 AND (w.wordLower = ?
           OR w.wordLower LIKE ?
           OR w.wordLower LIKE ?
           OR w.abbreviationLower LIKE ?
           OR w.meaning LIKE ?)
        ORDER BY
          CASE WHEN w.wordLower = ? THEN 0 ELSE 1 END,
          CASE WHEN w.wordLower LIKE ? THEN 0 ELSE 1 END,
          b.id ASC, w.wordId ASC
      ''',
        [
          keywordLower,
          '$keywordLower%',
          '%$keywordLower%',
          '%$keywordLower%',
          '%$keyword%',
          keywordLower,
          '$keywordLower%',
        ],
      );
    }

    return _mapToWords(maps);
  }

  /// 判断是否为缩写搜索
  bool _isAbbreviation(String keyword) {
    if (keyword.isEmpty) return false;

    if (keyword.toUpperCase() == keyword && keyword.length <= 10) {
      return true;
    }

    final hasUpper = keyword.contains(RegExp(r'[A-Z]'));
    final isShort = keyword.length <= 15;
    final hasSpecialChar = keyword.contains(RegExp(r'[-/]'));

    if (hasUpper && isShort && (keyword.length <= 6 || hasSpecialChar)) {
      return true;
    }

    final lettersOnly = keyword.replaceAll(RegExp(r'[^a-zA-Z]'), '');
    if (lettersOnly.length <= 8 && lettersOnly.length >= 2) {
      return true;
    }

    return false;
  }

  /// 获取词典书信息
  Future<DictionaryBook?> getDictionaryBook(int bookId) async {
    final db = await database;
    final result = await db.query(
      'dictionary_books',
      where: 'id = ?',
      whereArgs: [bookId],
    );
    if (result.isEmpty) return null;
    return DictionaryBook.fromMap(result.first);
  }

  /// 按 URL 获取词典书信息
  Future<DictionaryBook?> getDictionaryBookByUrl(String url) async {
    final db = await database;
    final result = await db.query(
      'dictionary_books',
      where: 'url = ?',
      whereArgs: [url],
      limit: 1,
    );
    if (result.isEmpty) return null;
    return DictionaryBook.fromMap(result.first);
  }

  /// 获取词典书的单词数量
  Future<int> getWordCount(int bookId) async {
    final db = await database;
    final result = await db.rawQuery(
      'SELECT COUNT(*) as count FROM dictionary_words WHERE bookId = ?',
      [bookId],
    );
    return Sqflite.firstIntValue(result) ?? 0;
  }

  /// 获取启用词典中的单词总数
  Future<int> getEnabledWordCount() async {
    final db = await database;
    final result = await db.rawQuery('''
      SELECT COUNT(*) as count FROM dictionary_words w
      JOIN dictionary_books b ON w.bookId = b.id
      WHERE b.enabled = 1
    ''');
    return Sqflite.firstIntValue(result) ?? 0;
  }

  /// 获取词典书的所有单词
  Future<List<DictionaryWord>> getWordsByBookId(int bookId) async {
    final db = await database;
    final maps = await db.query(
      'dictionary_words',
      where: 'bookId = ?',
      whereArgs: [bookId],
      orderBy: 'wordId ASC',
    );
    return _mapToWords(maps);
  }

  /// 获取所有启用词典的单词
  Future<List<DictionaryWord>> getAllEnabledWords() async {
    final db = await database;
    final maps = await db.rawQuery('''
      SELECT w.* FROM dictionary_words w
      JOIN dictionary_books b ON w.bookId = b.id
      WHERE b.enabled = 1
      ORDER BY w.bookId ASC, w.wordId ASC
    ''');
    return _mapToWords(maps);
  }

  /// 分页获取启用词典的单词
  Future<List<DictionaryWord>> getEnabledWordsPaged({
    required int offset,
    required int limit,
  }) async {
    final db = await database;
    final maps = await db.rawQuery(
      '''
      SELECT w.* FROM dictionary_words w
      JOIN dictionary_books b ON w.bookId = b.id
      WHERE b.enabled = 1
      ORDER BY w.bookId ASC, w.wordId ASC
      LIMIT ? OFFSET ?
    ''',
      [limit, offset],
    );
    return _mapToWords(maps);
  }

  /// 删除词典书及其单词
  Future<void> deleteDictionaryBook(int bookId) async {
    final db = await database;
    await db.delete(
      'dictionary_words',
      where: 'bookId = ?',
      whereArgs: [bookId],
    );
    await db.delete('dictionary_books', where: 'id = ?', whereArgs: [bookId]);
  }

  Future<void> clearDictionaryWords() async {
    final db = await database;
    await db.delete('dictionary_words');
  }

  /// 删除数据库（用于重建）
  Future<void> deleteDatabase() async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, _dbName);
    await databaseFactory.deleteDatabase(path);
    _database = null;
  }

  /// 获取数据库路径
  Future<String> getDatabasePath() async {
    final dbPath = await getDatabasesPath();
    return join(dbPath, _dbName);
  }

  /// 获取统计信息
  Future<Map<String, dynamic>> getStatistics() async {
    final db = await database;

    final bookCount =
        Sqflite.firstIntValue(
          await db.rawQuery('SELECT COUNT(*) FROM dictionary_books'),
        ) ??
        0;

    final enabledBookCount =
        Sqflite.firstIntValue(
          await db.rawQuery(
            'SELECT COUNT(*) FROM dictionary_books WHERE enabled = 1',
          ),
        ) ??
        0;

    final wordCount =
        Sqflite.firstIntValue(
          await db.rawQuery('SELECT COUNT(*) FROM dictionary_words'),
        ) ??
        0;

    return {
      'bookCount': bookCount,
      'enabledBookCount': enabledBookCount,
      'wordCount': wordCount,
    };
  }

  List<DictionaryWord> _mapToWords(List<Map<String, dynamic>> maps) {
    return maps.map((map) => DictionaryWord.fromMap(map)).toList();
  }
}
