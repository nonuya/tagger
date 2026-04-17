import 'dart:collection';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:tagger/db/database.dart';
import 'package:tagger/dialog.dart';
import 'package:tagger/image_extractor.dart';
import 'package:tagger/db/tables.dart';
import 'package:tagger/theme.dart';
import 'package:fpdart/fpdart.dart' as fp;
import 'package:toastification/toastification.dart';

class AddPage extends StatefulWidget {
  final Database _database;
  final String? _initial_artist_name;
  final HashMap<NonEmptyString, fp.Option<Uint8List>> _tag_map;
  final HashSet<NonEmptyString> _link_set;

  AddPage(ArtistEntry? entry, this._database, {super.key}) :
    _tag_map = entry != null ? entry.$2: HashMap(),
    _link_set = entry != null ? entry.$3 : HashSet(),
    _initial_artist_name = entry?.$1.value;


  @override
  createState() => _AddPage();
}

class _AddPage extends State<AddPage> {
  final formKey = GlobalKey<FormState>();
  final controller = TextEditingController();
  var loading = false;

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();

    if(widget._initial_artist_name != null) {
      controller.text = widget._initial_artist_name!;
    }
  }  

  @override
  Widget build(BuildContext context) {
    return Form(
      key: formKey,
      child: Column(
        children: [
          Row(
            children: [
              IconButton(
                onPressed: () {
                  Navigator.of(context, rootNavigator: true).pop();
                },
                icon: Icon(Icons.arrow_circle_left_rounded),
              ),
              const Expanded(
                child: Text(
                  "Add Artist",
                  textAlign: .center,
                  style: TextStyle(fontWeight: .bold, fontSize: 24),
                ),
              ),
              IconButton(
                onPressed: loading ? null : () async {
                  if (formKey.currentState!.validate()) {
                    NonEmptyString.makeFromString(controller.text)
                    .map((artist_name) =>(artist_name, widget._tag_map, widget._link_set)
                    ).match(
                      () {
                        toastification.show(
                                title: const Text("Tag images are empty!"),
                                type: .error,
                                autoCloseDuration: const Duration(seconds: 3),
                              );
                      },
                      (e) async {
                        if (widget._database.does_exist_artist(e.$1) &&
                          !await show_yes_no_dialog(context, "Save", "Artist '${e.$1.value}' exists. Overwrite?")) {
                            return;
                        }

                        setState(() => loading = true);

                        await widget.
                          _database
                          .add_artist(e)
                          .match(
                            (e) => toastification.show(
                                    title: const Text("Failed to save artist"),
                                    description: Text(e),
                                    type: .error,
                                    autoCloseDuration: const Duration(seconds: 5),
                                  ),
                            (_) {
                              toastification.show(
                                title: const Text("Artist saved!"),
                                type: .success,
                                autoCloseDuration: const Duration(seconds: 3),
                              );
                            }
                          )
                          .run()
                          .whenComplete(() {
                            if (context.mounted) {
                              setState(() => loading = false);
                            }
                          });
                      }
                    );
                  }
                },
                icon: Icon(Icons.save),
              ),
            ],
          ),

          Expanded(
            child: SingleChildScrollView(
              child: Column(
                children: [
                  SizedBox(height: 10),
                  TextFormField(
                    controller: controller,
                    decoration: InputDecoration(
                      labelText: "Artist Name",
                      hintText: "artist 1",
                    ),
                    validator: (value) => (value == null || value.isEmpty)
                        ? "Artist is empty"
                        : null,
                  ),
                  SizedBox(height: 20),

                  _TagForm(widget._tag_map, widget._database.tags),

                  SizedBox(height: 10),

                  _LinkForm(widget._link_set),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _TagForm extends StatefulWidget {
  final HashMap<NonEmptyString, fp.Option<Uint8List>> tag_map;
  final Iterable<Tag> tags;

  const _TagForm(this.tag_map, this.tags);

  @override
  createState() => _TagFormState();
}

class _TagFormState extends State<_TagForm> {
  final formKey = GlobalKey<FormState>();

  @override
  Widget build(BuildContext context) {
    return Form(
      key: formKey,
      child: Column(
        crossAxisAlignment: .start,
        children: [
          Autocomplete<String>(
            onSelected: (_) => FocusManager.instance.primaryFocus?.unfocus(),
            optionsBuilder: (input) {
              return widget.tags
                  .filter((tag) => tag.name.value.toLowerCase().contains(input.text))
                  .filter((tag) => !widget.tag_map.containsKey(tag.name))
                  .map((tag) => tag.name.value);
            },
            fieldViewBuilder:
                (context, controller, focusNode, onEditingComplete) {
                  return TextFormField(
                    onTapOutside: (_) {
                       focusNode.unfocus();
                    },
                    onFieldSubmitted: (_) => add_tag(controller, focusNode), 
                    controller: controller,
                    focusNode: focusNode,
                    decoration: InputDecoration(
                      labelText: "Tag?",
                      hintText: "tag 1",
                      suffixIcon: IconButton(
                        onPressed: () => add_tag(controller, focusNode),
                        icon: Icon(Icons.add),
                      ),
                    ),
                    validator: (value) => (value == null || value.isEmpty) ? "Tag is empty" : null,
                  );
                },
          ),
          SizedBox(height: 10),
          Wrap(
            runSpacing: 8,
            spacing: 8,
            children: widget.tag_map.entries
                .map(
                  (e) => OutlinedButton(
                    onPressed: () => showImageModal(e.key),
                    style: get_tag_style(
                      e.value.isSome() ? Colors.blue : null,
                    ),
                    child: Row(
                      mainAxisSize: .min,
                      children: [
                        Text(e.key.value),
                        SizedBox(width: 10),
                        IconButton(
                          onPressed: () async {
                            final confirm = await show_yes_no_dialog(
                              context,
                              "Delete Tag",
                              'Delete Tag "${e.key.value}"?',
                            );
                            if (confirm) {
                              setState(() => widget.tag_map.remove(e.key));
                            }
                          },
                          icon: Icon(Icons.delete),
                        ),
                      ],
                    ),
                  ),
                )
                .toList(),
          ),
        ],
      ),
    );
  }

  void add_tag(TextEditingController controller, FocusNode focusNode) {
    if (formKey.currentState!.validate()) {
      NonEmptyString.makeFromString(
          controller.text,
          ).match(() {}, (v) {
            if (!widget.tag_map.containsKey(v)) {
            setState(() {
                widget.tag_map[v] = fp.None();
                });
            }
            });
      controller.clear();
      focusNode.unfocus();
    }
  }

  void showImageModal(NonEmptyString key) {
    var loading = false;
    String url = "";

    final updateImage = (bytes) {
      if(mounted) {
        setState(() => widget.tag_map[key] = fp.some(bytes));
      }
    };

    showModalBottomSheet(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setState) {
            var image = widget.tag_map
                .lookup(key)
                .flatMap((o) => o)
                .match(
                  () => Icon(Icons.broken_image),
                  (bytes) => Image.memory(bytes, fit: .contain),
                );

            if (loading) {
              image = Center(child: CircularProgressIndicator());
            }

            return Column(
              children: [
                Expanded(
                  flex: 1,
                  child: TextField(
                    onChanged: (value) => url = value,
                    decoration: InputDecoration(
                      labelText: "Image URL",
                      suffixIcon: IconButton(
                        onPressed: loading ? null : () async {
                          setState(() => loading = true);

                          FocusManager.instance.primaryFocus?.unfocus();
                          await Future.delayed(
                            const Duration(milliseconds: 50),
                          );

                          final res = await get_image_bytes_from_hitomi_url(
                            url,
                          )
                          .run();

                          res.match(
                            (e) => toastification.show(
                                title: Text(e),
                                type: .error,
                                autoCloseDuration: const Duration(seconds: 3),
                            ),
                            (bytes) => updateImage(bytes),
                          );
                          
                          if (context.mounted) {
                            setState(() => loading = false);
                          }
                        },
                        icon: Icon(Icons.search),
                      ),
                      hintText: "https://hitomi.la/reader/xxxxxxx.html#xx-xx",
                    ),
                  ),
                ),
                Expanded(flex: 7, child: image),
              ],
            );
          },
        );
      },
    );
  }
}

class _LinkForm extends StatefulWidget {
  final HashSet<NonEmptyString> link_set;

  const _LinkForm(this.link_set);

  @override
  createState() => _LinkFormState();
}

class _LinkFormState extends State<_LinkForm> {
  final formKey = GlobalKey<FormState>();
  final controller = TextEditingController();
  final focusNode = FocusNode();

  @override
  void dispose() {
    controller.dispose();
    focusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Form(
      key: formKey,
      child: Column(
        crossAxisAlignment: .start,
        children: [
          TextFormField(
            controller: controller,
            focusNode: focusNode,
            onFieldSubmitted: (_) => add_tag(controller, focusNode),
            decoration: InputDecoration(
              labelText: "Link?",
              hintText: "https://www.pixiv.net/",
              suffixIcon: IconButton(
                onPressed: () => add_tag(controller, focusNode),
                icon: Icon(Icons.add),
              ),
            ),
            validator: (value) =>
                (value == null || value.isEmpty) ? "Link is empty" : null,
          ),
          SizedBox(height: 10),
          Wrap(
            runSpacing: 8,
            spacing: 8,
            children: widget.link_set
                .map(
                  (url) => TextButton(
                    onPressed: () {},
                    style: TextButton.styleFrom(
                      shape: RoundedRectangleBorder(
                        borderRadius: .zero
                      ),
                      foregroundColor: Colors.blue
                    ),
                    child: Row(
                      mainAxisSize: .min,
                      children: [
                        Flexible(child: Text(url.value)),
                        SizedBox(width: 10),
                        IconButton(
                          onPressed: () async {
                            final confirm = await show_yes_no_dialog(
                              context,
                              "Delete Link",
                              'Delete "${url.value}"?',
                            );
                            if (confirm) {
                              setState(() => widget.link_set.remove(url));
                            }
                          },
                          icon: Icon(Icons.delete),
                        ),
                      ],
                    ),
                  ),
                )
                .toList(),
          ),
        ],
      ),
    );
  }

  void add_tag(TextEditingController controller, FocusNode focusNode) {
    if (formKey.currentState!.validate()) {
      NonEmptyString.makeFromString(controller.text).match(
          () {},
          (v) {
          if (!widget.link_set.contains(v)) {
          setState(() {
              widget.link_set.add(v);
              });
          }
          },
          );
      controller.clear();
      focusNode.unfocus();
    }
  }
}
