import 'dart:async';
import 'dart:ui';

import 'package:dramabox_free/core/localization/app_localizations.dart';
import 'package:dramabox_free/data/models/drama_model.dart';
import 'package:dramabox_free/data/models/narto_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:dramabox_free/presentation/blocs/home_bloc.dart';
import 'package:dramabox_free/presentation/blocs/favorites_bloc.dart';
import 'package:dramabox_free/presentation/blocs/downloads_bloc.dart';
import 'package:dramabox_free/presentation/blocs/progressive_search_bloc.dart';
import 'package:dramabox_free/presentation/pages/home_page.dart';
import 'package:dramabox_free/presentation/pages/drama_detail_page.dart';
import 'package:dramabox_free/presentation/cubits/navigation_cubit.dart';
import 'package:dramabox_free/presentation/cubits/provider_visibility_cubit.dart';
import 'package:dramabox_free/presentation/widgets/drama_shimmer_grid.dart';
import 'package:dramabox_free/presentation/widgets/drama_card.dart';
import 'package:dramabox_free/core/di/injection_container.dart';
import 'package:dramabox_free/domain/repositories/drama_repository.dart';

/// Alternate "QuickPlay"-inspired app shell. Shares the same blocs and tab
/// bodies as the classic [HomePage] but wraps them in a distinct visual
/// layout with a gradient header, a QuickPlay-style bottom nav and a
/// progressive all-provider search tab.
class QuickPlayHomePage extends StatefulWidget {
  const QuickPlayHomePage({super.key});

  @override
  State<QuickPlayHomePage> createState() => _QuickPlayHomePageState();
}

class _QuickPlayHomePageState extends State<QuickPlayHomePage> {
  final TextEditingController _searchController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final ScrollController _providerScrollController = ScrollController();
  int _selectedSectionIndex = 0;
  int _selectedTabIndex = 0;
  bool _isPaginationInProgress = false;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    _providerScrollController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_isPaginationInProgress) return;
    if (_scrollController.position.pixels >=
        _scrollController.position.maxScrollExtent - 200) {
      final provider = context.read<NavigationCubit>().state;
      final state = context.read<HomeBloc>().state;
      if (state is HomeLoaded) {
        final sections = state.sectionsFor(state.activeNartoProvider);
        if (_selectedSectionIndex >= sections.length) return;
        final section = sections[_selectedSectionIndex];
        if (section.name != 'For You') return;
        if (section.hasMore) {
          setState(() => _isPaginationInProgress = true);
          context.read<HomeBloc>().add(
            LoadMoreHomeDataEvent(
              provider: provider,
              nartoProviderKey: state.activeNartoProvider,
              sectionIndex: _selectedSectionIndex,
            ),
          );
          Future.delayed(const Duration(seconds: 1), () {
            if (mounted) {
              setState(() => _isPaginationInProgress = false);
            }
          });
        }
      }
    }
  }

  void _switchProvider(String nartoProviderKey) {
    final state = context.read<HomeBloc>().state;
    if (state is HomeLoaded && state.activeNartoProvider == nartoProviderKey) {
      return;
    }
    context
        .read<HomeBloc>()
        .add(FetchHomeDataEvent(nartoProviderKey: nartoProviderKey));
    setState(() => _selectedSectionIndex = 0);
    if (_scrollController.hasClients) {
      _scrollController.jumpTo(0);
    }
  }

  void _selectTab(int index) {
    if (index == _selectedTabIndex) return;
    setState(() => _selectedTabIndex = index);
    if (index == 2) {
      context.read<FavoritesBloc>().add(LoadFavoritesEvent());
    } else if (index == 3) {
      context.read<DownloadsBloc>().add(LoadDownloadsEvent());
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(
        index: _selectedTabIndex,
        children: [
          _QuickPlayHomeTab(
            scrollController: _scrollController,
            providerScrollController: _providerScrollController,
            selectedSectionIndex: _selectedSectionIndex,
            isPaginationInProgress: _isPaginationInProgress,
            onSectionSelected: (index) {
              setState(() => _selectedSectionIndex = index);
              if (_scrollController.hasClients) {
                _scrollController.jumpTo(0);
              }
            },
            onProviderTap: _switchProvider,
            onSearchTap: () => _selectTab(1),
            onSettingsTap: () => _selectTab(4),
          ),
          _QuickPlaySearchTab(controller: _searchController),
          const MyListTab(),
          const DownloadsTab(),
          const ProfileTab(),
        ],
      ),
      bottomNavigationBar: _QuickPlayNavBar(
        selectedIndex: _selectedTabIndex,
        onDestinationSelected: _selectTab,
      ),
    );
  }
}

