import 'package:flutter/material.dart';
import 'package:tagger/bootstrap.dart';
import 'package:tagger/db/database.dart';
import 'package:tagger/pages/home.dart';
import 'package:toastification/toastification.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  runApp(
    await Database.make_from_data()
        .match(
          () => const MaterialApp(home: Text("Failed to initialize Database!!")),
          (database) => ToastificationWrapper(child: bootstrap(HomePage(database))),
        )
        .run(),
  );
}