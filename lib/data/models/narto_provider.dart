import 'package:dramabox_free/data/models/drama_model.dart';
import 'package:dramabox_free/data/models/drama_section_model.dart';

class NartoProvider {
  final String key;
  final String label;

  const NartoProvider({required this.key, required this.label});

  factory NartoProvider.fromJson(Map<String, dynamic> json) {
    final key = json['key']?.toString() ?? '';
    return NartoProvider(
      key: key,
      label: json['label']?.toString() ?? key,
    );
  }
}

class NartoProviderCatalog {
  final List<NartoProvider> providers;
  final String activeProvider;

  const NartoProviderCatalog({
    required this.providers,
    required this.activeProvider,
  });
}

class NartoSection {
  final String tabKey;
  final String tabLabel;
  final List<DramaModel> dramas;

  const NartoSection({
    required this.tabKey,
    required this.tabLabel,
    required this.dramas,
  });
}

class NartoHomeData {
  final List<NartoProvider> providers;
  final String activeProvider;
  final List<DramaSectionModel> sections;

  /// Raw sections retaining the original tab key/label, for cross-provider
  /// aggregation and classification.
  final List<NartoSection> sectionsWithKeys;

  const NartoHomeData({
    required this.providers,
    required this.activeProvider,
    required this.sections,
    this.sectionsWithKeys = const [],
  });
}
