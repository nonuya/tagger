import 'package:flutter/material.dart';
import 'package:tagger/database.dart';
import 'package:tagger/theme.dart';
import 'package:toastification/toastification.dart';
import 'package:tagger/home_page.dart' as home;
import 'package:tagger/add_page.dart' as add;

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Database.make_from_data()
  .match(
    () => runApp(const MaterialApp(home: Text("Failed to initialize Database!!"))),
    (database) => runApp(App(database))
  )
  .run();
}

class App extends StatelessWidget {
  final controller = PageController(initialPage: 1, keepPage: true);
  final Database database;

  App(this.database, {super.key});

  @override
  Widget build(BuildContext context) {
    return ToastificationWrapper(
      child: MaterialApp(
        theme: get_app_theme_data(),
        home: Scaffold(
          body: Padding(
            padding: EdgeInsetsGeometry.all(16),
            child: SafeArea(
              child: PageView(
                controller: controller,
                children: [buildHomePage(), buildAddPage()],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget buildHomePage() {
    return Column(
      crossAxisAlignment: .start,
      children: [
        Expanded(
          flex: 0,
          child: TextField(
            decoration: InputDecoration(hintText: "Search by..."),
          ),
        ),
        SizedBox(height: 10),
        // home.ArtistItem(test_artist),
      ],
    );
  }

  Widget buildAddPage() {
    return Column(
      crossAxisAlignment: .stretch,
      children: [
        const Text(
          "Add",
          textAlign: .center,
          style: TextStyle(fontWeight: .bold, fontSize: 24),
        ),
        SizedBox(height: 10),
        add.TagForm(),
      ],
    );
  }
}