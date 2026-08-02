import 'package:flutter/foundation.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:equatable/equatable.dart';
import 'package:dramabox_free/core/constants/app_enums.dart';
import 'package:dramabox_free/core/services/cross_provider_service.dart';
import 'package:dramabox_free/data/models/drama_section_model.dart';
import 'package:dramabox_free/data/models/narto_provider.dart';
import 'package:dramabox_free/domain/repositories/drama_repository.dart';
import 'package:dramabox_free/presentation/cubits/adult_lock_cubit.dart';

// Events
abstract class HomeEvent extends Equatable {
  @override
  List<Object?> get props => [];
}

class FetchHomeDataEvent extends HomeEvent {
  final AppContentProvider provider;
  final String? nartoProviderKey;
  final bool forceRefresh;
  FetchHomeDataEvent({
    this.provider = AppContentProvider.narto,
    this.nartoProviderKey,
    this.forceRefresh = false,
  });

  @override
  List<Object?> get props => [provider, nartoProviderKey, forceRefresh];
}

class PreloadAllEvent extends HomeEvent {}

class LoadMoreHomeDataEvent extends HomeEvent {
  final AppContentProvider provider;
  final String? nartoProviderKey;
  final int sectionIndex;

  LoadMoreHomeDataEvent({
    required this.provider,
    this.nartoProviderKey,
    required this.sectionIndex,
  });

  @override
  List<Object?> get props => [provider, nartoProviderKey, sectionIndex];
}

// States
abstract class HomeState extends Equatable {
  @override
  List<Object?> get props => [];
}

class HomeInitial extends HomeState {}

class HomeLoading extends HomeState {}

class HomeLoaded extends HomeState {
  final Map<String, List<DramaSectionModel>> providerSections;
  final List<NartoProvider> nartoProviders;
  final String activeNartoProvider;

  HomeLoaded({
    required this.providerSections,
    this.nartoProviders = const [],
    this.activeNartoProvider = '',
  });

  List<DramaSectionModel> sectionsFor(String nartoProviderKey) =>
      providerSections[nartoProviderKey] ?? [];

  HomeLoaded copyWith({
    Map<String, List<DramaSectionModel>>? providerSections,
    List<NartoProvider>? nartoProviders,
    String? activeNartoProvider,
  }) {
    return HomeLoaded(
      providerSections: providerSections ?? this.providerSections,
      nartoProviders: nartoProviders ?? this.nartoProviders,
      activeNartoProvider: activeNartoProvider ?? this.activeNartoProvider,
    );
  }

  @override
  List<Object?> get props =>
      [providerSections, nartoProviders, activeNartoProvider];
}

class HomeError extends HomeState {
  final String message;
  HomeError(this.message);

  @override
  List<Object?> get props => [message];
}

// Bloc
class HomeBloc extends Bloc<HomeEvent, HomeState> {
  final DramaRepository repository;
  final CrossProviderService crossProviderService;
  final AdultLockCubit adultLockCubit;

  /// Raw (non-pseudo) providers from the last preload, used to rebuild the
  /// provider list whenever the adult lock changes.
  List<NartoProvider>? _rawProviders;

  /// Sections currently being fetched (keyed by `provider:sectionIndex`), used
  /// as an in-flight guard so rapid scroll events never duplicate a request.
  final Set<String> _loadMoreInFlight = {};

  /// Consecutive empty (no-fresh) pages per section, used to detect when the
  /// server catalog has cycled back to already-seen titles.
  final Map<String, int> _emptyPageStreaks = {};

