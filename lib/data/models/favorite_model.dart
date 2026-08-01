import 'package:equatable/equatable.dart';
import '../../core/constants/app_enums.dart';
import 'drama_model.dart';

class FavoriteModel extends Equatable {
  final DramaModel drama;
  final AppContentProvider provider;
  final String nartoProviderKey;
  final DateTime addedAt;

  const FavoriteModel({
    required this.drama,
    required this.provider,
    required this.addedAt,
    this.nartoProviderKey = '',
  });

  factory FavoriteModel.fromJson(Map<String, dynamic> json) {
    return FavoriteModel(
      drama: DramaModel.fromJson(json['drama'] ?? {}),
      provider: AppContentProvider.values.firstWhere(
        (e) => e.toString() == json['provider'],
        orElse: () => AppContentProvider.narto,
      ),
      nartoProviderKey: json['nartoProviderKey'] ?? '',
      addedAt: DateTime.tryParse(json['addedAt']?.toString() ?? '') ??
          DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'drama': drama.toJson(),
      'provider': provider.toString(),
      'nartoProviderKey': nartoProviderKey,
      'addedAt': addedAt.toIso8601String(),
    };
  }

  @override
  List<Object?> get props => [drama, provider, nartoProviderKey];
}
