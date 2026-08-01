import 'dart:async';
import 'dart:io';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:dramabox_free/core/localization/app_localizations.dart';
import 'package:dramabox_free/data/models/drama_model.dart';
import 'package:dramabox_free/presentation/widgets/drama_details_sheet.dart';
import 'package:cached_video_player_plus/cached_video_player_plus.dart';
import 'package:video_player/video_player.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:shimmer/shimmer.dart';
import 'package:dramabox_free/data/models/episode_model.dart';
import 'package:dio/dio.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:dramabox_free/core/services/video_proxy_service.dart';
import 'package:dramabox_free/core/services/download_service.dart';
import 'package:dramabox_free/core/di/injection_container.dart' as di;
import 'package:dramabox_free/presentation/cubits/video_control_cubit.dart';
import 'package:dramabox_free/core/constants/app_enums.dart';
import 'video_gesture_overlay.dart';

class VideoPlayerItem extends StatefulWidget {
  final EpisodeModel episode;
  final int index;
  final bool isVisible;
  final String dramaTitle;
  final VoidCallback onBack;
  final VoidCallback? onFinished;
  final VoidCallback? onWatched;
  final void Function(
    int position,
    int duration,
    bool isHistoryUpdate,
    bool isSubtitlesEnabled,
    String? subtitleLanguage,
  )?
  onProgress;
  final int initialPosition;
  final bool initialIsSubtitlesEnabled;
  final String? initialSubtitleLanguage;
  final DramaModel drama;
  final List<EpisodeModel> episodes;
  final Function(int) onEpisodeSelected;
  final AppContentProvider provider;

  /// True 1-based episode number. Falls back to [index] + 1 when null
  /// (used when a downloaded subset of episodes is played).
  final int? episodeNumber;

  /// True total episode count. Falls back to [episodes].length when null.
  final int? totalEpisodes;

  const VideoPlayerItem({
    super.key,
    required this.episode,
    required this.index,
    required this.isVisible,
    required this.dramaTitle,
    required this.onBack,
    this.onFinished,
    this.onWatched,
    this.onProgress,
    this.initialPosition = 0,
    this.initialIsSubtitlesEnabled = true,
    this.initialSubtitleLanguage,
    required this.drama,
    required this.episodes,
    required this.onEpisodeSelected,
    required this.provider,
    this.episodeNumber,
    this.totalEpisodes,
  });

  @override
  State<VideoPlayerItem> createState() => _VideoPlayerItemState();
}

class _VideoPlayerItemState extends State<VideoPlayerItem> {
  CachedVideoPlayerPlus? _player;
  bool _isInitialized = false;
  bool _isInitializing = false;
  bool _hasError = false;
  String _errorMessage = '';
  bool _showUI = true;
  Timer? _hideTimer;
  bool _finishedTriggered = false;
  bool _watchedTriggered = false;
  int _lastReportedSecond = -1;

  // Subtitle state
  SubtitleModel? _selectedSubtitle;
  List<Caption> _captions = [];
  String _currentCaption = '';
  bool _subtitlesEnabled = true;

  late VideoControlCubit _videoControlCubit;

  @override
  void initState() {
    super.initState();
    _videoControlCubit = VideoControlCubit();
    _subtitlesEnabled = widget.initialIsSubtitlesEnabled;
    _selectSubtitle();
    _initializeController();
    _startHideTimer();
  }

  void _selectSubtitle() {
    if (widget.episode.subtitles.isEmpty) return;

    if (widget.initialSubtitleLanguage != null) {
      _selectedSubtitle = widget.episode.subtitles.firstWhere(
        (s) => s.language == widget.initialSubtitleLanguage,
        orElse: () => _getDefaultSubtitle(),
      );
    } else {
      _selectedSubtitle = _getDefaultSubtitle();
    }

    if (_selectedSubtitle != null) {
      _loadSubtitles(_selectedSubtitle!.url);
    }
  }

