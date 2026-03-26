// 词典书:每一个导入的文件都是一个独立的词典
class DictionaryBook {
  // 词典书唯一id,递增
  final int id;
  // 词典书名
  final String name;
  // 词典书的文件物理地址
  final String url;
  // 词典书的单词数量
  final int len;
  // 词典书格式类型(暂时仅支持'CSV'和'JSON')
  final String type;
  // 词典书注释
  final String comment;
  // 词典书添加日期
  final String addDate;
  // 是否启用
  final bool enabled;

  DictionaryBook({
    required this.id,
    required this.name,
    required this.url,
    required this.len,
    required this.type,
    required this.comment,
    required this.addDate,
    this.enabled = true,
  });

  /// 复制并修改部分字段
  DictionaryBook copyWith({
    int? id,
    String? name,
    String? url,
    int? len,
    String? type,
    String? comment,
    String? addDate,
    bool? enabled,
  }) {
    return DictionaryBook(
      id: id ?? this.id,
      name: name ?? this.name,
      url: url ?? this.url,
      len: len ?? this.len,
      type: type ?? this.type,
      comment: comment ?? this.comment,
      addDate: addDate ?? this.addDate,
      enabled: enabled ?? this.enabled,
    );
  }

  /// 从 Map 创建
  factory DictionaryBook.fromMap(Map<String, dynamic> map) {
    return DictionaryBook(
      id: map['id'] as int,
      name: map['name'] as String,
      url: map['url'] as String,
      len: map['len'] as int,
      type: map['type'] as String,
      comment: map['comment'] as String? ?? '',
      addDate: map['addDate'] as String,
      enabled: (map['enabled'] as int?) == 1,
    );
  }

  /// 转换为 Map
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'url': url,
      'len': len,
      'type': type,
      'comment': comment,
      'addDate': addDate,
      'enabled': enabled ? 1 : 0,
    };
  }
}

class DictionaryWord {
  // 单词所属词典ID
  final int bookId;
  // 单词在所属词典中的唯一id,递增
  final int wordId;
  // 单词(英文名)
  final String word;
  // 单词含义
  final String meaning;
  // 缩写（可选）
  final String abbreviation;

  DictionaryWord(
    this.bookId,
    this.wordId,
    this.word,
    this.meaning, {
    this.abbreviation = '',
  });

  /// 是否有缩写
  bool get hasAbbreviation => abbreviation.isNotEmpty;

  /// 从 Map 创建
  factory DictionaryWord.fromMap(Map<String, dynamic> map) {
    return DictionaryWord(
      map['bookId'] as int,
      map['wordId'] as int,
      map['word'] as String,
      map['meaning'] as String,
      abbreviation: map['abbreviation'] as String? ?? '',
    );
  }

  /// 转换为 Map
  Map<String, dynamic> toMap() {
    return {
      'bookId': bookId,
      'wordId': wordId,
      'word': word,
      'meaning': meaning,
      'abbreviation': abbreviation,
    };
  }
}
