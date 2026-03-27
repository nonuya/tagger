import 'package:flutter/material.dart';
import 'package:tagger/add_page.dart';
import 'package:tagger/bootstrap.dart';
import 'package:tagger/database.dart';
import 'package:tagger/serializer.dart';
import 'package:tagger/theme.dart';
import 'package:fpdart/fpdart.dart' as fp;

class HomePage extends StatelessWidget {
  final Database _database;

  const HomePage(this._database, {super.key});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: .start,
      children: [
        Expanded(
          flex: 0,
          child: TextField(
            decoration: InputDecoration(
              hintText: "artist name...",
              labelText: "Search",
              suffixIcon: IconButton(
                onPressed: () => go_to_add_page(context),
                icon: Icon(Icons.add),
              )
            ),
          ),
        ),
        SizedBox(height: 10),
        Expanded(
          child: SingleChildScrollView(
            child: Column(
              children: _database.artists
                  .map((a) => _ArtistItem(_database, a))
                  .toList(),
            ),
          ),
        ),
      ],
    );
  }

  void go_to_add_page(BuildContext context) async {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => Center(child: CircularProgressIndicator())
    );

    // await Future.delayed(Duration(seconds: 2)); // Simular tarea pesada

    if(context.mounted) {
      Navigator.pop(context);

      await Navigator.of(context)
        .push(MaterialPageRoute(builder: (context) => bootstrap(AddPage(null, _database))));
    }
  }
}

class _ArtistItem extends StatefulWidget {
  final Database database;
  final Artist artist;

  const _ArtistItem(this.database, this.artist);

  @override
  createState() => _ArtistItemState();
}

class _ArtistItemState extends State<_ArtistItem> {
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
        Padding(
          padding: .only(left: 8),
          child: Row(
            mainAxisAlignment: .spaceBetween,
            children: [
              Flexible(
                child: Text(
                  widget.artist.name.value,
                  style: get_artist_name_style(),
                ),
              ),
              Row(
                children: [
                  IconButton(onPressed: () {}, icon: Icon(Icons.edit)),
                  IconButton(onPressed: () {}, icon: Icon(Icons.delete)),
                ],
              ),
            ],
          ),
        ),
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
                    children: widget.artist.tags
                        .mapWithIndex(
                          (artist_tag, i) => widget.database
                              .get_tag_by_id(artist_tag.tag_id)
                              .map<Widget>(
                                (tag) => OutlinedButton(
                                  onPressed: () {
                                    setState(() {
                                      selectedItem = fp.some(i);
                                    });
                                  },
                                  style: get_tag_style(
                                    selectedItem.getOrElse(() => -1) == i
                                        ? Colors.blue
                                        : null,
                                  ),
                                  child: Text(tag.name.value),
                                ),
                              ),
                        )
                        .sequenceOption()
                        .getOrElse(List<Widget>.empty),
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
