import 'package:get_it/get_it.dart';
import 'package:jetpack/viewmodel.dart';

class AppViewModelFactory implements ViewModelFactory {
  @override
  T create<T extends ViewModel>() {
    return GetIt.I.get<T>();
  }
}
