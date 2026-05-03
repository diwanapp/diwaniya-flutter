import 'package:flutter/material.dart';

abstract final class AppRadius {
  static const double sm = 8;
  static const double md = 12;
  static const double lg = 16;
  static const double xl = 20;
  static const double card = 14;
  static const double sheet = 20;

  static BorderRadius get cardBR => BorderRadius.circular(card);
  static BorderRadius get sheetBR => const BorderRadius.vertical(top: Radius.circular(sheet));
}
