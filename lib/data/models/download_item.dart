import 'package:equatable/equatable.dart';
import '../../core/constants/app_enums.dart';
import 'drama_model.dart';
import 'episode_model.dart';

enum DownloadStatus { queued, downloading, paused, completed, failed }

class DownloadItem extends Equatable {
  final String id;
  final DramaModel drama;
  final EpisodeModel episode;
  final AppContentProvider provider;
  final String nartoProviderKey;
  final DownloadStatus status;
  final int episodeNumber;
  final int totalBytes;
  final int downloadedBytes;
  final DateTime createdAt;
  final DateTime? completedAt;
  final String? filePath;
  final String? error;

  const DownloadItem({
    required this.id,
    required this.drama,
    required this.episode,
    required this.provider,
    required this.status,
    required this.episodeNumber,
    required this.totalBytes,
    required this.downloadedBytes,
    required this.createdAt,
    this.nartoProviderKey = '',
    this.completedAt,
    this.filePath,
    this.error,
  });

  factory DownloadItem.fromJson(Map<String, dynamic> json) {
    return DownloadItem(
      id: json['id'] ?? '',
      drama: DramaModel.fromJson(json['drama'] ?? {}),
      episode: EpisodeModel.fromJson(json['episode'] ?? {}),
      provider: AppContentProvider.values.firstWhere(
        (e) => e.toString() == json['provider'],
        orElse: () => AppContentProvider.narto,
      ),
      nartoProviderKey: json['nartoProviderKey'] ?? '',
      status: DownloadStatus.values.firstWhere(
        (e) => e.name == json['status'],
        orElse: () => DownloadStatus.paused,
      ),
      episodeNumber: json['episodeNumber'] ?? 0,
      totalBytes: json['totalBytes'] ?? 0,
      downloadedBytes: json['downloadedBytes'] ?? 0,
      createdAt: DateTime.tryParse(json['createdAt']?.toString() ?? '') ??
          DateTime.now(),
      completedAt: json['completedAt'] != null
          ? DateTime.tryParse(json['completedAt'].toString())
          : null,
      filePath: json['filePath'],
      error: json['error'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'drama': drama.toJson(),
      'episode': episode.toJson(),
      'provider': provider.toString(),
      'nartoProviderKey': nartoProviderKey,
      'status': status.name,
      'episodeNumber': episodeNumber,
      'totalBytes': totalBytes,
      'downloadedBytes': downloadedBytes,
      'createdAt': createdAt.toIso8601String(),
      'completedAt': completedAt?.toIso8601String(),
      'filePath': filePath,
      'error': error,
    };
  }

  double get progress {
    if (totalBytes <= 0) return 0;
    final p = downloadedBytes / totalBytes;
    return p.clamp(0.0, 1.0);
  }

  DownloadItem copyWith({
    DownloadStatus? status,
    int? totalBytes,
    int? downloadedBytes,
    DateTime? completedAt,
    String? filePath,
    String? error,
    String? nartoProviderKey,
    bool clearError = false,
  }) {
    return DownloadItem(
      id: id,
      drama: drama,
      episode: episode,
      provider: provider,
      nartoProviderKey: nartoProviderKey ?? this.nartoProviderKey,
      status: status ?? this.status,
      episodeNumber: episodeNumber,
      totalBytes: totalBytes ?? this.totalBytes,
      downloadedBytes: downloadedBytes ?? this.downloadedBytes,
      createdAt: createdAt,
      completedAt: completedAt ?? this.completedAt,
      filePath: filePath ?? this.filePath,
      error: clearError ? null : (error ?? this.error),
    );
  }

  @override
  List<Object?> get props => [
    id,
    drama,
    episode,
    provider,
    nartoProviderKey,
    status,
    episodeNumber,
    totalBytes,
    downloadedBytes,
    completedAt,
    filePath,
    error,
  ];
}
