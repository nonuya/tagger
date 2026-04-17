import 'package:flutter/material.dart';
import 'package:tagger/theme.dart';

Widget bootstrap(Widget child) => 
  MaterialApp(
      theme: get_app_theme_data(),
      home: Scaffold(
        body: Padding(
          padding: EdgeInsetsGeometry.all(16),
          child: SafeArea(child: child),
        ),
      ),
);
