// lib/ui/input_styles.dart
import 'package:flutter/material.dart';

class AppColors {
  static const primary   = Color(0xFF5B4DF3);
  static const fieldFill = Color(0xFFF2F4FF);  //Color.fromARGB(238, 221, 214, 253);
  static const border    = Color(0xFFCAD1FF);
  static const suffix    = Color(0xFF6F6F79);
}

// ---- uso por campo (helper) ----
OutlineInputBorder _border([Color c = AppColors.border]) =>
    OutlineInputBorder(
      borderRadius: BorderRadius.circular(16),
      borderSide: BorderSide(color: c, width: 1.2),
    );

InputDecoration inputDecoration(
  String hint, {
  Widget? suffixIcon,
  String? helperText,
}) =>
    InputDecoration(
      hintText: hint,
      filled: true,
      fillColor: AppColors.fieldFill,
      contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 18),
      enabledBorder: _border(),
      border: _border(),
      focusedBorder: _border(AppColors.primary),
      helperText: helperText,
      helperStyle: const TextStyle(fontSize: 11.5, color: Color(0xFF8B8B97)),
      suffixIcon: suffixIcon,
    );

// ---- opcional: tema global para todos os TextField/TextFormField ----
class AppInputTheme {
  static OutlineInputBorder border([Color c = AppColors.border]) =>
      OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide(color: c, width: 1.2),
      );

  static final decorationTheme = InputDecorationTheme(
    filled: true,
    fillColor: AppColors.fieldFill,
    contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 18),
    enabledBorder: border(),
    border: border(),
    focusedBorder: border(AppColors.primary),
    helperStyle: const TextStyle(fontSize: 11.5, color: Color(0xFF8B8B97)),
  );
}
