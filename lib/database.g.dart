// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'database.dart';

// **************************************************************************
// FloorGenerator
// **************************************************************************

// ignore: avoid_classes_with_only_static_members
class $FloorMessageDatabase {
  /// Creates a database builder for a persistent database.
  /// Once a database is built, you should keep a reference to it and re-use it.
  static _$MessageDatabaseBuilder databaseBuilder(String name) =>
      _$MessageDatabaseBuilder(name);

  /// Creates a database builder for an in memory database.
  /// Information stored in an in memory database disappears when the process is killed.
  /// Once a database is built, you should keep a reference to it and re-use it.
  static _$MessageDatabaseBuilder inMemoryDatabaseBuilder() =>
      _$MessageDatabaseBuilder(null);
}

class _$MessageDatabaseBuilder {
  _$MessageDatabaseBuilder(this.name);

  final String? name;

  final List<Migration> _migrations = [];

  Callback? _callback;

  /// Adds migrations to the builder.
  _$MessageDatabaseBuilder addMigrations(List<Migration> migrations) {
    _migrations.addAll(migrations);
    return this;
  }

  /// Adds a database [Callback] to the builder.
  _$MessageDatabaseBuilder addCallback(Callback callback) {
    _callback = callback;
    return this;
  }

  /// Creates the database and initializes it.
  Future<MessageDatabase> build() async {
    final path = name != null
        ? await sqfliteDatabaseFactory.getDatabasePath(name!)
        : ':memory:';
    final database = _$MessageDatabase();
    database.database = await database.open(
      path,
      _migrations,
      _callback,
    );
    return database;
  }
}

class _$MessageDatabase extends MessageDatabase {
  _$MessageDatabase([StreamController<String>? listener]) {
    changeListener = listener ?? StreamController<String>.broadcast();
  }

  MessageDao? _messageDaoInstance;

  Future<sqflite.Database> open(
    String path,
    List<Migration> migrations, [
    Callback? callback,
  ]) async {
    final databaseOptions = sqflite.OpenDatabaseOptions(
      version: 1,
      onConfigure: (database) async {
        await database.execute('PRAGMA foreign_keys = ON');
        await callback?.onConfigure?.call(database);
      },
      onOpen: (database) async {
        await callback?.onOpen?.call(database);
      },
      onUpgrade: (database, startVersion, endVersion) async {
        await MigrationAdapter.runMigrations(
            database, startVersion, endVersion, migrations);

        await callback?.onUpgrade?.call(database, startVersion, endVersion);
      },
      onCreate: (database, version) async {
        await database.execute(
            'CREATE TABLE IF NOT EXISTS `messages` (`id` TEXT PRIMARY KEY AUTOINCREMENT NOT NULL, `text` TEXT NOT NULL, `updated_at` INTEGER NOT NULL)');

        await callback?.onCreate?.call(database, version);
      },
    );
    return sqfliteDatabaseFactory.openDatabase(path, options: databaseOptions);
  }

  @override
  MessageDao get messageDao {
    return _messageDaoInstance ??= _$MessageDao(database, changeListener);
  }
}

class _$MessageDao extends MessageDao {
  _$MessageDao(
    this.database,
    this.changeListener,
  )   : _queryAdapter = QueryAdapter(database, changeListener),
        _messageInsertionAdapter = InsertionAdapter(
            database,
            'messages',
            (Message item) => <String, Object?>{
                  'id': item.id,
                  'text': item.text,
                  'updated_at': item.updatedAt
                },
            changeListener);

  final sqflite.DatabaseExecutor database;

  final StreamController<String> changeListener;

  final QueryAdapter _queryAdapter;

  final InsertionAdapter<Message> _messageInsertionAdapter;

  @override
  Stream<List<Message>> getLatestMessages(int limit) {
    return _queryAdapter.queryListStream(
        'SELECT * FROM messages ORDER BY updated_at DESC LIMIT ?1',
        mapper: (Map<String, Object?> row) => Message(
            id: row['id'] as String,
            text: row['text'] as String,
            updatedAt: row['updated_at'] as int),
        arguments: [limit],
        queryableName: 'messages',
        isView: false);
  }

  @override
  Stream<List<Message>> getMessagesAfter(
    int after,
    int limit,
  ) {
    return _queryAdapter.queryListStream(
        'SELECT * FROM messages WHERE updated_at > ?1 ORDER BY updated_at DESC LIMIT ?2',
        mapper: (Map<String, Object?> row) => Message(
            id: row['id'] as String,
            text: row['text'] as String,
            updatedAt: row['updated_at'] as int),
        arguments: [after, limit],
        queryableName: 'messages',
        isView: false);
  }

  @override
  Stream<List<Message>> getMessagesBefore(
    int before,
    int limit,
  ) {
    return _queryAdapter.queryListStream(
        'SELECT * FROM messages WHERE updated_at < ?1 ORDER BY updated_at DESC LIMIT ?2',
        mapper: (Map<String, Object?> row) => Message(
            id: row['id'] as String,
            text: row['text'] as String,
            updatedAt: row['updated_at'] as int),
        arguments: [before, limit],
        queryableName: 'messages',
        isView: false);
  }

  @override
  Stream<List<Message>> getMessagesUpto(
    int upTo,
    int limit,
  ) {
    return _queryAdapter.queryListStream(
        'SELECT * FROM messages WHERE updated_at <= ?1 ORDER BY updated_at DESC LIMIT ?2',
        mapper: (Map<String, Object?> row) => Message(
            id: row['id'] as String,
            text: row['text'] as String,
            updatedAt: row['updated_at'] as int),
        arguments: [upTo, limit],
        queryableName: 'messages',
        isView: false);
  }

  @override
  Stream<List<Message>> getMessagesBetween(
    int from,
    int to,
    int limit,
  ) {
    return _queryAdapter.queryListStream(
        'SELECT * FROM messages WHERE updated_at <= ?2 AND updated_at >= ?1 ORDER BY updated_at DESC LIMIT ?3',
        mapper: (Map<String, Object?> row) => Message(
            id: row['id'] as String,
            text: row['text'] as String,
            updatedAt: row['updated_at'] as int),
        arguments: [from, to, limit],
        queryableName: 'messages',
        isView: false);
  }

  @override
  Future<void> insertMessage(Message message) async {
    await _messageInsertionAdapter.insert(message, OnConflictStrategy.replace);
  }

  @override
  Future<void> insertMessages(List<Message> messages) async {
    await _messageInsertionAdapter.insertList(
        messages, OnConflictStrategy.replace);
  }
}
