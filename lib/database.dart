import 'dart:async';

import 'package:floor/floor.dart';
import 'package:floor_sample/message.dart';
import 'package:injectable/injectable.dart';
import 'package:sqflite/sqflite.dart' as sqflite;

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
      'SELECT * FROM messages WHERE updated_at >= :timestamp ORDER BY updated_at DESC LIMIT :limit')
  Stream<List<Message>> getMessagesNewerThan(int timestamp, int limit);

  @Query(
      'SELECT * FROM messages WHERE updated_at <= :timestamp ORDER BY updated_at DESC LIMIT :limit')
  Stream<List<Message>> getMessagesOlderThan(int timestamp, int limit);

  @Query(
      'SELECT * FROM messages ORDER BY updated_at DESC LIMIT :limit')
  Stream<List<Message>> getOldestMessages(int limit);

  @Query(
      'SELECT * FROM messages WHERE updated_at <= :to AND updated_at >= :from ORDER BY updated_at DESC')
  Stream<List<Message>> getMessagesBetween(int from, int to);
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
  Stream<List<Message>> getMessagesNewerThan(int timestamp, int limit) async* {
    var dao = await _dao();
    await for (var messages in dao.getMessagesNewerThan(timestamp, limit)) {
      yield messages;
    }
  }

  @override
  Stream<List<Message>> getOldestMessages(int limit) async* {
    var dao = await _dao();
    await for (var messages in dao.getOldestMessages(limit)) {
      yield messages;
    }
  }

  @override
  Stream<List<Message>> getMessagesOlderThan(int timestamp, int limit) async* {
    var dao = await _dao();
    await for (var messages in dao.getMessagesOlderThan(timestamp, limit)) {
      yield messages;
    }
  }

  @override
  Stream<List<Message>> getMessagesBetween(int from, int to) async* {
    var dao = await _dao();
    await for (var messages in dao.getMessagesBetween(from, to)) {
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
