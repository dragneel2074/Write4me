// // GENERATED CODE - DO NOT MODIFY BY HAND

// part of 'reminder.dart';

// // **************************************************************************
// // TypeAdapterGenerator
// // **************************************************************************

// class ReminderAdapter extends TypeAdapter<Reminder> {
//   @override
//   final int typeId = 3;

//   @override
//   Reminder read(BinaryReader reader) {
//     final numOfFields = reader.readByte();
//     final fields = <int, dynamic>{
//       for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
//     };
//     return Reminder(
//       id: fields[0] as String?,
//       title: fields[1] as String,
//       dateTime: fields[2] as DateTime,
//       frequency: fields[3] as ReminderFrequency,
//       isActive: fields[4] as bool,
//     );
//   }

//   @override
//   void write(BinaryWriter writer, Reminder obj) {
//     writer
//       ..writeByte(5)
//       ..writeByte(0)
//       ..write(obj.id)
//       ..writeByte(1)
//       ..write(obj.title)
//       ..writeByte(2)
//       ..write(obj.dateTime)
//       ..writeByte(3)
//       ..write(obj.frequency)
//       ..writeByte(4)
//       ..write(obj.isActive);
//   }

//   @override
//   int get hashCode => typeId.hashCode;

//   @override
//   bool operator ==(Object other) =>
//       identical(this, other) ||
//       other is ReminderAdapter &&
//           runtimeType == other.runtimeType &&
//           typeId == other.typeId;
// }

// class ReminderFrequencyAdapter extends TypeAdapter<ReminderFrequency> {
//   @override
//   final int typeId = 2;

//   @override
//   ReminderFrequency read(BinaryReader reader) {
//     switch (reader.readByte()) {
//       case 0:
//         return ReminderFrequency.once;
//       case 1:
//         return ReminderFrequency.daily;
//       case 2:
//         return ReminderFrequency.weekly;
//       case 3:
//         return ReminderFrequency.monthly;
//       case 4:
//         return ReminderFrequency.yearly;
//       default:
//         return ReminderFrequency.once;
//     }
//   }

//   @override
//   void write(BinaryWriter writer, ReminderFrequency obj) {
//     switch (obj) {
//       case ReminderFrequency.once:
//         writer.writeByte(0);
//         break;
//       case ReminderFrequency.daily:
//         writer.writeByte(1);
//         break;
//       case ReminderFrequency.weekly:
//         writer.writeByte(2);
//         break;
//       case ReminderFrequency.monthly:
//         writer.writeByte(3);
//         break;
//       case ReminderFrequency.yearly:
//         writer.writeByte(4);
//         break;
//     }
//   }

//   @override
//   int get hashCode => typeId.hashCode;

//   @override
//   bool operator ==(Object other) =>
//       identical(this, other) ||
//       other is ReminderFrequencyAdapter &&
//           runtimeType == other.runtimeType &&
//           typeId == other.typeId;
// }
