import 'drama_model.dart';

class DramaSectionModel {
  final String name;
  final List<DramaModel> dramas;
  final int currentPage;
  final bool hasMore;

  /// Raw narto tab key (e.g. `for-you`, `feed-stream`) used for pagination.
  /// Empty for non-paginatable / pseudo sections.
  final String tabKey;

  DramaSectionModel({
    required this.name,
    required this.dramas,
    this.currentPage = 1,
    this.hasMore = true,
    this.tabKey = '',
  });

  factory DramaSectionModel.fromJson(Map<String, dynamic> json) {
    return DramaSectionModel(
      name: json['name'] as String,
      dramas: (json['dramas'] as List)
          .map((e) => DramaModel.fromJson(e))
          .toList(),
      currentPage: json['currentPage'] ?? 1,
      hasMore: json['hasMore'] ?? true,
      tabKey: json['tabKey'] ?? '',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'dramas': dramas.map((e) => e.toJson()).toList(),
      'currentPage': currentPage,
      'hasMore': hasMore,
      'tabKey': tabKey,
    };
  }

  DramaSectionModel copyWith({
    String? name,
    List<DramaModel>? dramas,
    int? currentPage,
    bool? hasMore,
    String? tabKey,
  }) {
    return DramaSectionModel(
      name: name ?? this.name,
      dramas: dramas ?? this.dramas,
      currentPage: currentPage ?? this.currentPage,
      hasMore: hasMore ?? this.hasMore,
      tabKey: tabKey ?? this.tabKey,
    );
  }
}
