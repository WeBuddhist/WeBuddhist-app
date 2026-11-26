import 'package:flutter/material.dart';
import 'package:flutter_pecha/core/theme/app_colors.dart';
import 'package:flutter_pecha/features/home/domain/entities/verse_of_day.dart';
import 'package:flutter_pecha/features/home/presentation/widgets/verse_of_day_card.dart';

/// The verse-of-the-day week: newest (today) first, swipe left for older
/// days, with a page indicator under the cards.
class VerseOfDayCarousel extends StatefulWidget {
  const VerseOfDayCarousel({super.key, required this.verses, this.now});

  /// Newest first.
  final List<VerseOfDay> verses;

  /// Pins "today" for the date pills; the device clock when null.
  final DateTime? now;

  @override
  State<VerseOfDayCarousel> createState() => _VerseOfDayCarouselState();
}

class _VerseOfDayCarouselState extends State<VerseOfDayCarousel> {
  final _controller = PageController();
  int _page = 0;

  @override
  void didUpdateWidget(VerseOfDayCarousel oldWidget) {
    super.didUpdateWidget(oldWidget);
    final target = verseCarouselPageAfterUpdate(
      oldIds: [for (final verse in oldWidget.verses) verse.id],
      newIds: [for (final verse in widget.verses) verse.id],
      page: _page,
    );
    if (target != _page) {
      _page = target;
      if (_controller.hasClients) _controller.jumpToPage(target);
    }
  }

  /// Lets a card (and its kept-alive state) follow its verse when the week
  /// shifts, instead of being rebuilt for whichever verse took its index.
  int? _indexOfKey(Key key) {
    if (key is! ValueKey<String>) return null;
    final index = widget.verses.indexWhere((verse) => verse.id == key.value);
    return index < 0 ? null : index;
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final verses = widget.verses;
    if (verses.isEmpty) return const SizedBox.shrink();

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          height: verseOfDayCardHeight,
          child: PageView.builder(
            controller: _controller,
            itemCount: verses.length,
            onPageChanged: (page) => setState(() => _page = page),
            findChildIndexCallback: _indexOfKey,
            itemBuilder:
                (context, index) => _KeepAlive(
                  key: ValueKey(verses[index].id),
                  child: VerseOfDayCard(
                    verseOfDay: verses[index],
                    now: widget.now,
                  ),
                ),
          ),
        ),
        if (verses.length > 1) ...[
          const SizedBox(height: 10),
          VerseOfDayPageDots(count: verses.length, current: _page),
        ],
      ],
    );
  }
}

/// The page to show after the week changes under the carousel. A refresh can
/// shorten the week (a day turned out empty) or move it on a day, which
/// shifts every verse's index: stay on the verse that was showing, and when
/// it is gone, on the same index kept in range.
@visibleForTesting
int verseCarouselPageAfterUpdate({
  required List<String> oldIds,
  required List<String> newIds,
  required int page,
}) {
  if (newIds.isEmpty) return 0;
  final shown = page < oldIds.length ? newIds.indexOf(oldIds[page]) : -1;
  return shown >= 0 ? shown : page.clamp(0, newIds.length - 1);
}

/// Keeps a swiped-away card (and its like / comment counts) alive, so going
/// back doesn't reload them. Seven cards at most.
class _KeepAlive extends StatefulWidget {
  const _KeepAlive({super.key, required this.child});

  final Widget child;

  @override
  State<_KeepAlive> createState() => _KeepAliveState();
}

class _KeepAliveState extends State<_KeepAlive>
    with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return widget.child;
  }
}

/// Small dots with the current page drawn as a wider pill.
class VerseOfDayPageDots extends StatelessWidget {
  const VerseOfDayPageDots({
    super.key,
    required this.count,
    required this.current,
  });

  final int count;
  final int current;

  static const _size = 6.0;
  static const _activeWidth = 18.0;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final active = isDark ? AppColors.grey400 : AppColors.grey800;
    final inactive = isDark ? AppColors.grey900 : AppColors.grey300;

    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        for (var i = 0; i < count; i++)
          AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            curve: Curves.easeOut,
            margin: const EdgeInsets.symmetric(horizontal: 3),
            width: i == current ? _activeWidth : _size,
            height: _size,
            decoration: BoxDecoration(
              color: i == current ? active : inactive,
              borderRadius: BorderRadius.circular(_size / 2),
            ),
          ),
      ],
    );
  }
}
