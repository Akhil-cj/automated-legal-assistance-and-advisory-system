import 'package:flutter/material.dart';

final ThemeData customTheme = ThemeData(
  primaryColor: Colors.blueGrey,
  hintColor: Colors.teal,
  brightness: Brightness.dark,
  textTheme: TextTheme(
    displayLarge: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.white),
    bodyLarge: TextStyle(fontSize: 16, color: Colors.white70),
  ),
);
  