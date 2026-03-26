import 'dart:collection';
import 'dart:io';

import 'package:fpdart/fpdart.dart';
import 'package:messagepack/messagepack.dart';
import 'package:path_provider/path_provider.dart';
import 'package:tagger/serializer.dart';

class Database {
  final String _directory_path;
  final List<Artist> _artists;
  final List<Tag> _tags;
  final HashMap<int /* tag_id */, int /* index in list */> _map_tags;

  List<Tag> get tags => List.unmodifiable(_artists);

  Database._(this._directory_path, this._artists, this._tags, this._map_tags);

  static TaskOption<Database> make_from_data() => TaskOption(() async {
    final directory = await getApplicationDocumentsDirectory();

    final artists = await TaskOption.tryCatch(() => File("${directory.path}/artist").readAsBytes())
      .flatMap((bytes) {
        final unpacker = Unpacker(bytes);
        return List.generate(
          unpacker.unpackListLength(),
          (_) => Artist.makeFromUnpacker(unpacker))
          .sequenceOption()
          .toTaskOption();
      })
      .getOrElse(() => [])
      .run();

    final tags = await TaskOption.tryCatch(() => File("${directory.path}/tags").readAsBytes())
      .flatMap((bytes) {
        final unpacker = Unpacker(bytes);
        return List.generate(
          unpacker.unpackListLength(),
          (_) => Tag.makeFromUnpacker(unpacker))
          .sequenceOption()
          .toTaskOption();
      })
      .getOrElse(() => [])
      .run();

    final map_tags = HashMap<int, int>.fromIterable(tags.mapWithIndex((tag, i) => (tag.id, i)));
    
    return some(Database._(directory.path, artists, tags, map_tags));
  });
}
