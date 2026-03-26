import 'package:flutter/material.dart';
import 'package:tagger/serializer.dart';
import 'package:tagger/theme.dart';
import 'package:fpdart/fpdart.dart' as fp;

final vec_tags = [
  Tag(id: 0, name: .unsafeMake("Tag 1")),
  Tag(id: 1, name: .unsafeMake("Tag 2")),
  Tag(id: 2, name: .unsafeMake("Tag 3")),
  Tag(id: 3, name: .unsafeMake("Tag 4")),
  Tag(id: 4, name: .unsafeMake("Tag 5")),
  Tag(id: 5, name: .unsafeMake("Tag 6")),
];

final test_tags = {
  0: vec_tags[0],
  1: vec_tags[1],
  2: vec_tags[2],
  3: vec_tags[3],
  4: vec_tags[4],
  5: vec_tags[5],
};

class ArtistItem extends StatefulWidget {
  final Artist artist;

  const ArtistItem(this.artist, {super.key});

  @override
  _ArtistItem createState() => _ArtistItem();
}

class _ArtistItem extends State<ArtistItem> {
  fp.Option<int> selectedItem = fp.none();

  @override
  Widget build(BuildContext context) {
    final content = Expanded(
      flex: 3,
      child: Padding(padding: .all(6), child: buildInnerContent()),
    );
    final children = selectedItem.match(() => [content], (i) {
      return [
        Expanded(
          flex: 1,
          child: SizedBox(
            child: Image.network(
              fit: .fitWidth,
              widget.artist.tags[i].image_url.value,
            ),
          ),
        ),
        content,
      ];
    });

    return Card(child: Row(children: children));
  }

  Widget buildInnerContent() {
    return Column(
      crossAxisAlignment: .start,
      children: [
        Text(widget.artist.name.value, style: get_artist_name_style()),
        Table(
          columnWidths: {0: FlexColumnWidth(1), 1: FlexColumnWidth(5)},
          children: [
            TableRow(
              children: [
                const TableCell(
                  verticalAlignment: .middle,
                  child: Center(child: Text("Tags")),
                ),
                Padding(
                  padding: EdgeInsetsGeometry.all(8),
                  child: Wrap(
                    spacing: 8.0,
                    runSpacing: 8.0,
                    children: widget.artist.tags.mapWithIndex((e, i) {
                      final tag = test_tags[e.tag_id];
                      assert(tag != null);

                      return OutlinedButton(
                        onPressed: () {
                          setState(() {
                            selectedItem = fp.some(i);
                          });
                        },
                        style: get_tag_style(
                          selectedItem.getOrElse(() => -1) == i
                              ? Colors.blue
                              : Colors.grey,
                        ),
                        child: Text(tag!.name.value),
                      );
                    }).toList(),
                  ),
                ),
              ],
            ),
            TableRow(
              children: [
                const TableCell(
                  verticalAlignment: .middle,
                  child: Center(child: Text("Links")),
                ),
                Wrap(
                  spacing: 8.0,
                  runSpacing: 8.0,
                  children: [
                    GestureDetector(child: Text("a", style: get_link_style())),
                  ],
                ),
              ],
            ),
          ],
        ),
      ],
    );
  }
}
