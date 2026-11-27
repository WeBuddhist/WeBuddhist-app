import 'package:flutter/material.dart';
import 'package:flutter_pecha/core/constants/app_assets.dart';
import 'package:flutter_pecha/core/extensions/context_ext.dart';
import 'package:flutter_pecha/core/theme/app_colors.dart';
import 'package:flutter_pecha/core/widgets/cached_network_image_widget.dart';
import 'package:flutter_pecha/features/practice/data/models/my_recitation_collection_models.dart';
import 'package:flutter_pecha/features/practice/presentation/providers/my_recitation_collections_providers.dart';
import 'package:flutter_pecha/features/practice/presentation/widgets/chants/chant_book_colors.dart';
import 'package:flutter_pecha/features/recitation/data/models/recitation_model.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// What the user picked in the Add to chant book sheet.
sealed class AddToChantBookChoice {
  const AddToChantBookChoice();
}

/// "New chant book": name a new book that starts with the chant.
class NewChantBookChoice extends AddToChantBookChoice {
  const NewChantBookChoice();
}

/// One of the user's books, to add the chant to.
class ExistingChantBookChoice extends AddToChantBookChoice {
  const ExistingChantBookChoice(this.book);

  final MyRecitationCollectionModel book;
}

/// Shows the Add to chant book sheet for [chant]; resolves to the user's
/// pick, or null when closed.
Future<AddToChantBookChoice?> showAddToChantBookSheet(
  BuildContext context, {
  required RecitationModel chant,
}) {
  return showModalBottomSheet<AddToChantBookChoice>(
    context: context,
    useRootNavigator: true,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => AddToChantBookSheet(chant: chant),
  );
}

/// The chant's title, a "New chant book" row, then the user's own chant
/// books. A book that already holds the chant is dimmed and can't be picked.
class AddToChantBookSheet extends ConsumerWidget {
  const AddToChantBookSheet({super.key, required this.chant});

  final RecitationModel chant;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final l10n = context.l10n;
    final titleColor =
        isDark ? AppColors.textPrimaryDark : AppColors.textPrimary;
    final secondary = ChantBookColors.secondaryText(isDark);
    final books = ref.watch(ownChantBooksProvider);
    final maxHeight = MediaQuery.sizeOf(context).height * 0.8;

    return ConstrainedBox(
      constraints: BoxConstraints(maxHeight: maxHeight),
      child: ClipRRect(
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        child: ColoredBox(
          color: ChantBookColors.sheet(isDark),
          child: SafeArea(
            top: false,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _SheetHeader(
                  title: l10n.chant_book_add_to,
                  isDark: isDark,
                  titleColor: titleColor,
                ),
                Flexible(
                  child: ListView(
                    shrinkWrap: true,
                    padding: const EdgeInsets.fromLTRB(20, 14, 20, 16),
                    children: [
                      Text(
                        chant.title,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          color: titleColor,
                        ),
                      ),
                      const SizedBox(height: 12),
                      _NewChantBookRow(
                        isDark: isDark,
                        titleColor: titleColor,
                        onTap:
                            () => Navigator.of(
                              context,
                            ).pop(const NewChantBookChoice()),
                      ),
                      ...books.when(
                        data:
                            (either) => either.fold(
                              (_) => const <Widget>[],
                              (list) => [
                                if (list.isNotEmpty) ...[
                                  const SizedBox(height: 16),
                                  Text(
                                    l10n.chant_book_your_books,
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: secondary,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                ],
                                for (final book in list)
                                  _ExistingChantBookRow(
                                    book: book,
                                    textId: chant.textId,
                                    isDark: isDark,
                                    titleColor: titleColor,
                                  ),
                              ],
                            ),
                        loading:
                            () => const [
                              Padding(
                                padding: EdgeInsets.symmetric(vertical: 20),
                                child: Center(
                                  child: SizedBox.square(
                                    dimension: 22,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                    ),
                                  ),
                                ),
                              ),
                            ],
                        // New chant book still works without the list.
                        error: (_, _) => const <Widget>[],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _SheetHeader extends StatelessWidget {
  const _SheetHeader({
    required this.title,
    required this.isDark,
    required this.titleColor,
  });

  final String title;
  final bool isDark;
  final Color titleColor;

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: ChantBookColors.tint(isDark),
      child: Column(
        children: [
          const SizedBox(height: 8),
          Container(
            width: 36,
            height: 4,
            decoration: BoxDecoration(
              color: titleColor.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 4, 8, 4),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    title,
                    style: TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w600,
                      color: titleColor,
                    ),
                  ),
                ),
                IconButton(
                  tooltip: context.l10n.close,
                  icon: Icon(AppAssets.x, color: titleColor),
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _NewChantBookRow extends StatelessWidget {
  const _NewChantBookRow({
    required this.isDark,
    required this.titleColor,
    required this.onTap,
  });

  final bool isDark;
  final Color titleColor;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Row(
          children: [
            Container(
              width: 52,
              height: 52,
              decoration: BoxDecoration(
                color: ChantBookColors.tint(isDark),
                borderRadius: BorderRadius.circular(10),
              ),
              alignment: Alignment.center,
              child: Icon(AppAssets.plus, size: 22, color: titleColor),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Text(
                context.l10n.chant_book_new_title,
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w500,
                  color: titleColor,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// One of the user's books. Its detail says whether it already holds the
/// chant; until that loads the row can be picked.
class _ExistingChantBookRow extends ConsumerWidget {
  const _ExistingChantBookRow({
    required this.book,
    required this.textId,
    required this.isDark,
    required this.titleColor,
  });

  final MyRecitationCollectionModel book;
  final String textId;
  final bool isDark;
  final Color titleColor;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final detail = ref
        .watch(myRecitationCollectionDetailProvider(book.id))
        .valueOrNull
        ?.fold((_) => null, (value) => value);
    final hasChant =
        detail?.items.any((item) => item.textId == textId) ?? false;
    final l10n = context.l10n;
    final count = detail?.items.length ?? book.itemCount;

    return Opacity(
      opacity: hasChant ? 0.4 : 1,
      child: InkWell(
        onTap:
            hasChant
                ? null
                : () =>
                    Navigator.of(context).pop(ExistingChantBookChoice(book)),
        borderRadius: BorderRadius.circular(10),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 6),
          child: Row(
            children: [
              CachedNetworkImageWidget(
                imageUrl: book.imgUrl,
                fallbackAsset: AppAssets.myCollectionDefault,
                width: 44,
                height: 44,
                borderRadius: BorderRadius.circular(8),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      book.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: titleColor,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${l10n.my_recitation_collection_chant_count(count)}'
                      ' · ${l10n.chant_book_only_you}',
                      style: TextStyle(
                        fontSize: 12,
                        color: ChantBookColors.secondaryText(isDark),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
