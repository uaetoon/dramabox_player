import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:dramabox_free/core/constants/app_enums.dart';
import 'package:dramabox_free/data/models/drama_model.dart';
import 'package:dramabox_free/domain/repositories/drama_repository.dart';

// Events
abstract class SearchEvent extends Equatable {
  @override
  List<Object?> get props => [];
}

class PerformSearchEvent extends SearchEvent {
  final String query;
  final String? nartoProviderKey;
  PerformSearchEvent(this.query, {this.nartoProviderKey});

  @override
  List<Object?> get props => [query, nartoProviderKey];
}

class ClearSearchEvent extends SearchEvent {}

// States
abstract class SearchState extends Equatable {
  @override
  List<Object?> get props => [];
}

class SearchInitial extends SearchState {}

class SearchLoading extends SearchState {}

class SearchLoaded extends SearchState {
  final String query;
  final List<DramaModel> results;
  SearchLoaded(this.query, this.results);

  @override
  List<Object?> get props => [query, results];
}

class SearchError extends SearchState {
  final String message;
  SearchError(this.message);

  @override
  List<Object?> get props => [message];
}

// Bloc
class SearchBloc extends Bloc<SearchEvent, SearchState> {
  final DramaRepository repository;

  SearchBloc({required this.repository}) : super(SearchInitial()) {
    on<PerformSearchEvent>((event, emit) async {
      if (event.query.trim().isEmpty) {
        emit(SearchInitial());
        return;
      }
      emit(SearchLoading());
      try {
        final results = await repository.searchDramas(
          event.query,
          provider: AppContentProvider.narto,
          nartoProviderKey: event.nartoProviderKey,
        );
        emit(SearchLoaded(event.query, results));
      } catch (e) {
        emit(SearchError(e.toString()));
      }
    });

    on<ClearSearchEvent>((event, emit) => emit(SearchInitial()));
  }
}
