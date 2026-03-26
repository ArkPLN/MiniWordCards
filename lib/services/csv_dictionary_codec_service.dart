import 'dart:convert';

import '../dto/dictionary.dart';

/// 词典 CSV 编解码服务，仅负责文本和模型之间的转换。
class CsvDictionaryCodecService {
  List<DictionaryWord> parseWords({
    required String csvContent,
    required int bookId,
  }) {
    final lines = const LineSplitter().convert(csvContent);
    if (lines.isEmpty) {
      throw Exception('CSV 文件为空');
    }

    final dataLines = lines
        .skip(1)
        .where((line) => line.trim().isNotEmpty)
        .toList();
    final words = <DictionaryWord>[];

    for (var index = 0; index < dataLines.length; index++) {
      final parts = _parseCsvLine(dataLines[index]);
      if (parts.length < 3) {
        continue;
      }

      final word = parts[1].trim();
      final meaning = parts[2].trim();
      words.add(
        DictionaryWord(
          bookId,
          index + 1,
          word,
          meaning,
          abbreviation: _extractAbbreviation(word, meaning),
        ),
      );
    }

    return words;
  }

  String encodeWords(List<DictionaryWord> words) {
    final buffer = StringBuffer()..writeln('序号,核心词汇,简要解释');

    for (var index = 0; index < words.length; index++) {
      final word = words[index];
      buffer.writeln(
        '${index + 1},${_escapeCsvField(word.word)},${_escapeCsvField(word.meaning)}',
      );
    }

    return buffer.toString();
  }

  String _escapeCsvField(String value) {
    final escaped = value.replaceAll('"', '""');
    if (escaped.contains(',') ||
        escaped.contains('"') ||
        escaped.contains('\n')) {
      return '"$escaped"';
    }
    return escaped;
  }

  String _extractAbbreviation(String word, String meaning) {
    final bracketMatch = RegExp(r'\(([A-Z0-9\-/]+)\)').firstMatch(word);
    if (bracketMatch != null) {
      return bracketMatch.group(1) ?? '';
    }

    if (_isAbbreviationWord(word)) {
      return word;
    }

    final leadingAbbrMatch = RegExp(
      r'^([A-Z][A-Z0-9\-/]{1,10})(?:\s|$)',
    ).firstMatch(word);
    if (leadingAbbrMatch != null) {
      return leadingAbbrMatch.group(1) ?? '';
    }

    final mixedAbbrMatch = RegExp(
      r'^([a-z]?[A-Z][A-Z0-9]{2,10})$',
    ).firstMatch(word);
    if (mixedAbbrMatch != null) {
      return word;
    }

    return '';
  }

  bool _isAbbreviationWord(String word) {
    if (word.isEmpty) {
      return false;
    }

    final upperPattern = RegExp(r'^[A-Z0-9\-/]+$');
    if (upperPattern.hasMatch(word)) {
      return true;
    }

    final mixedPattern = RegExp(r'^[a-z]?[A-Z][A-Z0-9]{2,}$');
    if (mixedPattern.hasMatch(word)) {
      return true;
    }

    if (word.length <= 3 && RegExp(r'\d').hasMatch(word)) {
      return true;
    }

    return false;
  }

  List<String> _parseCsvLine(String line) {
    final result = <String>[];
    var current = StringBuffer();
    var inQuotes = false;

    for (var index = 0; index < line.length; index++) {
      final char = line[index];
      if (char == '"') {
        final isEscapedQuote =
            inQuotes && index + 1 < line.length && line[index + 1] == '"';
        if (isEscapedQuote) {
          current.write('"');
          index++;
        } else {
          inQuotes = !inQuotes;
        }
      } else if (char == ',' && !inQuotes) {
        result.add(current.toString());
        current = StringBuffer();
      } else {
        current.write(char);
      }
    }

    result.add(current.toString());
    return result;
  }
}
