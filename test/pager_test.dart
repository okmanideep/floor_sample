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
    int from = than + 1;
    int to = min(from + limit - 1, end);
    yield List.generate(to - from + 1, (index) => to - index);
  }

  @override
  Stream<List<int>> older(int than, int limit) async* {
    assert(than >= start);
    assert(than <= end);
    int to = than - 1;
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
  IntReverseChronologicalPager(super.dataSource, super.pageSize);

  @override
  int timestamp(int item) {
    return item;
  }
}

void main() {
  test('Reverse Chronological Pagination', () async {
    final dataSource = IntDataSource(1, 10);
    final pager = IntReverseChronologicalPager(dataSource, 5);

    await Future.delayed(const Duration(milliseconds: 0));
    var result = pager.items.value;
    expect(result,
      [10, 9, 8, 7, 6],
    );

    pager.onEndReaching();
    await Future.delayed(const Duration(milliseconds: 0));
    result = pager.items.value;
    expect(result,
      [7, 6, 5, 4, 3],
    );

    pager.onEndReaching();
    await Future.delayed(const Duration(milliseconds: 0));
    result = pager.items.value;
    expect(result,
      [5, 4, 3, 2, 1],
    );

    pager.onEndReaching();
    await Future.delayed(const Duration(milliseconds: 0));
    var previousResult = result;
    result = pager.items.value;
    expect(result,
      previousResult,
    );

    pager.onStartReaching();
    await Future.delayed(const Duration(milliseconds: 0));
    result = pager.items.value;
    expect(result,
      [8, 7, 6, 5, 4],
    );

    pager.onStartReaching();
    await Future.delayed(const Duration(milliseconds: 0));
    result = pager.items.value;
    expect(result,
      [10, 9, 8, 7, 6],
    );

    pager.onStartReaching();
    await Future.delayed(const Duration(milliseconds: 0));
    previousResult = result;
    result = pager.items.value;
    expect(result,
      previousResult,
    );
  });
}
