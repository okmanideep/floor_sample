import 'package:floor_sample/base_page.dart';
import 'package:floor_sample/database.dart';
import 'package:floor_sample/message.dart';
import 'package:flutter/material.dart';
import 'package:flutter/src/widgets/framework.dart';
import 'package:injectable/injectable.dart';
import 'package:jetpack/viewmodel.dart';
import 'package:jetpack/livedata.dart';
import 'package:uuid/uuid.dart';

@injectable
class HomeViewModel extends ViewModel {
  MessageStore messageStore;

  HomeViewModel(this.messageStore);

  final MutableLiveData<bool> _isProcessing = MutableLiveData(false);
  LiveData<bool> get isProcessing => _isProcessing;

  final MutableLiveData<List<Message>> _messages = MutableLiveData([]);
  LiveData<List<Message>> get messages => _messages;

  final _uuid = const Uuid();

  Future<void> onPopulateClicked() async {
    _isProcessing.value = true;
    await _populate();
    _isProcessing.value = false;
  }

  Future<void> _populate() async {
    final messages = <Message>[];
    for (var i = 0; i < 100; i++) {
      final id = _uuid.v4();
      messages.add(Message(
        id: id,
        text: 'Message ${id.substring(0, 8)}',
        updatedAt: DateTime.now().millisecondsSinceEpoch,
      ));
    }
  }
}

class HomePage extends BasePage {
  const HomePage({super.key});

  @override
  Widget buildContent(BuildContext context) {
    var viewModel = context.viewModelProvider.get<HomeViewModel>();
    return Scaffold(
      appBar: AppBar(
        title: const Text('Home'),
        actions: [
          LiveDataBuilder(
              liveData: viewModel.isProcessing,
              builder: (_, isProcessing) {
                if (isProcessing) return const CircularProgressIndicator();

                return IconButton(
                  icon: const Icon(Icons.add_comment),
                  onPressed: () {
                    viewModel.onPopulateClicked();
                  },
                );
              }),
        ],
      ),
      body: const Center(
        child: Text('Home'),
      ),
    );
  }
}
