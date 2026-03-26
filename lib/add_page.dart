import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:tagger/image_extractor.dart';
import 'package:tagger/serializer.dart';
import 'package:tagger/theme.dart';
import 'package:fpdart/fpdart.dart' as fp;
import 'package:toastification/toastification.dart';

final vec_tags = [
  Tag(id: 0, name: .unsafeMake("Tag 1")),
  Tag(id: 1, name: .unsafeMake("Tag 2")),
  Tag(id: 2, name: .unsafeMake("Tag 3")),
  Tag(id: 3, name: .unsafeMake("Tag 4")),
  Tag(id: 4, name: .unsafeMake("Tag 5")),
  Tag(id: 5, name: .unsafeMake("Tag 6")),
];

class TagForm extends StatefulWidget {
  const TagForm({super.key});

  @override
  createState() => _TagForm();
}

class _TagForm extends State<TagForm> {
  final _formKey = GlobalKey<FormState>();
  final Map<NonEmptyString, fp.Option<Uint8List>> map = {};

  @override
  Widget build(BuildContext context) {
    return Form(
      key: _formKey,
      child: Column(
        crossAxisAlignment: .start,
        children: [
          Autocomplete<String>(
            optionsBuilder: (input) {
              return vec_tags
                  .filter(
                    (tag) =>
                        tag.name.value.toLowerCase().startsWith(input.text),
                  )
                  .filter((tag) => !map.containsKey(tag.name))
                  .map((tag) => tag.name.value);
            },
            fieldViewBuilder:
                (context, controller, focusNode, onEditingComplete) {
                  return TextFormField(
                    controller: controller,
                    focusNode: focusNode,
                    decoration: InputDecoration(
                      labelText: "Tag?",
                      hintText: "Write something",
                      suffixIcon: IconButton(
                        onPressed: () {
                          if (_formKey.currentState!.validate()) {
                            NonEmptyString.makeFromString(
                              controller.text,
                            ).match(() {}, (v) {
                              if (!map.containsKey(v)) {
                                setState(() {
                                  map[v] = fp.None();
                                });
                              }
                            });
                            controller.clear();
                            focusNode.unfocus();
                          }
                        },
                        icon: Icon(Icons.add),
                      ),
                    ),
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return "Tag is empty";
                      }
                      return null;
                    },
                  );
                },
          ),
          SizedBox(height: 10),
          Wrap(
            runSpacing: 8,
            spacing: 8,
            children: map.entries
                .map(
                  (e) => OutlinedButton(
                    onPressed: () => showImageModal(e.key),
                    style: get_tag_style(
                      e.value.isSome() ? Colors.green : Colors.red,
                    ),
                    child: Row(
                      mainAxisSize: .min,
                      children: [
                        Text(e.key.value),
                        SizedBox(width: 10),
                        IconButton(
                          onPressed: () => setState(() => map.remove(e.key)),
                          style: get_button_icon_style(),
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

  void showImageModal(NonEmptyString key) {
    final controller = TextEditingController();
    var loading = false;

    final updateImage = (bytes) => setState(() => map[key] = fp.some(bytes));

    showModalBottomSheet(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setState) {
            var image = map
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
                    controller: controller,
                    decoration: InputDecoration(
                      labelText: "Image URL",
                      suffixIcon: IconButton(
                        onPressed: () async {
                          setState(() => loading = true);

                          FocusManager.instance.primaryFocus?.unfocus();
                          await Future.delayed(
                            const Duration(milliseconds: 50),
                          );

                          final res = await get_image_bytes_from_hitomi_url(
                            controller.text,
                          ).run();
                          res.match(
                            (e) => setState(
                              () => toastification.show(title: Text(e), type: .error, autoCloseDuration: const Duration(seconds: 2)),
                            ),
                            (bytes) => updateImage(bytes),
                          );

                          setState(() => loading = false);
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