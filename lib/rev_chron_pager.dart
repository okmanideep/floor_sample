import 'dart:async';
import 'dart:math';

import 'package:jetpack/livedata.dart';

abstract class ReverseChronologicalPager<T> {
  final MutableLiveData<List<T>> _items = MutableLiveData([]);
  final int initialPageSize;
  final int maxPageSize;
  final ReverseChronologicalDataSource<T> dataSource;
  StreamSubscription? _subscription;
  _Anchor _currentAnchor = _Anchor.nothing;
  _Anchor _fetchedAnchor = _Anchor.nothing;
  bool _itemsRendered = true;

  ReverseChronologicalPager(
      {required this.dataSource,
      required this.initialPageSize,
      required this.maxPageSize}) {
    _onAnchorChanged(_Anchor.latest(initialPageSize));
  }

  String get key => _fetchedAnchor.key();

  // To be implemented by subclasses
  int timestamp(T item);
  LiveData<List<T>> get items => _items;

  bool get isLoading => _currentAnchor != _fetchedAnchor || !_itemsRendered;
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

    if (_items.value.length < maxPageSize) {
      if (currentAnchor is _Latest) {
        _onAnchorChanged(_Anchor.latest(
            min(currentAnchor.size + initialPageSize, maxPageSize)));
      } else if (currentAnchor is _Between) {
        _onAnchorChanged(_Anchor.older(timestamp(_items.value.first),
            min(_items.value.length + initialPageSize, maxPageSize)));
      }
      return;
    }

    // item length is maxed out
    final int targetPageSize = min(maxPageSize, 2 * initialPageSize);
    _onAnchorChanged(_Anchor.older(
        timestamp(_items.value[maxPageSize - (targetPageSize ~/ 2)]),
        targetPageSize));
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

    final currentAnchor = _currentAnchor;
    if (_items.value.length < maxPageSize) {
      if (currentAnchor is _Oldest) {
        _onAnchorChanged(_Anchor.oldest(
            min(currentAnchor.size + initialPageSize, maxPageSize)));
      } else if (currentAnchor is _Between) {
        _onAnchorChanged(_Anchor.newer(timestamp(_items.value.last),
            min(_items.value.length + initialPageSize, maxPageSize)));
      }
      return;
    }

    // item length is maxed out
    final int targetPageSize = min(maxPageSize, 2 * initialPageSize);
    _onAnchorChanged(_Anchor.newer(
        timestamp(_items.value[(targetPageSize ~/ 2) - 1]), targetPageSize));
  }

  void onItemsRendered(List<T> items) {
    _itemsRendered = items == _items.value;
  }

  void onDispose() {
    _subscription?.cancel();
  }

  void _updateItems(List<T> items) {
    if (items == _items.value) return;

    _itemsRendered = false;
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
          _Anchor.latest(anchor.size, isAlsoOldest: items.length < anchor.size);
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
    await for (final items in dataSource.older(anchor.than, anchor.size)) {
      final fetchedAnchor = _fetchedAnchor;
      if (items.isEmpty) {
        if (fetchedAnchor is _Latest) {
          yield _Anchor.latest(anchor.size, isAlsoOldest: true);
        } else if (fetchedAnchor is _Between) {
          yield _Anchor.oldest(anchor.size);
        }
      } else if (items.length < anchor.size) {
        yield _Anchor.oldest(anchor.size);
      } else {
        yield _Anchor.between(
          timestamp(items.last),
          timestamp(items.first),
        );
      }
    }
  }

  Stream<_Anchor> _listenToNewer(_Newer anchor) async* {
    await for (final items in dataSource.newer(anchor.after, anchor.size)) {
      final fetchedAnchor = _fetchedAnchor;
      if (items.isEmpty) {
        if (fetchedAnchor is _Oldest) {
          yield _Anchor.latest(anchor.size, isAlsoOldest: true);
        } else if (fetchedAnchor is _Between) {
          yield _Anchor.latest(anchor.size);
        }
      } else if (items.length < anchor.size) {
        yield _Anchor.latest(anchor.size);
      } else {
        yield _Anchor.between(
          timestamp(items.last),
          timestamp(items.first),
        );
      }
    }
  }

  Stream<_Anchor> _listenToBetween(_Between anchor) async* {
    await for (final items in dataSource.between(anchor.from, anchor.to)) {
      _updateItems(items);
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
  String key();

  static const _Anchor nothing = _Nothing();
  factory _Anchor.latest(int size, {bool isAlsoOldest = false}) =>
      _Latest(size, isAlsoOldest: isAlsoOldest);
  factory _Anchor.oldest(int size) => _Oldest(size);
  factory _Anchor.older(int than, int size) => _Older(than, size);
  factory _Anchor.newer(int than, int size) => _Newer(than, size);
  factory _Anchor.between(int from, int to) => _Between(from, to);
}

class _Nothing implements _Anchor {
  const _Nothing();

  @override
  String key() => 'Nothing';

  @override
  String toString() => 'Nothing';
}

class _Latest implements _Anchor {
  final int size;
  final bool isAlsoOldest;
  const _Latest(this.size, {this.isAlsoOldest = false});

  @override
  String key() => 'Latest';

  @override
  String toString() => 'Latest($size, isAlsoOldest: $isAlsoOldest)';

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is _Latest &&
          runtimeType == other.runtimeType &&
          size == other.size &&
          isAlsoOldest == other.isAlsoOldest;

  @override
  int get hashCode => size.hashCode ^ isAlsoOldest.hashCode;
}

class _Newer implements _Anchor {
  final int after;
  final int size;

  const _Newer(this.after, this.size);

  @override
  String key() => 'Newer($after)';

  @override
  String toString() => 'Newer(after: $after, size: $size)';

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is _Newer &&
          runtimeType == other.runtimeType &&
          after == other.after &&
          size == other.size;

  @override
  int get hashCode => after.hashCode ^ size.hashCode;
}

class _Older implements _Anchor {
  final int than;
  final int size;

  const _Older(this.than, this.size);

  @override
  String key() => 'Older($than)';

  @override
  String toString() => 'Older(than: $than, size: $size)';

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is _Older &&
          runtimeType == other.runtimeType &&
          than == other.than &&
          size == other.size;

  @override
  int get hashCode => than.hashCode ^ size.hashCode;
}

class _Between implements _Anchor {
  final int from;
  final int to;

  const _Between(this.from, this.to);

  @override
  String key() => 'Between($to)';

  @override
  String toString() => 'Between($from, $to)';

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is _Between &&
          runtimeType == other.runtimeType &&
          from == other.from &&
          to == other.to;

  @override
  int get hashCode => from.hashCode ^ to.hashCode;
}

class _Oldest implements _Anchor {
  final int size;

  const _Oldest(this.size);

  @override
  String key() => 'Oldest';

  @override
  String toString() => 'Oldest($size)';

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is _Oldest &&
          runtimeType == other.runtimeType &&
          size == other.size;

  @override
  int get hashCode => size.hashCode;
}

extension MiddleItem<T> on List<T> {
  T get middle {
    if (isEmpty) throw StateError('List is empty');
    return this[length ~/ 2];
  }
}
