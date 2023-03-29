import 'package:floor/floor.dart';
import 'package:floor_sample/message.dart';
import 'package:injectable/injectable.dart';

part 'database.g.dart';

@dao
abstract class MessageDao {
  @Insert(onConflict: OnConflictStrategy.replace)
  Future<void> insertMessage(Message message);

  @Insert(onConflict: OnConflictStrategy.replace)
  Future<void> insertMessages(List<Message> messages);

  @Query(
      'SELECT * FROM messages ORDER BY updated_at DESC LIMIT :limit')
  Stream<List<Message>> getLatestMessages(int limit);

  @Query(
      'SELECT * FROM messages WHERE updated_at > :after ORDER BY updated_at DESC LIMIT :limit')
  Stream<List<Message>> getMessagesAfter(int after, int limit);

  @Query(
      'SELECT * FROM messages WHERE updated_at < :before ORDER BY updated_at DESC LIMIT :limit')
  Stream<List<Message>> getMessagesBefore(int before, int limit);

  @Query(
      'SELECT * FROM messages WHERE updated_at <= :upTo ORDER BY updated_at DESC LIMIT :limit')
  Stream<List<Message>> getMessagesUpto(int upTo, int limit);

  @Query(
      'SELECT * FROM messages WHERE updated_at <= :to AND updated_at >= :from ORDER BY updated_at DESC LIMIT :limit')
  Stream<List<Message>> getMessagesBetween(int from, int to, int limit);
}

@Database(version: 1, entities: [Message])
abstract class MessageDatabase extends FloorDatabase {
  MessageDao get messageDao;
}

@singleton
class MessageStore implements MessageDao {
  MessageDao? _backingFieldDao;

  Future<MessageDao> _dao() async{
    _backingFieldDao ??= await $FloorMessageDatabase
          .databaseBuilder('messages.db')
          .build()
          .then((value) => value.messageDao);
    return _backingFieldDao!;
  }

  @override
  Stream<List<Message>> getLatestMessages(int limit) async* {
    var dao = await _dao();
    await for (var messages in dao.getLatestMessages(limit)) {
      yield messages;
    }
  }

  @override
  Stream<List<Message>> getMessagesAfter(int after, int limit) async* {
    var dao = await _dao();
    await for (var messages in dao.getMessagesAfter(after, limit)) {
      yield messages;
    }
  }

  @override
  Stream<List<Message>> getMessagesUpto(int upTo, int limit) async* {
    var dao = await _dao();
    await for (var messages in dao.getMessagesUpto(upTo, limit)) {
      yield messages;
    }
  }

  @override
  Stream<List<Message>> getMessagesBefore(int before, int limit) async* {
    var dao = await _dao();
    await for (var messages in dao.getMessagesBefore(before, limit)) {
      yield messages;
    }
  }

  @override
  Stream<List<Message>> getMessagesBetween(int from, int to, int limit) async* {
    var dao = await _dao();
    await for (var messages in dao.getMessagesBetween(from, to, limit)) {
      yield messages;
    }
  }

  @override
  Future<void> insertMessage(Message message) async {
    var dao = await _dao();
    return dao.insertMessage(message);
  }

  @override
  Future<void> insertMessages(List<Message> messages) async {
    var dao = await _dao();
    return dao.insertMessages(messages);
  }
}
