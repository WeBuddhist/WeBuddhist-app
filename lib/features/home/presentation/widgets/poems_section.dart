import 'package:flutter/material.dart';
import 'package:flutter_pecha/core/extensions/context_ext.dart';
import 'package:flutter_pecha/core/theme/font_config.dart';
import 'package:flutter_pecha/features/home/presentation/providers/home_poems_preview_provider.dart';
import 'package:flutter_pecha/features/home/presentation/widgets/poems_section_skeleton.dart';
import 'package:flutter_pecha/features/poems/domain/entities/poem.dart';
import 'package:flutter_pecha/features/poems/presentation/widgets/poem_preview_card.dart';
import 'package:flutter_pecha/shared/utils/helper_functions.dart';
import 'package:flutter_pecha/features/home/presentation/utils/home_analytics.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

/// Home's "Poems" row inside the feed: a swipeable row of poem cards with
/// the next card peeking in from the right (#1143 design).
class PoemsSection extends ConsumerWidget {
  const PoemsSection({super.key});

  static const horizontalPadding = 16.0;

  /// Share of the screen width each page takes; the rest shows the next
  /// card.
  static const viewportFraction = 0.88;

  /// Width of one card on a screen [screenWidth] wide: its page less the
  /// gap in front of it.
  static double cardWidthFor(double screenWidth) =>
      screenWidth * viewportFraction - horizontalPadding;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final poemsAsync = ref.watch(homePoemsPreviewProvider);

    return poemsAsync.when(
      data: (poems) {
        if (poems.isEmpty) return const SizedBox.shrink();
        return _PoemsContent(poems: poems);
      },
      loading: () => const PoemsSectionSkeleton(),
      error: (_, __) => const SizedBox.shrink(),
    );
  }
}

/// The section title, shared with [PoemsSectionSkeleton].
class PoemsSectionTitle extends StatelessWidget {
  const PoemsSectionTitle({super.key});

  @override
  Widget build(BuildContext context) {
    final isTibetan = context.isTibetanLocale;
    final fontSize = getLocalizedFontSize(AppTextSize.bodyLarge);
    return Padding(
      padding: EdgeInsets.fromLTRB(
        PoemsSection.horizontalPadding,
        0,
        PoemsSection.horizontalPadding,
        isTibetan ? 16 : 12,
      ),
      child: Text(
        context.l10n.home_poems,
        strutStyle: context.tibetanStrutStyle(fontSize, compact: true),
        style: TextStyle(
          fontSize: fontSize,
          fontWeight: FontWeight.w700,
          height: isTibetan ? AppFontConfig.tibetanCompactLineHeight : 1.2,
          leadingDistribution:
              isTibetan ? AppFontConfig.tibetanLeadingDistribution : null,
        ),
      ),
    );
  }
}

class _PoemsContent extends StatefulWidget {
  const _PoemsContent({required this.poems});

  final List<Poem> poems;

  @override
  State<_PoemsContent> createState() => _PoemsContentState();
}

class _PoemsContentState extends State<_PoemsContent> {
  final _pageController = PageController(
    viewportFraction: PoemsSection.viewportFraction,
  );

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  void _openViewer(
    BuildContext context, {
    required String initialPoemId,
    required int position,
  }) {
    ProviderScope.containerOf(context, listen: false)
        .read(homeAnalyticsProvider)
        .cardTapped(
          section: HomeSection.poems,
          targetId: initialPoemId,
          position: position,
        );
    context.pushNamed('home-poems', extra: {'initialPoemId': initialPoemId});
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const PoemsSectionTitle(),
        LayoutBuilder(
          builder: (context, constraints) {
            final cardWidth = PoemsSection.cardWidthFor(constraints.maxWidth);
            return SizedBox(
              height: PoemPreviewCard.heightFor(
                cardWidth,
                MediaQuery.textScalerOf(context),
              ),
              child: PageView.builder(
                controller: _pageController,
                // Pages start at the left edge, so the next card peeks in.
                padEnds: false,
                itemCount: widget.poems.length,
                itemBuilder:
                    (context, index) => Padding(
                      padding: const EdgeInsets.only(
                        left: PoemsSection.horizontalPadding,
                      ),
                      child: PoemPreviewCard(
                        poem: widget.poems[index],
                        onTap:
                            () => _openViewer(
                              context,
                              initialPoemId: widget.poems[index].id,
                              position: index,
                            ),
                      ),
                    ),
              ),
            );
          },
        ),
      ],
    );
  }
}
