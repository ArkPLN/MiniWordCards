import 'dart:math';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../dto/flashcard.dart';
import '../repositories/dictionary_repository.dart';
import '../services/settings_service.dart';
import 'flashcard_widget.dart';

/// 单词卡页面
class WordCardsPage extends StatefulWidget {
  const WordCardsPage({super.key});

  @override
  State<WordCardsPage> createState() => _WordCardsPageState();
}

class _WordCardsPageState extends State<WordCardsPage> {
  static const int _lazyThreshold = 300;
  static const int _batchSize = 80;
  static const int _prefetchTriggerDistance = 3;

  final DictionaryRepository _repository = DictionaryRepository();
  final PageController _pageController = PageController(viewportFraction: 0.92);
  final Random _random = Random();

  FlashcardSessionConfig _config = const FlashcardSessionConfig(
    mode: FlashcardStudyMode.free,
    fixedCount: 20,
  );

  List<FlashcardItem> _sessionCards = [];
  final Set<int> _visitedIndexes = {};

  int _currentIndex = 0;
  int _totalEnabledWords = 0;
  int _targetSessionCount = 0;
  int _loadedOffset = 0;
  int _sessionRandomSeed = 0;

  bool _lazyLoadOptimizationEnabled = true;
  bool _useLazyLoad = false;
  bool _isLoading = true;
  bool _isLoadingMore = false;
  String? _errorText;

  int _clampInt(int value, int minValue, int maxValue) {
    if (value < minValue) return minValue;
    if (value > maxValue) return maxValue;
    return value;
  }

  @override
  void initState() {
    super.initState();
    _initData();
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  Future<void> _initData() async {
    setState(() {
      _isLoading = true;
      _errorText = null;
    });

    try {
      final settings = context.read<SettingsService>();
      await _repository.initDefaultDictionary(
        deletedUrls: settings.deletedDictionaryUrls,
      );

      final total = await _repository.getEnabledWordCount();
      if (!mounted) return;

      setState(() {
        _totalEnabledWords = total;
        _lazyLoadOptimizationEnabled = settings.enableLazyLoadOptimization;
        _useLazyLoad = _lazyLoadOptimizationEnabled && total > _lazyThreshold;
      });

      await _startSession();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _errorText = '加载单词失败: $e';
      });
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _startSession() async {
    final boundedFixedCount = _clampInt(
      _config.fixedCount,
      1,
      max(1, _totalEnabledWords),
    );
    final targetCount = _config.mode == FlashcardStudyMode.free
        ? _totalEnabledWords
        : boundedFixedCount;
    // Each new session uses a fresh seed so "随机重排" can generate a new order.
    final nextSessionSeed = _random.nextInt(1 << 30);

    setState(() {
      _targetSessionCount = _totalEnabledWords == 0 ? 0 : targetCount;
      _sessionCards = [];
      _currentIndex = 0;
      _loadedOffset = 0;
      _sessionRandomSeed = nextSessionSeed;
      _visitedIndexes.clear();
      _errorText = null;
    });

    if (_pageController.hasClients) {
      _pageController.jumpToPage(0);
    }

    if (_targetSessionCount == 0) {
      return;
    }

    if (_useLazyLoad) {
      await _loadMoreCards();
    } else {
      await _loadSessionWithoutLazy();
    }
  }

  Future<void> _loadSessionWithoutLazy() async {
    final words = await _repository.getAllEnabledWords();
    if (!mounted) return;

    final allCards = words.map(FlashcardItem.fromDictionaryWord).toList();
    allCards.shuffle(_random);

    final cards = _config.mode == FlashcardStudyMode.free
        ? allCards
        : allCards.take(_targetSessionCount).toList();

    setState(() {
      _sessionCards = cards;
      _loadedOffset = cards.length;
      if (_sessionCards.isNotEmpty) {
        _visitedIndexes.add(0);
      }
    });
  }

  Future<void> _loadMoreCards() async {
    if (_isLoadingMore) return;
    if (_sessionCards.length >= _targetSessionCount) return;

    setState(() => _isLoadingMore = true);

    try {
      final remaining = _targetSessionCount - _sessionCards.length;
      final limit = min(_batchSize, remaining);

      final words = await _repository.getEnabledWordsPaged(
        offset: _loadedOffset,
        limit: limit,
        randomSeed: _sessionRandomSeed,
      );
      if (!mounted) return;

      final cards = words.map(FlashcardItem.fromDictionaryWord).toList();

      setState(() {
        _sessionCards = [..._sessionCards, ...cards];
        _loadedOffset += cards.length;
        if (_sessionCards.isNotEmpty && _visitedIndexes.isEmpty) {
          _visitedIndexes.add(0);
        }
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _errorText = '懒加载失败: $e');
    } finally {
      if (mounted) {
        setState(() => _isLoadingMore = false);
      }
    }
  }

  Future<void> _maybePrefetchNextBatch(int index) async {
    if (!_useLazyLoad) return;
    if (_isLoadingMore) return;
    if (_sessionCards.length >= _targetSessionCount) return;

    final nearEnd = index >= _sessionCards.length - _prefetchTriggerDistance;
    if (nearEnd) {
      await _loadMoreCards();
    }
  }

  Future<void> _switchMode(FlashcardStudyMode mode) async {
    if (_config.mode == mode) return;
    setState(() {
      _config = FlashcardSessionConfig(
        mode: mode,
        fixedCount: _config.fixedCount,
      );
    });
    await _startSession();
  }

  void _setFixedCount(int value) {
    final maxCount = max(1, _totalEnabledWords);
    final nextValue = _clampInt(value, 1, maxCount);
    setState(() {
      _config = FlashcardSessionConfig(
        mode: _config.mode,
        fixedCount: nextValue,
      );
    });
  }

  Future<void> _onPageChanged(int index) async {
    setState(() {
      _currentIndex = index;
      _visitedIndexes.add(index);
    });
    await _maybePrefetchNextBatch(index);
  }

  Future<void> _showJumpDialog() async {
    if (_config.mode != FlashcardStudyMode.free || _targetSessionCount == 0) {
      return;
    }

    final controller = TextEditingController(text: '${_currentIndex + 1}');
    final target = await showDialog<int>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('跳转到指定卡片'),
        content: TextField(
          controller: controller,
          keyboardType: TextInputType.number,
          decoration: InputDecoration(
            hintText: '输入 1 - $_targetSessionCount',
            border: const OutlineInputBorder(),
          ),
          autofocus: true,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () {
              final value = int.tryParse(controller.text.trim());
              Navigator.pop(context, value);
            },
            child: const Text('跳转'),
          ),
        ],
      ),
    );