/// Shared home body wrapped in a QuickPlay-style header.
class _QuickPlayHomeTab extends StatelessWidget {
  final ScrollController scrollController;
  final ScrollController providerScrollController;
  final int selectedSectionIndex;
  final bool isPaginationInProgress;
  final ValueChanged<int> onSectionSelected;
  final void Function(String key) onProviderTap;
  final VoidCallback onSearchTap;
  final VoidCallback onSettingsTap;

  const _QuickPlayHomeTab({
    required this.scrollController,
    required this.providerScrollController,
    required this.selectedSectionIndex,
    required this.isPaginationInProgress,
    required this.onSectionSelected,
    required this.onProviderTap,
    required this.onSearchTap,
    required this.onSettingsTap,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Column(
      children: [
        Container(
          width: double.infinity,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: isDark
                  ? [const Color(0xFF2A1E08), scheme.surface]
                  : [const Color(0xFFFFF3DD), scheme.surface],
            ),
          ),
          child: SafeArea(
            bottom: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 8, 8),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          AppStrings.appName(context),
                          style: TextStyle(
                            color: scheme.onSurface,
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          AppStrings.searchAllProviders(context),
                          style: TextStyle(
                            color: scheme.onSurfaceVariant,
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    tooltip: AppStrings.search(context),
                    onPressed: onSearchTap,
                    icon: Icon(Icons.search_rounded, color: scheme.onSurface),
                  ),
                  IconButton(
                    tooltip: AppStrings.settings(context),
                    onPressed: onSettingsTap,
                    icon: Icon(
                      Icons.settings_rounded,
                      color: scheme.onSurface,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        Expanded(
          child: HomeTabContent(
            scrollController: scrollController,
            providerScrollController: providerScrollController,
            selectedSectionIndex: selectedSectionIndex,
            isPaginationInProgress: isPaginationInProgress,
            onSectionSelected: onSectionSelected,
            onProviderTap: onProviderTap,
          ),
        ),
      ],
    );
  }
}

/// Progressive all-provider search with streaming results.
class _QuickPlaySearchTab extends StatefulWidget {
  final TextEditingController controller;

  const _QuickPlaySearchTab({required this.controller});

  @override
  State<_QuickPlaySearchTab> createState() => _QuickPlaySearchTabState();
}

class _QuickPlaySearchTabState extends State<_QuickPlaySearchTab> {
  List<String> _providerKeys(BuildContext context) {
    final homeState = context.read<HomeBloc>().state;
    final providers = homeState is HomeLoaded
        ? homeState.nartoProviders
        : const <NartoProvider>[];
    final visible = context.read<ProviderVisibilityCubit>().state;
    final keys = providers
        .where((p) => !visible.contains(p.key))
        .map((p) => p.key)
        .toList();
    if (keys.isEmpty) return const [''];
    return keys;
  }

  void _submit(String query) {
    final trimmed = query.trim();
    if (trimmed.isEmpty) return;
    context.read<ProgressiveSearchBloc>().add(
      PerformAllSearchEvent(trimmed, _providerKeys(context)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Column(
      children: [
        Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                scheme.primary.withValues(alpha: 0.25),
                scheme.surface,
              ],
            ),
          ),
          child: SafeArea(
            bottom: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
              child: TextField(
                controller: widget.controller,
                autofocus: false,
                style: TextStyle(color: scheme.onSurface, fontSize: 14),
                decoration: InputDecoration(
                  hintText: AppStrings.searchDramas(context),
                  hintStyle: TextStyle(color: scheme.onSurfaceVariant),
                  prefixIcon: Icon(
                    Icons.search,
                    color: scheme.onSurfaceVariant,
                  ),
                  suffixIcon: IconButton(
                    icon: Icon(
                      Icons.clear,
                      color: scheme.onSurfaceVariant,
                      size: 18,
                    ),
                    onPressed: () {
                      widget.controller.clear();
                      context
                          .read<ProgressiveSearchBloc>()
                          .add(ClearAllSearchEvent());
                    },
                  ),
                  filled: true,
                  fillColor: scheme.surfaceContainerHighest,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: BorderSide.none,
                  ),
                  contentPadding: const EdgeInsets.symmetric(vertical: 12),
                ),
                onSubmitted: _submit,
              ),
            ),
          ),
        ),
        Expanded(
          child: BlocBuilder<ProgressiveSearchBloc, ProgressiveSearchState>(
            builder: (context, state) {
              if (state is ProgressiveSearchLoading) {
                return Column(
                  children: [
                    _SearchProgressBar(
                      completed: 0,
                      total: state.totalProviders,
                    ),
                    const Expanded(child: DramaShimmerGrid()),
                  ],
                );
              } else if (state is ProgressiveSearchLoaded) {
                if (state.results.isEmpty && state.isDone) {
                  return EmptyState(
                    icon: Icons.search_off_rounded,
                    message: AppStrings.noResultsFound(context),
                  );
                }
                return Column(
                  children: [
                    _SearchProgressBar(
                      completed: state.completedProviders,
                      total: state.totalProviders,
                    ),
                    Expanded(
                      child: GridView.builder(
                        padding: const EdgeInsets.all(16),
                        physics: const BouncingScrollPhysics(),
                        gridDelegate:
                            const SliverGridDelegateWithFixedCrossAxisCount(
                              crossAxisCount: 3,
                              childAspectRatio: 0.5,
                              crossAxisSpacing: 12,
                              mainAxisSpacing: 12,
                            ),
                        itemCount: state.results.length,
                        itemBuilder: (context, index) {
                          final drama = state.results[index];
                          return DramaCard(
                            drama: drama,
                            provider:
                                context.read<NavigationCubit>().state,
                            nartoProviderKey: drama.nartoProviderKey,
                            lastWatchedFuture: sl<DramaRepository>()
                                .getLastWatchedIndex(
                                  drama.bookId,
                                  provider:
                                      context.read<NavigationCubit>().state,
                                ),
                            onTap: () => _openDetail(context, drama),
                          );
                        },
                      ),
                    ),
                  ],
                );
              } else if (state is ProgressiveSearchError) {
                return EmptyState(
                  icon: Icons.error_outline_rounded,
                  message: state.message,
                );
              }
              return EmptyState(
                icon: Icons.search_rounded,
                message: AppStrings.searchHint(context),
              );
            },
          ),
        ),
      ],
    );
  }

  void _openDetail(BuildContext context, DramaModel drama) {
    final provider = context.read<NavigationCubit>().state;
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => DramaDetailPage(
          drama: drama,
          provider: provider,
          nartoProviderKey: drama.nartoProviderKey,
        ),
      ),
    );
  }
}

