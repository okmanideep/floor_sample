import 'dart:async';

import 'package:jetpack/livedata.dart';

abstract class ReverseChronologicalPager<T> {
  final MutableLiveData<List<T>> _items = MutableLiveData([]);
  final int pageSize;
  final ReverseChronologicalDataSource<T> dataSource;
  StreamSubscription? _subscription;
  _Anchor _currentAnchor = _Anchor.nothing;
  _Anchor _fetchedAnchor = _Anchor.nothing;
  bool _itemsUpdatedOnUI = true;

  ReverseChronologicalPager(this.dataSource, this.pageSize) {
    _onAnchorChanged(_Anchor.latest(pageSize));
  }

  // To be implemented by subclasses
  int timestamp(T item);
  LiveData<List<T>> get items => _items;

  bool get isLoading => _currentAnchor != _fetchedAnchor || !_itemsUpdatedOnUI;
  bool get isAtStart => _fetchedAnchor is _Latest;
  bool get isAtEnd {
    final anchor = _fetchedAnchor;
    if (anchor is _Oldest) return true;
    if (anchor is _Latest) return anchor.isAlsoOldest;

    return false;
  }

  void onEndReaching() {
    if (_items.value.isEmpty) return;

    // if items are loading ignore
    if (isLoading) return;

    if (_currentAnchor is _Oldest) return;

    final currentAnchor = _currentAnchor;
    if (currentAnchor is _Latest && currentAnchor.isAlsoOldest) {
      return;
    }

    _onAnchorChanged(_Anchor.older(timestamp(_items.value.middle)));
  }

  // called when fetching and adding older items to the data source
  void onOlderItemsFetch() {
    assert(_fetchedAnchor is _Oldest);

    _onAnchorChanged(_Anchor.between(
        timestamp(_items.value.last), timestamp(_items.value.first)));
  }

  void onStartReaching() {
    if (_items.value.isEmpty) return;

    // if items are loading ignore
    if (isLoading) return;

    if (_currentAnchor is _Latest) return;

    _onAnchorChanged(_Anchor.newer(timestamp(_items.value.middle)));
  }

  void onItemsRendered(List<T> items) {
    _itemsUpdatedOnUI = items == _items.value;
  }

  void onDispose() {
    _subscription?.cancel();
  }

  void _updateItems(List<T> items) {
    if (items == _items.value) return;

    _itemsUpdatedOnUI = false;
    _items.value = items;
  }

  void _onAnchorChanged(_Anchor anchor) {
    if (_currentAnchor == anchor) return;

    _currentAnchor = anchor;

    if (_currentAnchor == _fetchedAnchor) return;

    _subscription?.cancel();
    _subscription = _listenToAnchor(_currentAnchor).listen(_onAnchorChanged);
  }

  Stream<_Anchor> _listenToAnchor(_Anchor anchor) async* {
    print('listening to anchor: $anchor');
    if (anchor is _Latest) {
      yield* _listenToLatest(anchor);
    } else if (anchor is _Oldest) {
      yield* _listenToOldest(anchor);
    } else if (anchor is _Older) {
      yield* _listenToOlder(anchor);
    } else if (anchor is _Newer) {
      yield* _listenToNewer(anchor);
    } else if (anchor is _Between) {
      yield* _listenToBetween(anchor);
    }
  }

  Stream<_Anchor> _listenToLatest(_Latest anchor) async* {
    await for (final items in dataSource.latest(anchor.size)) {
      _updateItems(items);
      _fetchedAnchor =
          _Anchor.latest(anchor.size, isAlsoOldest: items.length < pageSize);
      yield _fetchedAnchor;
    }
  }

  Stream<_Anchor> _listenToOldest(_Oldest anchor) async* {
    await for (final items in dataSource.oldest(anchor.size)) {
      _updateItems(items);
      _fetchedAnchor = anchor;
      yield _fetchedAnchor;
    }
  }

  Stream<_Anchor> _listenToOlder(_Older anchor) async* {
    await for (final items in dataSource.older(anchor.than, pageSize)) {
      final fetchedAnchor = _fetchedAnchor;
      if (items.isEmpty) {
        if (fetchedAnchor is _Latest) {
          yield _Anchor.latest(pageSize, isAlsoOldest: true);
        } else if (fetchedAnchor is _Between) {
          yield _Anchor.oldest(pageSize);
        }
      } else if (items.length < pageSize) {
        yield _Anchor.oldest(pageSize);
      } else {
        print('received ${items.length} older items');
        final newAnchor = _Anchor.between(
          timestamp(items.last),
          timestamp(items.first),
        );
        yield newAnchor;
      }
    }
  }

  Stream<_Anchor> _listenToNewer(_Newer anchor) async* {
    await for (final items in dataSource.newer(anchor.after, pageSize)) {
      final fetchedAnchor = _fetchedAnchor;
      if (items.isEmpty) {
        if (fetchedAnchor is _Oldest) {
          yield _Anchor.latest(pageSize, isAlsoOldest: true);
        } else if (fetchedAnchor is _Between) {
          yield _Anchor.latest(pageSize);
        }
      } else if (items.length < pageSize) {
        yield _Anchor.latest(pageSize);
      } else {
        final newAnchor = _Anchor.between(
          timestamp(items.last),
          timestamp(items.first),
        );
        yield newAnchor;
      }
    }
  }

  Stream<_Anchor> _listenToBetween(_Between anchor) async* {
    await for (final items in dataSource.between(anchor.from, anchor.to)) {
      _updateItems(items);
      print('received ${items.length} between items');
      _fetchedAnchor = anchor;
      yield _fetchedAnchor;
    }
  }
}

abstract class ReverseChronologicalDataSource<T> {
  Stream<List<T>> latest(int limit);
  Stream<List<T>> older(int than, int limit);
  Stream<List<T>> between(int from, int to);
  Stream<List<T>> newer(int than, int limit);
  Stream<List<T>> oldest(int limit);
}

abstract class _Anchor {
  static const _Anchor nothing = _Nothing();
  factory _Anchor.latest(int size, {bool isAlsoOldest = false}) =>
      _Latest(size, isAlsoOldest: isAlsoOldest);
  factory _Anchor.oldest(int size) => _Oldest(size);
  factory _Anchor.older(int than) => _Older(than);
  factory _Anchor.newer(int than) => _Newer(than);
  factory _Anchor.between(int from, int to) => _Between(from, to);
}

class _Nothing implements _Anchor {
  const _Nothing();

  @override
  String toString() => 'Nothing';
}

class _Latest implements _Anchor {
  final int size;
  final bool isAlsoOldest;
  const _Latest(this.size, {this.isAlsoOldest = false});

  @override
  String toString() => 'Latest($size, isAlsoOldest: $isAlsoOldest)';
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

extension MiddleItem<T> on List<T> {
  T get middle {
    if (isEmpty) throw StateError('List is empty');
    return this[length ~/ 2];
  }
}
