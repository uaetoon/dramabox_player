import 'package:flutter/foundation.dart';
import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:bloc_concurrency/bloc_concurrency.dart';
import 'package:dramabox_free/core/services/download_service.dart';
import 'package:dramabox_free/data/datasources/download_local_data_source.dart';
import 'package:dramabox_free/data/models/download_item.dart';

// Events
abstract class DownloadsEvent extends Equatable {
  @override
  List<Object?> get props => [];
}

class LoadDownloadsEvent extends DownloadsEvent {}

class StartDownloadEvent extends DownloadsEvent {
  final DownloadItem item;
  StartDownloadEvent(this.item);

  @override
  List<Object?> get props => [item];
}

class PauseDownloadEvent extends DownloadsEvent {
  final String id;
  PauseDownloadEvent(this.id);

  @override
  List<Object?> get props => [id];
}

class RemoveDownloadEvent extends DownloadsEvent {
  final String id;
  RemoveDownloadEvent(this.id);

  @override
  List<Object?> get props => [id];
}

class _DownloadProgressEvent extends DownloadsEvent {
  final DownloadItem item;
  _DownloadProgressEvent(this.item);

  @override
  List<Object?> get props => [item];
}

// States
abstract class DownloadsState extends Equatable {
  @override
  List<Object?> get props => [];
}

class DownloadsInitial extends DownloadsState {}

class DownloadsLoading extends DownloadsState {}

class DownloadsLoaded extends DownloadsState {
  final List<DownloadItem> items;
  DownloadsLoaded(this.items);

  @override
  List<Object?> get props => [items];
}

class DownloadsError extends DownloadsState {
  final String message;
  DownloadsError(this.message);

  @override
  List<Object?> get props => [message];
}

// Bloc
class DownloadsBloc extends Bloc<DownloadsEvent, DownloadsState> {
  final DownloadService service;
  final DownloadLocalDataSource dataSource;

  DownloadsBloc({required this.service, required this.dataSource})
      : super(DownloadsInitial()) {
    on<LoadDownloadsEvent>((event, emit) async {
      emit(DownloadsLoading());
      try {
        final items = await dataSource.getDownloads();
        // A 'downloading' entry with no live CancelToken means the app was
        // restarted mid-download; persist it as paused so it can be resumed.
        var needsPersist = false;
        final settled = items.map((item) {
          if (item.status == DownloadStatus.downloading &&
              !service.isActive(item.id)) {
            needsPersist = true;
            return item.copyWith(status: DownloadStatus.paused);
          }
          return item;
        }).toList();
        if (needsPersist) {
          for (final item in settled) {
            if (item.status == DownloadStatus.paused) {
              await dataSource.saveDownload(item);
            }
          }
        }
        emit(DownloadsLoaded(settled));
      } catch (e) {
        emit(DownloadsError(e.toString()));
      }
    });

    on<StartDownloadEvent>(
      (event, emit) async {
        _mergeProgress(emit, event.item);
        await service.start(
          event.item,
          onProgress: (updated) {
            if (!isClosed) add(_DownloadProgressEvent(updated));
          },
        );
        try {
          final items = await dataSource.getDownloads();
          if (!isClosed) emit(DownloadsLoaded(items));
        } catch (_) {}
      },
      transformer: concurrent(),
    );

    on<_DownloadProgressEvent>((event, emit) {
      _mergeProgress(emit, event.item);
    });

    on<PauseDownloadEvent>((event, emit) async {
      service.cancel(event.id);
      try {
        final current = await dataSource.getDownload(event.id);
        if (current != null) {
          final paused = current.copyWith(status: DownloadStatus.paused);
          await dataSource.saveDownload(paused);
          _mergeProgress(emit, paused);
        }
      } catch (e) {
        debugPrint('DownloadsBloc: pause error: $e');
      }
    });

    on<RemoveDownloadEvent>((event, emit) async {
      await service.delete(event.id);
      try {
        final items = await dataSource.getDownloads();
        if (!isClosed) emit(DownloadsLoaded(items));
      } catch (e) {
        debugPrint('DownloadsBloc: remove error: $e');
      }
    });
  }

  void _mergeProgress(Emitter<DownloadsState> emit, DownloadItem updated) {
    final current = state;
    if (current is DownloadsLoaded) {
      final list = current.items.map((item) {
        return item.id == updated.id ? updated : item;
      }).toList();
      emit(DownloadsLoaded(list));
    } else {
      emit(DownloadsLoaded([updated]));
    }
  }
}
