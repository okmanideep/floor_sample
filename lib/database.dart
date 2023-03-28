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
      'SELECT * FROM messages WHERE updated_at > :since ORDER BY updated_at DESC LIMIT :limit')
  Stream<List<Message>> getMessagesSince(int since, int limit);

  @Query(
      'SELECT * FROM messages WHERE updated_at < :before ORDER BY updated_at DESC LIMIT :limit')
  Stream<List<Message>> getMessagesBefore(int before, int limit);

  @Query(
      'SELECT * FROM messages WHERE updated_at < :before AND updated_at > :after ORDER BY updated_at DESC LIMIT :limit')
  Stream<List<Message>> getMessagesBetween(int before, int after, int limit);
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
  Stream<List<Message>> getMessagesSince(int since, int limit) async* {
    var dao = await _dao();
    await for (var messages in dao.getMessagesSince(since, limit)) {
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
  Stream<List<Message>> getMessagesBetween(int before, int after, int limit) async* {
    var dao = await _dao();
    await for (var messages in dao.getMessagesBetween(before, after, limit)) {
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
