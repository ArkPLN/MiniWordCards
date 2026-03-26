import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../dto/dictionary.dart';
import '../repositories/dictionary_repository.dart';
import '../services/settings_service.dart';
import 'book_manage_page.dart';

/// 词典页面
class DictionaryPage extends StatefulWidget {
  const DictionaryPage({super.key});

  @override
  State<DictionaryPage> createState() => _DictionaryPageState();
}

class _DictionaryPageState extends State<DictionaryPage> {
  final DictionaryRepository _repository = DictionaryRepository();
  final TextEditingController _searchController = TextEditingController();

  List<DictionaryWord> _searchResults = [];
  bool _isLoading = false;
  bool _isInitialized = false;
  SearchMode _searchMode = SearchMode.all;

  @override
  void initState() {
    super.initState();
    _initDictionary();
  }

  Future<void> _initDictionary() async {
    setState(() => _isLoading = true);
    try {
      // 获取已删除词典列表
      final settings = context.read<SettingsService>();
      await _repository.initDefaultDictionary(
        deletedUrls: settings.deletedDictionaryUrls,
      );
      setState(() => _isInitialized = true);
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _search(String keyword) async {
    if (keyword.trim().isEmpty) {
      setState(() => _searchResults = []);
      return;
    }

    setState(() => _isLoading = true);
    try {
      final results = switch (_searchMode) {
        SearchMode.word => await _repository.searchByWord(keyword),
        SearchMode.meaning => await _repository.searchByMeaning(keyword),
        SearchMode.all => await _repository.search(keyword),
      };
      setState(() => _searchResults = results);
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _quickImport() async {
    try {
      final bookId = await _repository.pickAndImportCsv();
      if (bookId != null && mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('词典导入成功')));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('导入失败: $e')));
      }
    }
  }

  Future<void> _openBookManage() async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const BookManagePage()),
    );
    // 返回后重新初始化以确保数据同步
    await _initDictionary();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('词典'),
        leading: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              icon: const Icon(Icons.add),
              onPressed: _quickImport,
              tooltip: '导入词典',
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.settings),
            onPressed: _openBookManage,
            tooltip: '词典管理',
          ),
        ],
      ),
      body: Column(
        children: [
          _buildSearchBar(),
          _buildSearchModeSelector(),
          _buildSearchHint(),
          Expanded(child: _buildSearchResults()),
        ],
      ),
    );
  }

  Widget _buildSearchBar() {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: TextField(
        controller: _searchController,
        decoration: InputDecoration(
          hintText: '搜索单词或释义...',
          prefixIcon: const Icon(Icons.search),
          suffixIcon: _searchController.text.isNotEmpty
              ? IconButton(
                  icon: const Icon(Icons.clear),
                  onPressed: () {
                    _searchController.clear();
                    setState(() => _searchResults = []);
                  },
                )
              : null,
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
          filled: true,
        ),
        onChanged: (value) {
          setState(() {});
          _search(value);
        },
      ),
    );
  }

  Widget _buildSearchModeSelector() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: SegmentedButton<SearchMode>(
        segments: const [
          ButtonSegment(
            value: SearchMode.all,
            label: Text('全部'),
            icon: Icon(Icons.search),
          ),
          ButtonSegment(
            value: SearchMode.word,
            label: Text('单词'),
            icon: Icon(Icons.text_fields),
          ),
          ButtonSegment(
            value: SearchMode.meaning,
            label: Text('释义'),
            icon: Icon(Icons.translate),
          ),
        ],
        selected: {_searchMode},
        onSelectionChanged: (Set<SearchMode> selection) {
          setState(() => _searchMode = selection.first);
          if (_searchController.text.isNotEmpty) {
            _search(_searchController.text);
          }
        },
      ),
    );
  }

  Widget _buildSearchHint() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
      child: Row(
        children: [
          Icon(
            Icons.tips_and_updates_outlined,
            size: 16,
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              '支持缩写搜索（如AFM、SEM）和包含匹配',
              style: TextStyle(
                fontSize: 12,
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchResults() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (!_isInitialized) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 16),
            Text('正在初始化词典...'),
          ],
        ),
      );
    }

    if (_searchController.text.isEmpty) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.book_outlined, size: 64, color: Colors.grey),
            SizedBox(height: 16),
            Text('输入关键词搜索', style: TextStyle(fontSize: 16, color: Colors.grey)),
          ],
        ),
      );
    }

    if (_searchResults.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.search_off, size: 64, color: Colors.grey),
            const SizedBox(height: 16),
            Text(
              '未找到 "${_searchController.text}" 的相关结果',
              style: const TextStyle(fontSize: 16, color: Colors.grey),
            ),
          ],
        ),
      );
    }

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Row(
            children: [
              Text(
                '找到 ${_searchResults.length} 个结果',
                style: TextStyle(
                  fontSize: 14,
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            itemCount: _searchResults.length,
            itemBuilder: (context, index) {
              final word = _searchResults[index];
              return _WordCard(word: word, keyword: _searchController.text);
            },
          ),
        ),
      ],
    );
  }
}

/// 搜索模式
enum SearchMode {
  all, // 全部（单词+释义）
  word, // 仅单词
  meaning, // 仅释义
}

/// 单词卡片组件
class _WordCard extends StatelessWidget {
  final DictionaryWord word;
  final String keyword;

  const _WordCard({required this.word, required this.keyword});

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 4),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Wrap(
                    crossAxisAlignment: WrapCrossAlignment.center,
                    spacing: 8,
                    runSpacing: 4,
                    children: [
                      Text(
                        word.word,
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      if (word.hasAbbreviation)
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: Theme.of(
                              context,
                            ).colorScheme.secondaryContainer,
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            word.abbreviation,
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                              color: Theme.of(
                                context,
                              ).colorScheme.onSecondaryContainer,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.primaryContainer,
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    '词典 ${word.bookId}',
                    style: TextStyle(
                      fontSize: 12,
                      color: Theme.of(context).colorScheme.onPrimaryContainer,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            _buildHighlightedMeaning(context),
          ],
        ),
      ),
    );
  }

  Widget _buildHighlightedMeaning(BuildContext context) {
    final meaning = word.meaning;
    final keywordLower = keyword.toLowerCase();

    // 查找关键词在释义中的位置
    final index = meaning.toLowerCase().indexOf(keywordLower);

    if (index == -1) {
      return Text(
        meaning,
        style: TextStyle(
          fontSize: 14,
          color: Theme.of(context).colorScheme.onSurfaceVariant,
        ),
      );
    }

    // 高亮显示关键词
    return Text.rich(
      TextSpan(
        children: [
          TextSpan(
            text: meaning.substring(0, index),
            style: TextStyle(
              fontSize: 14,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
          TextSpan(
            text: meaning.substring(index, index + keyword.length),
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: Theme.of(context).colorScheme.primary,
            ),
          ),
          TextSpan(
            text: meaning.substring(index + keyword.length),
            style: TextStyle(
              fontSize: 14,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}
