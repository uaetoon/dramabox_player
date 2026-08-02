import 'package:get_it/get_it.dart';
import 'package:dramabox_free/core/services/shorebird_service.dart';
import 'package:dramabox_free/core/services/video_proxy_service.dart';
import 'package:dramabox_free/core/services/download_service.dart';
import 'package:dramabox_free/core/services/cross_provider_service.dart';
import 'package:dramabox_free/core/services/cover_match_service.dart';
import 'package:dramabox_free/data/datasources/drama_local_data_source.dart';
import 'package:dramabox_free/data/datasources/download_local_data_source.dart';
import 'package:dramabox_free/data/datasources/narto_remote_data_source.dart';
import 'package:dramabox_free/data/datasources/shortwave_remote_data_source.dart';
import 'package:dramabox_free/data/repositories/drama_repository_impl.dart';
import 'package:dramabox_free/domain/repositories/drama_repository.dart';
import 'package:dramabox_free/presentation/blocs/home_bloc.dart';
import 'package:dramabox_free/presentation/blocs/player_bloc.dart';
import 'package:dramabox_free/presentation/blocs/history_bloc.dart';
import 'package:dramabox_free/presentation/blocs/favorites_bloc.dart';
import 'package:dramabox_free/presentation/blocs/downloads_bloc.dart';
import 'package:dramabox_free/presentation/blocs/search_bloc.dart';
import 'package:dramabox_free/presentation/blocs/progressive_search_bloc.dart';
import 'package:dramabox_free/presentation/cubits/navigation_cubit.dart';
import 'package:dramabox_free/presentation/cubits/app_language_cubit.dart';
import 'package:dramabox_free/presentation/cubits/app_theme_cubit.dart';
import 'package:dramabox_free/presentation/cubits/adult_lock_cubit.dart';
import 'package:dramabox_free/presentation/cubits/similar_section_cubit.dart';
import 'package:dramabox_free/presentation/cubits/ui_style_cubit.dart';
import 'package:dramabox_free/presentation/cubits/playback_settings_cubit.dart';

final sl = GetIt.instance;

Future<void> init() async {
  // Services
  sl.registerLazySingleton(() => ShorebirdService());
  sl.registerLazySingleton(() => VideoProxyService());
  sl.registerLazySingleton<DownloadService>(
    () => DownloadService(dataSource: sl()),
  );
  sl.registerLazySingleton<CrossProviderService>(
    () => CrossProviderService(remote: sl()),
  );
  sl.registerLazySingleton<CoverMatchService>(
    () => CoverMatchService(remote: sl()),
  );

  // Blocs
  sl.registerFactory(
    () => HomeBloc(
      repository: sl(),
      crossProviderService: sl(),
      adultLockCubit: sl(),
    ),
  );
  sl.registerFactory(() => PlayerBloc(repository: sl()));
  sl.registerFactory(() => HistoryBloc(repository: sl()));
  sl.registerFactory(() => FavoritesBloc(repository: sl()));
  sl.registerFactory(
    () => DownloadsBloc(service: sl(), dataSource: sl()),
  );
  sl.registerFactory(() => SearchBloc(repository: sl()));
  sl.registerFactory(() => ProgressiveSearchBloc(repository: sl()));
  sl.registerLazySingleton(() => NavigationCubit());
  sl.registerLazySingleton(() => AppLanguageCubit());
  sl.registerLazySingleton(() => AppThemeCubit());
  sl.registerLazySingleton(() => AdultLockCubit());
  sl.registerLazySingleton(() => SimilarSectionCubit());
  sl.registerLazySingleton(() => UiStyleCubit());
  sl.registerLazySingleton(() => PlaybackSettingsCubit());

  // Data Sources
  sl.registerLazySingleton<NartoRemoteDataSource>(
    () => NartoRemoteDataSource(),
  );
  sl.registerLazySingleton<ShortWaveRemoteDataSource>(
    () => ShortWaveRemoteDataSource(),
  );
  sl.registerLazySingleton<DramaLocalDataSource>(
    () => DramaLocalDataSourceImpl(),
  );
  sl.registerLazySingleton<DownloadLocalDataSource>(
    () => DownloadLocalDataSourceImpl(),
  );

  // Repositories
  sl.registerLazySingleton<DramaRepository>(
    () => DramaRepositoryImpl(
      nartoDataSource: sl(),
      shortwaveDataSource: sl(),
      localDataSource: sl(),
    ),
  );
}
