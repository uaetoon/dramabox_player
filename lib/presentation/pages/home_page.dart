import 'dart:async';
import 'dart:ui';

import 'package:dramabox_free/core/localization/app_localizations.dart';
import 'package:dramabox_free/core/theme/app_theme.dart';
import 'package:dramabox_free/data/models/drama_model.dart';
import 'package:dramabox_free/data/models/drama_section_model.dart';
import 'package:dramabox_free/data/models/download_item.dart';
import 'package:dramabox_free/data/models/favorite_model.dart';
import 'package:dramabox_free/data/models/narto_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:dramabox_free/presentation/blocs/home_bloc.dart';
import 'package:dramabox_free/presentation/blocs/favorites_bloc.dart';
import 'package:dramabox_free/presentation/blocs/downloads_bloc.dart';
import 'package:dramabox_free/presentation/blocs/search_bloc.dart';
import 'package:dramabox_free/presentation/pages/drama_detail_page.dart';
import 'package:dramabox_free/presentation/pages/history_page.dart';
import 'package:dramabox_free/presentation/pages/player_page.dart';
import 'package:dramabox_free/presentation/pages/dramafren_webview_page.dart';
import 'package:dramabox_free/presentation/cubits/navigation_cubit.dart';
import 'package:dramabox_free/presentation/cubits/app_language_cubit.dart';
import 'package:dramabox_free/presentation/cubits/app_theme_cubit.dart';
import 'package:dramabox_free/presentation/cubits/provider_visibility_cubit.dart';
import 'package:dramabox_free/presentation/cubits/adult_lock_cubit.dart';
import 'package:dramabox_free/presentation/cubits/similar_section_cubit.dart';
import 'package:dramabox_free/presentation/cubits/ui_style_cubit.dart';
import 'package:dramabox_free/presentation/cubits/playback_settings_cubit.dart';
import 'package:dramabox_free/presentation/widgets/drama_shimmer_grid.dart';
import 'package:dramabox_free/presentation/widgets/drama_card.dart';
import 'package:dramabox_free/presentation/widgets/platform_badge.dart';
import 'package:dramabox_free/core/services/shorebird_service.dart';
import 'package:dramabox_free/core/services/cross_provider_service.dart';
import 'package:dramabox_free/core/di/injection_container.dart';
import 'package:dramabox_free/domain/repositories/drama_repository.dart';
import 'package:cached_network_image/cached_network_image.dart';

void _openDetail(
  BuildContext context,
  DramaModel drama, {
  int? startIndex,
  String? nartoProviderKey,
}) {
  final provider = context.read<NavigationCubit>().state;
  final homeState = context.read<HomeBloc>().state;
  final activeKey = nartoProviderKey ??
      (drama.nartoProviderKey.isNotEmpty
          ? drama.nartoProviderKey
          : (homeState is HomeLoaded ? homeState.activeNartoProvider : ''));
  if (isDramafrenEmbeddedProvider(activeKey) && drama.bookId.isNotEmpty) {
    final site = dramafrenSites[activeKey];
    if (site != null) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => DramafrenWebViewPage(
            siteKey: activeKey,
            baseUrl: site,
            initialPath: dramafrenDetailPath(
              activeKey,
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
        provider: provider,
        nartoProviderKey: activeKey,
        startIndex: startIndex,
      ),
    ),
  );
}

String _providerDisplayLabel(BuildContext context, NartoProvider provider) {
  if (provider.key == CrossProviderService.dubbedKey) {
    return AppStrings.specialDubbed(context);
  }
  if (provider.key == CrossProviderService.adultKey) {
    return AppStrings.specialAdult(context);
  }
  return provider.label;
}

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final TextEditingController _searchController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final ScrollController _providerScrollController = ScrollController();
  final GlobalKey<_SearchTabState> _searchTabKey = GlobalKey();
  int _selectedSectionIndex = 0;
  int _selectedTabIndex = 0;

  bool _isPaginationInProgress = false;

  static const _providerIconColors = [
    Colors.amber,
    Colors.blue,
    Colors.red,
    Colors.green,
    Colors.purple,
    Colors.orange,
    Colors.teal,
    Colors.pink,
    Colors.indigo,
    Colors.cyan,
    Colors.lime,
    Colors.brown,
    Colors.blueGrey,
  ];

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
    setState(() {
      _selectedSectionIndex = 0;
    });
    if (_scrollController.hasClients) {
      _scrollController.jumpTo(0);
    }
  }

  void _onSearchSubmitted(String value) {
    if (value.trim().isEmpty) return;
    setState(() => _selectedTabIndex = 1);
    _searchTabKey.currentState?.performSearch(value.trim());
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
      appBar: _buildAppBar(context),
      body: IndexedStack(
        index: _selectedTabIndex,
        children: [
          HomeTabContent(
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
          ),
          _SearchTab(key: _searchTabKey),
          const MyListTab(),
          const DownloadsTab(),
          const ProfileTab(),
        ],
      ),
      bottomNavigationBar: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const _ShorebirdStatusBar(),
          _GlassNavBar(
            selectedIndex: _selectedTabIndex,
            onDestinationSelected: _selectTab,
          ),
        ],
      ),
    );
  }

  PreferredSizeWidget _buildAppBar(BuildContext context) {
    if (_selectedTabIndex == 0) {
      return AppBar(
        title: Row(
          children: [
            Expanded(
              child: Container(
                height: 40,
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: TextField(
                  controller: _searchController,
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.onSurface,
                    fontSize: 14,
                  ),
                  decoration: InputDecoration(
                    hintText: AppStrings.searchDramas(context),
                    hintStyle: TextStyle(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                    prefixIcon: Icon(
                      Icons.search,
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                      size: 20,
                    ),
                    border: InputBorder.none,
                    contentPadding: const EdgeInsets.symmetric(vertical: 10),
                  ),
                  onSubmitted: _onSearchSubmitted,
                ),
              ),
            ),
          ],
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: GestureDetector(
              onTap: () => _selectTab(4),
              child: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  Icons.person_rounded,
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                  size: 22,
                ),
              ),
            ),
          ),
        ],
      );
    }

    final titles = [
      '',
      AppStrings.search(context),
      AppStrings.myList(context),
      AppStrings.downloads(context),
      AppStrings.profile(context),
    ];
    return AppBar(title: Text(titles[_selectedTabIndex]));
  }
}

class HomeTabContent extends StatelessWidget {
  final ScrollController scrollController;
  final ScrollController providerScrollController;
  final int selectedSectionIndex;
  final bool isPaginationInProgress;
  final ValueChanged<int> onSectionSelected;
  final void Function(String key) onProviderTap;

