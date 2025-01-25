// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'saved_chat.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class SavedChatAdapter extends TypeAdapter<SavedChat> {
  @override
  final int typeId = 1;

  @override
  SavedChat read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return SavedChat(
      id: fields[0] as String,
      title: fields[1] as String,
      timestamp: fields[2] as DateTime,
      messages: (fields[3] as List)
          .map((dynamic e) => (e as Map).cast<String, dynamic>())
          .toList(),
    );
  }

  @override
  void write(BinaryWriter writer, SavedChat obj) {
    writer
      ..writeByte(4)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.title)
      ..writeByte(2)
      ..write(obj.timestamp)
      ..writeByte(3)
      ..write(obj.messages);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is SavedChatAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
