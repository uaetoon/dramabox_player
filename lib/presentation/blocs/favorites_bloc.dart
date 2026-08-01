import 'package:flutter/foundation.dart';
import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:dramabox_free/core/constants/app_enums.dart';
import 'package:dramabox_free/data/models/drama_model.dart';
import 'package:dramabox_free/data/models/favorite_model.dart';
import 'package:dramabox_free/domain/repositories/drama_repository.dart';

// Events
abstract class FavoritesEvent extends Equatable {
  @override
  List<Object?> get props => [];
}

class LoadFavoritesEvent extends FavoritesEvent {}

class ToggleFavoriteEvent extends FavoritesEvent {
  final DramaModel drama;
  final AppContentProvider provider;
  final String nartoProviderKey;
  ToggleFavoriteEvent(
    this.drama, {
    this.provider = AppContentProvider.narto,
    this.nartoProviderKey = '',
  });

  @override
  List<Object?> get props => [drama, provider, nartoProviderKey];
}

// States
abstract class FavoritesState extends Equatable {
  @override
  List<Object?> get props => [];
}

class FavoritesLoading extends FavoritesState {}

class FavoritesLoaded extends FavoritesState {
  final List<FavoriteModel> favorites;
  FavoritesLoaded(this.favorites);

  @override
  List<Object?> get props => [favorites];
}

class FavoritesError extends FavoritesState {
  final String message;
  FavoritesError(this.message);

  @override
  List<Object?> get props => [message];
}

// Bloc
class FavoritesBloc extends Bloc<FavoritesEvent, FavoritesState> {
  final DramaRepository repository;

  FavoritesBloc({required this.repository}) : super(FavoritesLoading()) {
    on<LoadFavoritesEvent>((event, emit) async {
      emit(FavoritesLoading());
      try {
        final favorites = await repository.getFavorites();
        emit(FavoritesLoaded(favorites));
      } catch (e) {
        emit(FavoritesError(e.toString()));
      }
    });

    on<ToggleFavoriteEvent>((event, emit) async {
      try {
        final exists = await repository.isFavorite(
          event.drama.bookId,
          event.provider,
        );
        if (exists) {
          await repository.removeFavorite(event.drama.bookId, event.provider);
        } else {
          await repository.saveFavorite(
            FavoriteModel(
              drama: event.drama,
              provider: event.provider,
              nartoProviderKey: event.nartoProviderKey,
              addedAt: DateTime.now(),
            ),
          );
        }
        final favorites = await repository.getFavorites();
        emit(FavoritesLoaded(favorites));
      } catch (e) {
        debugPrint('Error toggling favorite: $e');
      }
    });
  }
}