  void _initializeController() async {
    if (_isInitializing) return;
      if (widget.episode.videoUrl.isEmpty) {
      if (mounted) {
        setState(() {
          _hasError = true;
          _errorMessage = widget.episode.isPlayable
              ? AppStrings.videoUrlEmpty(context)
              : AppStrings.episodeNotAvailable(context);
        });
      }
      return;
    }

    if (mounted) {
      setState(() {
        _isInitializing = true;
        _hasError = false;
        _errorMessage = '';
      });
    }

    try {
      // Downloaded episodes play straight from local storage (no proxy, no
      // faststart reassembly needed since local reads are cheap).
      File? localFile;
      final downloadService = di.sl<DownloadService>();
      final localItem = await downloadService.getDownloadedItem(
        widget.drama.bookId,
        widget.episode.chapterId,
      );
      if (localItem?.filePath != null) {
        final candidate = File(localItem!.filePath!);
        if (await candidate.exists()) {
          localFile = candidate;
        }
      }

      CachedVideoPlayerPlus? player;
      if (localFile != null) {
        debugPrint('DIAG playing downloaded file for ${widget.episode.chapterId}');
        player = CachedVideoPlayerPlus.file(localFile);
      } else {
        String videoUrl = widget.episode.videoUrl;

        // Narto episodes are non-faststart MP4s (moov atom at the end) that
        // ExoPlayer cannot stream progressively, so the proxy reassembles them
        // into a faststart layout via &faststart=1. The await guarantees the
        // reassembly is finished before the player connects, so the first
        // request is served headers immediately (ExoPlayer would otherwise time
        // out waiting while the proxy downloads the file head/tail).
        videoUrl = await di.sl<VideoProxyService>().getProxyUrl(
          videoUrl,
          faststart: true,
        );

        // Check if we have a valid URL before proceeding
        if (videoUrl.isEmpty || !videoUrl.startsWith('http')) {
          throw Exception("Invalid video URL");
        }

        player = CachedVideoPlayerPlus.networkUrl(
          Uri.parse(videoUrl),
          // Narto episodes are large full-length direct MP4s; skip the full-file
          // background cache download to avoid disk/bandwidth exhaustion.
          skipCache: true,
          invalidateCacheIfOlderThan: const Duration(days: 7),
        );
      }

      _player = player;

      final playerRef = _player;
      if (playerRef == null) return;

      await playerRef.initialize();
      playerRef.controller.setLooping(false);
      playerRef.controller.addListener(_videoListener);
      debugPrint(
        'DIAG initialized: dur=${playerRef.controller.value.duration.inMilliseconds} '
        'pos=${playerRef.controller.value.position.inMilliseconds} '
        'ar=${playerRef.controller.value.aspectRatio} '
        'isPlaying=${playerRef.controller.value.isPlaying} '
        'err=${playerRef.controller.value.errorDescription}',
      );

      if (mounted) {
        setState(() {
          _isInitialized = true;
          _isInitializing = false;
        });

        if (widget.initialPosition > 0) {
          _player?.controller.seekTo(
            Duration(milliseconds: widget.initialPosition),
          );
        }

        if (widget.isVisible) {
          _player?.controller.play();
        }
      }
    } catch (e) {
      debugPrint("Error initializing video: $e");
      if (mounted) {
        setState(() {
          _hasError = true;
          _errorMessage = e.toString();
          _isInitializing = false;
        });
      }
    }
  }

  SubtitleModel _getDefaultSubtitle() {
    final subs = widget.episode.subtitles;
    if (subs.isEmpty) {
      return const SubtitleModel(url: '', format: '', language: '');
    }
    SubtitleModel? byLanguage(bool Function(String lang) test) {
      for (final s in subs) {
        if (test(s.language.toLowerCase().trim())) return s;
      }
      return null;
    }

    bool isArabic(String l) =>
        l == 'ar' || l.startsWith('ar-') || l.contains('arabic');
    bool isEnglish(String l) =>
        l == 'en' ||
        l == 'eng' ||
        l.startsWith('en-') ||
        l.contains('english');
    bool isIndonesian(String l) =>
        l == 'id' || l == 'in' || l == 'ind' || l.contains('indonesian') ||
        l.contains('bahasa');

    // Prioritize Arabic, then English, then Indonesian.
    return byLanguage(isArabic) ??
        byLanguage(isEnglish) ??
        byLanguage(isIndonesian) ??
        subs.first;
  }

  SubtitleModel? _findEnglishSubtitle() {
    for (final s in widget.episode.subtitles) {
      final l = s.language.toLowerCase().trim();
      if (l == 'en' || l == 'eng' || l.startsWith('en-') || l.contains('english')) {
        return s;
      }
    }
    return null;
  }

