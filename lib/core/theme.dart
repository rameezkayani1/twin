import 'package:flutter/material.dart';

class C {
  static const ink = Color(0xFF1B1F24), soft = Color(0xFF4A5158), bg = Color(0xFFF5F4F1);
  static const line = Color(0xFFE3E1DC), orange = Color(0xFFFF6A13), blue = Color(0xFF2D5F7C);
  static const green = Color(0xFF2E7D57), amber = Color(0xFFB9791B), red = Color(0xFFC7402E), info = Color(0xFFE7EEF2);
}

ThemeData buildTheme() => ThemeData(
      useMaterial3: true,
      scaffoldBackgroundColor: C.bg,
      colorScheme: ColorScheme.fromSeed(seedColor: C.orange, primary: C.orange),
      appBarTheme: const AppBarTheme(
          backgroundColor: C.bg, elevation: 0, scrolledUnderElevation: 0, foregroundColor: C.ink,
          titleTextStyle: TextStyle(fontWeight: FontWeight.w800, fontSize: 20, color: C.ink)),
      inputDecorationTheme: InputDecorationTheme(
          filled: true, fillColor: Colors.white,
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: C.line))),
      elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
              backgroundColor: C.orange, foregroundColor: Colors.white, elevation: 0,
              minimumSize: const Size.fromHeight(50),
              textStyle: const TextStyle(fontWeight: FontWeight.w700),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)))),
    );