  const HomeTabContent({
    super.key,
    required this.scrollController,
    required this.providerScrollController,
    required this.selectedSectionIndex,
    required this.isPaginationInProgress,
    required this.onSectionSelected,
    required this.onProviderTap,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _buildProviderPills(context),
        Expanded(
          child: BlocBuilder<HomeBloc, HomeState>(
            builder: (context, state) {
              if (state is HomeLoading) {
                return const DramaShimmerGrid();
              } else if (state is HomeLoaded) {
                final embeddedSite = dramafrenSites[state.activeNartoProvider];
                if (embeddedSite != null) {
                  return DramafrenWebViewPage(
                    siteKey: state.activeNartoProvider,
                    baseUrl: embeddedSite,
                  );
                }
                final sections = state.sectionsFor(state.activeNartoProvider);
                if (sections.isEmpty) {
                  return const DramaShimmerGrid();
                }
                final localIndex = selectedSectionIndex >= sections.length
                    ? 0
                    : selectedSectionIndex;
                return ListView(
                  controller: scrollController,
                  physics: const BouncingScrollPhysics(),
                  padding: EdgeInsets.zero,
                  children: [
                    _BannerCarousel(
                      items: sections.first.dramas.take(6).toList(),
                      onTap: (drama) => _openDetail(context, drama),
                    ),
                    _buildSectionTabs(context, sections, localIndex),
                    Padding(
                      padding: const EdgeInsets.all(16),
                      child: _buildDramaGrid(
                        context,
                        sections[localIndex].dramas,
                      ),
                    ),
                  ],
                );
              } else if (state is HomeError) {
                return Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Text(
                      state.message,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ),
                );
              }
              return const SizedBox();
            },
          ),
        ),
      ],
    );
  }

  Widget _buildProviderPills(BuildContext context) {
    return BlocBuilder<HomeBloc, HomeState>(
      builder: (context, homeState) {
        final nartoProviders = homeState is HomeLoaded
            ? homeState.nartoProviders
            : const <NartoProvider>[];
        final activeKey = homeState is HomeLoaded
            ? homeState.activeNartoProvider
            : '';
        return BlocBuilder<ProviderVisibilityCubit, Set<String>>(
          builder: (context, hidden) {
            final visibleProviders = nartoProviders.where((p) {
              return p.key == activeKey || !hidden.contains(p.key);
            }).toList();
            return SizedBox(
              height: 56,
              child: Row(
                children: [
                  Expanded(
                    child: ListView.builder(
                      controller: providerScrollController,
                      scrollDirection: Axis.horizontal,
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                      itemCount: visibleProviders.length,
                      itemBuilder: (context, index) {
                        final provider = visibleProviders[index];
                        final isSelected = provider.key == activeKey;
                        final color =
                            _HomePageState
                                ._providerIconColors[index %
                                    _HomePageState._providerIconColors.length];

                        return Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 4,
                            vertical: 8,
                          ),
                          child: GestureDetector(
                            onTap: () => onProviderTap(provider.key),
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 6,
                              ),
                              decoration: BoxDecoration(
                                color: isSelected
                                    ? color.withValues(alpha: 0.2)
                                    : Theme.of(
                                        context,
                                      ).colorScheme.surfaceContainerHighest,
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(
                                  color: isSelected
                                      ? color
                                      : Theme.of(
                                          context,
                                        ).colorScheme.outlineVariant,
                                  width: isSelected ? 1.5 : 0.5,
                                ),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  ClipOval(
                                    child: Image.asset(
                                      'assets/logos/${provider.key}.png',
                                      width: 22,
                                      height: 22,
                                      fit: BoxFit.cover,
                                      errorBuilder:
                                          (context, error, stackTrace) =>
                                              _buildProviderLetterAvatar(
                                                context,
                                                provider.label,
                                                isSelected,
                                                color,
                                              ),
                                    ),
                                  ),
                                  const SizedBox(width: 6),
                                  Text(
                                    _providerDisplayLabel(context, provider),
                                    style: TextStyle(
                                      color: isSelected
                                          ? Theme.of(
                                              context,
                                            ).colorScheme.onSurface
                                          : Theme.of(
                                              context,
                                            ).colorScheme.onSurfaceVariant,
                                      fontSize: 13,
                                      fontWeight: isSelected
                                          ? FontWeight.bold
                                          : FontWeight.normal,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.only(left: 4, right: 8),
                    child: Center(
                      child: GestureDetector(
                        onTap: () => _showPlatformSelector(
                          context,
                          visibleProviders,
                          activeKey,
                        ),
                        child: Container(
                          width: 40,
                          height: 40,
                          decoration: BoxDecoration(
                            color: Theme.of(
                              context,
                            ).colorScheme.surfaceContainerHighest,
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                              color: Theme.of(
                                context,
                              ).colorScheme.outlineVariant,
                              width: 0.5,
                            ),
                          ),
                          alignment: Alignment.center,
                          child: Icon(
                            Icons.apps_rounded,
                            size: 20,
                            color: Theme.of(
                              context,
                            ).colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  void _showPlatformSelector(
    BuildContext context,
    List<NartoProvider> providers,
    String activeKey,
  ) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Theme.of(context).colorScheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (sheetContext) {
        final maxHeight = MediaQuery.of(sheetContext).size.height * 0.7;
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      AppStrings.platforms(context).toUpperCase(),
                      style: TextStyle(
                        color:
                            Theme.of(sheetContext).colorScheme.onSurfaceVariant,
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 1.2,
                      ),
                    ),
                    const Spacer(),
                    Icon(
                      Icons.apps_rounded,
                      size: 18,
                      color: Theme.of(sheetContext).colorScheme.onSurfaceVariant,
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                ConstrainedBox(
                  constraints: BoxConstraints(maxHeight: maxHeight),
                  child: SingleChildScrollView(
                    child: Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        for (var i = 0; i < providers.length; i++)
                          _buildPlatformSelectorChip(
                            sheetContext,
                            providers[i],
                            activeKey,
                            i,
                          ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildPlatformSelectorChip(
    BuildContext context,
    NartoProvider provider,
    String activeKey,
    int index,
  ) {
    final isSelected = provider.key == activeKey;
    final scheme = Theme.of(context).colorScheme;
    final color =
        _HomePageState._providerIconColors[index %
            _HomePageState._providerIconColors.length];
    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: () {
        Navigator.pop(context);
        onProviderTap(provider.key);
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected
              ? color.withValues(alpha: 0.2)
              : scheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? color : scheme.outlineVariant,
            width: isSelected ? 1.5 : 0.5,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            ClipOval(
              child: Image.asset(
                'assets/logos/${provider.key}.png',
                width: 20,
                height: 20,
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) =>
                    _buildProviderLetterAvatar(
                      context,
                      provider.label,
                      isSelected,
                      color,
                    ),
              ),
            ),
            const SizedBox(width: 6),
            Text(
              _providerDisplayLabel(context, provider),
              style: TextStyle(
                color: isSelected ? scheme.onSurface : scheme.onSurfaceVariant,
                fontSize: 13,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildProviderLetterAvatar(
    BuildContext context,
    String label,
    bool isSelected,
    Color color,
  ) {
    return Container(
      width: 22,
      height: 22,
      decoration: BoxDecoration(
        color: isSelected
            ? color
            : Theme.of(context).colorScheme.outlineVariant,
        shape: BoxShape.circle,
      ),
      alignment: Alignment.center,
      child: Text(
        label.isNotEmpty ? label[0] : '?',
        style: const TextStyle(
          color: Colors.white,
          fontSize: 12,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  Widget _buildSectionTabs(
    BuildContext context,
    List<DramaSectionModel> sections,
    int localIndex,
  ) {
    return SizedBox(
      height: 46,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: sections.length,
        itemBuilder: (context, index) {
          final isSelected = localIndex == index;
          final name = sections[index].name;
          return Padding(
            padding: const EdgeInsets.only(right: 16),
            child: Center(
              child: GestureDetector(
                onTap: () => onSectionSelected(index),
                child: AnimatedDefaultTextStyle(
                  duration: const Duration(milliseconds: 200),
                  style: TextStyle(
                    color: isSelected
                        ? Theme.of(context).colorScheme.onSurface
                        : Theme.of(context).colorScheme.onSurfaceVariant,
                    fontSize: isSelected ? 20 : 18,
                    fontWeight: isSelected
                        ? FontWeight.bold
                        : FontWeight.normal,
                  ),
                  child: Text(_localizedSectionName(context, name)),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildDramaGrid(BuildContext context, List<DramaModel> dramas) {
    final provider = context.read<NavigationCubit>().state;
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        childAspectRatio: 0.5,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
      ),
      itemCount: dramas.length + (isPaginationInProgress ? 1 : 0),
      itemBuilder: (context, index) {
        if (index == dramas.length) {
          return const Center(
            child: SizedBox(
              height: 20,
              width: 20,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
          );
        }
        final drama = dramas[index];
        return DramaCard(
          drama: drama,
          provider: provider,
          lastWatchedFuture: sl<DramaRepository>().getLastWatchedIndex(
            drama.bookId,
            provider: provider,
          ),
          onTap: () => _openDetail(context, drama),
        );
      },
    );
  }

  String _localizedSectionName(BuildContext context, String name) {
    switch (name) {
      case 'For You':
        return AppStrings.sectionForYou(context);
      case 'Latest':
        return AppStrings.sectionLatest(context);
      case 'Trending':
        return AppStrings.sectionTrending(context);
      case 'VIP':
        return AppStrings.sectionVip(context);
      default:
        return name;
    }
  }
}

class _BannerCarousel extends StatefulWidget {
  final List<DramaModel> items;
  final void Function(DramaModel drama) onTap;

  const _BannerCarousel({required this.items, required this.onTap});

  @override
  State<_BannerCarousel> createState() => _BannerCarouselState();
}

class _BannerCarouselState extends State<_BannerCarousel> {
  final PageController _pageController = PageController(viewportFraction: 0.92);
  Timer? _timer;
  int _current = 0;

  @override
  void initState() {
    super.initState();
    _startTimer();
  }

  void _startTimer() {
    _timer?.cancel();
    if (widget.items.length < 2) return;
    _timer = Timer.periodic(const Duration(seconds: 5), (_) {
      if (!mounted || !_pageController.hasClients) return;
      final next = (_current + 1) % widget.items.length;
      _pageController.animateToPage(
        next,
        duration: const Duration(milliseconds: 450),
        curve: Curves.easeOut,
      );
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.items.isEmpty) {
      return const SizedBox.shrink();
    }
    final scheme = Theme.of(context).colorScheme;
    return SizedBox(
      height: 180,
      child: Stack(
        alignment: Alignment.bottomCenter,
        children: [
          PageView.builder(
            controller: _pageController,
            itemCount: widget.items.length,
            onPageChanged: (index) {
              setState(() => _current = index);
            },
            itemBuilder: (context, index) {
              final drama = widget.items[index];
              return GestureDetector(
                onTap: () => widget.onTap(drama),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(16),
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        Image.network(
                          drama.coverWap,
                          fit: BoxFit.cover,
                          errorBuilder: (context, error, stack) => Container(
                            color: scheme.surfaceContainerHighest,
                            child: Icon(
                              Icons.movie_creation_outlined,
                              size: 48,
                              color: scheme.onSurfaceVariant,
                            ),
                          ),
                        ),
                        const DecoratedBox(
                          decoration: BoxDecoration(
                            gradient: AppTheme.bannerGradient,
                          ),
                        ),
                        Positioned(
                          left: 14,
                          right: 14,
                          bottom: 12,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                drama.bookName,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              if (drama.tags.isNotEmpty) ...[
                                const SizedBox(height: 4),
                                Text(
                                  drama.tags.join(' · '),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    color: Colors.white.withValues(alpha: 0.85),
                                    fontSize: 12,
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
          if (widget.items.length > 1)
            Positioned(
              bottom: 6,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: List.generate(widget.items.length, (i) {
                  final selected = i == _current;
                  return AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    margin: const EdgeInsets.symmetric(horizontal: 3),
                    width: selected ? 16 : 6,
                    height: 6,
                    decoration: BoxDecoration(
                      color: selected ? Colors.amber : Colors.white54,
                      borderRadius: BorderRadius.circular(3),
                    ),
                  );
                }),
              ),
            ),
        ],
      ),
    );
  }
}

class _SearchTab extends StatefulWidget {
  const _SearchTab({super.key});

  @override
  State<_SearchTab> createState() => _SearchTabState();
}

class _SearchTabState extends State<_SearchTab> {
  final TextEditingController _controller = TextEditingController();

  void performSearch(String query) {
    _controller.text = query;
    _submit(query);
  }

  void _submit(String query) {
    final trimmed = query.trim();
    if (trimmed.isEmpty) return;
    final homeState = context.read<HomeBloc>().state;
    final providerKey = homeState is HomeLoaded
        ? homeState.activeNartoProvider
        : 'bibishort';
    context.read<SearchBloc>().add(
      PerformSearchEvent(trimmed, nartoProviderKey: providerKey),
    );
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
          child: TextField(
            controller: _controller,
            autofocus: false,
            style: TextStyle(color: scheme.onSurface, fontSize: 14),
            decoration: InputDecoration(
              hintText: AppStrings.searchDramas(context),
              hintStyle: TextStyle(color: scheme.onSurfaceVariant),
              prefixIcon: Icon(Icons.search, color: scheme.onSurfaceVariant),
              suffixIcon: IconButton(
                icon: Icon(
                  Icons.clear,
                  color: scheme.onSurfaceVariant,
                  size: 18,
                ),
                onPressed: () {
                  _controller.clear();
                  context.read<SearchBloc>().add(ClearSearchEvent());
                },
              ),
              filled: true,
              fillColor: scheme.surfaceContainerHighest,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none,
              ),
              contentPadding: const EdgeInsets.symmetric(vertical: 12),
            ),
            onSubmitted: _submit,
          ),
        ),
        Expanded(
          child: BlocBuilder<SearchBloc, SearchState>(
            builder: (context, state) {
              if (state is SearchLoading) {
                return const DramaShimmerGrid();
              } else if (state is SearchLoaded) {
                if (state.results.isEmpty) {
                  return EmptyState(
                    icon: Icons.search_off_rounded,
                    message: AppStrings.noResultsFound(context),
                  );
                }
                return _SearchGrid(
                  results: state.results,
                  nartoProviderKey: state.nartoProviderKey,
                );
              } else if (state is SearchError) {
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
}

class _SearchGrid extends StatelessWidget {
  final List<DramaModel> results;
  final String nartoProviderKey;

  const _SearchGrid({
    required this.results,
    this.nartoProviderKey = '',
  });

  @override
  Widget build(BuildContext context) {
    final provider = context.read<NavigationCubit>().state;
    return GridView.builder(
      padding: const EdgeInsets.all(16),
      physics: const BouncingScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        childAspectRatio: 0.5,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
      ),
      itemCount: results.length,
      itemBuilder: (context, index) {
        final drama = results[index];
        return DramaCard(
          drama: drama,
          provider: provider,
          nartoProviderKey: nartoProviderKey,
          lastWatchedFuture: sl<DramaRepository>().getLastWatchedIndex(
            drama.bookId,
            provider: provider,
          ),
          onTap: () =>
              _openDetail(context, drama, nartoProviderKey: nartoProviderKey),
        );
      },
    );
  }
}

class MyListTab extends StatelessWidget {
  const MyListTab({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<FavoritesBloc, FavoritesState>(
      builder: (context, state) {
        if (state is FavoritesLoading) {
          return const Center(
            child: CircularProgressIndicator(strokeWidth: 2),
          );
        } else if (state is FavoritesLoaded) {
          if (state.favorites.isEmpty) {
            return EmptyState(
              icon: Icons.favorite_border_rounded,
              message: AppStrings.emptyMyList(context),
            );
          }
          return FavoritesGrid(favorites: state.favorites);
        } else if (state is FavoritesError) {
          return EmptyState(
            icon: Icons.error_outline_rounded,
            message: state.message,
          );
        }
        return const SizedBox();
      },
    );
  }
}

class FavoritesGrid extends StatelessWidget {
  final List<FavoriteModel> favorites;

  const FavoritesGrid({super.key, required this.favorites});

  @override
  Widget build(BuildContext context) {
    return GridView.builder(
      padding: const EdgeInsets.all(16),
      physics: const BouncingScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        childAspectRatio: 0.5,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
      ),
      itemCount: favorites.length,
      itemBuilder: (context, index) {
        final item = favorites[index];
        return DramaCard(
          drama: item.drama,
          provider: item.provider,
          nartoProviderKey: item.nartoProviderKey,
          isFavorite: true,
          onToggleFavorite: () {
            context.read<FavoritesBloc>().add(
              ToggleFavoriteEvent(
                item.drama,
                provider: item.provider,
                nartoProviderKey: item.nartoProviderKey,
              ),
            );
          },
          onTap: () =>
              _openDetail(context, item.drama, nartoProviderKey: item.nartoProviderKey),
        );
      },
    );
  }
}

class DownloadsTab extends StatelessWidget {
  const DownloadsTab({super.key});

  static String _formatBytes(int bytes) {
    if (bytes <= 0) return '';
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) {
      return '${(bytes / 1024).toStringAsFixed(1)} KB';
    }
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }

  void _openDownloaded(BuildContext context, DownloadItem tapped) {
    final state = context.read<DownloadsBloc>().state;
    final items = <DownloadItem>[];
    if (state is DownloadsLoaded) {
      for (final item in state.items) {
        if (item.status == DownloadStatus.completed &&
            item.drama.bookId == tapped.drama.bookId &&
            item.provider == tapped.provider) {
          items.add(item);
        }
      }
    }
    if (items.isEmpty) return;
    items.sort((a, b) => a.episodeNumber.compareTo(b.episodeNumber));
    final episodes = items.map((item) => item.episode).toList();
    final numbers = items.map((item) => item.episodeNumber).toList();
    final startIndex = items.indexWhere((item) => item.id == tapped.id);
    if (startIndex < 0) return;
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => PlayerPage(
          drama: tapped.drama,
          provider: tapped.provider,
          nartoProviderKey: tapped.nartoProviderKey,
          episodesOverride: episodes,
          episodeNumbers: numbers,
          startIndex: startIndex,
        ),
      ),
    );
  }

  Future<void> _confirmDelete(BuildContext context, DownloadItem item) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(AppStrings.deleteDownloadConfirm(dialogContext)),
        content: Text(
          '${item.drama.bookName}\n${AppStrings.ep(dialogContext)} ${item.episodeNumber}',
          style: TextStyle(
            color: Theme.of(dialogContext).colorScheme.onSurfaceVariant,
          ),
        ),
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
    if (confirmed == true) {
      if (!context.mounted) return;
      context.read<DownloadsBloc>().add(RemoveDownloadEvent(item.id));
    }
  }

  void _handleItemTap(BuildContext context, DownloadItem item) {
    if (item.status == DownloadStatus.completed) {
      _openDownloaded(context, item);
    } else if (item.status == DownloadStatus.downloading) {
      context.read<DownloadsBloc>().add(PauseDownloadEvent(item.id));
    } else if (item.status == DownloadStatus.paused ||
        item.status == DownloadStatus.failed) {
      context.read<DownloadsBloc>().add(
        StartDownloadEvent(item.copyWith(status: DownloadStatus.queued)),
      );
    }
  }

  /// Groups downloads by series (same drama + provider). Each group is
  /// ordered by episode number so the series can be played in order.
  List<List<DownloadItem>> _groupDownloads(List<DownloadItem> items) {
    final grouped = <String, List<DownloadItem>>{};
    final order = <String>[];
    for (final item in items) {
      final key = '${item.drama.bookId}\u0000${item.provider}';
      final list = grouped[key] ?? <DownloadItem>[];
      if (list.isEmpty) order.add(key);
      list.add(item);
      grouped[key] = list;
    }
    return [
      for (final key in order)
        List<DownloadItem>.from(grouped[key]!)
          ..sort((a, b) => a.episodeNumber.compareTo(b.episodeNumber)),
    ];
  }

  Future<void> _confirmDeleteSeries(
    BuildContext context,
    List<DownloadItem> items,
  ) async {
    if (items.isEmpty) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(AppStrings.deleteDownloadConfirm(dialogContext)),
        content: Text(
          '${items.first.drama.bookName}\n'
          '${AppStrings.episodesCount(dialogContext, items.length)}',
          style: TextStyle(
            color: Theme.of(dialogContext).colorScheme.onSurfaceVariant,
          ),
        ),
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
    if (confirmed != true || !context.mounted) return;
    for (final item in items) {
      context.read<DownloadsBloc>().add(RemoveDownloadEvent(item.id));
    }
  }

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<DownloadsBloc, DownloadsState>(
      builder: (context, state) {
        if (state is DownloadsLoading || state is DownloadsInitial) {
          return const Center(
            child: CircularProgressIndicator(strokeWidth: 2),
          );
        } else if (state is DownloadsLoaded) {
          if (state.items.isEmpty) {
            return EmptyState(
              icon: Icons.download_outlined,
              message: AppStrings.emptyDownloads(context),
            );
          }
          return ListView(
            padding: const EdgeInsets.all(16),
            physics: const BouncingScrollPhysics(),
            children: [
              for (final group in _groupDownloads(state.items)) ...[
                _DownloadGroup(
                  items: group,
                  onTap: (item) => _handleItemTap(context, item),
                  onDelete: (item) => _confirmDelete(context, item),
                  onDeleteAll: (items) => _confirmDeleteSeries(context, items),
                ),
                const SizedBox(height: 10),
              ],
            ],
          );
        } else if (state is DownloadsError) {
          return EmptyState(
            icon: Icons.error_outline_rounded,
            message: state.message,
          );
        }
        return const SizedBox();
      },
    );
  }
}

class _DownloadGroup extends StatelessWidget {
  final List<DownloadItem> items;
  final ValueChanged<DownloadItem> onTap;
  final ValueChanged<DownloadItem> onDelete;
  final ValueChanged<List<DownloadItem>> onDeleteAll;

  const _DownloadGroup({
    required this.items,
    required this.onTap,
    required this.onDelete,
    required this.onDeleteAll,
  });

  DownloadItem get _head => items.first;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final thumbnail = _head.drama.coverWap.isNotEmpty
        ? _head.drama.coverWap
        : _head.episode.chapterImg;

    return GestureDetector(
      onLongPress: () => onDeleteAll(items),
      child: Container(
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF1C1C20) : Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: Colors.white12),
        ),
        clipBehavior: Clip.antiAlias,
        child: ExpansionTile(
          maintainState: true,
          shape: const Border(),
          collapsedShape: const Border(),
          tilePadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          childrenPadding: const EdgeInsets.fromLTRB(8, 0, 8, 8),
          leading: ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: Stack(
              children: [
                CachedNetworkImage(
                  imageUrl: thumbnail,
                  width: 56,
                  height: 76,
                  fit: BoxFit.cover,
                  errorWidget: (context, url, error) => Container(
                    width: 56,
                    height: 76,
                    color: scheme.surfaceContainerHighest,
                    child: Icon(
                      Icons.movie_creation_outlined,
                      color: scheme.onSurfaceVariant,
                      size: 24,
                    ),
                  ),
                ),
                if (_head.nartoProviderKey.isNotEmpty)
                  Positioned(
                    bottom: 3,
                    right: 3,
                    child: PlatformBadge(
                      providerKey: _head.nartoProviderKey,
                      size: 18,
                    ),
                  ),
              ],
            ),
          ),
          title: Text(
            _head.drama.bookName,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: scheme.onSurface,
              fontSize: 14,
              fontWeight: FontWeight.w600,
            ),
          ),
          subtitle: Text(
            AppStrings.episodesCount(context, items.length),
            style: TextStyle(color: scheme.onSurfaceVariant, fontSize: 12),
          ),
          children: [
            for (final item in items) ...[
              if (item != items.first)
                const Divider(height: 1, color: Colors.white12),
              _DownloadTile(
                item: item,
                bordered: false,
                onTap: () => onTap(item),
                onDelete: () => onDelete(item),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _DownloadTile extends StatelessWidget {
  final DownloadItem item;
  final VoidCallback onTap;
  final VoidCallback onDelete;

  /// When false the tile renders without its own card background so it can
  /// sit compactly inside a series group.
  final bool bordered;

  const _DownloadTile({
    required this.item,
    required this.onTap,
    required this.onDelete,
    this.bordered = true,
  });

  String _statusLabel(BuildContext context) {
    switch (item.status) {
      case DownloadStatus.completed:
        return AppStrings.downloadCompleted(context);
      case DownloadStatus.downloading:
        return '${AppStrings.ep(context)} ${item.episodeNumber} · '
            '${(item.progress * 100).toStringAsFixed(0)}%';
      case DownloadStatus.paused:
        return '${AppStrings.ep(context)} ${item.episodeNumber} · '
            '${AppStrings.downloadPaused(context)}';
      case DownloadStatus.failed:
        return '${AppStrings.ep(context)} ${item.episodeNumber} · '
            '${AppStrings.downloadFailed(context)}';
      case DownloadStatus.queued:
        return '${AppStrings.ep(context)} ${item.episodeNumber} · '
            '${AppStrings.downloadQueued(context)}';
    }
  }

  IconData _trailingIcon() {
    switch (item.status) {
      case DownloadStatus.completed:
        return Icons.play_circle_outline_rounded;
      case DownloadStatus.downloading:
        return Icons.pause_circle_outline_rounded;
      case DownloadStatus.paused:
        return Icons.play_circle_outline_rounded;
      case DownloadStatus.failed:
        return Icons.refresh_rounded;
      case DownloadStatus.queued:
        return Icons.download_outlined;
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final thumbnail =
        item.episode.chapterImg.isNotEmpty
            ? item.episode.chapterImg
            : item.drama.coverWap;

    return GestureDetector(
      onTap: onTap,
      onLongPress: item.status == DownloadStatus.completed ? onDelete : null,
      child: bordered
          ? Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF1C1C20) : Colors.white,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: Colors.white12),
              ),
              child: _buildRow(context, scheme, thumbnail),
            )
          : Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
              child: _buildRow(context, scheme, thumbnail),
            ),
    );
  }

  Widget _buildRow(BuildContext context, ColorScheme scheme, String thumbnail) {
    return Row(
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: Stack(
            children: [
              CachedNetworkImage(
                imageUrl: thumbnail,
                width: 56,
                height: 76,
                fit: BoxFit.cover,
                errorWidget: (context, url, error) => Container(
                  width: 56,
                  height: 76,
                  color: scheme.surfaceContainerHighest,
                  child: Icon(
                    Icons.movie_creation_outlined,
                    color: scheme.onSurfaceVariant,
                    size: 24,
                  ),
                ),
              ),
              if (item.nartoProviderKey.isNotEmpty)
                Positioned(
                  bottom: 3,
                  right: 3,
                  child: PlatformBadge(
                    providerKey: item.nartoProviderKey,
                    size: 18,
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                item.drama.bookName,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: scheme.onSurface,
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                _statusLabel(context),
                style: TextStyle(
                  color: scheme.onSurfaceVariant,
                  fontSize: 12,
                ),
              ),
              const SizedBox(height: 8),
              if (item.status == DownloadStatus.downloading ||
                  item.status == DownloadStatus.paused ||
                  item.status == DownloadStatus.failed) ...[
                LinearProgressIndicator(
                  value: item.progress,
                  minHeight: 4,
                  borderRadius: BorderRadius.circular(2),
                  color: item.status == DownloadStatus.failed
                      ? scheme.error
                      : scheme.primary,
                  backgroundColor: scheme.surfaceContainerHighest,
                ),
                const SizedBox(height: 4),
                Text(
                  '${DownloadsTab._formatBytes(item.downloadedBytes)}'
                  '${item.totalBytes > 0 ? ' / ${DownloadsTab._formatBytes(item.totalBytes)}' : ''}',
                  style: TextStyle(
                    color: scheme.onSurfaceVariant,
                    fontSize: 10,
                  ),
                ),
              ],
            ],
          ),
        ),
        IconButton(
          onPressed: onTap,
          icon: Icon(
            _trailingIcon(),
            color: item.status == DownloadStatus.completed
                ? Colors.greenAccent
                : scheme.primary,
          ),
        ),
      ],
    );
  }
}

class ProfileTab extends StatelessWidget {
  const ProfileTab({super.key});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: isDark
                ? const Color(0xFF1C1C20)
                : Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.white12),
          ),
          child: Row(
            children: [
              Container(
                width: 64,
                height: 64,
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: LinearGradient(
                    colors: [Colors.amber, Colors.orange],
                  ),
                ),
                alignment: Alignment.center,
                child: const Text(
                  'U',
                  style: TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                    color: Colors.black87,
                  ),
                ),
              ),
              const SizedBox(width: 16),
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
                    const SizedBox(height: 4),
                    Text(
                      AppStrings.profile(context),
                      style: TextStyle(
                        color: scheme.onSurfaceVariant,
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        _SectionCard(
          children: [
            _SectionTile(
              icon: Icons.history_rounded,
              title: AppStrings.watchHistory(context),
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const HistoryPage()),
                );
              },
            ),
          ],
        ),
        const SizedBox(height: 20),
        _sectionLabel(context, AppStrings.language(context)),
        const SizedBox(height: 8),
        _SectionCard(
          children: [
            BlocBuilder<AppLanguageCubit, Locale>(
              builder: (context, currentLocale) {
                return Column(
                  children: [
                    _LanguageTile(
                      locale: const Locale('en'),
                      label: AppStrings.english(context),
                      flag: '🇬🇧',
                      isSelected: currentLocale == const Locale('en'),
                    ),
                    Divider(height: 1, indent: 16, endIndent: 16, color: Colors.white12),
                    _LanguageTile(
                      locale: const Locale('ar'),
                      label: AppStrings.arabic(context),
                      flag: '🇸🇦',
                      isSelected: currentLocale == const Locale('ar'),
                    ),
                  ],
                );
              },
            ),
          ],
        ),
        const SizedBox(height: 20),
        _sectionLabel(context, AppStrings.theme(context)),
        const SizedBox(height: 8),
        _SectionCard(
          children: [
            BlocBuilder<AppThemeCubit, ThemeMode>(
              builder: (context, mode) {
                return Column(
                  children: [
                    _ThemeTile(
                      mode: ThemeMode.dark,
                      label: AppStrings.themeDark(context),
                      icon: Icons.dark_mode_rounded,
                      isSelected: mode == ThemeMode.dark,
                    ),
                    Divider(height: 1, indent: 16, endIndent: 16, color: Colors.white12),
                    _ThemeTile(
                      mode: ThemeMode.light,
                      label: AppStrings.themeLight(context),
                      icon: Icons.light_mode_rounded,
                      isSelected: mode == ThemeMode.light,
                    ),
                    Divider(height: 1, indent: 16, endIndent: 16, color: Colors.white12),
                    _ThemeTile(
                      mode: ThemeMode.system,
                      label: AppStrings.themeSystem(context),
                      icon: Icons.settings_brightness_rounded,
                      isSelected: mode == ThemeMode.system,
                    ),
                  ],
                );
              },
            ),
          ],
        ),
        const SizedBox(height: 20),
        _sectionLabel(context, AppStrings.uiStyle(context)),
        const SizedBox(height: 8),
        _SectionCard(
          children: [
            BlocBuilder<UiStyleCubit, UiStyle>(
              builder: (context, style) {
                return Column(
                  children: [
                    _ThemeTile(
                      mode: ThemeMode.dark,
                      label: AppStrings.uiClassic(context),
                      icon: Icons.dashboard_rounded,
                      isSelected: style == UiStyle.classic,
                      onTap: () => context
                          .read<UiStyleCubit>()
                          .setStyle(UiStyle.classic),
                    ),
                    Divider(height: 1, indent: 16, endIndent: 16, color: Colors.white12),
                    _ThemeTile(
                      mode: ThemeMode.light,
                      label: AppStrings.uiQuickplay(context),
                      icon: Icons.auto_awesome_rounded,
                      isSelected: style == UiStyle.quickplay,
                      onTap: () => context
                          .read<UiStyleCubit>()
                          .setStyle(UiStyle.quickplay),
                    ),
                  ],
                );
              },
            ),
          ],
        ),
        const SizedBox(height: 20),
        _sectionLabel(context, AppStrings.playback(context)),
        const SizedBox(height: 8),
        _SectionCard(
          children: [
            BlocBuilder<PlaybackSettingsCubit, PlaybackSettings>(
              builder: (context, settings) {
                return Column(
                  children: [
                    Padding(
                      padding:
                          const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                      child: Row(
                        children: [
                          Icon(
                            Icons.skip_next_rounded,
                            color: scheme.primary,
                            size: 22,
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  AppStrings.autoPlayNext(context),
                                  style: TextStyle(
                                    color: scheme.onSurface,
                                    fontSize: 15,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  AppStrings.autoPlayNextHint(context),
                                  style: TextStyle(
                                    color: scheme.onSurfaceVariant,
                                    fontSize: 12,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Switch(
                            value: settings.autoPlayNext,
                            onChanged: (value) => context
                                .read<PlaybackSettingsCubit>()
                                .setAutoPlayNext(value),
                          ),
                        ],
                      ),
                    ),
                    Divider(height: 1, indent: 16, endIndent: 16, color: Colors.white12),
                    _SpeedTile(
                      speed: settings.defaultSpeed,
                      onChanged: (value) => context
                          .read<PlaybackSettingsCubit>()
                          .setDefaultSpeed(value),
                    ),
                  ],
                );
              },
            ),
          ],
        ),
        const SizedBox(height: 20),
        _sectionLabel(context, AppStrings.platforms(context)),
        const SizedBox(height: 8),
        _SectionCard(
          children: [
            FutureBuilder(
              future: sl<DramaRepository>()
                  .getNartoProviders()
                  .catchError((Object _) =>
                      const NartoProviderCatalog(
                        providers: [],
                        activeProvider: '',
                      )),
              builder: (context, snapshot) {
                if (!snapshot.hasData) return const SizedBox.shrink();
                final providers = snapshot.data!.providers;
                return BlocBuilder<ProviderVisibilityCubit, Set<String>>(
                  builder: (context, hidden) {
                    return Column(
                      children: [
                        for (var i = 0; i < providers.length; i++)
                          _PlatformSwitchTile(
                            providerKey: providers[i].key,
                            label: providers[i].label,
                            visible: !hidden.contains(providers[i].key),
                            last: i == providers.length - 1,
                          ),
                      ],
                    );
                  },
                );
              },
            ),
          ],
        ),
        const SizedBox(height: 20),
        _sectionLabel(context, AppStrings.adultContent(context)),
        const SizedBox(height: 8),
        _SectionCard(
          children: [
            BlocBuilder<AdultLockCubit, bool>(
              builder: (context, unlocked) {
                return Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                  child: Row(
                    children: [
                      Icon(
                        unlocked
                            ? Icons.visibility_off_rounded
                            : Icons.visibility_rounded,
                        color: Colors.redAccent,
                        size: 22,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              unlocked
                                  ? AppStrings.unlocked(context)
                                  : AppStrings.locked(context),
                              style: TextStyle(
                                color: scheme.onSurface,
                                fontSize: 15,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              AppStrings.adultContentHint(context),
                              style: TextStyle(
                                color: scheme.onSurfaceVariant,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Switch(
                        value: unlocked,
                        activeThumbColor: Colors.redAccent,
                        onChanged: (value) =>
                            _onAdultLockChanged(context, value),
                      ),
                    ],
                  ),
                );
              },
            ),
          ],
        ),
        const SizedBox(height: 20),
        _sectionLabel(context, AppStrings.similarOnPlatforms(context)),
        const SizedBox(height: 8),
        _SectionCard(
          children: [
            BlocBuilder<SimilarSectionCubit, bool>(
              builder: (context, enabled) {
                return Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                  child: Row(
                    children: [
                      Icon(
                        Icons.hub_outlined,
                        color: scheme.primary,
                        size: 22,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              AppStrings.similarOnPlatforms(context),
                              style: TextStyle(
                                color: scheme.onSurface,
                                fontSize: 15,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              AppStrings.similarSectionHint(context),
                              style: TextStyle(
                                color: scheme.onSurfaceVariant,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Switch(
                        value: enabled,
                        onChanged: (value) => context
                            .read<SimilarSectionCubit>()
                            .setEnabled(value),
                      ),
                    ],
                  ),
                );
              },
            ),
          ],
        ),
        const SizedBox(height: 20),
        _sectionLabel(context, AppStrings.about(context)),
        const SizedBox(height: 8),
        _SectionCard(
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              child: Row(
                children: [
                  Icon(
                    Icons.info_outline,
                    color: scheme.onSurfaceVariant,
                    size: 20,
                  ),
                  const SizedBox(width: 12),
                  Text(
                    AppStrings.version(
                      context,
                      sl<ShorebirdService>().appVersion,
                    ),
                    style: TextStyle(color: scheme.onSurface, fontSize: 14),
                  ),
                ],
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _sectionLabel(BuildContext context, String label) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
      child: Text(
        label.toUpperCase(),
        style: TextStyle(
          color: Theme.of(context).colorScheme.onSurfaceVariant,
          fontSize: 12,
          fontWeight: FontWeight.bold,
          letterSpacing: 1.2,
        ),
      ),
    );
  }

  Future<void> _onAdultLockChanged(BuildContext context, bool unlock) async {
    final cubit = context.read<AdultLockCubit>();
    if (!unlock) {
      await cubit.lock();
      return;
    }
    final controller = TextEditingController();
    final code = await showDialog<String>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: Text(AppStrings.adultContent(dialogContext)),
          content: TextField(
            controller: controller,
            autofocus: true,
            obscureText: true,
            keyboardType: TextInputType.number,
            style: const TextStyle(fontSize: 24),
            decoration: InputDecoration(
              hintText: AppStrings.enterCode(dialogContext),
            ),
            onSubmitted: (value) => Navigator.pop(dialogContext, value),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: Text(AppStrings.cancel(dialogContext)),
            ),
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, controller.text),
              child: Text(
                AppStrings.confirm(dialogContext),
                style: const TextStyle(color: Colors.redAccent),
              ),
            ),
          ],
        );
      },
    );
    if (code == null) return;
    final ok = await cubit.unlock(code);
    if (!ok && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(AppStrings.wrongCode(context))),
      );
    }
  }
}

class _SectionCard extends StatelessWidget {
  final List<Widget> children;

  const _SectionCard({required this.children});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1C1C20) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white12),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(children: children),
    );
  }
}

class _PlatformSwitchTile extends StatelessWidget {
  final String providerKey;
  final String label;
  final bool visible;
  final bool last;

  const _PlatformSwitchTile({
    required this.providerKey,
    required this.label,
    required this.visible,
    required this.last,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          child: Row(
            children: [
              PlatformBadge(providerKey: providerKey, size: 24),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  label,
                  style: TextStyle(
                    color: scheme.onSurface,
                    fontSize: 15,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
              Switch(
                value: visible,
                activeThumbColor: Colors.amber,
                onChanged: (value) {
                  context
                      .read<ProviderVisibilityCubit>()
                      .setVisible(providerKey, value);
                },
              ),
            ],
          ),
        ),
        if (!last)
          Divider(
            height: 1,
            indent: 52,
            endIndent: 16,
            color: Colors.white12,
          ),
      ],
    );
  }
}

class _SectionTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final VoidCallback onTap;

  const _SectionTile({
    required this.icon,
    required this.title,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(
          children: [
            Icon(icon, color: scheme.primary, size: 22),
            const SizedBox(width: 12),
            Text(
              title,
              style: TextStyle(
                color: scheme.onSurface,
                fontSize: 15,
                fontWeight: FontWeight.w600,
              ),
            ),
            const Spacer(),
            Icon(Icons.chevron_right, color: scheme.onSurfaceVariant),
          ],
        ),
      ),
    );
  }
}

class _LanguageTile extends StatelessWidget {
  final Locale locale;
  final String label;
  final String flag;
  final bool isSelected;

  const _LanguageTile({
    required this.locale,
    required this.label,
    required this.flag,
    required this.isSelected,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return InkWell(
      onTap: () => context.read<AppLanguageCubit>().setLanguage(locale),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(
          children: [
            Text(flag, style: const TextStyle(fontSize: 22)),
            const SizedBox(width: 12),
            Text(
              label,
              style: TextStyle(
                color: scheme.onSurface,
                fontSize: 15,
                fontWeight: FontWeight.w600,
              ),
            ),
            const Spacer(),
            if (isSelected)
              Icon(Icons.check_circle_rounded, color: scheme.primary)
            else
              Icon(
                Icons.radio_button_unchecked,
                color: scheme.onSurfaceVariant,
                size: 22,
              ),
          ],
        ),
      ),
    );
  }
}

class _ThemeTile extends StatelessWidget {
  final ThemeMode mode;
  final String label;
  final IconData icon;
  final bool isSelected;
  final VoidCallback? onTap;

  const _ThemeTile({
    required this.mode,
    required this.label,
    required this.icon,
    required this.isSelected,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return InkWell(
      onTap: onTap ?? () => context.read<AppThemeCubit>().setThemeMode(mode),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(
          children: [
            Icon(icon, color: scheme.onSurfaceVariant, size: 22),
            const SizedBox(width: 12),
            Text(
              label,
              style: TextStyle(
                color: scheme.onSurface,
                fontSize: 15,
                fontWeight: FontWeight.w600,
              ),
            ),
            const Spacer(),
            if (isSelected)
              Icon(Icons.check_circle_rounded, color: scheme.primary)
            else
              Icon(
                Icons.radio_button_unchecked,
                color: scheme.onSurfaceVariant,
                size: 22,
              ),
          ],
        ),
      ),
    );
  }
}

class _SpeedTile extends StatelessWidget {
  final double speed;
  final ValueChanged<double> onChanged;

  const _SpeedTile({required this.speed, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    const speeds = [0.5, 0.75, 1.0, 1.25, 1.5, 2.0];
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          Icon(Icons.speed_rounded, color: scheme.onSurfaceVariant, size: 22),
          const SizedBox(width: 12),
          Text(
            AppStrings.defaultSpeed(context),
            style: TextStyle(
              color: scheme.onSurface,
              fontSize: 15,
              fontWeight: FontWeight.w600,
            ),
          ),
          const Spacer(),
          SizedBox(
            height: 32,
            child: ListView(
              scrollDirection: Axis.horizontal,
              shrinkWrap: true,
              children: [
                for (final s in speeds)
                  Padding(
                    padding: const EdgeInsets.only(left: 6),
                    child: ChoiceChip(
                      label: Text(
                        s == 1.0 ? '1x' : '${s}x',
                        style: const TextStyle(fontSize: 12),
                      ),
                      selected: speed == s,
                      visualDensity: VisualDensity.compact,
                      onSelected: (_) => onChanged(s),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class EmptyState extends StatelessWidget {
  final IconData icon;
  final String message;

  const EmptyState({super.key, required this.icon, required this.message});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 64, color: scheme.onSurfaceVariant),
            const SizedBox(height: 16),
            Text(
              message,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: scheme.onSurfaceVariant,
                fontSize: 14,
                height: 1.5,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _GlassNavBar extends StatelessWidget {
  final int selectedIndex;
  final ValueChanged<int> onDestinationSelected;

  const _GlassNavBar({
    required this.selectedIndex,
    required this.onDestinationSelected,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      decoration: BoxDecoration(
        color: (isDark ? Colors.black : Colors.white).withValues(alpha: 0.7),
        border: Border(
          top: BorderSide(color: Colors.white12),
        ),
      ),
      child: ClipRect(
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
          child: SafeArea(
            top: false,
            child: NavigationBar(
              selectedIndex: selectedIndex,
              onDestinationSelected: onDestinationSelected,
              destinations: [
                NavigationDestination(
                  icon: Icon(Icons.home_outlined),
                  selectedIcon: Icon(Icons.home_rounded),
                  label: AppStrings.home(context),
                ),
                NavigationDestination(
                  icon: Icon(Icons.search_outlined),
                  selectedIcon: Icon(Icons.search_rounded),
                  label: AppStrings.search(context),
                ),
                NavigationDestination(
                  icon: Icon(Icons.favorite_border_rounded),
                  selectedIcon: Icon(Icons.favorite_rounded),
                  label: AppStrings.myList(context),
                ),
                NavigationDestination(
                  icon: Icon(Icons.download_outlined),
                  selectedIcon: Icon(Icons.download_rounded),
                  label: AppStrings.downloads(context),
                ),
                NavigationDestination(
                  icon: Icon(Icons.person_outline_rounded),
                  selectedIcon: Icon(Icons.person_rounded),
                  label: AppStrings.profile(context),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ShorebirdStatusBar extends StatelessWidget {
  const _ShorebirdStatusBar();

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<ShorebirdUpdateStatus>(
      valueListenable: sl<ShorebirdService>().updateStatus,
      builder: (context, status, child) {
        return FutureBuilder<int?>(
          future: sl<ShorebirdService>().getCurrentPatchNumber(),
          builder: (context, snapshot) {
            if (status == ShorebirdUpdateStatus.idle) {
              return const SizedBox.shrink();
            }
            final patch = snapshot.data;
            final baseVersion = sl<ShorebirdService>().appVersion;
            final versionText =
                '$baseVersion${patch != null ? ' (Patch $patch)' : ''}';
            Widget statusWidget = const SizedBox.shrink();
            Color? bgColor = Colors.black;
            switch (status) {
              case ShorebirdUpdateStatus.idle:
                break;
              case ShorebirdUpdateStatus.checking:
                statusWidget = Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const SizedBox(
                      width: 10,
                      height: 10,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation<Color>(Colors.grey),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      AppStrings.checkingUpdates(context, versionText),
                      style: TextStyle(
                        fontSize: 10,
                        color: Colors.grey[400],
                      ),
                    ),
                  ],
                );
                break;
              case ShorebirdUpdateStatus.downloading:
                statusWidget = Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const SizedBox(
                      width: 10,
                      height: 10,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor:
                            AlwaysStoppedAnimation<Color>(Colors.amber),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      AppStrings.downloadingPatch(context, versionText),
                      style: const TextStyle(
                        fontSize: 10,
                        color: Colors.amber,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                );
                break;
              case ShorebirdUpdateStatus.readyToRestart:
                bgColor = Colors.amber[900]?.withValues(alpha: 0.8);
                statusWidget = Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(
                      Icons.system_update_alt,
                      size: 12,
                      color: Colors.white,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      AppStrings.updateReady(context),
                      style: const TextStyle(
                        fontSize: 11,
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                );
                break;
              case ShorebirdUpdateStatus.error:
                statusWidget = Text(
                  AppStrings.updateFailed(context),
                  style: TextStyle(fontSize: 10, color: Colors.red[400]),
                );
                break;
            }
            return GestureDetector(
              onTap: () {
                if (status != ShorebirdUpdateStatus.checking &&
                    status != ShorebirdUpdateStatus.downloading) {
                  sl<ShorebirdService>().checkForUpdates();
                }
              },
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 4),
                color: bgColor,
                child: SafeArea(top: false, child: statusWidget),
              ),
            );
          },
        );
      },
    );
  }
}
