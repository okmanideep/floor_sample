import 'package:floor/floor.dart';

@Entity(tableName: 'messages')
class Message {
	@PrimaryKey()
	String id;
	String text;
	@ColumnInfo(name: 'updated_at')
	int updatedAt;

	Message({
		required this.id,
		required this.text,
		required this.updatedAt
	});

	Message copyWith({
		String? id,
		String? text,
		int? updatedAt
	}) {
		return Message(
			id: id ?? this.id,
			text: text ?? this.text,
			updatedAt: updatedAt ?? this.updatedAt
		);
	}
}
