import 'package:equatable/equatable.dart';

class SubtitleModel extends Equatable {
  final String url;
  final String format;
  final String language;

  const SubtitleModel({
    required this.url,
    required this.format,
    required this.language,
  });

  factory SubtitleModel.fromJson(Map<String, dynamic> json) {
    return SubtitleModel(
      url: json['url'] ?? '',
      format: json['url']?.toString().endsWith('.srt') == true ? 'srt' : 'vtt',
      language: json['subtitleLanguage'] ??
          json['language'] ??
          json['captionLanguage'] ??
          '',
    );
  }

  Map<String, dynamic> toJson() {
    return {'url': url, 'format': format, 'subtitleLanguage': language};
  }

  @override
  List<Object?> get props => [url, format, language];
}

class EpisodeModel extends Equatable {
  final String chapterId;
  final String chapterName;
  final String videoUrl;

  /// Secondary source (e.g. narto's own cached mirror) to try when the primary
  /// [videoUrl] fails to load. Empty when no alternative exists.
  final String alternateVideoUrl;
  final String chapterImg;
  final List<SubtitleModel> subtitles;
  final bool isPlayable;

  const EpisodeModel({
    required this.chapterId,
    required this.chapterName,
    required this.videoUrl,
    required this.chapterImg,
    this.alternateVideoUrl = '',
    this.subtitles = const [],
    this.isPlayable = true,
  });

  factory EpisodeModel.fromJson(Map<String, dynamic> json) {
    final List<SubtitleModel> subtitles = [];

    void extractSubtitles(String? key) {
      if (json[key] != null) {
        final list = json[key] as List;
        for (var e in list) {
          if (e is Map<String, dynamic>) {
            final url = e['url']?.toString() ?? e['subtitleUrl']?.toString() ?? '';
            if (url.isNotEmpty && e['captionLanguage'] != 'none') {
              subtitles.add(SubtitleModel.fromJson(e));
            }
          }
        }
      }
    }

    extractSubtitles('subtitles');
    extractSubtitles('subtitleList');
    extractSubtitles('subLanguageVoList');
    extractSubtitles('captionList');

    // Secondary source (narto's own mirror) used as a fallback when the primary
    // video URL is unreachable/expired.
    final alternateUrl = json['alternateVideoUrl']?.toString() ??
        json['direct_play_url']?.toString() ??
        '';

    // Direct videoUrl (already parsed)
    final directUrl = json['videoUrl']?.toString() ?? '';
    if (directUrl.isNotEmpty) {
      return EpisodeModel(
        chapterId: json['chapterId']?.toString() ??
            json['id']?.toString() ??
            json['episodeId']?.toString() ??
            '',
        chapterName: json['chapterName'] ??
            json['name'] ??
            json['episodeName'] ??
            'Episode ${json['episodeNo'] ?? json['sort'] ?? ''}',
        videoUrl: directUrl,
        alternateVideoUrl: alternateUrl == directUrl ? '' : alternateUrl,
        chapterImg: json['chapterImg'] ??
            json['cover'] ??
            json['episodeCover'] ??
            json['thumbnail'] ??
            '',
        subtitles: subtitles,
        isPlayable: (json['isPlayable'] as bool?) ?? true,
      );
    }

    String foundUrl = '';

    // Check playVoucher (Netshort pattern)
    if ((json['playVoucher']?.toString() ?? '').isNotEmpty) {
      foundUrl = json['playVoucher'].toString();
      return EpisodeModel(
        chapterId: json['episodeId']?.toString() ??
            json['chapterId']?.toString() ??
            json['id']?.toString() ??
            '',
        chapterName: json['episodeName'] ??
            json['chapterName'] ??
            json['name'] ??
            'Episode ${json['episodeNo'] ?? ''}',
        videoUrl: foundUrl,
        alternateVideoUrl: alternateUrl == foundUrl ? '' : alternateUrl,
        chapterImg: json['episodeCover'] ??
            json['chapterImg'] ??
            json['cover'] ??
            json['thumbnail'] ??
            '',
        subtitles: subtitles,
        isPlayable: (json['isPlayable'] as bool?) ?? true,
      );
    }

    // cdnList pattern (Dramabox)
    final cdnList = json['cdnList'] as List?;
    if (cdnList != null && cdnList.isNotEmpty) {
      final cdn = cdnList.firstWhere(
        (e) => (e['cdnDomain'] as String?)?.contains('akavideo') ?? false,
        orElse: () => cdnList.first,
      );
      final videoPaths = cdn['videoPathList'] as List?;
      if (videoPaths != null && videoPaths.isNotEmpty) {
        final path = videoPaths.firstWhere(
          (v) => v['quality'] == 720,
          orElse: () => videoPaths.first,
        );
        foundUrl = path['videoPath'] ?? '';
      }
    }

    // Try direct videoUrl field
    if (foundUrl.isEmpty) {
      foundUrl = json['videoUrl']?.toString() ??
          json['url']?.toString() ??
          json['playUrl']?.toString() ??
          '';
    }

    return EpisodeModel(
      chapterId: json['chapterId']?.toString() ??
          json['id']?.toString() ??
          json['episodeId']?.toString() ??
          '',
      chapterName: json['chapterName'] ??
          json['name'] ??
          json['episodeName'] ??
          'Episode ${json['episodeNo'] ?? json['sort'] ?? ''}',
      videoUrl: foundUrl,
      alternateVideoUrl: alternateUrl == foundUrl ? '' : alternateUrl,
      chapterImg: json['chapterImg'] ??
          json['cover'] ??
          json['episodeCover'] ??
          json['thumbnail'] ??
          '',
      subtitles: subtitles,
      isPlayable: foundUrl.isNotEmpty && ((json['isPlayable'] as bool?) ?? true),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'chapterId': chapterId,
      'chapterName': chapterName,
      'videoUrl': videoUrl,
      'alternateVideoUrl': alternateVideoUrl,
      'chapterImg': chapterImg,
      'subtitles': subtitles.map((e) => e.toJson()).toList(),
      'isPlayable': isPlayable,
    };
  }

  @override
  List<Object?> get props => [
    chapterId,
    chapterName,
    videoUrl,
    alternateVideoUrl,
    chapterImg,
    subtitles,
    isPlayable,
  ];
}
