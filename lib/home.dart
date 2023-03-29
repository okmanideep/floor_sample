import 'dart:async';
import 'dart:math';

import 'package:floor_sample/base_page.dart';
import 'package:floor_sample/database.dart';
import 'package:floor_sample/message.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
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

  _Anchor _currentAnchor = _Anchor.latest(100);
  _ServerFetchStatus _serverFetchStatus = _ServerFetchStatus.none;
  ScrollDirection _scrollDirection = ScrollDirection.idle;

  final _uuid = const Uuid();

  Future<void> onPopulateClicked() async {
    _isProcessing.value = true;
    await _populate();
    _isProcessing.value = false;
  }

  bool onScrollNotification(ScrollNotification notification) {
    if (notification is UserScrollNotification) {
      _scrollDirection = notification.direction;
      return true;
    }

    if (notification is ScrollUpdateNotification) {
      if (notification.metrics.isAtEnd) {
        print('At end ${notification.metrics}');
        _onPageEndReaching();
      } else if (notification.metrics.isAtStart) {
        print('At start ${notification.metrics}');
        _onPageStartReaching();
      } else if (_scrollDirection == ScrollDirection.reverse &&
          notification.metrics.isReachingEnd) {
        print('Reaching end ${notification.metrics}');
        _onPageEndReaching();
      } else if (_scrollDirection == ScrollDirection.forward &&
          notification.metrics.isReachingStart) {
        print('Reaching start ${notification.metrics}');
        _onPageStartReaching();
      }
    }
    return true;
  }

  @override
  void onDispose() {
    _subscription?.cancel();
  }

  Future<void> _onPageEndReaching() async {
    if (_messages.value.isEmpty) return;

    final currentAnchor = _currentAnchor;
    if (_messages.value.isEmpty) return;

    if (currentAnchor is _Oldest) return;

    if (currentAnchor is _Older) {
      // messages are likely being fetched right now,
      // after being fetched, the anchor will change to _Between
      // nothing to do here
      return;
    }

    _onAnchorChanged(_Anchor.older(messages.value.middle.updatedAt));
  }

  Future<void> _onPageStartReaching() async {
    final currentAnchor = _currentAnchor;
    if (_messages.value.isEmpty) return;

    if (currentAnchor is _Latest) return;

    if (currentAnchor is _Newer) {
      // messages are likely being fetched right now,
      // after being fetched, the anchor will change to _Between
      // nothing to do here
    }

    _onAnchorChanged(_Anchor.newer(messages.value.middle.updatedAt));
  }

  Future<void> _populate() async {
    for (var i = 0; i < 5; i++) {
      final id = _uuid.v4();
      await messageStore.insertMessage(Message(
        id: id,
        text: 'Message ${id.substring(0, 8)}',
        updatedAt: DateTime.now().secondsSinceEpoch0,
      ));
      await Future.delayed(const Duration(seconds: 2));
    }
  }

  Future<void> _fetchMessagesBeforeFromServer(int before) async {
    final status = _serverFetchStatus;
    if (status is _Fetching) return;
    if (status is _Fetched && before == status.before) return;

    // faking network call
    _serverFetchStatus = _Fetching(before);
    final random = Random();
    await Future.delayed(const Duration(seconds: 1));
    final messages = <Message>[];
    for (var i = 0; i < 25; i++) {
      final id = _uuid.v4();
      messages.add(Message(
        id: id,
        text: 'Message ${id.substring(0, 8)}',
        updatedAt: before - random.nextInt(100),
      ));
    }
    messageStore.insertMessages(messages);
    _serverFetchStatus = _Fetched(before);
  }

  Future<void> _initialize() async {
    _subscription =
        _listenToMessagesForAnchor(_currentAnchor).listen(_onAnchorChanged);
  }

  void _onAnchorChanged(_Anchor anchor) {
    if (_currentAnchor == anchor) return;

    _subscription?.cancel();
    _currentAnchor = anchor;
    _subscription =
        _listenToMessagesForAnchor(_currentAnchor).listen(_onAnchorChanged);
  }

  Stream<_Anchor> _listenToMessagesForAnchor(_Anchor anchor) async* {
    print('Listening to messages for anchor: $anchor');

    if (anchor is _Latest) {
      await for (var messages in messageStore.getLatestMessages(anchor.size)) {
        _messages.value = messages;
        yield anchor;
      }
    } else if (anchor is _Older) {
      await for (var messages
          in messageStore.getMessagesOlderThan(anchor.than, 100)) {
        _Anchor newAnchor = anchor;
        if (messages.length == 100) {
          newAnchor = _Anchor.between(
              messages.last.updatedAt, messages.first.updatedAt);
          _messages.value = messages;
        } else {
          newAnchor = _Anchor.oldest(messages.length + 100);
        }
        yield newAnchor;
      }
    } else if (anchor is _Newer) {
      await for (var messages
          in messageStore.getMessagesNewerThan(anchor.after, 100)) {
        _messages.value = messages;
        _Anchor newAnchor = anchor;
        if (messages.length == 100) {
          newAnchor = _Anchor.between(
              messages.last.updatedAt, messages.first.updatedAt);
        } else {
          //Assume app has all latest messages and update Anchor
          newAnchor = _Anchor.latest(messages.length + 100);
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
      await for (var messages in messageStore.getOldestMessages(anchor.size)) {
        _messages.value = messages;
        yield anchor;
      }
    } else {
      throw ArgumentError('Unknown anchor type: $anchor');
    }
  }
}

abstract class _Anchor {
  factory _Anchor.latest(int size) => _Latest(size);
  factory _Anchor.oldest(int size) => _Oldest(size);
  factory _Anchor.older(int than) => _Older(than);
  factory _Anchor.newer(int than) => _Newer(than);
  factory _Anchor.between(int from, int to) => _Between(from, to);
}

class _Latest implements _Anchor {
  final int size;
  const _Latest(this.size);

  @override
  String toString() => 'Latest($size)';
}

class _Newer implements _Anchor {
  final int after;

  const _Newer(this.after);

  @override
  String toString() => 'Newer($after)';
}

class _Older implements _Anchor {
  final int than;

  const _Older(this.than);

  @override
  String toString() => 'Older($than)';
}

class _Between implements _Anchor {
  final int from;
  final int to;

  const _Between(this.from, this.to);

  @override
  String toString() => 'Between($from, $to)';
}

class _Oldest implements _Anchor {
  final int size;

  const _Oldest(this.size);

  @override
  String toString() => 'Oldest($size)';
}

class HomePage extends BasePage {
  final GlobalKey<AnimatedListState> _listKey = GlobalKey();
  HomePage({super.key});

  void _onMessagesChanged(_, List<Message> messages, List<Message>? oldMessages) {
    if (oldMessages == null || oldMessages.isEmpty || messages.length < 2) return;

    if (oldMessages.first.id == messages[1].id) {
      _listKey.currentState?.insertItem(0);
    }
  }

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
        body: LiveDataListener(
          liveData: viewModel.messages,
          changeListener: _onMessagesChanged,
          child: LiveDataBuilder<List<Message>>(
            liveData: viewModel.messages,
            builder: (_, messages) {
              if (messages.isEmpty) {
                return const Center(child: Text('No messages'));
              }

              return NotificationListener<ScrollNotification>(
                  onNotification: viewModel.onScrollNotification,
                  child: ListView.separated(
                    itemCount: messages.length,
                    reverse: true,
                    findChildIndexCallback: (key) {
                      if (key is ValueKey) {
                        final i = messages.indexWhere((m) => m.id == key.value);
                        if (i < 0) return null;
                        return i;
                      }
                      return null;
                    },
                    separatorBuilder: (_, index) => const SizedBox(height: 8),
                    itemBuilder: (_, index) {
                      return ListTile(
                        key: Key(messages[index].id),
                        title: Text(messages[index].text),
                        subtitle: Text(DateTime.fromMillisecondsSinceEpoch(
                                messages[index].updatedAt * 1000)
                            .toString()),
                      );
                    },
                  ));
            },
        )));
  }
}

abstract class _ServerFetchStatus {
  static const none = _None();
}

class _None implements _ServerFetchStatus {
  const _None();

  @override
  String toString() => 'None';
}

class _Fetching implements _ServerFetchStatus {
  final int before;

  _Fetching(this.before);

  @override
  String toString() => 'Fetching($before)';
}

class _Fetched implements _ServerFetchStatus {
  final int before;

  _Fetched(this.before);

  @override
  String toString() => 'Fetched($before)';
}

extension on DateTime {
  int get secondsSinceEpoch0 => millisecondsSinceEpoch ~/ 1000;
}

extension on ScrollMetrics {
  bool get isAtEnd => extentAfter == 0;
  bool get isAtStart => extentBefore == 0;
  bool get isReachingEnd => extentAfter < 0.25 * maxScrollExtent;
  bool get isReachingStart => extentBefore < 0.25 * maxScrollExtent;
}

extension on List<Message> {
  Message get middle {
    if (isEmpty) throw StateError('List is empty');
    return this[length ~/ 2];
  }
}
