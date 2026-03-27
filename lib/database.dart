import 'dart:collection';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:fpdart/fpdart.dart';
import 'package:messagepack/messagepack.dart';
import 'package:path_provider/path_provider.dart';
import 'package:tagger/serializer.dart';

typedef ArtistEntry = (
  NonEmptyString, // Artist Name
  List<(NonEmptyString, Uint8List)>, // Tags
  HashSet<NonEmptyString>); // Urls

class ArtistList with ChangeNotifier {
  final List<Artist> _list;

  ArtistList(this._list);

  int get length => _list.length;
  Iterable<Artist> get iterable => _list;

  void add(Artist artist) {
    _list.add(artist);
    notifyListeners();
  }

  void update(int index, Artist artist) {
    _list[index] = artist;
    notifyListeners();
  }

  Artist get(int index) => _list[index];
}

class Database {
  final String _directory_path;
  final ArtistList artists;
  final List<Tag> _tags;
  final HashMap<NonEmptyString/* artist_name */, int /* index in list */> _map_artists;
  final HashMap<int /* tag_id */, int /* index in list */> _map_tags;

  List<Tag> get tags => List.unmodifiable(_tags);
  
  Database._(this._directory_path, this.artists, this._tags, this._map_artists, this._map_tags);

  Option<Tag> get_tag_by_id(int id) => _map_tags.lookup(id).map((i) => _tags[i]);

  bool doesExistArtist(NonEmptyString artist_name) => _map_artists.containsKey(artist_name);

  TaskOption<void> add(ArtistEntry artist_entry) => TaskOption
    .tryCatch(() async => await Directory("$_directory_path/images").create(recursive: true))
    .andThen(() => TaskOption.tryCatch(() async { // Saving images
      for (final tag in artist_entry.$2) {
        await File("$_directory_path/images/${artist_entry.$1.value}-${tag.$1.value}").writeAsBytes(tag.$2);
      }
    }))
    .andThen(() => TaskOption.tryCatch(() async {
      var artist_tags = <ArtistTag>[];
      var new_tags = <Tag>[];

      for (final tag in artist_entry.$2) {
        final tag_id = tag.$1.generateHash();

        if (!_map_tags.containsKey(tag_id)) {
          new_tags.add(Tag(id: tag_id, name:tag.$1));
        }
        artist_tags.add(
          ArtistTag(
            tag_id: tag_id,
            image_url: NonEmptyString.unsafeMake("$_directory_path/images/${artist_entry.$1.value}-${tag.$1.value}")));
      }

      {
      final packer = Packer();
      packer.packListLength(tags.length + new_tags.length);
      for (final tag in Iterable<Tag>.empty().followedBy(tags).followedBy(new_tags)) {
        tag.writeIntoPacker(packer);
      }

      await File("$_directory_path/tags").writeAsBytes(packer.takeBytes());
      }

      final new_artist = Artist(name: artist_entry.$1, tags: artist_tags, urls: artist_entry.$3.toList());
      {
      final packer = Packer();
      _map_artists.lookup(artist_entry.$1)
      .match(
        () {
          packer.packListLength(artists.length+1);
          for (final artist in Iterable<Artist>.empty().followedBy(artists.iterable).followedBy([new_artist])) {
            artist.writeIntoPacker(packer);
          }
        },
        (j) {
          packer.packListLength(artists.length);
          for (var i = 0; i < artists.length; ++i) {
            if (i == j) {
              new_artist.writeIntoPacker(packer);
            } else {
              artists.get(i).writeIntoPacker(packer);
            }
          }
        });
      
      await File("$_directory_path/artists").writeAsBytes(packer.takeBytes());
      }

      // Updating structures
      for (final tag in new_tags) {
        assert(!_map_tags.containsKey(tag.id));
        _tags.add(tag);
        _map_tags[tag.id] = tags.length-1;
      }

      _map_artists.lookup(artist_entry.$1)
        .match(
          () {
            artists.add(new_artist);
            _map_artists[artist_entry.$1] = artists.length-1;
          },
          (i) => artists.update(i, new_artist));
    }))
    .orElse(() => TaskOption(() async {
      for (final tag in artist_entry.$2) {
        final file = File("$_directory_path/images/${artist_entry.$1.value}-${tag.$1.value}");
        if (await file.exists()) {
          try {await file.delete();} catch(_) {}
        }
      }

      {
      final packer = Packer();
      packer.packListLength(tags.length);
      for (final tag in tags) {
        tag.writeIntoPacker(packer);
      }

      try {
        await File("$_directory_path/artists").writeAsBytes(packer.takeBytes());
      } catch(_) {}
      }

      {
      final packer = Packer();
      packer.packListLength(artists.length);
      for (final artist in artists.iterable) {
        artist.writeIntoPacker(packer);
      }

      try {
        await File("$_directory_path/tags").writeAsBytes(packer.takeBytes());
      } catch(_) {}
      }

      return none();
    }));

  static TaskOption<Database> make_from_data() => TaskOption(() async {
    final directory = await getApplicationDocumentsDirectory();

    final artists = await TaskOption.tryCatch(() => File("${directory.path}/artists").readAsBytes())
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

    final map_tags    = HashMap<int, int>.fromEntries(tags.mapWithIndex((tag, i) => MapEntry(tag.id, i)));
    final map_artists = HashMap<NonEmptyString, int>.fromEntries(artists.mapWithIndex((artist, i) => MapEntry(artist.name, i)));

    return some(Database._(directory.path, ArtistList(artists), tags, map_artists, map_tags));
  });
}
