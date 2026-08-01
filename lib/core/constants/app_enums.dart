enum AppContentProvider { narto }

extension AppContentProviderExtension on AppContentProvider {
  String get displayName {
    return 'Narto';
  }

  String get apiPath {
    return 'narto';
  }
}
