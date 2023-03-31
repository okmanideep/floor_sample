import 'dart:math';

import 'package:floor_sample/rev_chron_pager.dart';
import 'package:flutter_test/flutter_test.dart';

class IntDataSource extends ReverseChronologicalDataSource<int> {
  final int start;
  final int end;
  IntDataSource(this.start, this.end);

  @override
  Stream<List<int>> between(int from, int to) async* {
    assert(from >= start);
    assert(to <= end);
    yield List.generate(to - from + 1, (index) => to - index);
  }

  @override
  Stream<List<int>> latest(int limit) async* {
    int size = min(limit, end - start + 1);
    yield List.generate(size, (index) => end - index);
  }

  @override
  Stream<List<int>> newer(int than, int limit) async* {
    assert(than >= start);
    assert(than <= end);
    int from = than;
    int to = min(from + limit - 1, end);
    yield List.generate(to - from + 1, (index) => to - index);
  }

  @override
  Stream<List<int>> older(int than, int limit) async* {
    assert(than >= start);
    assert(than <= end);
    int to = than;
    int from = max(to - limit + 1, start);
    yield List.generate(to - from + 1, (index) => to - index);
  }

  @override
  Stream<List<int>> oldest(int limit) async* {
    int size = min(limit, end - start + 1);
    yield List.generate(size, (index) => start + size - 1 - index);
  }
}

class IntReverseChronologicalPager extends ReverseChronologicalPager<int> {
  IntReverseChronologicalPager(
      {required super.dataSource,
      required super.initialPageSize,
      required super.maxPageSize});

  @override
  int timestamp(int item) {
    return item;
  }
}

void main() {
  test('Reverse Chronological Pagination', () async {
    final dataSource = IntDataSource(1, 20);
    final pager = IntReverseChronologicalPager(
        dataSource: dataSource, initialPageSize: 5, maxPageSize: 10);

    await Future.delayed(const Duration(milliseconds: 0));
    var result = pager.items.value;
    pager.onItemsRendered(result);
    expect(
      result,
      [20, 19, 18, 17, 16],
    );

    pager.onEndReaching();
    await Future.delayed(const Duration(milliseconds: 0));
    result = pager.items.value;
    pager.onItemsRendered(result);
    expect(
      result,
      [20, 19, 18, 17, 16, 15, 14, 13, 12, 11],
    );

    pager.onEndReaching();
    await Future.delayed(const Duration(milliseconds: 0));
    result = pager.items.value;
    pager.onItemsRendered(result);
    expect(
      result,
      [15, 14, 13, 12, 11, 10, 9, 8, 7, 6],
    );

    pager.onEndReaching();
    await Future.delayed(const Duration(milliseconds: 0));
    result = pager.items.value;
    pager.onItemsRendered(result);
    expect(
      result,
      [10, 9, 8, 7, 6, 5, 4, 3, 2, 1],
    );

    pager.onEndReaching();
    await Future.delayed(const Duration(milliseconds: 0));
    result = pager.items.value;
    pager.onItemsRendered(result);
    expect(
      result,
      [10, 9, 8, 7, 6, 5, 4, 3, 2, 1],
    );
    expect(pager.isAtEnd, true);

    pager.onStartReaching();
    await Future.delayed(const Duration(milliseconds: 0));
    result = pager.items.value;
    pager.onItemsRendered(result);
    expect(
      result,
      [15, 14, 13, 12, 11, 10, 9, 8, 7, 6],
    );

    pager.onStartReaching();
    await Future.delayed(const Duration(milliseconds: 0));
    result = pager.items.value;
    pager.onItemsRendered(result);
    expect(
      result,
      [20, 19, 18, 17, 16, 15, 14, 13, 12, 11],
    );

    pager.onStartReaching();
    await Future.delayed(const Duration(milliseconds: 0));
    result = pager.items.value;
    pager.onItemsRendered(result);
    expect(
      result,
      [20, 19, 18, 17, 16, 15, 14, 13, 12, 11],
    );
    expect(pager.isAtStart, true);
  });
}
