import 'package:flutter/material.dart';
import 'dart:io';

import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:dramabox_free/core/di/injection_container.dart' as di;
import 'package:dramabox_free/presentation/blocs/home_bloc.dart';
import 'package:dramabox_free/presentation/blocs/player_bloc.dart';
import 'package:dramabox_free/presentation/blocs/history_bloc.dart';
import 'package:dramabox_free/presentation/blocs/favorites_bloc.dart';
import 'package:dramabox_free/presentation/blocs/downloads_bloc.dart';
import 'package:dramabox_free/presentation/blocs/search_bloc.dart';
import 'package:dramabox_free/presentation/blocs/progressive_search_bloc.dart';
import 'package:dramabox_free/presentation/cubits/navigation_cubit.dart';
import 'package:dramabox_free/presentation/cubits/app_language_cubit.dart';
import 'package:dramabox_free/presentation/cubits/provider_visibility_cubit.dart';
import 'package:dramabox_free/core/services/shorebird_service.dart';
import 'package:dramabox_free/core/services/video_proxy_service.dart';
import 'package:dramabox_free/core/theme/app_theme.dart';
import 'package:dramabox_free/presentation/cubits/app_theme_cubit.dart';
import 'package:dramabox_free/presentation/cubits/adult_lock_cubit.dart';
import 'package:dramabox_free/presentation/cubits/similar_section_cubit.dart';
import 'package:dramabox_free/presentation/cubits/ui_style_cubit.dart';
import 'package:dramabox_free/presentation/cubits/playback_settings_cubit.dart';
import 'package:dramabox_free/presentation/pages/home_page.dart';
import 'package:dramabox_free/presentation/pages/quickplay_home_page.dart';
import 'package:dramabox_free/l10n/generated/app_localizations.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  HttpOverrides.global = MyHttpOverrides();

  await Hive.initFlutter();
  await Hive.openBox('settings');
  await di.init();
  await di.sl<ShorebirdService>().init();
  await di.sl<VideoProxyService>().init();

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiBlocProvider(
      providers: [
        BlocProvider<HomeBloc>(
          create: (context) => di.sl<HomeBloc>()..add(PreloadAllEvent()),
        ),
        BlocProvider<PlayerBloc>(create: (context) => di.sl<PlayerBloc>()),
        BlocProvider<HistoryBloc>(
          create: (context) => di.sl<HistoryBloc>()..add(LoadHistoryEvent()),
        ),
        BlocProvider<FavoritesBloc>(
          create: (context) => di.sl<FavoritesBloc>()..add(LoadFavoritesEvent()),
        ),
        BlocProvider<DownloadsBloc>(
          create: (context) => di.sl<DownloadsBloc>()..add(LoadDownloadsEvent()),
        ),
        BlocProvider<SearchBloc>(
          create: (context) => di.sl<SearchBloc>(),
        ),
        BlocProvider<ProgressiveSearchBloc>(
          create: (context) => di.sl<ProgressiveSearchBloc>(),
        ),
        BlocProvider<NavigationCubit>(
          create: (context) => di.sl<NavigationCubit>(),
        ),
        BlocProvider<AppLanguageCubit>(
          create: (context) => di.sl<AppLanguageCubit>(),
        ),
        BlocProvider<ProviderVisibilityCubit>(
          create: (context) => ProviderVisibilityCubit(),
        ),
        BlocProvider<AppThemeCubit>(
          create: (context) => di.sl<AppThemeCubit>(),
        ),
        BlocProvider<AdultLockCubit>(
          create: (context) => di.sl<AdultLockCubit>(),
        ),
        BlocProvider<SimilarSectionCubit>(
          create: (context) => di.sl<SimilarSectionCubit>(),
        ),
        BlocProvider<UiStyleCubit>(
          create: (context) => di.sl<UiStyleCubit>(),
        ),
        BlocProvider<PlaybackSettingsCubit>(
          create: (context) => di.sl<PlaybackSettingsCubit>(),
        ),
      ],
      child: BlocBuilder<AppLanguageCubit, Locale>(
        builder: (context, locale) {
          return BlocBuilder<AppThemeCubit, ThemeMode>(
            builder: (context, themeMode) {
              return BlocBuilder<UiStyleCubit, UiStyle>(
                builder: (context, uiStyle) {
                  return MaterialApp(
                    title: 'UAETooNDrama',
                    debugShowCheckedModeBanner: false,
                    theme: AppTheme.light,
                    darkTheme: AppTheme.dark,
                    themeMode: themeMode,
                    locale: locale,
                    supportedLocales: AppLocalizations.supportedLocales,
                    localizationsDelegates:
                        AppLocalizations.localizationsDelegates,
                    home: uiStyle == UiStyle.quickplay
                        ? const QuickPlayHomePage()
                        : const HomePage(),
                  );
                },
              );
            },
          );
        },
      ),
    );
  }
}

class MyHttpOverrides extends HttpOverrides {
  @override
  HttpClient createHttpClient(SecurityContext? context) {
    return super.createHttpClient(context)
      ..badCertificateCallback =
          (X509Certificate cert, String host, int port) => true;
  }
}
