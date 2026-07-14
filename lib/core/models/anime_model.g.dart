// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'anime_model.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class AnimeModelAdapter extends TypeAdapter<AnimeModel> {
  @override
  final int typeId = 0;

  @override
  AnimeModel read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return AnimeModel(
      id: fields[0] as int,
      title: fields[1] as String,
      japaneseTitle: fields[2] as String,
      image: fields[3] as String,
      score: fields[4] as double?,
      synopsis: fields[5] as String,
      genres: (fields[6] as List).cast<String>(),
      status: fields[7] as String,
      rating: fields[8] as String,
      trailerId: fields[9] as String?,
      studios: (fields[10] as List).cast<String>(),
      episodes: fields[11] as String,
      year: fields[12] as String,
      type: fields[13] as String,
      source: fields[14] as String,
      duration: fields[15] as String,
      members: fields[16] as int?,
      rank: fields[17] as int?,
      popularity: fields[18] as int?,
      airedFrom: fields[19] as String?,
      airedTo: fields[20] as String?,
      broadcastDay: fields[21] as String?,
      broadcastTime: fields[22] as String?,
      season: fields[23] as String?,
      romajiTitle: fields[24] as String?,
    );
  }

  @override
  void write(BinaryWriter writer, AnimeModel obj) {
    writer
      ..writeByte(25)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.title)
      ..writeByte(2)
      ..write(obj.japaneseTitle)
      ..writeByte(3)
      ..write(obj.image)
      ..writeByte(4)
      ..write(obj.score)
      ..writeByte(5)
      ..write(obj.synopsis)
      ..writeByte(6)
      ..write(obj.genres)
      ..writeByte(7)
      ..write(obj.status)
      ..writeByte(8)
      ..write(obj.rating)
      ..writeByte(9)
      ..write(obj.trailerId)
      ..writeByte(10)
      ..write(obj.studios)
      ..writeByte(11)
      ..write(obj.episodes)
      ..writeByte(12)
      ..write(obj.year)
      ..writeByte(13)
      ..write(obj.type)
      ..writeByte(14)
      ..write(obj.source)
      ..writeByte(15)
      ..write(obj.duration)
      ..writeByte(16)
      ..write(obj.members)
      ..writeByte(17)
      ..write(obj.rank)
      ..writeByte(18)
      ..write(obj.popularity)
      ..writeByte(19)
      ..write(obj.airedFrom)
      ..writeByte(20)
      ..write(obj.airedTo)
      ..writeByte(21)
      ..write(obj.broadcastDay)
      ..writeByte(22)
      ..write(obj.broadcastTime)
      ..writeByte(23)
      ..write(obj.season)
      ..writeByte(24)
      ..write(obj.romajiTitle);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is AnimeModelAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
