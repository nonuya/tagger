import 'dart:typed_data';
import 'package:fpdart/fpdart.dart';
import 'package:messagepack/messagepack.dart';

class NonEmptyString {
  final String value;

  NonEmptyString._(this.value) : assert(value.isNotEmpty);

  // TODO: Just for test!!!!!!!!!
  static NonEmptyString unsafeMake(String value) {
    assert(const bool.fromEnvironment("dart.vm.product"));
    return NonEmptyString._(value);
  }

  static Option<NonEmptyString> makeFromString(String value) =>
    value.trim().isEmpty ? none() : some(NonEmptyString._(value));

  static Option<NonEmptyString> makeFromUnpacker(Unpacker unpacker) => Option
    .tryCatch(() => unpacker.unpackString())
    .flatMapNullable((e) => e)
    .flatMap((name) => makeFromString(name));
}

class Artist {
  final NonEmptyString name;
  final List<Tag> tags;
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
    .flatMap((name) => Option.tryCatch(() => unpacker.unpackInt()).flatMapNullable((e) => e)
      .flatMap((n) => List<Option<Tag>>.generate(n, (_) => Tag.makeFromUnpacker(unpacker))
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

  static Option<Tag> makeFromUnpacker(Unpacker unpacker) => Option
      .tryCatch(() => unpacker.unpackInt())
      .flatMapNullable((e) => e)
      .flatMap((id) => NonEmptyString.makeFromUnpacker(unpacker)
        .flatMap((name) => some(Tag(id: id, name: name))));

  void pack(Packer packer) {
    packer.packInt(id);
    packer.packString(name.value);
  }
}