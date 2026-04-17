import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:tagger/add_page.dart';
import 'package:tagger/bootstrap.dart';
import 'package:tagger/db/database.dart';
import 'package:tagger/dialog.dart';
import 'package:tagger/db/tables.dart';
import 'package:tagger/theme.dart';
import 'package:fpdart/fpdart.dart' as fp;
import 'package:toastification/toastification.dart';

class HomePage extends StatefulWidget {
  final Database _database;
  
  const HomePage(this._database, {super.key});

  @override
  createState() => _HomePage();
}

class _HomePage extends State<HomePage> {
  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: .start,
      children: [
        Expanded(
          flex: 0,
          child: TextField(
            // FIXME: Change this!
            decoration: InputDecoration(
              hintText: 'artist name tag:tag1 tag: tag 2',
              labelText: "Search",
              suffixIcon: IconButton(
                onPressed: () => _go_to_add_page(widget._database, context),
                icon: Icon(Icons.add),
              )
            ),
          ),
        ),
        SizedBox(height: 10),
        Expanded(
          child: ListenableBuilder(
          listenable: widget._database.get_artists_notifier(),
          builder: (context, _) {
            final artists = widget._database
                .artists
                .toList()
                ..sort((a,b) => b.tags.length.compareTo(a.tags.length));

            return ListView.builder(
              itemCount: artists.length,
              itemBuilder: (context, index) =>
                  _ArtistItem(widget._database, artists[index]),
            );
          },
        )
        ),
      ],
    );
  }
}


Future<void> _go_to_add_page(Database database, BuildContext context, [Artist? artist]) async {
  showDialog(
    context: context,
    barrierDismissible: false,
    builder: (context) => Center(child: CircularProgressIndicator())
  );

  ArtistEntry? artist_entry = null;

  if (artist != null) {
    await database.convert_artist_to_entry(artist)
      .match(
        (error) => {
          toastification.show(
            title: const Text("Failed to edit tag"),
            description: Text(error),
            type: .error,
            autoCloseDuration: const Duration(seconds: 3),
          )
        },
        (entry) => artist_entry = entry 
      )
      .run();
  }

  if(context.mounted) {
    Navigator.pop(context);

    await Navigator.of(context)
      .push(MaterialPageRoute(builder: (context) => bootstrap(AddPage(artist_entry, database))));
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
  fp.Option<int> selectedTagId = fp.none();

  @override
  Widget build(BuildContext context) {
    final children =
      selectedTagId
      .flatMap((tag_id) => fp.Option.tryCatch(() => widget.artist.tags.firstWhere((artist_tag) => artist_tag.tag_id == tag_id)))
      .flatMap((tag) => tag.opt_image_path)
      .match(
      () => [buildInnerContent()],
      (path) =>
        [
          buildInnerContent(),
          SizedBox(height: 10),
          Flexible(
            child: SizedBox(
              child: FutureBuilder<fp.Option<Uint8List>>(
                future: fp.TaskOption.tryCatch(() async => File(path.value).readAsBytes()).run(),
                builder: (context, snapshot) {
                  if (!snapshot.hasData) return CircularProgressIndicator();

                  return snapshot.data!.match(
                    () => Icon(Icons.broken_image),
                    (bytes) => Image.memory(
                      bytes,
                      width: .infinity)
                  );
                },
              )
            ),
          )
        ]
      );

    return Card(
      child: Padding(
        padding: .all(5),
        child: Column(
        mainAxisSize: .min,
        children: [
          Row(
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
                  IconButton(onPressed: () => _go_to_add_page(widget.database, context, widget.artist), icon: Icon(Icons.edit)),
                  IconButton(onPressed: () async {
                    if (await show_yes_no_dialog(context, "Delete", "Delete '${widget.artist.name.value}'")) {
                      await widget.database.remove_artist(widget.artist.name)
                        .match(
                          (e) => toastification.show(
                              title: Text(e),
                              type: .error,
                              autoCloseDuration: const Duration(seconds: 3),
                            ),
                          (_) {}
                        ).run();
                    }
                  }, icon: Icon(Icons.delete)),
                ],
              ),
            ],
          ),
          
          ...children
        ],
      ))
    );   
  }

  Widget buildInnerContent() {
    return Table(
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
                    children:
                      widget.artist.tags
                        .map(
                          (artist_tag) {
                            final tag = widget.database.get_tag_by_id(artist_tag.tag_id);
                            return OutlinedButton(
                                  onPressed: artist_tag.opt_image_path.isNone() ? null : () {
                                    setState(() {
                                      final prev = selectedTagId.getOrElse(() => 0);
                                      if (artist_tag.tag_id == prev) {
                                        selectedTagId = fp.none();
                                      } else {
                                        selectedTagId = fp.some(artist_tag.tag_id);
                                      }
                                    });
                                  },
                                  style: get_tag_style(
                                    selectedTagId.getOrElse(() => 0) == tag.id
                                        ? Colors.blue
                                        : null,
                                  ),
                                  child: Text(tag.name.value),
                                );
                            }
                        ).toList(),
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
        );
  }
}
