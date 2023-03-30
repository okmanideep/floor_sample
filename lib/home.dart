import 'dart:async';
import 'dart:math';

import 'package:floor_sample/base_page.dart';
import 'package:floor_sample/database.dart';
import 'package:floor_sample/message.dart';
import 'package:floor_sample/message_pager.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:injectable/injectable.dart';
import 'package:jetpack/viewmodel.dart';
import 'package:jetpack/livedata.dart';
import 'package:uuid/uuid.dart';

@injectable
class HomeViewModel extends ViewModel {
  MessageStore messageStore;
  MessagePager messagePager;

  HomeViewModel(this.messageStore, MessageDataSource messageDataSource)
      : messagePager = MessagePager(messageDataSource, 5) {
    scrollController.addListener(_onScrollChanged);
  }

  final MutableLiveData<bool> _isProcessing = MutableLiveData(false);
  LiveData<bool> get isProcessing => _isProcessing;

  LiveData<List<Message>> get messages => messagePager.items;

  ScrollController scrollController = ScrollController();
  _ServerFetchStatus _serverFetchStatus = _ServerFetchStatus.none;

  final _uuid = const Uuid();

  Future<void> onPopulateClicked() async {
    _isProcessing.value = true;
    await _populate();
    _isProcessing.value = false;
  }

  void _onScrollChanged() {
    if (messagePager.isLoading) return;

    if (scrollController.position.isReachingEnd && !messagePager.isAtEnd) {
      print(
          'onScrollChange EndReaching at position: ${scrollController.position}');
      _onPageEndReaching();
    } else if (scrollController.position.isReachingStart &&
        !messagePager.isAtStart) {
      print(
          'onScrollChanged StartReaching at position: ${scrollController.position}');
      _onPageStartReaching();
    }
  }

  void onItemsReceived(List<Message> messages) {
    messagePager.onItemsRendered(messages);
  }

  @override
  void onDispose() {
    messagePager.onDispose();
    super.onDispose();
  }

  Future<void> _onPageEndReaching() async {
    // if (messagePager.isAtEnd) {
    //   if (_serverFetchStatus is _Fetched || _serverFetchStatus is _Fetching) {
    //     return;
    //   }
    //
    //   messagePager.onOlderItemsFetch();
    //   _serverFetchStatus = _ServerFetchStatus.fetching;
    //   // make network call to fetch older messages from server
    //   await _fetchMessagesBeforeFromServer(
    //       messagePager.items.value.last.updatedAt);
    //   _serverFetchStatus = _ServerFetchStatus.fetched;
    //   if (_lastScrollNotification != null) {
    //     onScrollNotification(_lastScrollNotification!);
    //   }
    //   return;
    // }
    messagePager.onEndReaching();
  }

  Future<void> _onPageStartReaching() async {
    messagePager.onStartReaching();
  }

  Future<void> _populate() async {
    final messages = <Message>[];
    for (var i = 0; i < 250; i++) {
      final id = _uuid.v4();
      messages.add(Message(
        id: id,
        text: 'Message ${id.substring(0, 8)}',
        updatedAt: DateTime.now().secondsSinceEpoch0 - i * 2,
      ));
    }
    await messageStore.insertMessages(messages);
  }

  Future<void> _fetchMessagesBeforeFromServer(int before) async {
    await Future.delayed(const Duration(seconds: 1));
    final messages = <Message>[];
    for (var i = 0; i < 25; i++) {
      final id = _uuid.v4();
      messages.add(Message(
        id: id,
        text: 'Message ${id.substring(0, 8)}',
        updatedAt: before - i - 1,
      ));
    }
    messageStore.insertMessages(messages);
  }
}

class HomePage extends BasePage {
  final PageStorageKey _listKey = const PageStorageKey('messages');
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
        body: LiveDataBuilder<List<Message>>(
          liveData: viewModel.messages,
          builder: (_, messages) {
            viewModel.onItemsReceived(messages);
            if (messages.isEmpty) {
              return const Center(child: Text('No messages'));
            }

            print(
                '${messages.length} Messages: [${messages.first.updatedAt} ... ${messages.last.updatedAt}]');

            return ListView.separated(
              key: _listKey,
              itemCount: messages.length,
              reverse: false,
              controller: viewModel.scrollController,
              findChildIndexCallback: (key) {
                if (key is ValueKey<int>) {
                  final i = messages.indexWhere((m) => m.updatedAt == key.value);
                  if (i < 0) {
                    print('findChildIndexCallback: $key not found');
                    return null;
                  }
                  print('findChildIndexCallback: $key found at $i');
                  return i;
                }
                print('findChildIndexCallback: $key not found');
                return null;
              },
              separatorBuilder: (_, index) => const SizedBox(height: 640),
              itemBuilder: (_, index) {
                return ListTile(
                  key: ValueKey(messages[index].updatedAt),
                  title: Text(messages[index].text),
                  subtitle: Text(DateTime.fromMillisecondsSinceEpoch(
                          messages[index].updatedAt * 1000)
                      .toString()),
                );
              },
            );
          },
        ));
  }
}

abstract class _ServerFetchStatus {
  static const none = _None();
  static const fetching = _Fetching();
  static const fetched = _Fetched();
}

class _None implements _ServerFetchStatus {
  const _None();

  @override
  String toString() => 'None';
}

class _Fetching implements _ServerFetchStatus {
  const _Fetching();

  @override
  String toString() => 'Fetching';
}

class _Fetched implements _ServerFetchStatus {
  const _Fetched();

  @override
  String toString() => 'Fetched';
}

extension on DateTime {
  int get secondsSinceEpoch0 => millisecondsSinceEpoch ~/ 1000;
}

extension on ScrollPosition {
  bool get isAtEnd => extentAfter == 0;
  bool get isAtStart => extentBefore == 0;
  bool get isReachingEnd {
    if (userScrollDirection == ScrollDirection.forward) return false;
    if (isAtEnd) return true;
    return pixels > 0.75 * (maxScrollExtent + viewportDimension);
  }

  bool get isReachingStart {
    if (userScrollDirection == ScrollDirection.reverse) return false;
    if (isAtStart) return true;
    return pixels < 0.25 * (maxScrollExtent + viewportDimension);
  }
}
