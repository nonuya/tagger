import 'package:flutter/material.dart';
import 'package:tagger/bootstrap.dart';
import 'package:tagger/database.dart';
import 'package:tagger/home_page.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  runApp(
    await Database.make_from_data()
        .match(
          () =>
              const MaterialApp(home: Text("Failed to initialize Database!!")),
          (database) => App(database),
        )
        .run(),
  );
}

class App extends StatelessWidget {
  final Database database;

  App(this.database, {super.key});

  @override
  Widget build(BuildContext context) {
    return bootstrap(HomePage(database));
  }
}
