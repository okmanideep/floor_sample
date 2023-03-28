import 'package:flutter/widgets.dart';
import 'package:jetpack/viewmodel.dart';

/// A [StatelessWidget] that provides a [ViewModelScope] to its descendants.
/// All pages in the app are expected to extend this class.
abstract class BasePage extends StatelessWidget {
  const BasePage({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return ViewModelScope(builder: buildContent);
  }

  Widget buildContent(BuildContext context);
}