  HomeBloc({
    required this.repository,
    required this.crossProviderService,
    required this.adultLockCubit,
  }) : super(HomeInitial()) {

    List<NartoProvider> withPseudoProviders(List<NartoProvider> providers) {
      return [
        ...providers,
        const NartoProvider(
          key: CrossProviderService.dubbedKey,
          label: 'Dubbed',
        ),
        if (adultLockCubit.isUnlocked)
          const NartoProvider(
            key: CrossProviderService.adultKey,
            label: '18+',
          ),
      ];
    }

    adultLockCubit.stream.listen((unlocked) {
      final current = state;
      if (current is! HomeLoaded) return;
      final providers = withPseudoProviders(_rawProviders ?? current.nartoProviders);
      var activeKey = current.activeNartoProvider;
      if (!unlocked && activeKey == CrossProviderService.adultKey) {
        activeKey = (_rawProviders != null && _rawProviders!.isNotEmpty)
            ? _rawProviders!.first.key
            : activeKey;
        crossProviderService.invalidate();
      }
      emit(current.copyWith(
        nartoProviders: providers,
        activeNartoProvider: activeKey,
      ));
    });

    on<PreloadAllEvent>((event, emit) async {
      Map<String, List<DramaSectionModel>> sectionsMap = {};
      if (state is HomeLoaded) {
        sectionsMap = Map.of((state as HomeLoaded).providerSections);
      }

      try {
        final data = await repository.getNartoHomeData();
        if (data.providers.isEmpty || data.sections.isEmpty) {
          emit(HomeError('Failed to load Narto home'));
          return;
        }

        final activeKey = data.activeProvider.isEmpty
            ? data.providers.first.key
            : data.activeProvider;
        _rawProviders = data.providers;
        sectionsMap[activeKey] = data.sections;
        emit(
          HomeLoaded(
            providerSections: Map.of(sectionsMap),
            nartoProviders: withPseudoProviders(data.providers),
            activeNartoProvider: activeKey,
          ),
        );
      } catch (e) {
        debugPrint('Error preloading Narto: $e');
        final cached = await repository.getCachedHomeSections(
          nartoProviderKey: 'bibishort',
        );
        if (cached != null && cached.isNotEmpty) {
          emit(
            HomeLoaded(
              providerSections: {'bibishort': cached},
              nartoProviders: const [],
              activeNartoProvider: 'bibishort',
            ),
          );
        } else {
          emit(HomeError(e.toString()));
        }
      }
    });

    on<FetchHomeDataEvent>((event, emit) async {
      final key = event.nartoProviderKey;
      if (key == null || key.isEmpty) return;
      if (key == CrossProviderService.adultKey && !adultLockCubit.isUnlocked) {
        return;
      }

      if (state is! HomeLoaded) {
        emit(HomeLoading());
      } else if (state is HomeLoaded &&
          !(state as HomeLoaded).providerSections.containsKey(key)) {
        // Immediately mark the target as active so a shimmer is shown while
        // the (possibly slow) aggregated scan runs.
        emit((state as HomeLoaded).copyWith(activeNartoProvider: key));
      }

      try {
        final sectionsMap = state is HomeLoaded
            ? Map.of((state as HomeLoaded).providerSections)
            : <String, List<DramaSectionModel>>{};

        List<DramaSectionModel> sections;
        if (key == CrossProviderService.dubbedKey) {
          sections = await crossProviderService.getDubbedSections();
        } else if (key == CrossProviderService.adultKey) {
          sections = await crossProviderService.getAdultSections();
        } else {
          sections = await repository.getHomeSections(
            provider: event.provider,
            nartoProviderKey: key,
          );
        }

        sectionsMap[key] = sections;

        if (state is HomeLoaded) {
          emit(
            (state as HomeLoaded).copyWith(
              providerSections: sectionsMap,
              activeNartoProvider: key,
            ),
          );
        } else {
          emit(HomeLoaded(providerSections: sectionsMap, activeNartoProvider: key));
        }
      } catch (e) {
        if (state is! HomeLoaded) {
          emit(_errorFromException(e));
        }
      }
    });

    on<LoadMoreHomeDataEvent>((event, emit) async {
      if (state is! HomeLoaded) return;
      final currentState = state as HomeLoaded;

      final key = event.nartoProviderKey ?? currentState.activeNartoProvider;
      final sectionsMap = Map<String, List<DramaSectionModel>>.from(
        currentState.providerSections,
      );
      final sections = List<DramaSectionModel>.from(
        sectionsMap[key] ?? [],
      );

      if (event.sectionIndex >= sections.length) return;

      final section = sections[event.sectionIndex];
      if (section.name != 'For You') return;
      if (!section.hasMore) return;

      // Prevent duplicate concurrent fetches for the same section: the scroll
      // callbacks can fire faster than the network round-trip, so a plain UI
      // flag is not enough.
      final loadKey = '$key:${event.sectionIndex}';
      if (_loadMoreInFlight.contains(loadKey)) return;
      _loadMoreInFlight.add(loadKey);

      final nextPage = section.currentPage + 1;

      try {
        final moreDramas = await repository.getForYouDramas(
          provider: event.provider,
          nartoProviderKey: key,
          page: nextPage,
        );

        final existingIds = section.dramas.map((d) => d.bookId).toSet();
        final fresh = moreDramas
            .where((d) => !existingIds.contains(d.bookId))
            .toList();

        // The server cycles through a small catalog: page N can repeat earlier
        // titles while a later page holds a few new ones. Only stop after
        // several consecutive pages with no fresh titles so sparse new items
        // are still picked up.
        if (fresh.isEmpty) {
          _emptyPageStreaks[loadKey] = (_emptyPageStreaks[loadKey] ?? 0) + 1;
        } else {
          _emptyPageStreaks[loadKey] = 0;
        }

        debugPrint(
          'LoadMore: key=$key page=$nextPage got=${moreDramas.length} '
          'fresh=${fresh.length} total=${section.dramas.length + fresh.length} '
          'emptyStreak=${_emptyPageStreaks[loadKey]}',
        );

        final exhausted =
            moreDramas.isEmpty || (_emptyPageStreaks[loadKey] ?? 0) >= 3;
        sections[event.sectionIndex] = section.copyWith(
          dramas: [...section.dramas, ...fresh],
          currentPage: nextPage,
          hasMore: !exhausted,
        );

        sectionsMap[key] = sections;
        emit(currentState.copyWith(providerSections: sectionsMap));
      } catch (e) {
        debugPrint("Error loading more dramas: $e");
      } finally {
        _loadMoreInFlight.remove(loadKey);
      }
    });
  }

  HomeError _errorFromException(Object e) {
    return HomeError(e.toString());
  }
}
