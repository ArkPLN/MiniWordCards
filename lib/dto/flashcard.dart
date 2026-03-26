import 'dictionary.dart';

/// 学习模式
enum FlashcardStudyMode { free, fixedCount }

/// 卡片朝向
enum FlashcardFace { front, back }

/// 单词卡项（用于 UI 展示）
class FlashcardItem {
  final int bookId;
  final int wordId;
  final String word;
  final String meaning;
  final String abbreviation;

  const FlashcardItem({
    required this.bookId,
    required this.wordId,
    required this.word,
    required this.meaning,
    this.abbreviation = '',
  });

  factory FlashcardItem.fromDictionaryWord(DictionaryWord word) {
    return FlashcardItem(
      bookId: word.bookId,
      wordId: word.wordId,
      word: word.word,
      meaning: word.meaning,
      abbreviation: word.abbreviation,
    );
  }

  bool get hasAbbreviation => abbreviation.isNotEmpty;

  String get id => '$bookId-$wordId';
}

/// 单词卡会话配置
class FlashcardSessionConfig {
  final FlashcardStudyMode mode;
  final int fixedCount;

  const FlashcardSessionConfig({required this.mode, this.fixedCount = 20});
}
