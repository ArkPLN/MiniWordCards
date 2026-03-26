import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../dto/dictionary.dart';
import '../repositories/dictionary_repository.dart';
import '../services/settings_service.dart';

/// 词典书详情页面
class BookDetailPage extends StatefulWidget {
  final DictionaryBook book;

  const BookDetailPage({super.key, required this.book});

  @override
  State<BookDetailPage> createState() => _BookDetailPageState();
}

class _BookDetailPageState extends State<BookDetailPage> {
  final DictionaryRepository _repository = DictionaryRepository();
  late TextEditingController _commentController;
  bool _hasChanges = false;

  @override
  void initState() {
    super.initState();
    _commentController = TextEditingController(text: widget.book.comment);
  }

  @override
  void dispose() {
    _commentController.dispose();
    super.dispose();
  }

  Future<void> _saveComment() async {
    if (!_hasChanges) return;
    await _repository.updateBookComment(
      widget.book.id,
      _commentController.text,
    );
    setState(() => _hasChanges = false);
    if (mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('注释已保存')));
    }
  }

  Future<void> _exportBook() async {
    try {
      final path = await _repository.pickAndExportDictionaryBook(
        widget.book.id,
      );
      if (path != null && mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('已导出到: $path')));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('导出失败: $e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.book.name),
        actions: [
          IconButton(
            icon: const Icon(Icons.download),
            onPressed: _exportBook,
            tooltip: '导出',
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _buildInfoCard(),
          const SizedBox(height: 16),
          _buildCommentSection(),
          const SizedBox(height: 16),
          _buildActionButtons(),
        ],
      ),
    );
  }

  Widget _buildInfoCard() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '词典信息',
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
            ),
            const Divider(),
            _buildInfoRow('词典名称', widget.book.name),
            _buildInfoRow('词典ID', '${widget.book.id}'),
            _buildInfoRow('文件类型', widget.book.type),
            _buildInfoRow('单词数量', '${widget.book.len}'),
            _buildInfoRow('添加日期', widget.book.addDate),
            _buildInfoRow('状态', widget.book.enabled ? '已启用' : '已禁用'),
            _buildInfoRow('文件路径', widget.book.url, maxLines: 2),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoRow(String label, String value, {int maxLines = 1}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 80,
            child: Text(
              label,
              style: TextStyle(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(fontWeight: FontWeight.w500),
              maxLines: maxLines,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCommentSection() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(
                  '注释',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const Spacer(),
                if (_hasChanges)
                  TextButton.icon(
                    onPressed: _saveComment,
                    icon: const Icon(Icons.save, size: 18),
                    label: const Text('保存'),
                  ),
              ],
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _commentController,
              maxLines: 3,
              decoration: InputDecoration(
                hintText: '添加注释...',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                filled: true,
              ),
              onChanged: (_) {
                if (!_hasChanges) {
                  setState(() => _hasChanges = true);
                }
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActionButtons() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '操作',
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            ListTile(
              leading: Icon(
                widget.book.enabled ? Icons.toggle_on : Icons.toggle_off,
                color: widget.book.enabled ? Colors.green : Colors.grey,
              ),
              title: Text(widget.book.enabled ? '禁用词典' : '启用词典'),
              subtitle: Text(
                widget.book.enabled ? '禁用后将不会在搜索中显示' : '启用后将在搜索中显示',
              ),
              trailing: Switch(
                value: widget.book.enabled,
                onChanged: (value) async {
                  await _repository.updateBookEnabled(widget.book.id, value);
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text(value ? '词典已启用' : '词典已禁用')),
                    );
                    Navigator.pop(context);
                  }
                },
              ),
            ),
            ListTile(
              leading: const Icon(Icons.download, color: Colors.blue),
              title: const Text('导出词典'),
              subtitle: const Text('导出为 CSV 文件'),
              onTap: _exportBook,
            ),
            ListTile(
              leading: Icon(Icons.delete, color: Colors.red.shade400),
              title: const Text('删除词典'),
              subtitle: const Text('删除此词典及其所有单词'),
              onTap: () => _confirmDelete(),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _confirmDelete() async {
    final settings = context.read<SettingsService>();

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('确认删除'),
        content: Text(
          '确定要删除词典 "${widget.book.name}" 吗？\n这将删除该词典下的所有 ${widget.book.len} 个单词。',
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
      await settings.addDeletedDictionaryUrl(widget.book.url);
      await _repository.deleteDictionaryBook(widget.book.id);
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('词典已删除')));
        Navigator.pop(context);
      }
    }
  }
}
