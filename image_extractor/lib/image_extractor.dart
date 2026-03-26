import 'dart:convert';
import 'dart:typed_data';
import 'package:fpdart/fpdart.dart';
import 'package:http/http.dart' as http;

typedef _HitomiGalleryPage = (int /*galleryId*/, int /*page*/);

TaskEither<String, Uint8List> get_image_bytes_from_hitomi_url(
  String url,
) => _get_image_url_from_hitomi_url(url).flatMap(
  (image_url) => TaskEither(() async {
    final uri = Uri.tryParse(image_url);
    assert(uri != null);
    final response = await http.get(
      uri!,
      headers: {
        "accept":
            "image/avif,image/webp,image/apng,image/svg+xml,image/*,*/*;q=0.8",
        "Referer": "https://hitomi.la",
      },
    );

    if (response.statusCode != 200) {
      return left("Failed to get image bytes from URL");
    }

    return right(response.bodyBytes);
  }),
);

TaskEither<String, String> _get_image_url_from_hitomi_url(String url) =>
    _get_hitomi_gallery_page_from_url(url).match(
      () => TaskEither.left("Invalid URL"),
      (gallery_page) => TaskEither(() async {
        final gallery_script = await http.get(
          Uri.https(
            "ltn.gold-usergeneratedcontent.net",
            "galleries/${gallery_page.$1}.js",
          ),
        );
        final gg_script = await http.get(
          Uri.https("ltn.gold-usergeneratedcontent.net", "gg.js"),
        );

        if (gallery_script.statusCode != 200 || gg_script.statusCode != 200) {
          return left("Failed to get JS from hitomi.la");
        }

        return _GG
            .makeFromString(gg_script.body)
            .match(
              () => left("Failed to parse JS from hitomi.la"),
              (gg) =>
                  Option.fromNullable(
                        RegExp(
                          r'"files":\s*(\[[^\]]+\])',
                        ).firstMatch(gallery_script.body),
                      )
                      .flatMap((match) => Option.fromNullable(match.group(1)))
                      .flatMap(
                        (body) => Option.tryCatch(
                          () =>
                              (jsonDecode(body)
                                      as List<dynamic>)[gallery_page.$2 - 1]
                                  as Map<String, dynamic>,
                        ),
                      )
                      .flatMap(
                        (entry) => Option.tryCatch(
                          () => (
                            entry["hash"] as String,
                            (entry["hasavif"] as int) == 1,
                          ),
                        ),
                      )
                      .match(() => left("Invalid Page ${gallery_page.$2}"), (
                        entry,
                      ) {
                        return right(
                          _url_from_url(
                            _url_from_hash(entry.$1, entry.$2, gg),
                            entry.$2,
                            gg,
                          ),
                        );
                      }),
            );
      }),
    );

String _url_from_hash(String hash, bool hasavif, _GG gg) =>
    "https://${hasavif ? "a" : "w"}.gold-usergeneratedcontent.net/${_full_path_from_hash(hash, gg)}.${hasavif ? "avif" : "webp"}";

String _full_path_from_hash(String hash, _GG gg) =>
    "${gg.b}/${gg.s(hash)}/$hash";

String _url_from_url(String url, bool hasavif, _GG gg) {
  final regex = RegExp(
    r'//..?\.(?:gold-usergeneratedcontent\.net|hitomi\.la)/',
  );

  return url.replaceFirstMapped(regex, (match) {
    final subdomain = _subdomain_from_url(url, hasavif, gg);
    return '//$subdomain.gold-usergeneratedcontent.net/';
  });
}

String _subdomain_from_url(String url, bool hasavif, _GG gg) {
  // w for webp, a for avif
  String retval = hasavif ? 'a' : 'w';

  const int b = 16;

  // Regex: /\/[0-9a-f]{61}([0-9a-f]{2})([0-9a-f])/
  final regex = RegExp(r'/[0-9a-f]{61}([0-9a-f]{2})([0-9a-f])');
  final match = regex.firstMatch(url);

  if (match == null) {
    return retval;
  }

  // Combina los grupos 2 + 1 y parsea en base 16
  final g = int.tryParse(match.group(2)! + match.group(1)!, radix: b);

  if (g != null) {
    retval = retval + (gg.m(g) ? 2 : 1).toString();
  }

  return retval;
}

class _GG {
  final Set<int> _m;
  final bool _o;
  final int b;

  const _GG._(this._m, this._o, this.b);

  bool m(int g) => _m.contains(g) ? _o : !_o;

  String s(String h) {
    final _s = int.tryParse(
      (RegExp(r'(..)(.)$').firstMatch(h)?.group(2) ?? '') +
          (RegExp(r'(..)(.)$').firstMatch(h)?.group(1) ?? ''),
      radix: 16,
    );

    assert(_s != null);

    return _s.toString();
  }

  static Option<_GG> makeFromString(String body) {
    final lines = const LineSplitter().convert(body);
    final Set<int> m = {};
    var o = none<bool>();
    var b = none<int>();
    for (final _line in lines) {
      final line = _line.trim();
      if (line.startsWith("case ")) {
        final cas = int.tryParse(line.substring(5, line.length - 1));
        if (cas != null) {
          m.add(cas);
        }
      } else if (line.startsWith("o = ")) {
        if (line.startsWith("o = 1")) {
          o = some(true);
        } else {
          o = some(false);
        }
      } else if (line.startsWith("b: '")) {
        b = Option.tryCatch(
          () => int.parse(line.substring(4, line.length - 2)),
        );
      }
    }

    return o.flatMap((o) => b.flatMap((b) => some(_GG._(m, o, b))));
  }
}

Option<_HitomiGalleryPage> _get_hitomi_gallery_page_from_url(String url) =>
    Option.fromNullable(
      RegExp(
        r"^https://hitomi\.la/reader/([\d]+)\.html#([\d]+)(?:-(?:[\d]+)?)?$",
      ).firstMatch(url),
    ).flatMap(
      (match) => some((int.parse(match.group(1)!), int.parse(match.group(2)!))),
    );
