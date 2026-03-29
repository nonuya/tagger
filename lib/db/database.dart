import 'dart:collection';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:fpdart/fpdart.dart';
import 'package:messagepack/messagepack.dart';
import 'package:path_provider/path_provider.dart';
import 'package:tagger/db/tables.dart';

typedef ArtistEntry = (
  NonEmptyString, // Artist Name
  HashMap<NonEmptyString, Option<Uint8List>>, // Tags
  HashSet<NonEmptyString>); // Urls

class _ArtistList with ChangeNotifier {
  final HashMap<NonEmptyString, Artist> container;

  _ArtistList(this.container);

  int get length => container.length;

  void operator[]=(NonEmptyString key, Artist value) {
    container[key] = value;
    notifyListeners();
  }

  Option<Artist> get(NonEmptyString name) => container.lookup(name);

  bool contains(NonEmptyString name) => container.containsKey(name);

  void removeAt(NonEmptyString name) {
    container.remove(name);
    notifyListeners();
  }
}

class Database {
  final String _directory_path;
  final _ArtistList _artists;
  final TagTable _tag_table;

  Iterable<Tag> get tags => List.unmodifiable(_tag_table.tags);
  
  Database._(this._directory_path, List<Artist> artists, this._tag_table) :
    _artists = _ArtistList(HashMap.fromIterable(artists, key: (e) => e.name, value: (e) => e));

  Tag get_tag_by_id(int id) => _tag_table.get_tag(id);

  ChangeNotifier get_artists_notifier() => _artists;

  Iterable<Artist> all_artists() => _artists.container.values;

  bool doesExistArtist(NonEmptyString artist_name) => _artists.contains(artist_name);

  TaskEither<String, ArtistEntry> convert_artist_to_entry(Artist artist) {
    return TaskEither.tryCatch(
      () async {
        final futures = artist.tags.map((artist_tag) {
          Tag tag = get_tag_by_id(artist_tag.tag_id);
          return artist_tag.opt_image_path.match(
            () => Future.value((tag, none<Uint8List>())),
            (image_path) => 
              File(image_path.value)
                .readAsBytes()
                .then((bytes) => (tag, some(bytes)))
          );
        });
        return await Future.wait(futures);
      },
      (e, _) => "$e"
    )
    .flatMap((tags) => TaskEither.right((
      artist.name,
      HashMap<NonEmptyString, Option<Uint8List>>
          .fromIterable(
            tags,
            key: (e) => e.$1.name,
            value: (e) => e.$2)
      , HashSet<NonEmptyString>.from(artist.urls))));
  }
  
  TaskEither<String, void> removeArtist(NonEmptyString artist_name) => TaskEither.tryCatch(
    () async {
      _artists.get(artist_name).match(
        () {},
        (artist) async {
          final futures = <Future<void>>[];
          for (final artist_tag in artist.tags) {
            _tag_table.detach(artist_tag);
            artist_tag.opt_image_path.match(
              () {},
              (image_path) => futures.add(File(image_path.value).delete())
            );
          }
          await Future.wait(futures);

          _artists.removeAt(artist_name);
          
          final packer = Packer();
          packer.packListLength(tags.length);
          for (final tag in tags) {
            tag.writeIntoPacker(packer);
          }
          packer.packListLength(_artists.length);
          for (final artist in all_artists()) {
            artist.writeIntoPacker(packer);
          }
          await File("$_directory_path/db").writeAsBytes(packer.takeBytes());
        }
      );
    },
    (e, _) => "Failed to remove artist $e"
  );