class _SearchProgressBar extends StatelessWidget {
  final int completed;
  final int total;

  const _SearchProgressBar({required this.completed, required this.total});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    if (total <= 0) return const SizedBox.shrink();
    final done = completed >= total;
    final progress = total == 0 ? 1.0 : completed / total;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
      child: Row(
        children: [
          Expanded(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: done ? 1.0 : progress,
                minHeight: 4,
                backgroundColor: scheme.surfaceContainerHighest,
              ),
            ),
          ),
          const SizedBox(width: 10),
          Text(
            done
                ? AppStrings.searchComplete(context, completed)
                : AppStrings.searchingProviders(
                    context,
                    completed,
                    total,
                  ),
            style: TextStyle(
              color: scheme.onSurfaceVariant,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }
}

/// Distinct QuickPlay-style bottom navigation.
class _QuickPlayNavBar extends StatelessWidget {
  final int selectedIndex;
  final ValueChanged<int> onDestinationSelected;

  const _QuickPlayNavBar({
    required this.selectedIndex,
    required this.onDestinationSelected,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      decoration: BoxDecoration(
        color: (isDark ? Colors.black : Colors.white).withValues(alpha: 0.75),
        border: Border(top: BorderSide(color: Colors.white12)),
      ),
      child: ClipRect(
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
          child: SafeArea(
            top: false,
            child: Row(
              children: [
                _navItem(
                  context,
                  index: 0,
                  icon: Icons.home_outlined,
                  selectedIcon: Icons.home_rounded,
                  label: AppStrings.home(context),
                ),
                _navItem(
                  context,
                  index: 1,
                  icon: Icons.search_outlined,
                  selectedIcon: Icons.search_rounded,
                  label: AppStrings.search(context),
                ),
                _navItem(
                  context,
                  index: 2,
                  icon: Icons.favorite_border_rounded,
                  selectedIcon: Icons.favorite_rounded,
                  label: AppStrings.myList(context),
                ),
                _navItem(
                  context,
                  index: 3,
                  icon: Icons.download_outlined,
                  selectedIcon: Icons.download_rounded,
                  label: AppStrings.downloads(context),
                ),
                _navItem(
                  context,
                  index: 4,
                  icon: Icons.settings_outlined,
                  selectedIcon: Icons.settings_rounded,
                  label: AppStrings.settings(context),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _navItem(
    BuildContext context, {
    required int index,
    required IconData icon,
    required IconData selectedIcon,
    required String label,
  }) {
    final scheme = Theme.of(context).colorScheme;
    final selected = index == selectedIndex;
    return Expanded(
      child: InkWell(
        onTap: () => onDestinationSelected(index),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 10),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 42,
                height: 30,
                decoration: BoxDecoration(
                  color: selected
                      ? scheme.primary.withValues(alpha: 0.18)
                      : Colors.transparent,
                  borderRadius: BorderRadius.circular(15),
                ),
                alignment: Alignment.center,
                child: Icon(
                  selected ? selectedIcon : icon,
                  size: 22,
                  color: selected
                      ? scheme.primary
                      : scheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                label,
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: selected ? FontWeight.bold : FontWeight.w500,
                  color: selected ? scheme.primary : scheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
