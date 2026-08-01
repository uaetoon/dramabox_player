import 'package:equatable/equatable.dart';

class DramaModel extends Equatable {
  final String bookId;
  final String bookName;
  final String coverWap;
  final String introduction;
  final List<String> tags;
  final String protagonist;
  final int chapterCount;
  final int? ranking;
  final String? hotCode;

  /// Narto platform key this drama belongs to ('' = generic/narto-only).
  final String nartoProviderKey;

  const DramaModel({
    required this.bookId,
    required this.bookName,
    required this.coverWap,
    required this.introduction,
    required this.tags,
    required this.protagonist,
    required this.chapterCount,
    this.ranking,
    this.hotCode,
    this.nartoProviderKey = '',
  });

  factory DramaModel.fromJson(Map<String, dynamic> json) {
    final rankVo = json['rankVo'] as Map<String, dynamic>?;
    return DramaModel(
      bookId: json['bookId']?.toString() ??
          json['book_id']?.toString() ??
          json['id']?.toString() ??
          json['shortPlayId']?.toString() ??
          json['contentId']?.toString() ??
          json['dramaId']?.toString() ??
          json['key']?.toString() ??
          '',
      bookName: json['bookName'] ??
          json['book_title'] ??
          json['title'] ??
          json['shortPlayName'] ??
          json['contentName'] ??
          json['dramaName'] ??
          json['name'] ??
          '',
      coverWap: json['coverWap'] ??
          json['book_pic'] ??
          json['cover'] ??
          json['coverVerticalUrl'] ??
          json['shortPlayCover'] ??
          json['poster'] ??
          json['coverWide'] ??
          json['thumbnail'] ??
          '',
      introduction: json['introduction'] ??
          json['description'] ??
          json['special_desc'] ??
          json['desc'] ??
          json['shotIntroduce'] ??
          json['brief'] ??
          json['synopsis'] ??
          '',
      tags: json['tags'] != null
          ? List<String>.from(json['tags'])
          : (json['tagNames'] != null
              ? List<String>.from(json['tagNames'])
              : (json['categories'] != null
                  ? List<String>.from(json['categories'])
                  : (json['labelArray'] != null
                      ? List<String>.from(json['labelArray'])
                      : (json['theme'] != null
                          ? List<String>.from(json['theme'])
                          : (json['tag'] != null
                              ? List<String>.from(json['tag'])
                              : []))))),
      protagonist: json['protagonist'] ??
          json['actor'] ??
          json['cast'] ??
          json['stars'] ??
          '',
      chapterCount:
          int.tryParse(
            (json['chapterCount'] ??
                    json['chapter_count'] ??
                    json['episode_count'] ??
                    json['totalChapter'] ??
                    json['chapterTotal'] ??
                    json['episodeCount'] ??
                    json['totalEpisode'] ??
                    json['episodeTotal'] ??
                    json['totalEpisodes'] ??
                    json['total_count'] ??
                    '0')
                .toString(),
          ) ??
          0,
      ranking: rankVo != null ? rankVo['sort'] : json['ranking'],
      hotCode: rankVo != null
          ? rankVo['hotCode']?.toString()
          : (json['hotCode'] ??
                  json['heatScoreShow'] ??
                  json['scoreShow'] ??
                  json['heat'])
              ?.toString(),
      nartoProviderKey: json['nartoProviderKey']?.toString() ?? '',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'bookId': bookId,
      'bookName': bookName,
      'coverWap': coverWap,
      'introduction': introduction,
      'tags': tags,
      'protagonist': protagonist,
      'chapterCount': chapterCount,
      'ranking': ranking,
      'hotCode': hotCode,
      'nartoProviderKey': nartoProviderKey,
    };
  }

  DramaModel copyWith({
    String? bookId,
    String? bookName,
    String? coverWap,
    String? introduction,
    List<String>? tags,
    String? protagonist,
    int? chapterCount,
    int? ranking,
    String? hotCode,
    String? nartoProviderKey,
  }) {
    return DramaModel(
      bookId: bookId ?? this.bookId,
      bookName: bookName ?? this.bookName,
      coverWap: coverWap ?? this.coverWap,
      introduction: introduction ?? this.introduction,
      tags: tags ?? this.tags,
      protagonist: protagonist ?? this.protagonist,
      chapterCount: chapterCount ?? this.chapterCount,
      ranking: ranking ?? this.ranking,
      hotCode: hotCode ?? this.hotCode,
      nartoProviderKey: nartoProviderKey ?? this.nartoProviderKey,
    );
  }

  @override
  List<Object?> get props => [
    bookId,
    bookName,
    coverWap,
    introduction,
    tags,
    protagonist,
    chapterCount,
    ranking,
    hotCode,
    nartoProviderKey,
  ];
}
