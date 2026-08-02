import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:dramabox_free/core/localization/app_localizations.dart';
import 'package:dramabox_free/presentation/pages/dramafren_webview_page.dart';
import 'package:dramabox_free/presentation/widgets/drama_card.dart';
import '../../data/models/history_model.dart';
import '../blocs/history_bloc.dart';
import '../pages/drama_detail_page.dart';

class HistoryPage extends StatelessWidget {
  const HistoryPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          AppStrings.history(context),
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 24,
            color: Theme.of(context).colorScheme.onSurface,
          ),
        ),
      ),
      body: BlocBuilder<HistoryBloc, HistoryState>(
        builder: (context, state) {
          if (state is HistoryLoading) {
            return const Center(
              child: CircularProgressIndicator(),
            );
          } else if (state is HistoryLoaded) {
            if (state.history.isEmpty) {
              return _buildEmptyState(context);
            }
            return RefreshIndicator(
              onRefresh: () async {
                context.read<HistoryBloc>().add(LoadHistoryEvent());
              },
              child: _buildHistoryGrid(context, state.history),
            );
          } else if (state is HistoryError) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    state.message,
                    style: TextStyle(color: Theme.of(context).colorScheme.onSurface),
                  ),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: () {
                      context.read<HistoryBloc>().add(LoadHistoryEvent());
                    },
                    child: Text(AppStrings.retry(context)),
                  ),
                ],
              ),
            );
          }
          return const SizedBox();
        },
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: scheme.surfaceContainerHighest.withValues(alpha: 0.5),
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.history_rounded,
              size: 64,
              color: scheme.outline,
            ),
          ),
          const SizedBox(height: 24),
          Text(
            AppStrings.keepTrack(context),
            style: TextStyle(
              color: scheme.onSurface,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 40),
            child: Text(
              AppStrings.emptyHistory(context),
              textAlign: TextAlign.center,
              style: TextStyle(
                color: scheme.outline,
                fontSize: 14,
                height: 1.5,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHistoryGrid(BuildContext context, List<HistoryModel> history) {
    return GridView.builder(
      padding: const EdgeInsets.all(16),
      physics: const AlwaysScrollableScrollPhysics(
        parent: BouncingScrollPhysics(),
      ),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        childAspectRatio: 0.5,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
      ),
      itemCount: history.length,
      itemBuilder: (context, index) {
        final item = history[index];
        final drama = item.drama;
        return DramaCard(
          drama: drama,
          provider: item.provider,
          nartoProviderKey: item.nartoProviderKey,
          lastWatchedIndex: item.episodeIndex,
          watchedPosition: item.watchedPosition,
          totalDuration: item.totalDuration,
          hideHotCode: true,
          showChapterCount: true,
          onTap: () {
            if (isDramafrenEmbeddedProvider(item.nartoProviderKey) &&
                drama.bookId.isNotEmpty) {
              final site = dramafrenSites[item.nartoProviderKey];
              if (site != null) {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => DramafrenWebViewPage(
                      siteKey: item.nartoProviderKey,
                      baseUrl: site,
                      initialPath: dramafrenDetailPath(
                        item.nartoProviderKey,
                        drama.bookId,
                        drama.bookName,
                      ),
                    ),
                  ),
                );
                return;
              }
            }
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => DramaDetailPage(
                  drama: drama,
                  provider: item.provider,
                  nartoProviderKey: item.nartoProviderKey,
                  startIndex: item.episodeIndex,
                ),
              ),
            );
          },
        );
      },
    );
  }
}