  Future<void> _loadSubtitles(String url) async {
    try {
      String requestUrl = url;
      if (!requestUrl.startsWith('http')) {
        requestUrl =
            'https://narto-drama.com${requestUrl.startsWith('/') ? requestUrl : '/$requestUrl'}';
      }
      final response = await Dio().get(requestUrl);
      if (response.data is String) {
        final content = response.data as String;
        // The parser is now robust enough to handle VTT or SRT
        _parseSubtitles(content);
      }
    } catch (e) {
      debugPrint("Error loading subtitles: $e");
      _trySubtitleFallback();
    }
  }

  /// When the currently selected subtitle fails to load (e.g. an Arabic track
  /// is missing/broken), fall back to the English track if one exists.
  void _trySubtitleFallback() {
    if (!mounted || widget.episode.subtitles.isEmpty) return;
    final current = _selectedSubtitle;
    if (current == null || current.url.isEmpty) return;
    final currentLang = current.language.toLowerCase().trim();
    if (currentLang == 'en' || currentLang.contains('english')) return;
    final fallback = _findEnglishSubtitle();
    if (fallback == null || fallback.url == current.url) return;
    debugPrint('DIAG falling back subtitles to ${fallback.language}');
    setState(() => _selectedSubtitle = fallback);
    _loadSubtitles(fallback.url);
  }

  void _selectSubtitleByLanguage(String? language) {
    setState(() {
      if (language == null) {
        _subtitlesEnabled = false;
        _selectedSubtitle = null;
        _captions = [];
        _currentCaption = '';
        return;
      }
      _subtitlesEnabled = true;
      _selectedSubtitle = widget.episode.subtitles.firstWhere(
        (s) => s.language == language,
        orElse: () => _getDefaultSubtitle(),
      );
      if (_selectedSubtitle!.url.isNotEmpty) {
        _captions = [];
        _currentCaption = '';
        _loadSubtitles(_selectedSubtitle!.url);
      }
    });
  }

