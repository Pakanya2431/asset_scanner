import 'package:flutter/material.dart';

const kPrimary     = Color(0xFF1A56DB);
const kPrimaryDark = Color(0xFF1648BF);
const kBg          = Color(0xFFF0F2F5);
const kCardBg      = Colors.white;
const kGreen       = Color(0xFF16A34A);
const kAmber       = Color(0xFFD97706);
const kRed         = Color(0xFFDC2626);
const kGrayText    = Color(0xFF6B7280);
const kBorder      = Color(0xFFE0E0E0);

const kTextPrimary   = Color(0xFF111827);
const kTextSecondary = Color(0xFF6B7280);
const kTextHint      = Color(0xFFAAAAAA);

ThemeData appTheme() => ThemeData(
  colorScheme: ColorScheme.fromSeed(seedColor: kPrimary),
  scaffoldBackgroundColor: kBg,
  appBarTheme: const AppBarTheme(
    backgroundColor: kPrimary,
    foregroundColor: Colors.white,
    elevation: 0,
    centerTitle: false,
    titleTextStyle: TextStyle(
      fontSize: 18, fontWeight: FontWeight.w600, color: Colors.white),
  ),
  elevatedButtonTheme: ElevatedButtonThemeData(
    style: ElevatedButton.styleFrom(
      backgroundColor: kPrimary,
      foregroundColor: Colors.white,
      minimumSize: const Size.fromHeight(52),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      textStyle:
          const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
    ),
  ),
  useMaterial3: true,
);

BoxDecoration cardDecoration({bool selected = false, Color? borderColor}) =>
    BoxDecoration(
      color: selected ? const Color(0xFFEEF3FE) : kCardBg,
      borderRadius: BorderRadius.circular(12),
      border: Border.all(
        color: borderColor ?? (selected ? kPrimary : kBorder),
        width: selected ? 2 : 0.5,
      ),
    );
