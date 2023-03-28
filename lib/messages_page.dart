import 'package:floor_sample/database.dart';
import 'package:injectable/injectable.dart';
import 'package:jetpack/viewmodel.dart';

@injectable
class MessagesViewModel extends ViewModel {
  MessageStore messageStore;
  MessagesViewModel(this.messageStore);

  final MutableLiveData<List<Message>> _messages = MutableLiveData([]);

}
