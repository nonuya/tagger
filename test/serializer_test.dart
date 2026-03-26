import 'package:flutter/foundation.dart';
import 'package:messagepack/messagepack.dart';
import 'package:tagger/serializer.dart';
import 'package:test/test.dart';

void main() {
  group("NonEmptyString", () {
    test("makeFromString must return Some if the string is not empty", () {
      final str = NonEmptyString.makeFromString("Hola");
      expect(str.isSome(), true);
    });
    test("makeFromString must return None if the string is empty", () {
      final str = NonEmptyString.makeFromString("");
      expect(str.isNone(), true);
    });
    test("makeFromString must return None if the string is just spaces", () {
      final str = NonEmptyString.makeFromString("    ");
      expect(str.isNone(), true);
    });
  });

  group("Artist Serialization", () {
    test("Serialization of an Artist (only name)", () {
      final bytes = Artist(name: NonEmptyString.unsafeMake("Tester")).toBytes();
      final artist = Artist.makeFromUnpacker(Unpacker(bytes));
      artist.match(
        () => fail("Artist is None"),
        (artist) {
          expect(artist.name.value, "Tester");
          expect(artist.tags.length, 0);
          expect(artist.urls.length, 0);
        }
      );
    });
    test("Incorrect Artist", () {
      final artist = Artist.makeFromUnpacker(Unpacker(Uint8List.fromList([1,2,3])));
      expect(artist.isNone(), true);
    });
    test("Serialization of an Artist (name, single tag, single url)", () {
      final bytes = Artist(
        name: NonEmptyString.unsafeMake("Tester"),
        tags: [ArtistTag(tag_id: 0, image_url: NonEmptyString.unsafeMake("Image Url 1"))],
        urls: [NonEmptyString.unsafeMake("Url 1")],
        ).toBytes();
      final artist = Artist.makeFromUnpacker(Unpacker(bytes));
      artist.match(
        () => fail("Artist is None"),
        (artist) {
          expect(artist.name.value, "Tester");
          expect(artist.tags.length, 1);
          expect(artist.tags[0].tag_id, 0);
          expect(artist.tags[0].image_url.value, "Image Url 1");
          expect(artist.urls.length, 1);
          expect(artist.urls[0].value, "Url 1");
        }
      );
    });
    test("Serialization of an Artist (name, multiple tag, multiple url)", () {
      final tags = List.generate(10, (i) => ArtistTag(tag_id: i, image_url: NonEmptyString.unsafeMake("Tag $i")));
      final urls = List.generate(20, (i) => NonEmptyString.unsafeMake("Url $i"));
      final bytes = Artist(
        name: NonEmptyString.unsafeMake("Tester"),
        tags: tags,
        urls: urls
      ).toBytes();

      final artist = Artist.makeFromUnpacker(Unpacker(bytes));
      artist.match(
        () => fail("Artist is None"),
        (artist) {
          expect(artist.name.value, "Tester");
          expect(artist.tags.length, 10);
          for(var i = 0; i < 10; ++i) {
            expect(artist.tags[i].tag_id, i);
            expect(artist.tags[i].image_url.value, "Tag $i");
          }
          expect(artist.urls.length, 20);
          for(var i = 0; i < 20; ++i) {
            expect(artist.urls[i].value, "Url $i");
          }
        }
      );
    });
  });
  group("Artist Performance", () {
    final artists = List.generate(500, (i) => Artist(
      name: NonEmptyString.unsafeMake("Artist $i"),
      tags: List.generate(500, (i) => ArtistTag(tag_id: i, image_url: NonEmptyString.unsafeMake("Image Url $i"))),
      urls: List.generate(500, (i) => NonEmptyString.unsafeMake("Image Url $i")),
    ));

    final packer = Packer();
    packer.packListLength(artists.length);
    for (var artist in artists) {
      artist.toPacker(packer);
    }
    final bytes = packer.takeBytes();

    final tags = Map.fromEntries(List.generate(500, (i) => MapEntry(i, Tag(id: i, name: NonEmptyString.unsafeMake("Tag $i")))));

    test("500 Artist with 500 tags with 500 Urls each one", () {
      final unpacker = Unpacker(bytes);
      
      final watch = Stopwatch();
      watch.start();
      final n = unpacker.unpackListLength();
      for(var i = 0; i < n; ++i) {
        final artist = Artist.makeFromUnpacker(unpacker);
        expect(artist.isSome(), true);
      }
      watch.stop();

      print("Elapsed time: ${watch.elapsedMilliseconds}ms");
      expect(watch.elapsedMilliseconds, lessThan(300));
    });

    test("500 Artist with 500 tags with 500 Urls each one with reading Tag", () {
      final unpacker = Unpacker(bytes);
      
      final watch = Stopwatch();
      watch.start();
      final n = unpacker.unpackListLength();
      for(var i = 0; i < n; ++i) {
        final artist = Artist.makeFromUnpacker(unpacker);
        artist.match(
          () => fail("Artist is none!"),
          (artist) {
            for(var i = 0; i < artist.tags.length; ++i) {
              var tag = artist.tags[i];
              expect(tags.containsKey(i), true, reason: "ArtistTag: ${tag.tag_id}   Tag: $i");
            }
          }
        );
      }
      watch.stop();

      print("Elapsed time: ${watch.elapsedMilliseconds}ms");
      expect(watch.elapsedMilliseconds, lessThan(400));
    });
  });
}
