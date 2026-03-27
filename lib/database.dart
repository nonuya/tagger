import 'dart:collection';
import 'dart:io';
import 'dart:typed_data';

import 'package:fpdart/fpdart.dart';
import 'package:messagepack/messagepack.dart';
import 'package:path_provider/path_provider.dart';
import 'package:tagger/serializer.dart';

typedef ArtistEntry = (NonEmptyString, Iterable<(NonEmptyString, Uint8List)>, Iterable<NonEmptyString>);

class Database {
  final String _directory_path;
  final List<Artist> _artists;
  final List<Tag> _tags;
  final HashMap<NonEmptyString/* artist_name */, int /* index in list */> _map_artists;
  final HashMap<int /* tag_id */, int /* index in list */> _map_tags;

  List<Tag> get tags => List.unmodifiable(_tags);
  List<Artist> get artists => List.unmodifiable(_artists);
  
  Database._(this._directory_path, this._artists, this._tags, this._map_artists, this._map_tags);

  Option<Tag> get_tag_by_id(int id) => _map_tags.lookup(id).map((i) => _tags[i]); 

  /*void add(
    NonEmptyString artist_name,
    Iterable<(NonEmptyString, Uint8List)> tags,
    Iterable<NonEmptyString> urls) {
    var artist_tags = <ArtistTag>[];
    for(var e in tags) {
      final tag_id = e.$1.hashCode;
      if (!_map_tags.containsKey(tag_id)) {
        _tags.add(Tag(id: tag_id, name:e.$1));
        _map_tags[tag_id] = _tags.length-1;
      }
      artist_tags.add(ArtistTag(tag_id: tag_id, image_url: NonEmptyString.unsafeMake("https://encrypted-tbn0.gstatic.com/images?q=tbn:ANd9GcRdUY6-53NESEHhJDAyfXsJigOm9_okUAsgjw&s")));
    }

    final artist = Artist(name: artist_name, tags: artist_tags, urls: urls.toList());
    _map_artists.lookup(artist_name)
      .match(
        () {
          _artists.add(artist);
          _map_artists[artist_name] = _artists.length-1;
        },
        (i) => _artists[i] = artist);
  }*/

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

    final map_tags    = HashMap<int, int>.fromIterable(tags.mapWithIndex((tag, i) => (tag.id, i)));
    final map_artists = HashMap<NonEmptyString, int>.fromIterable(artists.mapWithIndex((artist, i) => (artist.name, i)));

    return some(Database._(directory.path, artists, tags, map_artists, map_tags));
  });
}
