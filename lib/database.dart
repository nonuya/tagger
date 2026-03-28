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

  void removeAt(int index) {
    _list.removeAt(index);
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
  final HashMap<int /* tag_id */, int /* rfc_count */> _map_reference_tags;

  List<Tag> get tags => List.unmodifiable(_tags);
  
  Database._(this._directory_path, this.artists, this._tags, this._map_artists, this._map_tags, this._map_reference_tags);

  Option<Tag> get_tag_by_id(int id) => _map_tags.lookup(id).map((i) => _tags[i]);

  TaskOption<ArtistEntry> convert_artist_to_entry(Artist artist) => TaskOption.tryCatch(() async => 
    artist.tags
      .traverseOption((art_tag) => get_tag_by_id(art_tag.tag_id).map((tag) => (tag.name, File(art_tag.image_url.value).readAsBytesSync())))
  )
  .flatMap((tags) => tags.toTaskOption())
  .map((tags) => (artist.name, tags, HashSet<NonEmptyString>.from(artist.urls)));

  bool doesExistArtist(NonEmptyString artist_name) => _map_artists.containsKey(artist_name);

  Future<void> removeArtist(NonEmptyString artist_name) async {
    if (!doesExistArtist(artist_name)) {
      return;
    }

    int artist_index = _map_artists[artist_name]!;
    for (final artist_tag in artists.get(artist_index).tags) {
      _unref_tag(artist_tag.tag_id);
      await File(artist_tag.image_url.value).delete();
    }

    _map_artists.remove(artist_name);
    artists.removeAt(artist_index);

    _removeDanglingTags();

    {
      final packer = Packer();
      packer.packListLength(_tags.length);
      for (final tag in _tags) {
        tag.writeIntoPacker(packer);
      }

      await File("$_directory_path/tags").writeAsBytes(packer.takeBytes());
    }

    {
      final packer = Packer();
      packer.packListLength(artists.length);
      for (final artist in artists.iterable) {
        artist.writeIntoPacker(packer);
      }
      
      await File("$_directory_path/artists").writeAsBytes(packer.takeBytes());
    }
  }

  void _ref_tag(int tag_id) {
    assert(_map_reference_tags[tag_id] != null);
    _map_reference_tags[tag_id] = _map_reference_tags[tag_id]! + 1;
  }

  void _unref_tag(int tag_id) {
    assert(_map_reference_tags[tag_id] != null);
    _map_reference_tags[tag_id] = _map_reference_tags[tag_id]! - 1;
  }

  void _add_tag(Tag tag) {
    if (!_map_tags.containsKey(tag.id)) {
      _tags.add(tag);
      _map_reference_tags[tag.id] = 1;
      _map_tags[tag.id] = tags.length-1;
    } else {
      _ref_tag(tag.id);
    }
  }
  
  // TODO: Allow exceptions only for check if it's necessary rollback
  Future<void> addArtist(ArtistEntry artist_entry) async {
    final dir = Directory("$_directory_path/images");
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }

    HashSet<ArtistTag> new_artist_tags = HashSet();

    // Tags
    for (final tag_entry in artist_entry.$2) {
      final tag = Tag(
        id: tag_entry.$1.generateHash(),
        name: tag_entry.$1
      );
      final artist_tag = ArtistTag(
        tag_id: tag.id,
        image_url: NonEmptyString.unsafeMake("$_directory_path/images/${artist_entry.$1.value}-${tag.name.value}"));

      _add_tag(tag);
      new_artist_tags.add(artist_tag);
     
      await File(artist_tag.image_url.value).writeAsBytes(tag_entry.$2);
    }
    
    _map_artists.lookup(artist_entry.$1)
    .match(() {},
      (i) {
        for (final artist_tag in artists.get(i).tags) {
          if (!new_artist_tags.contains(artist_tag)) {
            _unref_tag(artist_tag.tag_id);
            File(artist_tag.image_url.value).deleteSync();
          }
        }
      });

    _removeDanglingTags();

    {
      final packer = Packer();
      packer.packListLength(_tags.length);
      for (final tag in _tags) {
        tag.writeIntoPacker(packer);
      }

      await File("$_directory_path/tags").writeAsBytes(packer.takeBytes());
    }

    final new_artist = Artist(name: artist_entry.$1, tags: new_artist_tags.toList(), urls: artist_entry.$3.toList());
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

    _map_artists.lookup(artist_entry.$1)
      .match(
        () {
          artists.add(new_artist);
          _map_artists[artist_entry.$1] = artists.length-1;
        },
        (i) => artists.update(i, new_artist));
  }

  void _removeDanglingTags() async {
    final idsToRemove = _map_reference_tags
      .entries
      .where((e) => e.value <= 0)
      .map((e) => e.key)
      .toList();

    for (final id in idsToRemove) {
      final i = _map_tags[id];
      assert(i != null);
      _tags.removeAt(i!);
      _map_reference_tags.remove(id);
      _map_tags.remove(id);
    }
  }

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
    HashMap<int, int> map_reference_tags = HashMap();

    for (final artist in artists) {
      for (final tag in artist.tags) {
        map_reference_tags.update(
          tag.tag_id,
          (ref_cnt) => ref_cnt+1,
          ifAbsent: () => 1);
      }
    }

    return some(Database._(directory.path, ArtistList(artists), tags, map_artists, map_tags, map_reference_tags));
  });
}