    if (!mounted || target == null) return;

    final index = target - 1;
    if (index < 0 || index >= _targetSessionCount) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('请输入 1 - $_targetSessionCount 的数字')),
      );
      return;
    }

    await _jumpToCard(index);
  }

  Future<void> _jumpToCard(int index) async {
    await _ensureLoadedUntil(index);
    if (!mounted) return;
    if (index >= _sessionCards.length) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('目标卡片尚未加载完成，请稍后重试')));
      return;
    }

    if (_pageController.hasClients) {
      _pageController.jumpToPage(index);
      return;
    }
    await _onPageChanged(index);
  }

  Future<void> _ensureLoadedUntil(int index) async {
    if (!_useLazyLoad) return;
    if (index < _sessionCards.length) return;

    // Load additional batches until the target index is available.
    while (mounted &&
        index >= _sessionCards.length &&
        _sessionCards.length < _targetSessionCount) {
      final before = _sessionCards.length;
      await _loadMoreCards();
      if (_sessionCards.length == before) {
        break;
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isFixedMode = _config.mode == FlashcardStudyMode.fixedCount;

    return Scaffold(
      appBar: AppBar(
        leadingWidth: isFixedMode ? 108 : null,
        leading: isFixedMode
            ? Padding(
                padding: const EdgeInsets.only(left: 8, top: 8, bottom: 8),
                child: FilledButton.icon(
                  onPressed: _startSession,
                  icon: const Icon(Icons.play_arrow, size: 16),
                  label: const Text('开始本轮', style: TextStyle(fontSize: 12)),
                  style: FilledButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    visualDensity: VisualDensity.compact,
                  ),
                ),
              )
            : null,
        title: const Text('单词卡'),
        actions: [
          IconButton(
            onPressed: _initData,
            icon: const Icon(Icons.refresh),
            tooltip: '重新加载',
          ),
        ],
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_errorText != null && _sessionCards.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(
            _errorText!,
            style: const TextStyle(color: Colors.red),
            textAlign: TextAlign.center,
          ),
        ),
      );
    }

    if (_totalEnabledWords == 0) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.style_outlined, size: 64, color: Colors.grey),
            const SizedBox(height: 12),
            const Text('暂无可用单词，请先启用词典'),
            const SizedBox(height: 12),
            FilledButton(onPressed: _initData, child: const Text('重新加载')),
          ],
        ),
      );
    }

    return SafeArea(
      child: Column(
        children: [
          _buildModePanel(),
          _buildProgressPanel(),
          if (_totalEnabledWords > _lazyThreshold) _buildLazyHint(),
          Expanded(child: _buildCardsView()),
          if (_isLoadingMore)
            const Padding(
              padding: EdgeInsets.fromLTRB(16, 0, 16, 12),
              child: LinearProgressIndicator(),
            ),
        ],
      ),
    );
  }

  Widget _buildModePanel() {
    final maxCount = max(1, _totalEnabledWords);
    final showFixedControls = _config.mode == FlashcardStudyMode.fixedCount;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SegmentedButton<FlashcardStudyMode>(
            segments: const [
              ButtonSegment(
                value: FlashcardStudyMode.free,
                icon: Icon(Icons.all_inclusive),
                label: Text('自由翻阅'),
              ),
              ButtonSegment(
                value: FlashcardStudyMode.fixedCount,
                icon: Icon(Icons.filter_9_plus),
                label: Text('一次 N 张'),
              ),
            ],
            selected: {_config.mode},
            onSelectionChanged: (value) => _switchMode(value.first),
          ),
          const SizedBox(height: 10),
          if (showFixedControls)
            Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: Theme.of(context).colorScheme.surfaceContainer,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        'N = ${_config.fixedCount}',
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    IconButton(
                      onPressed: _config.fixedCount > 1
                          ? () => _setFixedCount(_config.fixedCount - 1)
                          : null,
                      icon: const Icon(Icons.remove_circle_outline),
                      iconSize: 20,
                      visualDensity: VisualDensity.compact,
                      constraints: const BoxConstraints.tightFor(
                        width: 32,
                        height: 32,
                      ),
                      padding: EdgeInsets.zero,
                      tooltip: '减少',
                    ),
                    IconButton(
                      onPressed: _config.fixedCount < maxCount
                          ? () => _setFixedCount(_config.fixedCount + 1)
                          : null,
                      icon: const Icon(Icons.add_circle_outline),
                      iconSize: 20,
                      visualDensity: VisualDensity.compact,
                      constraints: const BoxConstraints.tightFor(
                        width: 32,
                        height: 32,
                      ),
                      padding: EdgeInsets.zero,
                      tooltip: '增加',
                    ),
                    Text(
                      '上限 $maxCount',
                      style: TextStyle(
                        fontSize: 12,
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          if (!showFixedControls)
            Row(
              children: [
                OutlinedButton.icon(
                  onPressed: _showJumpDialog,
                  icon: const Icon(Icons.pin_outlined),
                  label: const Text('跳转'),
                ),
                const Spacer(),
                TextButton.icon(
                  onPressed: _startSession,
                  icon: const Icon(Icons.shuffle),
                  label: const Text('随机重排'),
                ),
              ],
            ),
        ],
      ),
    );
  }

  Widget _buildProgressPanel() {
    final current = _sessionCards.isEmpty ? 0 : _currentIndex + 1;
    final total = _targetSessionCount;
    final viewed = _clampInt(_visitedIndexes.length, 0, total);
    final isFixedMode = _config.mode == FlashcardStudyMode.fixedCount;
    final isRoundDone = isFixedMode && viewed >= total && total > 0;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surfaceContainer,
          borderRadius: BorderRadius.circular(14),
        ),
        child: Row(
          children: [
            Text('第 $current / $total 张'),
            const SizedBox(width: 18),
            Text('已翻阅: $viewed / $total'),
            const Spacer(),
            if (isRoundDone)
              Text(
                '本轮完成',
                style: TextStyle(
                  color: Theme.of(context).colorScheme.primary,
                  fontWeight: FontWeight.w700,
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildLazyHint() {
    final hint = _lazyLoadOptimizationEnabled
        ? '已启用懒加载（总词数 $_totalEnabledWords，按批次加载）'
        : '已关闭懒加载优化（当前使用一次性加载）';

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
      child: Row(
        children: [
          Icon(
            Icons.speed_outlined,
            size: 16,
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
          const SizedBox(width: 6),
          Text(
            hint,
            style: TextStyle(
              fontSize: 12,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCardsView() {
    if (_sessionCards.isEmpty) {
      return const Center(child: Text('本轮无可用单词卡'));
    }

    return PageView.builder(
      controller: _pageController,
      itemCount: _sessionCards.length,
      onPageChanged: (index) => _onPageChanged(index),
      itemBuilder: (context, index) {
        final card = _sessionCards[index];
        return Padding(
          padding: const EdgeInsets.fromLTRB(6, 8, 6, 22),
          child: Column(
            children: [
              Expanded(
                child: FlashcardWidget(key: ValueKey(card.id), card: card),
              ),
              const SizedBox(height: 8),
              Text(
                '词典 ${card.bookId}',
                style: TextStyle(
                  fontSize: 12,
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
