import 'dart:convert';
import 'dart:typed_data';
import 'package:equatable/equatable.dart';
import 'package:fpdart/fpdart.dart';
import 'package:xxh3/xxh3.dart';
import 'packer_extension.dart';
import 'package:messagepack/messagepack.dart';

class NonEmptyString extends Equatable {
  final String value;

  NonEmptyString._(this.value) : assert(value.isNotEmpty);

  @override
  List<Object?> get props => [value];

  static NonEmptyString unsafeMake(String value) {
    assert(!const bool.fromEnvironment("dart.vm.product"));
    return NonEmptyString._(value);
  }

  int generateHash() => xxh3(utf8.encode(value));

  static Option<NonEmptyString> makeFromString(String value) {
    final trimmed = value.trim();
    return trimmed.isEmpty ? none(): some(NonEmptyString._(trimmed));
  }

  static Option<NonEmptyString> makeFromUnpacker(Unpacker unpacker) => unpacker
    .toOptionString()
    .flatMap((name) => makeFromString(name));
}

class ArtistTag extends Equatable {
  final int tag_id;
  final Option<NonEmptyString> opt_image_url;

  ArtistTag({required this.tag_id, required this.opt_image_url});

  @override
  List<Object?> get props => [tag_id];

  void pack(Packer packer) {
    packer.packInt(tag_id);
    opt_image_url.match(
      () {
        packer.packBool(false);
      },
      (url) {
        packer.packBool(true);
        packer.packString(url.value);
      }
    );
  }

  static Option<ArtistTag> makeFromUnpacker(Unpacker unpacker) => unpacker
    .toOptionInt()
    .flatMap((id) => unpacker
      .toOptionBool()
      .map((b) => b ? unpacker.toOptionString().flatMap((url) => NonEmptyString.makeFromString(url)) : none<NonEmptyString>())
      .flatMap((opt) => some(ArtistTag(tag_id: id, opt_image_url: opt))));
}

class Artist {
  final NonEmptyString name;
  final List<ArtistTag> tags;
  final List<NonEmptyString> urls;

  Artist({required this.name, this.tags = const [], this.urls = const []});

  void writeIntoPacker(Packer packer) {
    packer.packString(name.value);
    packer.packInt(tags.length);
    for (var tag in tags) {
      tag.pack(packer);
    }
    packer.packListLength(urls.length);
    for (var url in urls) {
      packer.packString(url.value);
    }
  }

  Uint8List toBytes() {
    final packer = Packer();
    writeIntoPacker(packer);
    return packer.takeBytes();
  }

  static Option<Artist> makeFromUnpacker(Unpacker unpacker) => NonEmptyString
    .makeFromUnpacker(unpacker)
    .flatMap((name) => unpacker.toOptionInt()
      .flatMap((n) => List<Option<ArtistTag>>.generate(n, (_) => ArtistTag.makeFromUnpacker(unpacker))
        .sequenceOption()
      )
      .flatMap((tags) => Option.tryCatch(() => unpacker.unpackList())
        .flatMap((list) => Option.tryCatch(() => list.map((o) => o as String)
          .map((s) => NonEmptyString.makeFromString(s))
          .toList()
          .sequenceOption()))
          .flatMap((e) => e)
          .flatMap((urls) => some(Artist(name: name, tags: tags, urls: urls)))
      )
    );
}

class Tag {
  final int id;
  final NonEmptyString name;

  Tag({required this.id, required this.name});

  void writeIntoPacker(Packer packer) {
    packer.packInt(id);
    packer.packString(name.value);
  }

  static Option<Tag> makeFromUnpacker(Unpacker unpacker) => unpacker
    .toOptionInt()
    .flatMap((id) => NonEmptyString.makeFromUnpacker(unpacker)
      .flatMap((name) => some(Tag(id: id, name: name))));
}