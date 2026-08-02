import 'package:equatable/equatable.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:dramabox_free/core/constants/app_enums.dart';
import 'package:dramabox_free/data/models/drama_model.dart';
import 'package:dramabox_free/domain/repositories/drama_repository.dart';

// Events
abstract class ProgressiveSearchEvent extends Equatable {
  @override
  List<Object?> get props => [];
}

class PerformAllSearchEvent extends ProgressiveSearchEvent {
  final String query;

  /// Narto provider keys ('' for generic/narto-wide) to search in parallel.
  final List<String> providerKeys;

  PerformAllSearchEvent(this.query, this.providerKeys);

  @override
  List<Object?> get props => [query, providerKeys];
}

class ClearAllSearchEvent extends ProgressiveSearchEvent {}

// States
abstract class ProgressiveSearchState extends Equatable {
  @override
  List<Object?> get props => [];
}

class ProgressiveSearchInitial extends ProgressiveSearchState {}

class ProgressiveSearchLoading extends ProgressiveSearchState {
  final String query;
  final int totalProviders;

  ProgressiveSearchLoading(this.query, this.totalProviders);

  @override
  List<Object?> get props => [query, totalProviders];
}

/// Emitted repeatedly as each provider's results arrive, so the UI can show
/// results streaming in while the remaining providers finish.
class ProgressiveSearchLoaded extends ProgressiveSearchState {
  final String query;
  final List<DramaModel> results;
  final int completedProviders;
  final int totalProviders;

  ProgressiveSearchLoaded({
    required this.query,
    required this.results,
    required this.completedProviders,
    required this.totalProviders,
  });

  bool get isDone => completedProviders >= totalProviders;

  @override
  List<Object?> get props => [
    query,
    results,
    completedProviders,
    totalProviders,
  ];
}

class ProgressiveSearchError extends ProgressiveSearchState {
  final String message;
  ProgressiveSearchError(this.message);

  @override
  List<Object?> get props => [message];
}

// Bloc
class ProgressiveSearchBloc extends Bloc<
    ProgressiveSearchEvent,
    ProgressiveSearchState> {
  final DramaRepository repository;

  ProgressiveSearchBloc({required this.repository})
    : super(ProgressiveSearchInitial()) {
    on<PerformAllSearchEvent>((event, emit) async {
      if (event.query.trim().isEmpty) {
        emit(ProgressiveSearchInitial());
        return;
      }
      emit(ProgressiveSearchLoading(event.query, event.providerKeys.length));
      try {
        final results = <DramaModel>[];
        final seenBookIds = <String>{};
        var completed = 0;

        Future<void> searchProvider(String providerKey) async {
          List<DramaModel> found;
          try {
            found = await repository.searchDramas(
              event.query,
              provider: AppContentProvider.narto,
              nartoProviderKey: providerKey.isEmpty ? null : providerKey,
            );
          } catch (e) {
            debugPrint(
              'ProgressiveSearch: $providerKey failed: $e',
            );
            found = [];
          }
          completed++;
          for (final drama in found) {
            final id =
                '${providerKey.isEmpty ? 'narto' : providerKey}:${drama.bookId}';
            if (seenBookIds.add(id)) {
              results.add(
                providerKey.isEmpty
                    ? drama
                    : drama.copyWith(nartoProviderKey: providerKey),
              );
            }
          }
          if (completed > 0) {
            emit(
              ProgressiveSearchLoaded(
                query: event.query,
                results: List.of(results),
                completedProviders: completed,
                totalProviders: event.providerKeys.length,
              ),
            );
          }
        }

        await Future.wait([
          for (final key in event.providerKeys) searchProvider(key),
        ]);
      } catch (e) {
        emit(ProgressiveSearchError(e.toString()));
      }
    });

    on<ClearAllSearchEvent>((event, emit) => emit(ProgressiveSearchInitial()));
  }
}
