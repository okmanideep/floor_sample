import 'package:floor_sample/database.dart';
import 'package:floor_sample/message.dart';
import 'package:floor_sample/rev_chron_pager.dart';
import 'package:injectable/injectable.dart';

@injectable
class MessageDataSource extends ReverseChronologicalDataSource<Message> {
  final MessageStore messageStore;

  MessageDataSource(this.messageStore);

  @override
  Stream<List<Message>> between(int from, int to) async* {
    yield* messageStore.getMessagesBetween(from, to);
  }

  @override
  Stream<List<Message>> latest(int limit) async* {
    yield* messageStore.getLatestMessages(limit);
  }

  @override
  Stream<List<Message>> newer(int than, int limit) async* {
    yield* messageStore.getMessagesNewerThan(than, limit);
  }

  @override
  Stream<List<Message>> older(int than, int limit) async* {
    yield* messageStore.getMessagesOlderThan(than, limit);
  }

  @override
  Stream<List<Message>> oldest(int limit) async* {
    yield* messageStore.getOldestMessages(limit);
  }
}

class MessagePager extends ReverseChronologicalPager<Message> {
  MessagePager(MessageDataSource dataSource, int pageSize)
      : super(dataSource, pageSize);

  @override
  int timestamp(Message item) {
    return item.updatedAt;
  }
}