  void _showSubtitlePicker() {
    _startHideTimer();
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: const Color(0xFF1C1C20),
      builder: (sheetContext) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                child: Row(
                  children: [
                    Text(
                      AppStrings.subtitles(sheetContext),
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
              ListTile(
                title: Text(
                  AppStrings.subtitleOff(sheetContext),
                  style: const TextStyle(color: Colors.white),
                ),
                trailing: _selectedSubtitle == null || !_subtitlesEnabled
                    ? const Icon(Icons.check, color: Colors.greenAccent)
                    : null,
                onTap: () {
                  _selectSubtitleByLanguage(null);
                  Navigator.pop(sheetContext);
                },
              ),
              for (final sub in widget.episode.subtitles)
                ListTile(
                  title: Text(
                    _subtitleLabel(sub.language),
                    style: const TextStyle(color: Colors.white),
                  ),
                  trailing:
                      _subtitlesEnabled && _selectedSubtitle?.language == sub.language
                          ? const Icon(Icons.check, color: Colors.greenAccent)
                          : null,
                  onTap: () {
                    _selectSubtitleByLanguage(sub.language);
                    Navigator.pop(sheetContext);
                  },
                ),
              const SizedBox(height: 8),
            ],
          ),
        );
      },
    );
  }

  String _subtitleLabel(String language) {
    final l = language.toLowerCase().trim();
    if (l.isEmpty) return 'CC';
    if (l == 'ar' || l.startsWith('ar-') || l.contains('arabic')) return 'العربية';
    if (l == 'en' || l == 'eng' || l.startsWith('en-') || l.contains('english')) {
      return 'English';
    }
    if (l == 'id' ||
        l == 'in' ||
        l == 'ind' ||
        l.startsWith('id-') ||
        l.startsWith('in-') ||
        l.contains('indonesian') ||
        l.contains('bahasa')) {
      return 'Indonesian';
    }
    if (l == 'zh' || l == 'cn' || l.startsWith('zh-') || l.contains('chinese')) return '中文';
    if (l == 'es' || l.startsWith('es-') || l.contains('spanish')) return 'Español';
    if (l == 'fr' || l.startsWith('fr-') || l.contains('french')) return 'Français';
    if (l == 'de' || l.startsWith('de-') || l.contains('german')) return 'Deutsch';
    if (l == 'tr' || l.startsWith('tr-') || l.contains('turkish')) return 'Türkçe';
    if (l == 'ko' || l.startsWith('ko-') || l.contains('korean')) return '한국어';
    if (l == 'ja' || l.startsWith('ja-') || l.contains('japanese')) return '日本語';
    if (l == 'pt' || l.startsWith('pt-') || l.contains('portuguese')) return 'Português';
    if (l == 'ru' || l.startsWith('ru-') || l.contains('russian')) return 'Русский';
    if (l == 'it' || l.startsWith('it-') || l.contains('italian')) return 'Italiano';
    if (l == 'hi' || l.startsWith('hi-') || l.contains('hindi')) return 'हिन्दी';
    return language;
  }

  String _languageCode(String language) {
    final l = language.trim();
    if (l.isEmpty) return 'CC';
    return l.length <= 3 ? l.toUpperCase() : l.substring(0, 3).toUpperCase();
  }

  void _parseSubtitles(String content) {
    try {
      final lines = content.split('\n');
      final List<Caption> captions = [];

      for (int i = 0; i < lines.length; i++) {
        final line = lines[i].trim();
        if (line.contains('-->')) {
          final times = line.split('-->');
          if (times.length == 2) {
            final startTimePart = times[0].trim();
            final endTimeLine = times[1].trim();
            // Handle possibility of space after time (VTT/SRT variance)
            final endTimePart = endTimeLine.split(' ')[0];

            final start = _parseSubtitleTime(startTimePart);
            final end = _parseSubtitleTime(endTimePart);

            // Fetch the text following the time code
            String text = '';
            i++;
            while (i < lines.length && lines[i].trim().isNotEmpty) {
              // Skip numeric lines if it looks like an SRT index
              if (i + 1 < lines.length && lines[i + 1].contains('-->')) {
                // It was just the index, text is still empty or belongs to previous. Break.
                break;
              }

              if (text.isNotEmpty) text += '\n';
              text += lines[i].trim().replaceAll(
                RegExp(r'<[^>]*>'),
                '',
              ); // Basic HTML tag strip
              i++;
            }

            if (text.isNotEmpty && start != Duration.zero) {
              captions.add(
                Caption(
                  number: captions.length,
                  start: start,
                  end: end,
                  text: text,
                ),
              );
            }
          }
        }
      }

      if (mounted) {
        setState(() {
          _captions = captions;
        });
      }
      if (captions.isEmpty) {
        _trySubtitleFallback();
      }
    } catch (e) {
      debugPrint("Error parsing subtitles: $e");
    }
  }

  Duration _parseSubtitleTime(String time) {
    // Robustly handle VTT (00:00:00.000) and SRT (00:00:00,000)
    final timeClean = time.replaceAll(',', '.');
    final parts = timeClean.split(':');

    try {
      if (parts.length == 3) {
        final hours = int.parse(parts[0]);
        final minutes = int.parse(parts[1]);
        final secondsParts = parts[2].split('.');
        final seconds = int.parse(secondsParts[0]);
        final milliseconds = int.parse(
          secondsParts[1].padRight(3, '0').substring(0, 3),
        );
        return Duration(
          hours: hours,
          minutes: minutes,
          seconds: seconds,
          milliseconds: milliseconds,
        );
      } else if (parts.length == 2) {
        final minutes = int.parse(parts[0]);
        final secondsParts = parts[1].split('.');
        final seconds = int.parse(secondsParts[0]);
        final milliseconds = int.parse(
          secondsParts[1].padRight(3, '0').substring(0, 3),
        );
        return Duration(
          minutes: minutes,
          seconds: seconds,
          milliseconds: milliseconds,
        );
      }
    } catch (e) {
      debugPrint("Error parsing time part [$time]: $e");
    }
    return Duration.zero;
  }

  void _updateCurrentCaption(Duration position) {
    if (_captions.isEmpty || !_subtitlesEnabled) {
      if (_currentCaption.isNotEmpty) {
        setState(() => _currentCaption = '');
      }
      return;
    }

    final caption = _captions.firstWhere(
      (c) => position >= c.start && position <= c.end,
      orElse: () => const Caption(
        number: -1,
        start: Duration.zero,
        end: Duration.zero,
        text: '',
      ),
    );

    if (_currentCaption != caption.text) {
      setState(() {
        _currentCaption = caption.text;
      });
    }
  }

  void _videoListener() {
    if (!mounted || !_isInitialized || _player == null) return;

    final player = _player;
    if (player == null) return;
    final position = player.controller.value.position;
    final duration = player.controller.value.duration;

    if (position.inMilliseconds % 10000 < 200 && position.inMilliseconds > 0) {
      debugPrint(
        'DIAG progress: pos=${position.inMilliseconds}ms '
        'dur=${duration.inMilliseconds}ms '
        'ar=${player.controller.value.aspectRatio} '
        'isPlaying=${player.controller.value.isPlaying}',
      );
    }

    _updateCurrentCaption(position);

    if (position >= duration &&
        duration != Duration.zero &&
        !_finishedTriggered) {
      _finishedTriggered = true;
      widget.onFinished?.call();
      // Also ensure watched is triggered if it hasn't been yet (for short episodes)
      if (widget.isVisible && !_watchedTriggered) {
        _watchedTriggered = true;
        widget.onWatched?.call();
      }
    }

    if (widget.isVisible && !_watchedTriggered) {
      final threshold = widget.index == 0 ? 10 : 3;
      if (position.inSeconds >= threshold) {
        _watchedTriggered = true;
        widget.onWatched?.call();
      }
    }

    // Process periodic progress updates
    if (widget.isVisible) {
      final currentSecond = position.inSeconds;
      if (currentSecond != _lastReportedSecond) {
        _lastReportedSecond = currentSecond;
        widget.onProgress?.call(
          position.inMilliseconds,
          duration.inMilliseconds,
          currentSecond % 2 == 0,
          _subtitlesEnabled,
          _selectedSubtitle?.language,
        );
      }
    }
  }

  void _startHideTimer() {
    _hideTimer?.cancel();
    _hideTimer = Timer(const Duration(seconds: 3), () {
      if (mounted) {
        _videoControlCubit.setControlsVisible(false);
      }
    });
  }

  @override
  void didUpdateWidget(VideoPlayerItem oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.episode.videoUrl != widget.episode.videoUrl) {
      _isInitialized = false;
      _finishedTriggered = false;
      _watchedTriggered = false;
      _player?.dispose();
      _player = null;
      _captions = [];
      _currentCaption = '';
      _selectSubtitle();
      _initializeController();
    } else if (_isInitialized) {
      if (widget.isVisible) {
        _player?.controller.play();
      } else {
        _player?.controller.pause();
      }
    }
  }

  @override
  void dispose() {
    _hideTimer?.cancel();
    _player?.dispose();
    _videoControlCubit.close();
    super.dispose();
  }

  void _seek(bool forward) async {
    if (!mounted) return;
    if (!_isInitialized || _player == null) return;
    final player = _player;
    if (player == null) return;
    final currentPosition = player.controller.value.position;
    final seekTo = forward
        ? currentPosition + const Duration(seconds: 3)
        : currentPosition - const Duration(seconds: 3);

    await player.controller.seekTo(seekTo);
    // Clearing seek action is handled by the consumer logic or a timer if needed by UI
  }

  String _formatDuration(Duration duration) {
    String twoDigits(int n) => n.toString().padLeft(2, "0");
    String twoDigitMinutes = twoDigits(duration.inMinutes.remainder(60));
    String twoDigitSeconds = twoDigits(duration.inSeconds.remainder(60));
    return "$twoDigitMinutes:$twoDigitSeconds";
  }

  @override
  Widget build(BuildContext context) {
    return BlocProvider.value(
      value: _videoControlCubit,
      child: BlocConsumer<VideoControlCubit, VideoControlState>(
        listener: (context, state) {
          // Handle side effects like player control
          if (_isInitialized && _player != null) {
            if (state.isSpeedUp) {
              _player!.controller.setPlaybackSpeed(1.5);
            } else {
              _player!.controller.setPlaybackSpeed(1.0);
            }

            if (state.seekAction != null) {
              _seek(state.seekAction == 'forward');
              // Clear the seek action state immediately after processing to prevent loops
              // Or better, let the UI showing "Seek" be the one relying on state
              // Actually the Seek side effect (video position) is handled here.
              // The visual feedback is handled by the builder.
              Future.delayed(const Duration(milliseconds: 500), () {
                if (mounted) {
                  _videoControlCubit.clearSeek();
                }
              });
            }
          }

          if (state.areControlsVisible && !_showUI) {
            setState(() => _showUI = true);
            _startHideTimer();
          } else if (!state.areControlsVisible && _showUI) {
            setState(() => _showUI = false);
          }
        },
        builder: (context, state) {
          return Scaffold(
            backgroundColor: Colors.black,
            body: Stack(
              children: [
                // Background Thumbnail / First Frame
                if (!_isInitialized)
                  Positioned.fill(
                    child: CachedNetworkImage(
                      imageUrl: widget.episode.chapterImg,
                      fit: BoxFit.cover,
                      placeholder: (context, url) => Shimmer.fromColors(
                        baseColor: Colors.grey[900] ?? Colors.black87,
                        highlightColor: Colors.grey[800] ?? Colors.black54,
                        child: Container(color: Colors.black),
                      ),
                      errorWidget: (context, url, error) =>
                          Container(color: Colors.black),
                    ),
                  ),

                Center(
                  child: _isInitialized && _player != null
                      ? Builder(
                          builder: (context) {
                            final player = _player;
                            if (player == null) {
                              return const SizedBox();
                            }
                            return AspectRatio(
                              aspectRatio: player.controller.value.aspectRatio,
                              child: VideoPlayer(player.controller),
                            );
                          },
                        )
                      : const SizedBox(),
                ),

                // Subtitle Overlay
                if (_currentCaption.isNotEmpty && _subtitlesEnabled)
                  Positioned(
                    bottom: _showUI ? 220 : 160,
                    left: 32,
                    right: 32,
                    child: IgnorePointer(
                      child: Center(
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 18,
                            vertical: 10,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.black54,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            _currentCaption,
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              height: 1.2,
                              shadows: [
                                Shadow(
                                  blurRadius: 4,
                                  color: Colors.black,
                                  offset: Offset(1, 1),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),

                // Loading indicator on top of thumbnail if not initialized and no error
                if (!_isInitialized && !_hasError)
                  const Center(
                    child: CircularProgressIndicator(color: Colors.white24),
                  ),

                // Error UI
                if (_hasError)
                  Center(
                    child: Padding(
                      padding: const EdgeInsets.all(20.0),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(
                            Icons.error_outline,
                            color: Colors.white54,
                            size: 60,
                          ),
                          const SizedBox(height: 16),
                          Text(
                            _errorMessage,
                            textAlign: TextAlign.center,
                            style: const TextStyle(color: Colors.white70),
                          ),
                          const SizedBox(height: 20),
                          ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.white24,
                              foregroundColor: Colors.white,
                            ),
                            onPressed: _initializeController,
                            child: Text(AppStrings.retry(context)),
                          ),
                        ],
                      ),
                    ),
                  ),

                // Layer 1: Background Toggle Layer (Handles taps on empty space)
                // Hidden while in error state so the Retry button is reachable.
                if (!_hasError)
                  Positioned.fill(
                    child: VideoGestureOverlay(
                      videoControlCubit: _videoControlCubit,
                    ),
                  ),

                // Visual Feedback for Speed Up
                if (state.isSpeedUp)
                  Positioned(
                    top: MediaQuery.of(context).padding.top + 80,
                    left: 0,
                    right: 0,
                    child: Center(
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 8,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.black54,
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(
                              Icons.fast_forward_rounded,
                              color: Colors.amber,
                              size: 20,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              AppStrings.speedPlaying(context),
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 14,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),

                // Visual Feedback for Seeking
                if (state.seekAction != null)
                  Center(
                    child: Container(
                      padding: const EdgeInsets.all(20),
                      decoration: const BoxDecoration(
                        color: Colors.black38,
                        shape: BoxShape.circle,
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            state.seekAction == 'forward'
                                ? Icons.fast_forward_rounded
                                : Icons.fast_rewind_rounded,
                            color: Colors.white,
                            size: 40,
                          ),
                          const SizedBox(height: 4),
                          const Text(
                            '3s',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                // Layer 2: UI Bars & Buttons
                // Top Bar (Back button + Episode Index)
                AnimatedOpacity(
                  opacity: _showUI ? 1.0 : 0.0,
                  duration: const Duration(milliseconds: 300),
                  child: IgnorePointer(
                    ignoring: !_showUI, // Prevent clicks when hidden
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8.0,
                        vertical: 8.0,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.2),
                        border: Border(
                          bottom: BorderSide(
                            color: Colors.white.withValues(alpha: 0.05),
                            width: 0.5,
                          ),
                        ),
                      ),
                      child: SafeArea(
                        bottom: false,
                        child: Row(
                          children: [
                            GestureDetector(
                              onTap: () {
                                widget.onBack();
                                _startHideTimer();
                              },
                              child: Container(
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: Colors.white.withValues(alpha: 0.1),
                                  shape: BoxShape.circle,
                                  border: Border.all(
                                    color: Colors.white.withValues(alpha: 0.1),
                                    width: 0.5,
                                  ),
                                ),
                                child: ClipRRect(
                                  borderRadius: BorderRadius.circular(20),
                                  child: BackdropFilter(
                                    filter: ImageFilter.blur(
                                      sigmaX: 10,
                                      sigmaY: 10,
                                    ),
                                    child: const Icon(
                                      Icons.arrow_back,
                                      color: Colors.white,
                                      size: 24,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 16),
                            Text(
                              '${AppStrings.ep(context)}. ${widget.episodeNumber ?? widget.index + 1} / ${widget.totalEpisodes ?? widget.episodes.length} ${AppStrings.episodes(context)}',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                letterSpacing: -0.5,
                              ),
                            ),
                            const Spacer(),
                            if (widget.episode.subtitles.isNotEmpty)
                              GestureDetector(
                                onTap: () {
                                  _showSubtitlePicker();
                                },
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 12,
                                    vertical: 6,
                                  ),
                                  decoration: BoxDecoration(
                                    color: _subtitlesEnabled
                                        ? Colors.redAccent.withValues(
                                            alpha: 0.8,
                                          )
                                        : Colors.white.withValues(alpha: 0.1),
                                    borderRadius: BorderRadius.circular(20),
                                    border: Border.all(
                                      color: Colors.white.withValues(
                                        alpha: 0.1,
                                      ),
                                      width: 0.5,
                                    ),
                                  ),
                                  child: ClipRRect(
                                    borderRadius: BorderRadius.circular(20),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Icon(
                                          _subtitlesEnabled
                                              ? Icons.closed_caption
                                              : Icons.closed_caption_disabled,
                                          color: Colors.white,
                                          size: 18,
                                        ),
                                        const SizedBox(width: 4),
                                        Text(
                                          _subtitlesEnabled &&
                                                  _selectedSubtitle != null
                                              ? _languageCode(
                                                  _selectedSubtitle!.language,
                                                )
                                              : 'CC',
                                          style: const TextStyle(
                                            color: Colors.white,
                                            fontSize: 12,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),

                // Bottom UI (Drama Info and Progress Indicator)
                Positioned(
                  bottom: 0,
                  left: 0,
                  right: 0,
                  child: AnimatedOpacity(
                    opacity: _showUI ? 1.0 : 0.0,
                    duration: const Duration(milliseconds: 300),
                    child: IgnorePointer(
                      ignoring: !_showUI, // Prevent clicks when hidden
                      child: Container(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.bottomCenter,
                            end: Alignment.topCenter,
                            colors: [
                              Colors.black.withValues(alpha: 0.8),
                              Colors.black.withValues(alpha: 0.4),
                              Colors.transparent,
                            ],
                          ),
                        ),
                        child: SafeArea(
                          top: false,
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const SizedBox(height: 12),
                              // Controls Row: Play/Pause + Duration
                              Padding(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 16.0,
                                ),
                                child: Row(
                                  children: [
                                    if (_isInitialized && _player != null)
                                      GestureDetector(
                                        onTap: () {
                                          final controller =
                                              _player?.controller;
                                          if (controller == null) return;
                                          if (controller.value.isPlaying) {
                                            controller.pause();
                                          } else {
                                            controller.play();
                                          }
                                          setState(() {});
                                          _startHideTimer();
                                        },
                                        child: Container(
                                          padding: const EdgeInsets.all(4),
                                          decoration: BoxDecoration(
                                            color: Colors.white.withValues(
                                              alpha: 0.1,
                                            ),
                                            shape: BoxShape.circle,
                                            border: Border.all(
                                              color: Colors.white.withValues(
                                                alpha: 0.1,
                                              ),
                                              width: 0.5,
                                            ),
                                          ),
                                          child: ClipRRect(
                                            borderRadius: BorderRadius.circular(
                                              20,
                                            ),
                                            child: BackdropFilter(
                                              filter: ImageFilter.blur(
                                                sigmaX: 10,
                                                sigmaY: 10,
                                              ),
                                              child: Icon(
                                                _player
                                                            ?.controller
                                                            .value
                                                            .isPlaying ??
                                                        false
                                                    ? Icons.pause_rounded
                                                    : Icons.play_arrow_rounded,
                                                color: Colors.white,
                                                size: 32,
                                              ),
                                            ),
                                          ),
                                        ),
                                      ),
                                    const SizedBox(width: 12),
                                    if (_isInitialized && _player != null)
                                      Builder(
                                        builder: (context) {
                                          final player = _player;
                                          if (player == null) {
                                            return const SizedBox();
                                          }
                                          return ValueListenableBuilder(
                                            valueListenable: player.controller,
                                            builder:
                                                (
                                                  context,
                                                  VideoPlayerValue value,
                                                  child,
                                                ) {
                                                  return Text(
                                                    '${_formatDuration(value.position)} / ${_formatDuration(value.duration)}',
                                                    style: const TextStyle(
                                                      color: Colors.white,
                                                      fontSize: 14,
                                                      fontWeight:
                                                          FontWeight.w600,
                                                      fontFeatures: [
                                                        FontFeature.tabularFigures(),
                                                      ],
                                                    ),
                                                  );
                                                },
                                          );
                                        },
                                      ),
                                    const Spacer(),
                                    GestureDetector(
                                      onTap: () {
                                        showModalBottomSheet(
                                          context: context,
                                          isScrollControlled: true,
                                          useSafeArea: true,
                                          backgroundColor: Colors.transparent,
                                          builder: (context) =>
                                              DramaDetailsSheet(
                                                drama: widget.drama,
                                                episodes: widget.episodes,
                                                currentIndex: widget.index,
                                                onEpisodeSelected:
                                                    widget.onEpisodeSelected,
                                              ),
                                        );
                                        _startHideTimer();
                                      },
                                      child: Container(
                                        padding: const EdgeInsets.all(8),
                                        decoration: BoxDecoration(
                                          color: Colors.white.withValues(
                                            alpha: 0.1,
                                          ),
                                          shape: BoxShape.circle,
                                          border: Border.all(
                                            color: Colors.white.withValues(
                                              alpha: 0.15,
                                            ),
                                            width: 1,
                                          ),
                                        ),
                                        child: ClipRRect(
                                          borderRadius: BorderRadius.circular(
                                            20,
                                          ),
                                          child: BackdropFilter(
                                            filter: ImageFilter.blur(
                                              sigmaX: 10,
                                              sigmaY: 10,
                                            ),
                                            child: const Icon(
                                              Icons
                                                  .format_list_bulleted_rounded,
                                              color: Colors.white,
                                              size: 20,
                                            ),
                                          ),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(height: 12),

                              if (_isInitialized && _player != null)
                                Builder(
                                  builder: (context) {
                                    final player = _player;
                                    if (player == null) {
                                      return const SizedBox(height: 4);
                                    }
                                    return Padding(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 16.0,
                                      ),
                                      child: VideoProgressIndicator(
                                        player.controller,
                                        allowScrubbing: true,
                                        colors: const VideoProgressColors(
                                          playedColor: Colors.amber,
                                          bufferedColor: Colors.grey,
                                          backgroundColor: Colors.white24,
                                        ),
                                      ),
                                    );
                                  },
                                )
                              else
                                const SizedBox(height: 4),

                              const SizedBox(height: 16),

                              // Drama Title & Episode Info
                              Padding(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 16.0,
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      widget.dramaTitle,
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 18,
                                        fontWeight: FontWeight.bold,
                                        shadows: [
                                          Shadow(
                                            blurRadius: 10,
                                            color: Colors.black,
                                          ),
                                        ],
                                      ),
                                    ),
                                    const SizedBox(height: 20),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}
