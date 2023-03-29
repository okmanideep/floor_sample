import 'dart:async';

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

  HomeViewModel(this.messageStore) {
    _initialize();
  }

  final MutableLiveData<bool> _isProcessing = MutableLiveData(false);
  LiveData<bool> get isProcessing => _isProcessing;

  final MutableLiveData<List<Message>> _messages = MutableLiveData([]);
  LiveData<List<Message>> get messages => _messages;
  StreamSubscription? _subscription;

  _Anchor _currentAnchor = _Anchor.latest;

  final _uuid = const Uuid();

  Future<void> onPageEndReaching() async {
    if (_messages.value.isEmpty) return;

    // TODO: Fetch more messages from the server?
    if (_messages.value.length < 100) return;

    _subscription?.cancel();
    _currentAnchor = _Anchor.before(_messages.value[49].updatedAt);
    _subscription = _listenToMessagesForAnchor(_currentAnchor).listen((_) {});
  }

  Future<void> onPageStartReaching() async {
    if (_messages.value.isEmpty) return;

    if (_currentAnchor is _Latest) return;
  }

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

  Future<void> _initialize() async {
    _subscription = _listenToMessagesForAnchor(_currentAnchor)
        .listen(_onAnchorYielded);
  }

  void _onAnchorYielded(_Anchor anchor) {
    if (_currentAnchor == anchor) return;

    _subscription?.cancel();
    _currentAnchor = anchor;
    _subscription = _listenToMessagesForAnchor(_currentAnchor)
        .listen(_onAnchorYielded);
  }

  Stream<_Anchor> _listenToMessagesForAnchor(_Anchor anchor) async* {
    if (anchor is _Latest) {
      await for (var messages in messageStore.getLatestMessages(100)) {
        _messages.value = messages;
        yield anchor;
      }
    } else if (anchor is _Before) {
      await for (var messages
          in messageStore.getMessagesBefore(anchor.before, 100)) {
        _messages.value = messages;
        _Anchor newAnchor = anchor;
        if (messages.length == 100) {
          newAnchor = _Anchor.between(messages.last.updatedAt, anchor.before);
        }
        yield newAnchor;
      }
    } else if (anchor is _After) {
      await for (var messages
          in messageStore.getMessagesAfter(anchor.after, 100)) {
        _messages.value = messages;
        _Anchor newAnchor = anchor;
        if (messages.length == 100) {
          newAnchor = _Anchor.between(
              messages.last.updatedAt, messages.first.updatedAt);
        }
        yield newAnchor;
      }
    } else if (anchor is _Between) {
      await for (var messages
          in messageStore.getMessagesBetween(anchor.from, anchor.to, 100)) {
        _messages.value = messages;
        yield anchor;
      }
    } else if (anchor is _Oldest) {
      await for (var messages
          in messageStore.getMessagesBefore(anchor.upTo, 100)) {
        _messages.value = messages;
        yield anchor;
      }
    } else {
      throw ArgumentError('Unknown anchor type: $anchor');
    }
  }
}

abstract class _Anchor {
  static const _Latest latest = _Latest();
  factory _Anchor.oldest(int upTo) => _Oldest(upTo);
  factory _Anchor.before(int before) => _Before(before);
  factory _Anchor.after(int after) => _After(after);
  factory _Anchor.between(int from, int to) => _Between(from, to);
}

class _Latest implements _Anchor {
  const _Latest();
}

class _After implements _Anchor {
  final int after;

  const _After(this.after);
}

class _Before implements _Anchor {
  final int before;

  const _Before(this.before);
}

class _Between implements _Anchor {
  final int from;
  final int to;

  const _Between(this.from, this.to);
}

class _Oldest implements _Anchor {
  final int upTo;

  const _Oldest(this.upTo);
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
