import 'dart:async';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:dramabox_free/core/constants/app_enums.dart';
import 'package:dramabox_free/core/localization/app_localizations.dart';
import 'package:dramabox_free/core/di/injection_container.dart';
import 'package:dramabox_free/core/services/cover_match_service.dart';
import 'package:dramabox_free/data/models/drama_model.dart';
import 'package:dramabox_free/data/models/download_item.dart';
import 'package:dramabox_free/data/models/episode_model.dart';
import 'package:dramabox_free/data/models/favorite_model.dart';
import 'package:dramabox_free/domain/repositories/drama_repository.dart';
import 'package:dramabox_free/presentation/blocs/downloads_bloc.dart';
import 'package:dramabox_free/presentation/blocs/favorites_bloc.dart';
import 'package:dramabox_free/presentation/cubits/similar_section_cubit.dart';
import 'package:dramabox_free/presentation/pages/player_page.dart';
import 'package:dramabox_free/presentation/widgets/drama_card.dart';

class DramaDetailPage extends StatefulWidget {
  final DramaModel drama;
  final AppContentProvider provider;

  /// The narto platform key (bibishort, dramabox, ...) this drama belongs to.
  final String nartoProviderKey;
  final int? startIndex;

  const DramaDetailPage({
    super.key,
    required this.drama,
    this.provider = AppContentProvider.narto,
    this.nartoProviderKey = '',
    this.startIndex,
  });

  @override
  State<DramaDetailPage> createState() => _DramaDetailPageState();
}

class _DramaDetailPageState extends State<DramaDetailPage> {
  late Future<({List<EpisodeModel> episodes, int lastIndex})> _episodesFuture;
  late final Stream<List<DramaModel>> _similarStream;

  @override
  void initState() {
    super.initState();
    _episodesFuture = _load();
    _similarStream = sl<CoverMatchService>().match(
      bookId: widget.drama.bookId,
      coverWap: widget.drama.coverWap,
      excludeProvider: widget.nartoProviderKey,
    );
  }

  Future<({List<EpisodeModel> episodes, int lastIndex})> _load() async {
    final repo = sl<DramaRepository>();
    final episodes = await repo.getDramaEpisodes(
      widget.drama.bookId,
      provider: widget.provider,
    );
    final lastIndex = widget.startIndex ??
        await repo.getLastWatchedIndex(
          widget.drama.bookId,
          provider: widget.provider,
        );
    return (episodes: episodes, lastIndex: lastIndex);
  }

  void _retry() {
    setState(() {
      _episodesFuture = _load();
    });
  }

  bool _isFavorite(List<FavoriteModel> favorites) {
    for (final f in favorites) {
      if (f.drama.bookId == widget.drama.bookId &&
          f.provider == widget.provider) {
        return true;
      }
    }
    return false;
  }

  void _toggleFavorite() {
    context
        .read<FavoritesBloc>()
        .add(
          ToggleFavoriteEvent(
            widget.drama,
            provider: widget.provider,
            nartoProviderKey: widget.nartoProviderKey,
          ),
        );
  }

