import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../dto/dictionary.dart';
import '../repositories/dictionary_repository.dart';
import '../services/settings_service.dart';
import 'book_detail_page.dart';

/// 单词书管理页面
class BookManagePage extends StatefulWidget {
  const BookManagePage({super.key});

  @override
  State<BookManagePage> createState() => _BookManagePageState();
}

class _BookManagePageState extends State<BookManagePage> {
  final DictionaryRepository _repository = DictionaryRepository();
  List<DictionaryBook> _books = [];
  Map<String, dynamic> _stats = {};
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    try {
      final books = await _repository.getAllDictionaryBooks();
      final stats = await _repository.getStatistics();
      setState(() {
        _books = books;
        _stats = stats;
      });
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _importCsv() async {
    try {
      final bookId = await _repository.pickAndImportCsv();
      if (bookId != null) {
        if (mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(const SnackBar(content: Text('词典导入成功')));
        }
        await _loadData();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('导入失败: $e')));
      }
    }
  }

  Future<void> _toggleEnabled(DictionaryBook book) async {
    await _repository.updateBookEnabled(book.id, !book.enabled);
    await _loadData();
  }

  Future<void> _deleteBook(DictionaryBook book) async {
    // 在 await 之前获取 settings 和 scaffold messenger
    final settings = context.read<SettingsService>();
    final messenger = ScaffoldMessenger.of(context);

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('确认删除'),
        content: Text(
          '确定要删除词典 "${book.name}" 吗？\n这将删除该词典下的所有 ${book.len} 个单词。',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('删除'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      // 记录删除的词典 URL（用于防止默认词典在重建后重新出现）
      await settings.addDeletedDictionaryUrl(book.url);
      await _repository.deleteDictionaryBook(book.id);
      await _loadData();
      if (mounted) {
        messenger.showSnackBar(const SnackBar(content: Text('词典已删除')));
      }
    }
  }

  Future<void> _rebuildDatabase() async {
    // 在 await 之前获取 scaffold messenger
    final messenger = ScaffoldMessenger.of(context);

    final confirmed = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('数据库操作'),
        content: const Text('请选择操作类型：'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, 'cancel'),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, 'clear'),
            style: TextButton.styleFrom(foregroundColor: Colors.orange),
            child: const Text('清空数据库'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, 'rebuild'),
            style: TextButton.styleFrom(foregroundColor: Colors.blue),
            child: const Text('从文件重建'),
          ),
        ],
      ),
    );

    if (confirmed == null || confirmed == 'cancel') return;
    if (!mounted) return;

    if (confirmed == 'clear') {
      // 清空数据库确认
      final confirmClear = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('确认清空'),
          content: const Text('确定要清空数据库吗？\n这将删除所有词典和单词数据，操作不可恢复。'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('取消'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context, true),
              style: TextButton.styleFrom(foregroundColor: Colors.red),
              child: const Text('清空'),
            ),
          ],
        ),
      );

      if (!mounted) return;

      if (confirmClear == true) {
        await _repository.deleteDatabase();
        await _loadData();
        if (mounted) {
          messenger.showSnackBar(const SnackBar(content: Text('数据库已清空')));
        }
      }
    } else if (confirmed == 'rebuild') {
      // 从文件重建
      final confirmRebuild = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('确认重建'),
          content: const Text('确定要从文件重建数据库吗？\n将根据已导入词典的文件重新加载单词数据。'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('取消'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context, true),
              style: TextButton.styleFrom(foregroundColor: Colors.blue),
              child: const Text('重建'),
            ),
          ],
        ),
      );

      if (!mounted) return;

      if (confirmRebuild == true) {
        final result = await _repository.rebuildDatabaseFromFiles();
        await _loadData();

        if (mounted) {
          if (result.hasIssues) {
            _showRebuildResultDialog(result);
          } else {
            messenger.showSnackBar(SnackBar(content: Text(result.summary)));
          }
        }
      }
    }
  }

  void _showRebuildResultDialog(RebuildResult result) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('重建结果'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(result.summary),
              if (result.failedBooks.isNotEmpty) ...[
                const SizedBox(height: 12),
                const Text(
                  '失败词典：',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                ...result.failedBooks.map(
                  (b) => Padding(
                    padding: const EdgeInsets.only(left: 8, top: 4),
                    child: Text(
                      '• $b',
                      style: const TextStyle(color: Colors.red),
                    ),
                  ),
                ),
              ],
              if (result.skippedBooks.isNotEmpty) ...[
                const SizedBox(height: 12),
                const Text(
                  '跳过词典：',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                ...result.skippedBooks.map(
                  (b) => Padding(
                    padding: const EdgeInsets.only(left: 8, top: 4),
                    child: Text(
                      '• $b',
                      style: const TextStyle(color: Colors.orange),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('确定'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('词典管理'),
        actions: [
          PopupMenuButton<String>(
            onSelected: (value) {
              if (value == 'rebuild') {
                _rebuildDatabase();
              }
            },
            itemBuilder: (context) => [
              const PopupMenuItem(
                value: 'rebuild',
                child: ListTile(
                  leading: Icon(Icons.build_outlined),
                  title: Text('数据库操作'),
                  subtitle: Text('清空数据库或从文件重建'),
                ),
              ),
            ],
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _buildBody(),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _importCsv,
        icon: const Icon(Icons.add),
        label: const Text('导入词典'),
      ),
    );
  }

  Widget _buildBody() {
    return Column(
      children: [
        _buildStatsCard(),
        Expanded(
          child: _books.isEmpty
              ? _buildEmptyState()
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: _books.length,
                  itemBuilder: (context, index) =>
                      _buildBookCard(_books[index]),
                ),
        ),
      ],
    );
  }

  Widget _buildStatsCard() {
    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.primaryContainer,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _buildStatItem(
            icon: Icons.book,
            label: '词典总数',
            value: '${_stats['bookCount'] ?? 0}',
          ),
          _buildStatItem(
            icon: Icons.book_online,
            label: '已启用',
            value: '${_stats['enabledBookCount'] ?? 0}',
          ),
          _buildStatItem(
            icon: Icons.text_fields,
            label: '单词总数',
            value: '${_stats['wordCount'] ?? 0}',
          ),
        ],
      ),
    );
  }

  Widget _buildStatItem({
    required IconData icon,
    required String label,
    required String value,
  }) {
    return Column(
      children: [
        Icon(icon, color: Theme.of(context).colorScheme.onPrimaryContainer),
        const SizedBox(height: 4),
        Text(
          value,
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: Theme.of(context).colorScheme.onPrimaryContainer,
          ),
        ),
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            color: Theme.of(context).colorScheme.onPrimaryContainer,
          ),
        ),
      ],
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.book_outlined, size: 64, color: Colors.grey),
          const SizedBox(height: 16),
          const Text(
            '暂无词典',
            style: TextStyle(fontSize: 18, color: Colors.grey),
          ),
          const SizedBox(height: 8),
          TextButton.icon(
            onPressed: _importCsv,
            icon: const Icon(Icons.add),
            label: const Text('导入词典'),
          ),
        ],
      ),
    );
  }

  Widget _buildBookCard(DictionaryBook book) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        onTap: () => _showBookDetail(book),
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Text(
                              book.name,
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(width: 8),
                            if (!book.enabled)
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 6,
                                  vertical: 2,
                                ),
                                decoration: BoxDecoration(
                                  color: Colors.grey.shade300,
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: const Text(
                                  '已禁用',
                                  style: TextStyle(fontSize: 10),
                                ),
                              ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '${book.len} 个单词 · ${book.type}',
                          style: TextStyle(
                            fontSize: 12,
                            color: Theme.of(
                              context,
                            ).colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Switch(
                    value: book.enabled,
                    onChanged: (_) => _toggleEnabled(book),
                  ),
                ],
              ),
              if (book.comment.isNotEmpty) ...[
                const SizedBox(height: 8),
                Text(
                  book.comment,
                  style: TextStyle(
                    fontSize: 13,
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
              const SizedBox(height: 8),
              Row(
                children: [
                  Text(
                    '添加于 ${book.addDate}',
                    style: TextStyle(
                      fontSize: 11,
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const Spacer(),
                  IconButton(
                    icon: const Icon(Icons.edit_outlined, size: 20),
                    onPressed: () => _showBookDetail(book),
                    tooltip: '编辑',
                  ),
                  IconButton(
                    icon: Icon(
                      Icons.delete_outline,
                      size: 20,
                      color: Colors.red.shade400,
                    ),
                    onPressed: () => _deleteBook(book),
                    tooltip: '删除',
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showBookDetail(DictionaryBook book) async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => BookDetailPage(book: book)),
    );
    await _loadData();
  }
}