  TaskEither<String, void> add_artist(ArtistEntry artist_entry) =>
    TaskEither.tryCatch(
      () async {
        final dir = Directory("$_directory_path/images");
        if (!await dir.exists()) {
          await dir.create(recursive: true);
        }
      },
      (e, _) => "Failed to create images directory: $e"
    )
    .andThen(() => TaskEither.tryCatch(
      () async {
      final futures = <Future<void>>[];

      final new_artist = _artists.get(artist_entry.$1)
        .map((artist) {
          final filter = HashSet<NonEmptyString>();

          // Differences in the tags
          final artist_tags = artist.tags.foldLeft(<ArtistTag>[], (acc, prev_artist_tag) {
            final tag = _tag_table.get_tag(prev_artist_tag.tag_id);
            filter.add(tag.name);
            return artist_entry.$2.lookup(tag.name)
              .match(
                () {
                  _tag_table.detach(prev_artist_tag);
                  prev_artist_tag.opt_image_path.match(() {},
                    (image_path) => futures.add(File(image_path.value).delete()));

                  return [...acc];
                },
                (opt_bytes) {
                  final artist_tag = opt_bytes.match(
                    () {
                      prev_artist_tag.opt_image_path.match(() {}, (image_path) => futures.add(File(image_path.value).delete()));
                      return prev_artist_tag.cloneWith(none());
                    },
                    (bytes) {
                      final image_path = prev_artist_tag.opt_image_path.getOrElse(() => NonEmptyString.unsafeMake("$_directory_path/images/${artist_entry.$1.value}-${tag.name.value}"));
                      futures.add(File(image_path.value).writeAsBytes(bytes));
                      return prev_artist_tag.cloneWith(some(NonEmptyString.unsafeMake(image_path.value)));
                    });

                  return [...acc, artist_tag];
                });
          });

          for(final entry in artist_entry.$2.entries) {
            if (!filter.contains(entry.key)) {
              final opt_image_path = 
                entry.value.map((bytes) {
                  final image_path = "$_directory_path/images/${artist_entry.$1.value}-${entry.key.value}";
                  futures.add(File(image_path).writeAsBytes(bytes));
                  return NonEmptyString.unsafeMake(image_path); 
                });
              artist_tags.add(_tag_table.attach(entry.key, opt_image_path));
            }
          }

          return Artist(name: artist_entry.$1, tags: artist_tags, urls: artist_entry.$3.toList());
        })
        .getOrElse(() {
          final artist_tags = artist_entry.$2.entries.foldLeft(<ArtistTag>[],
            (acc, entry) {
              final opt_image_path = 
                entry.value.map((bytes) {
                  final image_path = "$_directory_path/images/${artist_entry.$1.value}-${entry.key.value}";
                  futures.add(File(image_path).writeAsBytes(bytes));
                  return NonEmptyString.unsafeMake(image_path); 
                });

                
              return [...acc, _tag_table.attach(entry.key, opt_image_path)];
            });
          return Artist(name: artist_entry.$1, tags: artist_tags, urls: artist_entry.$3.toList());
        });

      await Future.wait(futures);
      
      _artists[new_artist.name] = new_artist;

      final packer = Packer();
      packer.packListLength(tags.length);
      for (final tag in tags) {
        tag.writeIntoPacker(packer);
      }
      packer.packListLength(_artists.length);
      for (final artist in all_artists()) {
        artist.writeIntoPacker(packer);
      }
      await File("$_directory_path/db").writeAsBytes(packer.takeBytes());
      },
      (e, _) => "Failed to save data: $e"
    ));

  static TaskOption<Database> make_from_data() =>
    TaskOption.tryCatch(() async => await getApplicationDocumentsDirectory())
    .flatMap(
      (directory) {
      return TaskOption
        .tryCatch(() async => Unpacker(await File("${directory.path}/db").readAsBytes()))
        .flatMap((unpacker) {
          final tag_table = TagTable();
          return List
            .generate(unpacker.unpackListLength(), (_) => Tag.makeFromUnpacker(unpacker))
            .sequenceOption()
            .flatMap((tags) {
              for (final tag in tags) {
                tag_table.add_tag(tag.id, tag.name);
              }
              return List.generate(unpacker.unpackListLength(), (_) => Artist.makeFromUnpacker(unpacker, tag_table)).sequenceOption();
            }).toTaskOption()
            .flatMap((artists) => TaskOption.some(Database._(directory.path, artists, tag_table)));
          })
          .alt(() => TaskOption.some(Database._(directory.path, <Artist>[], TagTable())));
    });
}