  Future<void> _openPlayer(int index) async {
    final data = await _episodesFuture;
    final episode = index >= 0 && index < data.episodes.length
        ? data.episodes[index]
        : null;
    if (episode != null && !episode.isPlayable) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
        ..clearSnackBars()
        ..showSnackBar(
          SnackBar(
            content: Text(AppStrings.episodeNotAvailable(context)),
            duration: const Duration(seconds: 2),
          ),
        );
      return;
    }
    if (!mounted) return;
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => PlayerPage(
          drama: widget.drama,
          provider: widget.provider,
          nartoProviderKey: widget.nartoProviderKey,
          startIndex: index,
        ),
      ),
    );
  }

  String _downloadId(EpisodeModel episode) {
    return '${widget.drama.bookId}_${episode.chapterId}';
  }

  Widget _buildDownloadControl(
    BuildContext context,
    EpisodeModel episode,
    int index,
  ) {
    final id = _downloadId(episode);
    return BlocBuilder<DownloadsBloc, DownloadsState>(
      builder: (context, state) {
        DownloadItem? item;
        if (state is DownloadsLoaded) {
          for (final i in state.items) {
            if (i.id == id) {
              item = i;
              break;
            }
          }
        }
        return GestureDetector(
          onTap: () => _onDownloadTap(context, item, episode, index),
          child: Container(
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: 0.45),
              shape: BoxShape.circle,
            ),
            child: _downloadIcon(context, item),
          ),
        );
      },
    );
  }

  Widget _downloadIcon(BuildContext context, DownloadItem? item) {
    switch (item?.status) {
      case DownloadStatus.downloading:
        return SizedBox(
          width: 16,
          height: 16,
          child: CircularProgressIndicator(
            strokeWidth: 2,
            value: item!.progress,
            color: Colors.white,
          ),
        );
      case DownloadStatus.completed:
        return const Icon(
          Icons.check_circle,
          size: 16,
          color: Colors.greenAccent,
        );
      case DownloadStatus.paused:
        return const Icon(
          Icons.pause_circle_outline,
          size: 16,
          color: Colors.amber,
        );
      case DownloadStatus.failed:
        return const Icon(
          Icons.error_outline,
          size: 16,
          color: Colors.redAccent,
        );
      case DownloadStatus.queued:
        return const SizedBox(
          width: 16,
          height: 16,
          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
        );
      case null:
        return Icon(
          Icons.download_outlined,
          size: 16,
          color: Colors.white.withValues(alpha: 0.85),
        );
    }
  }

  void _onDownloadTap(
    BuildContext context,
    DownloadItem? item,
    EpisodeModel episode,
    int index,
  ) {
    if (!episode.isPlayable) return;
    final id = _downloadId(episode);
    final status = item?.status;
    if (status == DownloadStatus.downloading) {
      context.read<DownloadsBloc>().add(PauseDownloadEvent(id));
      return;
    }
    if (status == DownloadStatus.paused || status == DownloadStatus.failed) {
      context.read<DownloadsBloc>().add(
        StartDownloadEvent(
          item!.copyWith(status: DownloadStatus.queued),
        ),
      );
      return;
    }
    if (status == DownloadStatus.completed) {
      _confirmDeleteDownload(id);
      return;
    }
    context.read<DownloadsBloc>().add(
      StartDownloadEvent(
        DownloadItem(
          id: id,
          drama: widget.drama,
          episode: episode,
          provider: widget.provider,
          nartoProviderKey: widget.nartoProviderKey,
          status: DownloadStatus.queued,
          episodeNumber: index + 1,
          totalBytes: 0,
          downloadedBytes: 0,
          createdAt: DateTime.now(),
        ),
      ),
    );
  }

  Future<void> _confirmDeleteDownload(String id) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(AppStrings.deleteDownloadConfirm(dialogContext)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: Text(AppStrings.cancel(dialogContext)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: Text(AppStrings.deleteDownload(dialogContext)),
          ),
        ],
      ),
    );
    if (confirmed == true && mounted) {
      context.read<DownloadsBloc>().add(RemoveDownloadEvent(id));
    }
  }

  void _downloadAll(List<EpisodeModel> episodes) {
    final bloc = context.read<DownloadsBloc>();
    var enqueued = 0;
    for (var i = 0; i < episodes.length; i++) {
      final episode = episodes[i];
      if (!episode.isPlayable) continue;
      final id = _downloadId(episode);
      bloc.add(
        StartDownloadEvent(
          DownloadItem(
            id: id,
            drama: widget.drama,
            episode: episode,
            provider: widget.provider,
            nartoProviderKey: widget.nartoProviderKey,
            status: DownloadStatus.queued,
            episodeNumber: i + 1,
            totalBytes: 0,
            downloadedBytes: 0,
            createdAt: DateTime.now(),
          ),
        ),
      );
      enqueued++;
    }
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(AppStrings.downloadsQueued(context, enqueued)),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: scheme.surface,
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            expandedHeight: 300,
            pinned: true,
            stretch: true,
            leading: IconButton(
              icon: const Icon(Icons.arrow_back, color: Colors.white),
              onPressed: () => Navigator.pop(context),
            ),
            actions: [
              BlocBuilder<FavoritesBloc, FavoritesState>(
                builder: (context, state) {
                  final favorite = state is FavoritesLoaded &&
                      _isFavorite(state.favorites);
                  return Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: IconButton(
                      icon: Icon(
                        favorite ? Icons.favorite : Icons.favorite_border,
                        color: favorite
                            ? Colors.redAccent
                            : Colors.white.withValues(alpha: 0.9),
                      ),
                      onPressed: _toggleFavorite,
                    ),
                  );
                },
              ),
              FutureBuilder<({List<EpisodeModel> episodes, int lastIndex})>(
                future: _episodesFuture,
                builder: (context, snapshot) {
                  final episodes = snapshot.data?.episodes ?? const <EpisodeModel>[];
                  if (episodes.isEmpty) return const SizedBox.shrink();
                  return Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: IconButton(
                      tooltip: AppStrings.downloadAllTooltip(context),
                      icon: const Icon(
                        Icons.file_download_outlined,
                        color: Colors.white,
                      ),
                      onPressed: () => _downloadAll(episodes),
                    ),
                  );
                },
              ),
            ],
            flexibleSpace: FlexibleSpaceBar(
              stretchModes: const [StretchMode.zoomBackground],
              background: Stack(
                fit: StackFit.expand,
                children: [
                  CachedNetworkImage(
                    imageUrl: widget.drama.coverWap,
                    fit: BoxFit.cover,
                    errorWidget: (context, url, error) => Container(
                      color: scheme.surfaceContainerHighest,
                      child: Icon(
                        Icons.movie_creation_outlined,
                        size: 64,
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                  ),
                  DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Colors.black.withValues(alpha: 0.15),
                          Colors.transparent,
                          Colors.black.withValues(alpha: 0.85),
                        ],
                        stops: const [0, 0.4, 1],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: CachedNetworkImage(
                          imageUrl: widget.drama.coverWap,
                          width: 96,
                          height: 128,
                          fit: BoxFit.cover,
                          errorWidget: (context, url, error) => Container(
                            width: 96,
                            height: 128,
                            color: scheme.surfaceContainerHighest,
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              widget.drama.bookName,
                              style: TextStyle(
                                color: scheme.onSurface,
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                height: 1.25,
                              ),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              widget.drama.chapterCount > 0
                                  ? AppStrings.episodesCount(
                                      context,
                                      widget.drama.chapterCount,
                                    )
                                  : '',
                              style: TextStyle(
                                color: scheme.onSurfaceVariant,
                                fontSize: 13,
                              ),
                            ),
                            if (widget.drama.protagonist.isNotEmpty) ...[
                              const SizedBox(height: 4),
                              Text(
                                widget.drama.protagonist,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  color: scheme.onSurfaceVariant,
                                  fontSize: 13,
                                ),
                              ),
                            ],
                            const SizedBox(height: 8),
                            Wrap(
                              spacing: 6,
                              runSpacing: 6,
                              children: widget.drama.tags
                                  .take(6)
                                  .map(
                                    (tag) => _TagChip(label: tag),
                                  )
                                  .toList(),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  _buildPlaySection(context, isDark),
                  if (widget.drama.introduction.isNotEmpty) ...[
                    const SizedBox(height: 20),
                    Text(
                      AppStrings.descriptionTab(context),
                      style: TextStyle(
                        color: scheme.onSurfaceVariant,
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 1.2,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      widget.drama.introduction,
                      style: TextStyle(
                        color: scheme.onSurface.withValues(alpha: 0.85),
                        fontSize: 14,
                        height: 1.6,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
              child: Text(
                AppStrings.episodes(context),
                style: TextStyle(
                  color: scheme.onSurface,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
          _buildEpisodesSection(context, isDark),
          BlocBuilder<SimilarSectionCubit, bool>(
            builder: (context, enabled) => enabled
                ? _buildSimilarSection(context)
                : const SliverToBoxAdapter(child: SizedBox.shrink()),
          ),
          const SliverToBoxAdapter(child: SizedBox(height: 24)),
        ],
      ),
    );
  }

  Widget _buildPlaySection(BuildContext context, bool isDark) {
    final scheme = Theme.of(context).colorScheme;
    return FutureBuilder<({List<EpisodeModel> episodes, int lastIndex})>(
      future: _episodesFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return SizedBox(
            height: 52,
            child: Center(
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: scheme.primary,
              ),
            ),
          );
        }
        if (snapshot.hasError) {
          return _ErrorBox(
            message: snapshot.error.toString(),
            onRetry: _retry,
          );
        }
        final data = snapshot.data!;
        if (data.episodes.isEmpty) {
          return _ErrorBox(
            message: AppStrings.serverUnavailable(context),
            onRetry: _retry,
          );
        }
        final lastIndex = data.lastIndex >= 0 ? data.lastIndex : 0;
        return SizedBox(
          width: double.infinity,
          child: ElevatedButton.icon(
            onPressed: () => _openPlayer(lastIndex),
            icon: const Icon(Icons.play_arrow_rounded, size: 26),
            label: Text(
              data.lastIndex >= 0
                  ? '${AppStrings.continueWatching(context)} · EP ${lastIndex + 1}'
                  : AppStrings.play(context),
            ),
          ),
        );
      },
    );
  }

  Widget _buildEpisodesSection(BuildContext context, bool isDark) {
    final scheme = Theme.of(context).colorScheme;
    return FutureBuilder<({List<EpisodeModel> episodes, int lastIndex})>(
      future: _episodesFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const SliverToBoxAdapter(
            child: Padding(
              padding: EdgeInsets.all(32),
              child: Center(
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            ),
          );
        }
        if (snapshot.hasError || snapshot.data!.episodes.isEmpty) {
          return SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Center(
                child: Text(
                  AppStrings.serverUnavailable(context),
                  style: TextStyle(color: scheme.onSurfaceVariant),
                ),
              ),
            ),
          );
        }
        final episodes = snapshot.data!.episodes;
        final lastIndex = snapshot.data!.lastIndex;
        return SliverGrid(
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 4,
            mainAxisSpacing: 10,
            crossAxisSpacing: 10,
            childAspectRatio: 1.4,
          ),
          delegate: SliverChildBuilderDelegate(
            (context, index) {
              final isCurrent = index == lastIndex;
              final episode = episodes[index];
              final isPlayable = episode.isPlayable;
              return GestureDetector(
                onTap: () => _openPlayer(index),
                child: Stack(
                  children: [
                    Positioned.fill(
                      child: Container(
                        decoration: BoxDecoration(
                          color: isCurrent
                              ? scheme.primary.withValues(alpha: 0.18)
                              : isPlayable
                              ? scheme.surfaceContainerHighest
                              : scheme.surfaceContainerHighest.withValues(
                                  alpha: 0.45,
                                ),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: isCurrent
                                ? scheme.primary
                                : Colors.transparent,
                            width: 1.5,
                          ),
                        ),
                        alignment: Alignment.center,
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              AppStrings.ep(context),
                              style: TextStyle(
                                color: scheme.onSurfaceVariant,
                                fontSize: 9,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            Text(
                              '${index + 1}',
                              style: TextStyle(
                                color: isCurrent
                                    ? scheme.primary
                                    : isPlayable
                                    ? scheme.onSurface
                                    : scheme.onSurfaceVariant,
                                fontSize: 14,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            if (isCurrent) ...[
                              const SizedBox(height: 2),
                              Icon(
                                Icons.play_arrow_rounded,
                                size: 12,
                                color: scheme.primary,
                              ),
                            ] else if (!isPlayable) ...[
                              const SizedBox(height: 2),
                              Text(
                                AppStrings.comingSoon(context),
                                style: TextStyle(
                                  color: scheme.onSurfaceVariant,
                                  fontSize: 8,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ),
                    Positioned(
                      top: 4,
                      right: 4,
                      child: isPlayable
                          ? _buildDownloadControl(context, episode, index)
                          : const SizedBox.shrink(),
                    ),
                  ],
                ),
              );
            },
            childCount: episodes.length,
          ),
        );
      },
    );
  }

  Widget _buildSimilarSection(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return StreamBuilder<List<DramaModel>>(
      stream: _similarStream,
      builder: (context, snapshot) {
        final matches = snapshot.data ?? const <DramaModel>[];
        final done = snapshot.connectionState == ConnectionState.done;
        if (done && matches.isEmpty) {
          return const SliverToBoxAdapter(child: SizedBox.shrink());
        }
        return SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  AppStrings.similarOnPlatforms(context),
                  style: TextStyle(
                    color: scheme.onSurface,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 12),
                if (matches.isEmpty)
                  SizedBox(
                    height: 200,
                    child: Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const SizedBox(
                            width: 24,
                            height: 24,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          ),
                          const SizedBox(height: 12),
                          Text(
                            AppStrings.scanningPlatforms(context),
                            style: TextStyle(
                              color: scheme.onSurfaceVariant,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                  )
                else
                  SizedBox(
                    height: 204,
                    child: ListView.separated(
                      scrollDirection: Axis.horizontal,
                      padding: EdgeInsets.zero,
                      itemCount: matches.length,
                      separatorBuilder: (context, index) =>
                          const SizedBox(width: 10),
                      itemBuilder: (context, index) {
                        final drama = matches[index];
                        return SizedBox(
                          width: 110,
                          child: DramaCard(
                            drama: drama,
                            provider: AppContentProvider.narto,
                            nartoProviderKey: drama.nartoProviderKey,
                            showChapterCount: false,
                            hideHotCode: true,
                            onTap: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) => DramaDetailPage(
                                    drama: drama,
                                    provider: AppContentProvider.narto,
                                    nartoProviderKey: drama.nartoProviderKey,
                                  ),
                                ),
                              );
                            },
                          ),
                        );
                      },
                    ),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _TagChip extends StatelessWidget {
  final String label;

  const _TagChip({required this.label});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: isDark
            ? const Color(0xFF232326)
            : const Color(0xFFEFE9DC),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.white12),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: scheme.onSurface,
          fontSize: 11,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }
}

class _ErrorBox extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;

  const _ErrorBox({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          Icon(Icons.error_outline, color: scheme.error, size: 20),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              message,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(color: scheme.onSurface, fontSize: 12),
            ),
          ),
          TextButton(
            onPressed: onRetry,
            child: Text(AppStrings.retry(context)),
          ),
        ],
      ),
    );
  }
}
