import 'package:flutter/material.dart';

ThemeData get_app_theme_data() {
  return ThemeData(
    brightness: .dark,
    inputDecorationTheme: InputDecorationTheme(
      hintStyle: TextStyle(color: Colors.grey[600]),
      border: .none,
      contentPadding: EdgeInsets.symmetric(horizontal: 5),
      focusedBorder: OutlineInputBorder(
        borderRadius: .zero,
        borderSide: BorderSide(color: Colors.blue)
      ),
      filled: true,
      fillColor: Colors.grey[900],
    ),
  );
}

ButtonStyle get_tag_style([Color? borderColor]) {
  return OutlinedButton.styleFrom(
    side: borderColor != null ? BorderSide(color: borderColor, width: 2) : null,
    backgroundColor: Colors.grey[800],
    foregroundColor: const Color.fromRGBO(255, 255, 255, 1),
    padding: .symmetric(vertical: 4, horizontal: 8),
    tapTargetSize: .shrinkWrap,
    minimumSize: .zero,
    textStyle: TextStyle(fontSize: 12)
  );
}

ButtonStyle get_button_icon_style() {
  return OutlinedButton.styleFrom(
    minimumSize: .zero,
    tapTargetSize: .shrinkWrap,
    padding: .all(5)
  );
}

TextStyle get_link_style() {
  return TextStyle(
    color: Color(0xFF00BCD4),
    decoration: TextDecoration.underline,
    decorationColor: Colors.cyan.shade700,
    decorationThickness: 1.5,
  );
}

TextStyle get_artist_name_style() {
  return TextStyle(
    fontSize: 16,
    fontWeight: .bold
  );
}