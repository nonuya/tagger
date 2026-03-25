import 'package:flutter/material.dart';
import 'package:tagger/theme.dart';

void main() {
  runApp(const App());
}

class App extends StatelessWidget {
  const App({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      theme: get_app_theme_data(),
      home: Scaffold(
        body: Padding(
          padding: EdgeInsetsGeometry.all(16),
          child: SafeArea(
            child: Column(
              crossAxisAlignment: .start,
              children: [
                Expanded(
                  flex: 0,
                  child: TextField(
                    decoration: InputDecoration(hintText: "Search by..."),
                  ),
                ),
                SizedBox(height: 10),
                ArtistItem(),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class ArtistItem extends StatelessWidget {
  const ArtistItem({super.key});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Row(
        children: [
          Expanded(
            flex: 1,
            child: SizedBox(
              child: Image.network(
                fit: .fitWidth,
                "https://upload.wikimedia.org/wikipedia/commons/9/94/Tagosaku_to_Mokube_no_Tokyo_Kenbutsu.jpg",
              ),
            ),
          ),
          Expanded(
            flex: 3,
            child: Padding(padding: .all(6), child: buildInnerContent()),
          ),
        ],
      ),
    );
  }

  Widget buildInnerContent() {
    return Column(
      crossAxisAlignment: .start,
      children: [
        Text("Artist Name", style: get_artist_name_style()),
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
                    children: [
                      ElevatedButton(
                        onPressed: () {},
                        style: get_tag_style(),
                        child: Text("Short Tag"),
                      ),
                    ],
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
                    GestureDetector(
                      child: Text(
                        "a",
                        style: get_link_style(),
                      ),
                    ),
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
