import 'package:flutter/foundation.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../core/constants/app_enums.dart';

class NavigationCubit extends Cubit<AppContentProvider> {
  NavigationCubit() : super(AppContentProvider.narto);

  void changeProvider(AppContentProvider provider) {
    if (state != provider) {
      debugPrint('Navigation: switching to $provider');
      emit(provider);
    }
  }
}
