import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../dto/flashcard.dart';

class FlashcardWidget extends StatefulWidget {
  const FlashcardWidget({super.key, required this.card, this.onFaceChanged});

  final FlashcardItem card;
  final ValueChanged<FlashcardFace>? onFaceChanged;

  @override
  State<FlashcardWidget> createState() => _FlashcardWidgetState();
}

class _FlashcardWidgetState extends State<FlashcardWidget>
    with SingleTickerProviderStateMixin {
  late final AnimationController _flipController;
  bool _maskWord = false;
  bool _maskMeaning = false;

  @override
  void initState() {
    super.initState();
    _flipController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 420),
    );
  }

  @override
  void dispose() {
    _flipController.dispose();
    super.dispose();
  }

  Future<void> _toggleFace() async {
    final isFront = _flipController.value < 0.5;
    if (isFront) {
      await _flipController.forward();
      widget.onFaceChanged?.call(FlashcardFace.back);
    } else {
      await _flipController.reverse();
      widget.onFaceChanged?.call(FlashcardFace.front);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _flipController,
      builder: (context, _) {
        final angle = _flipController.value * math.pi;
        final showFront = angle <= math.pi / 2;

        return GestureDetector(
          onTap: _toggleFace,
          child: Transform(
            alignment: Alignment.center,
            transform: Matrix4.identity()
              ..setEntry(3, 2, 0.0011)
              ..rotateY(angle),
            child: showFront
                ? _buildFront(context)
                : Transform(
                    alignment: Alignment.center,
                    transform: Matrix4.identity()..rotateY(math.pi),
                    child: _buildBack(context),
                  ),
          ),
        );
      },
    );
  }

  Widget _buildFront(BuildContext context) {
    return Card(
      elevation: 5,
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Theme.of(context).colorScheme.surface,
              Theme.of(context).colorScheme.surfaceContainerHighest,
            ],
          ),
        ),
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                _MaskToggleChip(
                  label: _maskWord ? '显示单词' : '遮盖单词',
                  active: _maskWord,
                  onTap: () => setState(() => _maskWord = !_maskWord),
                ),
                const SizedBox(width: 8),
                _MaskToggleChip(
                  label: _maskMeaning ? '显示释义' : '遮盖释义',
                  active: _maskMeaning,
                  onTap: () => setState(() => _maskMeaning = !_maskMeaning),
                ),
                const Spacer(),
                if (widget.card.hasAbbreviation)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.primaryContainer,
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Text(
                      widget.card.abbreviation,
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.onPrimaryContainer,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 20),
            Expanded(
              child: GestureDetector(
                onTap: () => setState(() => _maskWord = !_maskWord),
                child: _MaskedContent(
                  isMasked: _maskWord,
                  borderRadius: 12,
                  child: Center(
                    child: Text(
                      widget.card.word,
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                        color: Theme.of(context).colorScheme.onSurface,
                      ),
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 14),
            Expanded(
              child: GestureDetector(
                onTap: () => setState(() => _maskMeaning = !_maskMeaning),
                child: _MaskedContent(
                  isMasked: _maskMeaning,
                  borderRadius: 12,
                  child: Center(
                    child: Text(
                      widget.card.meaning,
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        height: 1.35,
                        color: Theme.of(context).colorScheme.onSurface,
                      ),
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 10),
            Text(
              '点按卡片翻到背面',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
                fontSize: 12,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBack(BuildContext context) {
    return Card(
      elevation: 5,
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Theme.of(context).colorScheme.surfaceContainerHigh,
              Theme.of(context).colorScheme.surfaceContainer,
            ],
          ),
        ),
        child: Center(
          child: Text(
            'Tap to flip',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
        ),
      ),
    );
  }
}

class _MaskedContent extends StatelessWidget {
  const _MaskedContent({
    required this.isMasked,
    required this.borderRadius,
    required this.child,
  });

  final bool isMasked;
  final double borderRadius;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(borderRadius),
      child: Stack(
        fit: StackFit.expand,
        children: [
          AnimatedOpacity(
            opacity: isMasked ? 0.08 : 1,
            duration: const Duration(milliseconds: 220),
            child: child,
          ),
          IgnorePointer(
            child: TweenAnimationBuilder<double>(
              tween: Tween<double>(begin: 0, end: isMasked ? 1 : 0),
              duration: const Duration(milliseconds: 320),
              curve: Curves.easeOutCubic,
              builder: (context, value, _) {
                return Align(
                  alignment: Alignment.centerLeft,
                  child: FractionallySizedBox(
                    widthFactor: value,
                    heightFactor: 1,
                    child: Container(
                      decoration: const BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.centerLeft,
                          end: Alignment.centerRight,
                          colors: [
                            Color(0xF0101010),
                            Color(0xF4141414),
                            Color(0xF01A1A1A),
                            Color(0xF0101010),
                          ],
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _MaskToggleChip extends StatelessWidget {
  const _MaskToggleChip({
    required this.label,
    required this.active,
    required this.onTap,
  });

  final String label;
  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(999),
      child: Ink(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(999),
          color: active
              ? const Color(0xFF101010)
              : Theme.of(context).colorScheme.surfaceContainerHighest,
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: active
                ? Colors.white
                : Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
      ),
    );
  }
}
