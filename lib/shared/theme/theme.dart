
import 'package:flutter/material.dart';
import 'package:lockspot/shared/theme/colors.dart';

final appTheme = ThemeData(
  primaryColor: primaryBrown,
  scaffoldBackgroundColor: backgroundLight,
  cardColor: cardBeige,
  textTheme: const TextTheme(
    bodyLarge: TextStyle(color: textDark),
    bodyMedium: TextStyle(color: textDark),
    titleLarge: TextStyle(color: textDark),
  ),
  elevatedButtonTheme: ElevatedButtonThemeData(
    style: ElevatedButton.styleFrom(
      backgroundColor: primaryBrown,
      foregroundColor: Colors.white,
    ),
  ),
  appBarTheme: const AppBarTheme(
    backgroundColor: backgroundLight,
    foregroundColor: textDark,
    elevation: 0,
  ),
  textButtonTheme: TextButtonThemeData(
    style: TextButton.styleFrom(
      foregroundColor: primaryBrown,
    ),
  ),
  inputDecorationTheme: InputDecorationTheme(
    border: OutlineInputBorder(
      borderRadius: BorderRadius.circular(8.0),
    ),
    focusedBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(8.0),
      borderSide: const BorderSide(color: primaryBrown),
    ),
  ),
);
