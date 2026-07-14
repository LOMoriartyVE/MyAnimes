// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'anime_list_item.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class UserRatingAdapter extends TypeAdapter<UserRating> {
  @override
  final int typeId = 3;

  @override
  UserRating read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return UserRating(
      overall: fields[0] as double,
      story: fields[1] as double,
      character: fields[2] as double,
      draw: fields[6] as double,
      animation: fields[3] as double,
      music: fields[4] as double,
      notes: fields[5] as String,
    );
  }

  @override
  void write(BinaryWriter writer, UserRating obj) {
    writer
      ..writeByte(7)
      ..writeByte(0)
      ..write(obj.overall)
      ..writeByte(1)
      ..write(obj.story)
      ..writeByte(2)
      ..write(obj.character)
      ..writeByte(3)
      ..write(obj.animation)
      ..writeByte(4)
      ..write(obj.music)
      ..writeByte(5)
      ..write(obj.notes)
      ..writeByte(6)
      ..write(obj.draw);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is UserRatingAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}

class AnimeListItemAdapter extends TypeAdapter<AnimeListItem> {
  @override
  final int typeId = 1;

  @override
  AnimeListItem read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return AnimeListItem(
      animeId: fields[0] as int,
      title: fields[1] as String,
      image: fields[2] as String,
      score: fields[3] as double?,
      genres: (fields[4] as List).cast<String>(),
      category: fields[5] as AnimeCategory,
      addedAt: fields[6] as DateTime?,
      userRating: fields[7] as UserRating?,
      episodes: fields[8] as String,
      episodeProgress: fields[9] == null ? 0 : fields[9] as int,
      type: fields[10] as String?,
      studios: (fields[11] as List?)?.cast<String>(),
      year: fields[12] as String?,
      rank: fields[13] as int?,
      popularity: fields[14] as int?,
      season: fields[15] as String?,
      isMalSynced: fields[16] as bool?,
    );
  }

  @override
  void write(BinaryWriter writer, AnimeListItem obj) {
    writer
      ..writeByte(17)
      ..writeByte(0)
      ..write(obj.animeId)
      ..writeByte(1)
      ..write(obj.title)
      ..writeByte(2)
      ..write(obj.image)
      ..writeByte(3)
      ..write(obj.score)
      ..writeByte(4)
      ..write(obj.genres)
      ..writeByte(5)
      ..write(obj.category)
      ..writeByte(6)
      ..write(obj.addedAt)
      ..writeByte(7)
      ..write(obj.userRating)
      ..writeByte(8)
      ..write(obj.episodes)
      ..writeByte(9)
      ..write(obj.episodeProgress)
      ..writeByte(10)
      ..write(obj.type)
      ..writeByte(11)
      ..write(obj.studios)
      ..writeByte(12)
      ..write(obj.year)
      ..writeByte(13)
      ..write(obj.rank)
      ..writeByte(14)
      ..write(obj.popularity)
      ..writeByte(15)
      ..write(obj.season)
      ..writeByte(16)
      ..write(obj.isMalSynced);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is AnimeListItemAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}

class AnimeCategoryAdapter extends TypeAdapter<AnimeCategory> {
  @override
  final int typeId = 2;

  @override
  AnimeCategory read(BinaryReader reader) {
    switch (reader.readByte()) {
      case 0:
        return AnimeCategory.planned;
      case 1:
        return AnimeCategory.watching;
      case 2:
        return AnimeCategory.completed;
      case 3:
        return AnimeCategory.ignored;
      default:
        return AnimeCategory.planned;
    }
  }

  @override
  void write(BinaryWriter writer, AnimeCategory obj) {
    switch (obj) {
      case AnimeCategory.planned:
        writer.writeByte(0);
        break;
      case AnimeCategory.watching:
        writer.writeByte(1);
        break;
      case AnimeCategory.completed:
        writer.writeByte(2);
        break;
      case AnimeCategory.ignored:
        writer.writeByte(3);
        break;
    }
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is AnimeCategoryAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
