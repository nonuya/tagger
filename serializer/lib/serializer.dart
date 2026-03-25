import 'dart:typed_data';
import 'package:fpdart/fpdart.dart';
import 'package:serializer/packer_extension.dart';
import 'package:messagepack/messagepack.dart';

class NonEmptyString {
  final String value;

  NonEmptyString._(this.value) : assert(value.isNotEmpty);

  // TODO: Just for test!!!!!!!!!
  static NonEmptyString unsafeMake(String value) {
    assert(!const bool.fromEnvironment("dart.vm.product"));
    return NonEmptyString._(value);
  }

  static Option<NonEmptyString> makeFromString(String value) =>
    value.trim().isEmpty ? none() : some(NonEmptyString._(value));

  static Option<NonEmptyString> makeFromUnpacker(Unpacker unpacker) => unpacker
    .toOptionString()
    .flatMap((name) => makeFromString(name));
}

class ArtistTag {
  final int tag_id;
  final NonEmptyString image_url;

  ArtistTag({required this.tag_id, required this.image_url});

  void pack(Packer packer) {
    packer.packInt(tag_id);
    packer.packString(image_url.value);
  }

  static Option<ArtistTag> makeFromUnpacker(Unpacker unpacker) => unpacker
    .toOptionInt()
    .flatMap((id) => unpacker
      .toOptionString()
      .flatMap((url) => NonEmptyString.makeFromString(url))
      .flatMap((url) => some(ArtistTag(tag_id: id, image_url: url))));
}

class Artist {
  final NonEmptyString name;
  final List<ArtistTag> tags;
  final List<NonEmptyString> urls;

  Artist({required this.name, this.tags = const [], this.urls = const []});

  Uint8List toBytes() {
    final packer = Packer();
    packer.packString(name.value);
    packer.packInt(tags.length);
    for (var tag in tags) {
      tag.pack(packer);
    }
    packer.packListLength(urls.length);
    for (var url in urls) {
      packer.packString(url.value);
    }

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

  static Option<Tag> makeFromUnpacker(Unpacker unpacker) => unpacker
    .toOptionInt()
    .flatMap((id) => NonEmptyString.makeFromUnpacker(unpacker)
      .flatMap((name) => some(Tag(id: id, name: name))));
}