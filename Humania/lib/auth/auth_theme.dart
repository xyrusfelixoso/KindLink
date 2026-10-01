import 'package:flutter/material.dart';

/// Shared visual tokens for every authentication screen.
abstract final class AuthTheme {
  static const pageBackground = Color(0xfffafaf7);
  static const headingColor = Color(0xff263238);
  static const primaryAction = Color(0xff2a7f73);
  static const fieldBorder = Color(0xffd7e5df);
  static const focusedFieldBorder = Color(0xff2a7f73);

  static const compactBreakpoint = 420.0;
  static const contentMaxWidth = 560.0;
  static const fieldRadius = 16.0;
  static const cardRadius = 30.0;
  static const fieldSpacing = 16.0;
  static const actionHeight = 58.0;

  static const titleStyle = TextStyle(
    color: headingColor,
    fontSize: 30,
    fontWeight: FontWeight.bold,
  );

  static InputDecoration fieldDecoration({
    required String hintText,
    required IconData icon,
  }) {
    return InputDecoration(
      hintText: hintText,
      prefixIcon: Icon(icon),
      filled: true,
      fillColor: Colors.white,
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(fieldRadius),
        borderSide: const BorderSide(color: fieldBorder, width: 2),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(fieldRadius),
        borderSide: const BorderSide(color: focusedFieldBorder, width: 2),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(fieldRadius),
        borderSide: const BorderSide(color: Color(0xffd9534f), width: 2),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(fieldRadius),
        borderSide: const BorderSide(color: Color(0xffd9534f), width: 2),
      ),
    );
  }
}
