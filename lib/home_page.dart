import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:tagger/add_page.dart';
import 'package:tagger/bootstrap.dart';
import 'package:tagger/database.dart';
import 'package:tagger/dialog.dart';
import 'package:tagger/serializer.dart';
import 'package:tagger/theme.dart';
import 'package:fpdart/fpdart.dart' as fp;
import 'package:toastification/toastification.dart';

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
                onPressed: () => _go_to_add_page(_database, context),
                icon: Icon(Icons.add),
              )
            ),
          ),
        ),
        SizedBox(height: 10),
        Expanded(
          child: SingleChildScrollView(
            child: ListenableBuilder(
              listenable: _database.artists,
              builder: (builder, _) => Column(
                children: _database
                  .artists
                  .iterable
                  .map((a) => _ArtistItem(_database, a))
                  .toList(),
              ))
          ),
        ),
      ],
    );
  }

  static void _go_to_add_page(Database database, BuildContext context, [Artist? artist]) async {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => Center(child: CircularProgressIndicator())
    );

    ArtistEntry? artist_entry = null;

    if (artist != null) {
      await database.convert_artist_to_entry(artist)
        .match(
          () => {
            toastification.show(
              title: const Text("Failed to edit tag"),
              type: .error,
              autoCloseDuration: const Duration(seconds: 3),
            )
          },
          (e) => artist_entry = e 
        )
        .run();
    }

    if(context.mounted) {
      Navigator.pop(context);

      await Navigator.of(context)
        .push(MaterialPageRoute(builder: (context) => bootstrap(AddPage(artist_entry, database))));
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
            child: FutureBuilder<fp.Option<File>>(
              future: fp.TaskOption.tryCatch(() async => File(widget.artist.tags[i].image_url.value)).run(),
              builder: (context, snapshot) {
                if (!snapshot.hasData) return CircularProgressIndicator();

                return snapshot.data!.match(
                  () => Icon(Icons.broken_image),
                  (file) => Image.file(file, fit: .fitWidth)
                );
              },
            )
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
                  IconButton(onPressed: () => HomePage._go_to_add_page(widget.database, context, widget.artist), icon: Icon(Icons.edit)),
                  IconButton(onPressed: () async {
                    if (await show_yes_no_dialog(context, "Delete '${widget.artist.name.value}'")) {
                      widget.database.removeArtist(widget.artist.name);
                    }
                  }, icon: Icon(Icons.delete)),
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
                  children: widget.artist.urls
                    .map((url) => 
                    GestureDetector(
                      onTap: () async {
                        await Clipboard.setData(ClipboardData(text: url.value));

                        toastification.show(
                          title: const Text("URL copied!"),
                          type: .success,
                          autoCloseDuration: const Duration(seconds: 2),
                        );
                      },
                      child: Text(url.value, style: get_link_style())
                      ),
                    ).toList(),
                ),
              ],
            ),
          ],
        ),
      ],
    );
  }
}
