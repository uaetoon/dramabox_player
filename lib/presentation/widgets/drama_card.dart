import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:shimmer/shimmer.dart';
import '../../core/localization/app_localizations.dart';
import '../../data/models/drama_model.dart';
import '../../core/constants/app_enums.dart';
import 'platform_badge.dart';

class DramaCard extends StatelessWidget {
  final DramaModel drama;
  final AppContentProvider provider;
  final VoidCallback onTap;
  final bool showChapterCount;
  final Future<int>? lastWatchedFuture;
  final int? lastWatchedIndex;
  final int? watchedPosition;
  final int? totalDuration;
  final bool hideHotCode;
  final bool? isFavorite;
  final VoidCallback? onToggleFavorite;

  /// When set, renders a platform badge overlay on the cover.
  final String nartoProviderKey;

  const DramaCard({
    super.key,
    required this.drama,
    required this.provider,
    required this.onTap,
    this.showChapterCount = true,
    this.lastWatchedFuture,
    this.lastWatchedIndex,
    this.watchedPosition,
    this.totalDuration,
    this.hideHotCode = false,
    this.isFavorite,
    this.onToggleFavorite,
    this.nartoProviderKey = '',
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final hasPlayData =
        drama.hotCode != null &&
        drama.hotCode != '0' &&
        drama.hotCode!.isNotEmpty;

    return GestureDetector(
      onTap: onTap,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Stack(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(14),
                  child: CachedNetworkImage(
                    imageUrl: drama.coverWap,
                    height: double.infinity,
                    width: double.infinity,
                    fit: BoxFit.cover,
                    placeholder: (context, url) => Shimmer.fromColors(
                      baseColor: isDark
                          ? const Color(0xFF232326)
                          : const Color(0xFFE4E1DA),
                      highlightColor: isDark
                          ? const Color(0xFF2E2E33)
                          : const Color(0xFFF0EEE9),
                      child: Container(color: scheme.surface),
                    ),
                    errorWidget: (context, url, error) => Container(
                      color: scheme.surfaceContainerHighest,
                      child: Icon(
                        Icons.movie_creation_outlined,
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                  ),
                ),
                // Favorite toggle (Top Right)
                if (onToggleFavorite != null)
                  Positioned(
                    top: 4,
                    right: 4,
                    child: GestureDetector(
                      onTap: onToggleFavorite,
                      child: Container(
                        padding: const EdgeInsets.all(5),
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.45),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          isFavorite == true
                              ? Icons.favorite
                              : Icons.favorite_border,
                          color: isFavorite == true
                              ? Colors.redAccent
                              : Colors.white,
                          size: 16,
                        ),
                      ),
                    ),
                  ),
                // Episode Info (Top Left)
                if (showChapterCount && drama.chapterCount > 0)
                  Positioned(
                    top: 0,
                    left: 0,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.75),
                        borderRadius: const BorderRadius.only(
                          topLeft: Radius.circular(14),
                          bottomRight: Radius.circular(14),
                        ),
                      ),
                      child: Text(
                        '${drama.chapterCount} ${AppStrings.ep(context)}',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 10,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 0.2,
                        ),
                      ),
                    ),
                  ),
                // View Count & Play Icon (Conditional)
                if (hasPlayData && !hideHotCode)
                  Positioned(
                    bottom: 8,
                    right: 8,
                    child: Row(
                      children: [
                        const Icon(
                          Icons.play_arrow,
                          color: Colors.white,
                          size: 14,
                        ),
                        Text(
                          drama.hotCode!,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                // Platform Badge (Bottom Left)
                if (nartoProviderKey.isNotEmpty)
                  Positioned(
                    bottom: 6,
                    left: 6,
                    child: PlatformBadge(providerKey: nartoProviderKey),
                  ),
                // Last Watched Progress (Bottom Overlay)
                if (lastWatchedIndex != null && lastWatchedIndex! >= 0)
                  _buildProgressBadge(
                    context,
                    lastWatchedIndex!,
                    watchedPosition: watchedPosition,
                    totalDuration: totalDuration,
                  )
                else if (lastWatchedFuture != null)
                  FutureBuilder<int>(
                    future: lastWatchedFuture,
                    builder: (ctx, snapshot) {
                      final index = snapshot.data ?? -1;
                      if (index < 0) return const SizedBox.shrink();
                      return _buildProgressBadge(ctx, index);
                    },
                  ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          SizedBox(
            height: 54,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  drama.bookName,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: scheme.onSurface,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    height: 1.2,
                  ),
                ),
                if (drama.tags.length > 1) ...[
                  const SizedBox(height: 2),
                  Text(
                    drama.tags[1],
                    style: TextStyle(
                      color: scheme.onSurfaceVariant,
                      fontSize: 11,
                      fontWeight: FontWeight.w400,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProgressBadge(
    BuildContext context,
    int index, {
    int? watchedPosition,
    int? totalDuration,
  }) {
    double progress = 0.0;
    bool hasProgressData = false;
    if (watchedPosition != null && totalDuration != null && totalDuration > 0) {
      progress = (watchedPosition / totalDuration).clamp(0.0, 1.0);
      hasProgressData = true;
    }

    return Positioned(
      bottom: 0,
      left: 0,
      right: 0,
      child: ClipRRect(
        borderRadius: const BorderRadius.only(
          bottomLeft: Radius.circular(14),
          bottomRight: Radius.circular(14),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
              color: Colors.amber.withValues(alpha: 0.95),
              child: Text(
                AppStrings.lastWatched(context, index + 1),
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: Colors.black,
                  fontSize: 8.5,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 0.3,
                ),
              ),
            ),
            if (hasProgressData)
              SizedBox(
                height: 3,
                child: LinearProgressIndicator(
                  value: progress,
                  backgroundColor: Colors.black.withValues(alpha: 0.2),
                  valueColor: const AlwaysStoppedAnimation<Color>(Colors.amber),
                  minHeight: 3,
                ),
              ),
          ],
        ),
      ),
    );
  }
}
